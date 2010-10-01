/*
	IMSUSB.cpp
	USB acess snipped from LM-Config hwio.cpp

	Applications probably SHOULD use the helper DLL, but
	we'll do direct driver access here. Note that we use a named
	semaphore to make sure that only one app at a time
	is using USB access.

	Basically opening opens the driver and creates a thread
	for received data, transmitted data is pushed out to the driver
	directly.
*/

// Includes ..................................................................

#include "stdafx.h"
#include <winioctl.h>

#include "imsusbdrv.h"
#pragma warning(disable:4200)
#include "usbdi.h"	// Microsoft DDK
#pragma warning(default:4200)

#include "imsusb.h"


// USB Stuff .................................................................

static HANDLE m_noDuplicateInstanceSemaphore = INVALID_HANDLE_VALUE;

static HANDLE m_Handle = INVALID_HANDLE_VALUE;

// critical section for input access
static CRITICAL_SECTION m_InputAccess;
static bool m_InputRun = false;
static HANDLE m_InputThread = INVALID_HANDLE_VALUE;
static DWORD m_InputThreadID;
static DWORD InputLoop(LPDWORD);

#define _USB_BUF_SIZE 512
static BYTE m_IBuffer[_USB_BUF_SIZE];

static int m_IHead, m_ITail;


// USB Functions .............................................................

int imsusbOpen()
{
	//	Create a named semaphore, which all processes can access.
	m_noDuplicateInstanceSemaphore = 
		CreateSemaphore( NULL, 0, 1, L"LM-2 USB Semaphore");

	//	If we get no handle back, we're in big trouble.
	if ( m_noDuplicateInstanceSemaphore == NULL )
	{
		printf("Error creating LM-2 Semaphore!\n");
		return FALSE;
	}

	//	If the semaphore has already been created, someone already tried to run us.
	//	Exit gracefully
	if( GetLastError() == ERROR_ALREADY_EXISTS ) 
	{
		CloseHandle( m_noDuplicateInstanceSemaphore );
		printf("IMSUSB driver already in use!\n");
		return FALSE;
	}

	// initialize critical section for input access
	InitializeCriticalSection( &m_InputAccess );

	m_Handle = CreateFile( L"\\\\.\\IMSLM2-0",
		GENERIC_WRITE,
		FILE_SHARE_WRITE,
		NULL,
		OPEN_EXISTING,
		0,
		NULL);

	if (m_Handle == INVALID_HANDLE_VALUE)
	{
		DeleteCriticalSection( &m_InputAccess );
		CloseHandle( m_noDuplicateInstanceSemaphore );
		return FALSE;
	}

	DWORD bret;

	// Clear Pipes (just in case)
	ULONG maxpipe = 4;
	ULONG pipe;

	for (pipe = 0; pipe < maxpipe ; pipe++)
	{
		DeviceIoControl(m_Handle, IOCTL_IMSUSB_ABORTPIPE, 
			&pipe, sizeof(pipe), NULL, 0, &bret, NULL);

		DeviceIoControl(m_Handle, IOCTL_IMSUSB_RESETPIPE, 
			&pipe, sizeof(pipe), NULL, 0, &bret, NULL);
	}

	m_InputRun = true;
	m_IHead = m_ITail = 0;
	m_InputThread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE) InputLoop, (void *)-55, 0, &m_InputThreadID);		
	Sleep(150);
	printf("IMSUSB Device Found.\n");
	return TRUE;
}


void imsusbClose()
{
	if (m_Handle != INVALID_HANDLE_VALUE)
	{
		DWORD bret;

		// Clear Pipes (just in case)
		ULONG maxpipe = 4;
		ULONG pipe;

		m_InputRun = false;

		for (pipe = 0; pipe < maxpipe ; pipe++)
		{
			DeviceIoControl(m_Handle, IOCTL_IMSUSB_ABORTPIPE, 
				&pipe, sizeof(pipe), NULL, 0, &bret, NULL);

			DeviceIoControl(m_Handle, IOCTL_IMSUSB_RESETPIPE, 
				&pipe, sizeof(pipe), NULL, 0, &bret, NULL);
		}
		WaitForSingleObject(m_InputThread, INFINITE);
		CloseHandle(m_InputThread);
		m_InputThread = INVALID_HANDLE_VALUE;

		CloseHandle(m_Handle);
		m_Handle = INVALID_HANDLE_VALUE;

		DeleteCriticalSection( &m_InputAccess );
		CloseHandle( m_noDuplicateInstanceSemaphore );
	}
}

