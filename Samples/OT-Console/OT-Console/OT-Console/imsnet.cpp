/*
	imsnet.cpp

	Basic IMSNet functions
	Functions to find a device, open a device, close it, and send/rcv data

	IMPORTANT!
	
	To use this you MUST link to WinSock32 and you must initialize
	WinSock. It is not done here because you are supposed to only call
	init once from an app and the app may already have network functionality
*/

// Includes ..................................................................

#include "stdafx.h"
#include "ims.h"
#include "imsnet.h"

// Defines ...................................................................

#define _IMSNET_BUF_SIZE (512)	// Our ring buffer size


// Local Variables ...........................................................

static CRITICAL_SECTION m_InputAccess;		// We use a critical section for buffer

static bool m_InputRun = false;				// Thread variables
static HANDLE m_InputThread = INVALID_HANDLE_VALUE;
static DWORD m_InputThreadID;

static SOCKET m_Socket = INVALID_SOCKET;	// Open socket when connected

static BYTE m_IBuffer[_IMSNET_BUF_SIZE];	// Ring buffer for receive
static int m_IHead, m_ITail;


// Local Functions ...........................................................

static DWORD SocketLoop(LPDWORD);
static SOCKET OpenSocket(SOCKADDR_IN *IMSDevice);
static int ImsNetFind(SOCKADDR_IN *,BOOL *,DWORD *);


// Public Functions ..........................................................

// Open/Close
int imsnetOpen()
{
	SOCKADDR_IN IMSDevice;
	BOOL inuse;
	DWORD user;

	if (m_Socket != INVALID_SOCKET)
	{
		printf("IMSNET Device already open!\n");
		return 0;
	}

	// Find it (if we can)
	if (!ImsNetFind(&IMSDevice, &inuse, &user))
		return 0;

	printf("IMSNET Device found.\n");

	if (inuse)
	{
		in_addr addr;

		addr.S_un.S_addr = user;
		printf("IMSNET Device is currenly in use by: %s!\n", inet_ntoa(addr));
		return 0;
	}

	// Open Socket
	m_Socket = OpenSocket(&IMSDevice);
	if (m_Socket == INVALID_SOCKET)
	{
		printf("Could not open IMSNET Device!\n");
		return 0;
	}

	// initialize critical section for input access
	InitializeCriticalSection( &m_InputAccess );

	// Start Our Thread
	m_InputRun = true;
	m_IHead = m_ITail = 0;
	m_InputThread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE) SocketLoop, (void *)-99, 0, &m_InputThreadID);		

	return 1;
}

void imsnetClose()
{
	if (m_Socket != INVALID_SOCKET)
	{
		m_InputRun = false;
		closesocket(m_Socket);
		m_Socket = INVALID_SOCKET;

		WaitForSingleObject(m_InputThread, INFINITE);
		CloseHandle(m_InputThread);
		m_InputThread = INVALID_HANDLE_VALUE;

		DeleteCriticalSection( &m_InputAccess );
	}
}

// Data transmit
void imsnetSendBytes(int len, void *dat)
{
	int nRet = send(m_Socket, (const char *)dat, len, 0);
	if (nRet == SOCKET_ERROR)
	{
		closesocket(m_Socket);
		m_Socket = INVALID_SOCKET;
	}
}

// Data receive
void imsnetFlush()
{
	EnterCriticalSection( &m_InputAccess );
	{
		m_ITail = m_IHead;
	}
	LeaveCriticalSection( &m_InputAccess );
}


bool imsnetIsByte()
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

BYTE imsnetGetByte()
{
	BYTE ret;

	while (! imsnetIsByte());

	EnterCriticalSection( &m_InputAccess );
	{
		ret = m_IBuffer[m_ITail++];
		if (m_ITail >= _IMSNET_BUF_SIZE)
			m_ITail = 0;
	}
	LeaveCriticalSection( &m_InputAccess );

	return ret;
}

// !!!!! Should timeout and return short!
int imsnetGetBytes(int len, void *buf)
{
	BYTE *pb = (BYTE *)buf;

	for (int n= 0 ; n<len ; n++)
		*(pb++) = imsnetGetByte();

	return len;
}


// Local Helper Functions ....................................................


/*
	ImsNetFind

	Find the first IMS Net Device Available
	If found, reports address, rather or not it is currently in use, and
	if in use, the IP address of the current user

	This is a little complicated because it loops through all adapters

	You could just try opening a fixed IP address for OT-2, but this UDP
	discovery method is more future compatible.

	IMPORTANT! WSA Startup must already have been called

	Returns: 0=not found, 1=found
*/

static int 
ImsNetFind( SOCKADDR_IN *IMSDevice,		// OUT: Address found (if any)
			BOOL *inuse,				// OUT: Is the device in use by someone
			DWORD *user )				// OUT: If inuse, by what IP
{
	// Find all the adapters first
	IP_ADAPTER_INFO  *pAdapterInfo;
	ULONG            ulOutBufLen;
	DWORD            dwRetVal;

	// Allocate enough room for one adapter first
	pAdapterInfo = (IP_ADAPTER_INFO *) malloc( sizeof(IP_ADAPTER_INFO) );
	ulOutBufLen = sizeof(IP_ADAPTER_INFO);

	// If the call failed, we allocate more space
	if (GetAdaptersInfo( pAdapterInfo, &ulOutBufLen) != ERROR_SUCCESS) {
		free (pAdapterInfo);
		pAdapterInfo = (IP_ADAPTER_INFO *) malloc ( ulOutBufLen );
	}

	// This call should succeed, but if not, free the memory and set the pointer to null
	if ((dwRetVal = GetAdaptersInfo( pAdapterInfo, &ulOutBufLen)) != ERROR_SUCCESS) {
		free(pAdapterInfo);
		pAdapterInfo = NULL;
	}

	// Now, for either each adapter or IP_ANY, look for IMS-Net
	PIP_ADAPTER_INFO pAdapter = pAdapterInfo;
	do
	{
		// Create a socket and configure it
		SOCKET udpsocket = INVALID_SOCKET;
		do
		{
			// Create a UDP Socket
			udpsocket = socket(AF_INET,	// Address family
							   SOCK_DGRAM,			// Socket type
							   IPPROTO_UDP);		// Protocol
			
			if (udpsocket == INVALID_SOCKET)
				break;

			// Allow address to be reused
			BOOL bOptVal = TRUE;
			int bOptLen = sizeof(BOOL);
			setsockopt(udpsocket, SOL_SOCKET, SO_REUSEADDR, (char*)&bOptVal, bOptLen);

			// Allow broadcasts
			bOptLen = sizeof(BOOL);
			setsockopt(udpsocket, SOL_SOCKET, SO_BROADCAST, (char*)&bOptVal, bOptLen);

			// 1/4 second timeout
			int iOptVal = 250;
			bOptLen = sizeof(int);
			setsockopt(udpsocket, SOL_SOCKET, SO_RCVTIMEO, (char*)&iOptVal, bOptLen);

			// Address structure
			SOCKADDR_IN saServer;

			saServer.sin_family = AF_INET;
			if (!pAdapter)
				saServer.sin_addr.s_addr = INADDR_ANY; // Let WinSock assign address
			else
				saServer.sin_addr.s_addr = inet_addr(pAdapter->IpAddressList.IpAddress.String);
			saServer.sin_port = htons(IMSNET_DISCOVERY);
			IMSDevice->sin_family = AF_INET;
			IMSDevice->sin_addr.s_addr = inet_addr("255.255.255.255");
			IMSDevice->sin_port = htons(IMSNET_DISCOVERY);

			// Bind the port
			int nRet = bind(udpsocket,				// Socket descriptor
						(LPSOCKADDR)&saServer,		// Address to bind to
						sizeof(struct sockaddr));	// Size of address

			if (nRet == SOCKET_ERROR)
			{
				closesocket(udpsocket);
				udpsocket = INVALID_SOCKET;
				break;
			}

			// Construct a Poll Packet
			IMSNET_POLL outblock;
			memset(&outblock, 0, sizeof(outblock));
			strcpy((char *)outblock.ProtoID, IMSNET_PROTO_ID);
			outblock.OpCode = htons(IMSNET_OPCODE_POLL);
			outblock.VersionL = IMSNET_VERSION;

			//Broadcast it
			nRet = sendto(udpsocket, (char *)(&outblock), sizeof(outblock), 0, (LPSOCKADDR)IMSDevice, sizeof(struct sockaddr));
		
			// Wait for data from the IMS Net device (if any)
			// We loop a few times because we'll hear our own echo
			int nLen;
			char szBuf[1024];

			int n;
			for (n = 0 ; n < 3 ; n++)
			{
				memset(szBuf, 0, sizeof(szBuf));
				nLen = sizeof(SOCKADDR);

				nRet = recvfrom(udpsocket,			// Bound socket
							szBuf,					// Receive buffer
							sizeof(szBuf),			// Size of buffer in bytes
							0,						// Flags
							(LPSOCKADDR)IMSDevice,	// Buffer to receive client address 
							&nLen);					// Length of client address buffer

				if (nRet == SOCKET_ERROR || nRet == 0)
				{
					closesocket(udpsocket);
					udpsocket = INVALID_SOCKET;
					break;
				}

				IMSNET_POLLREPLY *reply;
				reply = (IMSNET_POLLREPLY *)szBuf;
				if (!strcmp((char *)reply->ProtoID, IMSNET_PROTO_ID))
				{
					if (reply->OpCode == htons(IMSNET_OPCODE_POLLREPLY))
					{
						if (reply->VersionL == IMSNET_VERSION)
						{
							// The address is in the payload, but it
							// has already been put in our structure by recvfrom
							// above, so just add the port (which is already in network order)
							IMSDevice->sin_port = reply->Port;

							// Check if inuse and copy if nec.
							if (reply->Flags & htons(IMSNET_FLAG_INUSE))
							{
								*inuse = TRUE;
								*user = (DWORD)reply->Info;
							}
							else
							{
								*inuse = FALSE;
								*user = 0;
							}

							closesocket(udpsocket);
							free(pAdapterInfo);
							return 1;
						}
					}
				}
			}

			if (n == 3 || udpsocket == INVALID_SOCKET)
				break;

		} while (0);

		// Just in case it wasn't closed above
		if (udpsocket != INVALID_SOCKET)
			closesocket(udpsocket);

		// Advance (if not already null)
		if (pAdapter)
			pAdapter = pAdapter->Next;
	}
	while (pAdapter);

	// Free the adapter info
	if (pAdapterInfo)
        free(pAdapterInfo);

	// Not found...
	return 0;
}