void imsusbSend(int len, BYTE *buf)
{
	DWORD bret;

	if (m_Handle != INVALID_HANDLE_VALUE)
	{
		BULK_TRANSFER_CONTROL bc;
		bc.pipeNum = 3;

		DeviceIoControl(m_Handle, IOCTL_IMSUSB_BULK_WRITE, 
		&bc, sizeof(bc), buf, len, &bret, NULL);
	}
}

void imsusbFlush()
{
	EnterCriticalSection( &m_InputAccess );
	{
		m_ITail = m_IHead;
	}
	LeaveCriticalSection( &m_InputAccess );
}

bool imsusbIsByte()
{
	bool ret = false;

	Sleep(0);
	EnterCriticalSection( &m_InputAccess );
	{
		if (m_IHead != m_ITail)
			ret = true;
	}
	LeaveCriticalSection( &m_InputAccess );

	return ret;
}

BYTE imsusbGetByte()
{
	BYTE ret;

	while (! imsusbIsByte());

	EnterCriticalSection( &m_InputAccess );
	{
		ret = m_IBuffer[m_ITail++];
		if (m_ITail >= _USB_BUF_SIZE)
			m_ITail = 0;
	}
	LeaveCriticalSection( &m_InputAccess );

	return ret;
}

// !!!!! Should timeout and return short!
int imsusbGetBytes(int len, BYTE *buf)
{
	for (int n= 0 ; n<len ; n++)
		*(buf++) = imsusbGetByte();

	return len;
}

// USB Input Thread
static DWORD
InputLoop(LPDWORD selection)
{
	BYTE ipacket[64];	// For received input packets
	BULK_TRANSFER_CONTROL bc;	// We use pipe 1 or 6
	bc.pipeNum = 2;

	Sleep(100);

	HANDLE Handle;

	if (selection == (void *)-55)
	{
		// Create our own file handle to the driver
		// This allows us to write to other pipes if nec.
		Handle = CreateFile( L"\\\\.\\IMSLM2-0",
			GENERIC_WRITE,
			FILE_SHARE_WRITE,
			NULL,
			OPEN_EXISTING,
			0,
			NULL);
	}
	else
	{
		// Create our own file handle to the driver
		// This allows us to write to other pipes if nec.
		Handle = CreateFile( L"\\\\.\\IMSOT1-0",
			GENERIC_WRITE,
			FILE_SHARE_WRITE,
			NULL,
			OPEN_EXISTING,
			0,
			NULL);
	}

	// Assuming we got a handle, loop until we are told to quit
	if (Handle != INVALID_HANDLE_VALUE)
	{
//      OutputDebugString("Input Run\n");
		// To kill us, the foreground will set this to false
		// and abort our pipe
		while (m_InputRun)
		{
			DWORD bret;

			// Block until there is a time packet
			if (DeviceIoControl(Handle, IOCTL_IMSUSB_BULK_READ, 
				&bc, sizeof(bc), &ipacket, sizeof(ipacket), &bret, NULL) == 0)
         {
            // Crap! it failed
            CloseHandle(Handle);
//            OutputDebugString("Input Error\n");
            return 0;
         }


			// Manipulate input buffer
			EnterCriticalSection( &m_InputAccess );
			{
				for (DWORD n=0 ; n < bret ; n++)
				{
					m_IBuffer[m_IHead++] = ipacket[n];
					if (m_IHead >= _USB_BUF_SIZE)
						m_IHead = 0;

					if (m_IHead == m_ITail)
					{
						m_IHead--;
						if (m_IHead < 0)
							m_IHead = (_USB_BUF_SIZE-1);
					}
				}
			}
			LeaveCriticalSection( &m_InputAccess );

		}

		CloseHandle(Handle);
	}

//   OutputDebugString("Input Exit\n");
	return 0L;
}