/*
	SocketLoop

	Background thread for received data while open
*/

DWORD SocketLoop(LPDWORD utype)
{
	BYTE ipacket[256];
	int iRet;

	Sleep(100);

	if (m_Socket != INVALID_SOCKET)
	{
		// To kill us, the foreground will set this to false
		// and abort our socket
		while (m_InputRun)
		{
			iRet = recv(m_Socket, (char *)ipacket, sizeof(ipacket), 0);
			if (iRet == 0 || iRet == SOCKET_ERROR)
				break;

			// Manipulate input buffer
			EnterCriticalSection( &m_InputAccess );
			{
				for (int n=0 ; n < iRet ; n++)
				{
					m_IBuffer[m_IHead++] = ipacket[n];
					if (m_IHead >= _IMSNET_BUF_SIZE)
						m_IHead = 0;

					if (m_IHead == m_ITail)
					{
						m_IHead--;
						if (m_IHead < 0)
							m_IHead = (_IMSNET_BUF_SIZE-1);
					}
				}
			}
			LeaveCriticalSection( &m_InputAccess );
		}
	}

	return 0L;
}


static SOCKET OpenSocket(SOCKADDR_IN *IMSDevice)
{
	SOCKET tcpsocket;

	tcpsocket = socket(AF_INET,				// Address family
						SOCK_STREAM,			// Socket type
						IPPROTO_TCP);		// Protocol
	if (tcpsocket == INVALID_SOCKET)
		return INVALID_SOCKET;

	// Set to Nagel buffering off
	BOOL bOptVal = TRUE;
	int bOptLen = sizeof(BOOL);
	setsockopt(tcpsocket, IPPROTO_TCP, TCP_NODELAY, (char*)&bOptVal, bOptLen);

	// connect to the server
	int nRet = connect(tcpsocket,				// Socket
					(LPSOCKADDR)IMSDevice,	// Client address
					sizeof(struct sockaddr));// Length of server address structure
	if (nRet == SOCKET_ERROR)
	{
		closesocket(tcpsocket);
		return INVALID_SOCKET;
	}

	return tcpsocket;
}
