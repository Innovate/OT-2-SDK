/*
	OT-Console.cpp

	This is a simple console app to exercise the Innovate Motorsports OT-2 
	hardware

	It is actually put together with chunks of other projects, so, alas, 
	it does not really follow a uniform coding/naming style. But I have 
	tried to comment each chunk of borrowed code, at least with a functional 
	explanation at the top.
*/

// Includes ..................................................................

#include "stdafx.h"
#include "imsnet.h"	// Network services
#include "imsusb.h"	// USB services


// Defines ...................................................................

#define _OTC_NONE (0)	// OT Console Connection Type
#define _OTC_USB (1)
#define _OTC_NET (2)


// Local Variables ...........................................................

static int OtcConnection = _OTC_NONE;


// Local Functions ...........................................................

static int OpenConnection();
static void CloseConnection();

static int GetBytes(int len, void *buf);
static void SendByte(unsigned char dat);
static void SendBytes(int len, void *dat);
static void Flush();
static bool IsByte();
static BYTE GetByte();

static void SetupMode();

// Public Functions ..........................................................

/*
	_tmain

	Execution begins here and basically stays in a main loop until we exit if hardware
	is found
	
	Returns: 0 for normal exit, -1 for init error, -255 for 'no hw found'
*/

int _tmain(int argc, _TCHAR* argv[])
{
	printf("OT-Console\n\n");

	// Initialize WinSock
	WORD wVersionRequested = MAKEWORD(2,2);
	WSADATA wsaData;

	// Initialize Winsock
	if (WSAStartup(wVersionRequested, &wsaData) != 0)
	{
		printf("Could not start Socket services!\n");
		return -1;
	}

	// Check version
	if (wsaData.wVersion != wVersionRequested)
	{
		WSACleanup();
		printf("Wrong version for Socket services!\n");
		return -1;
	}

	// Try to open a device
	if (OpenConnection() != _OTC_NONE)
	{
		// Enter Setup Mode
		// Important! setup and expert modes time out, so be careful
		// single stepping in a debugger.
		//
		// Also, the SetupMode function assumes OT-2 and will loop forever
		// if you are connected to something else
		SetupMode();

		// Enter expert mode
		SendBytes(2, "e\x01");
		unsigned char b = GetByte();	// Can take a LONG time! See SDK doc for details

		int n = 0;
		if (b == 1)
		{
			for (n=0 ; n<2000 ; n++)
			{
				SendByte(0xFF);
				b = GetByte();
				if (b != 0xFF)
					break;
			}
		}
		if (n != 2000)
			printf("Expert Mode Error!\n");

		// Dump our current rate
		SendByte('r');
		b = GetByte();

		// Set the rate to 500 Kbit
		SendByte('R');
		SendByte(2);
		b = GetByte();

		// Toggle the LED on, then off
		SendByte('L');
		SendByte(1);
		b = GetByte();

		SendByte('L');
		SendByte(0);
		b = GetByte();

		// Set an 'everything' filter
		SendByte('F');
		SendByte(0);
		SendByte(0);
		SendByte(0);
		SendByte(0);
		SendByte(0);
		SendByte(0);
		SendByte(0);
		SendByte(0);
		b = GetByte();

		// Listen for 250 mS or up to 8 packets
		SendByte('I');
		SendByte(250);
		SendByte(8);

		while (1)
		{
			b = GetByte();
			if (b == 0xFF)
				break;

			if (b)
				printf("ext:");
			else
				printf("std:");

			DWORD d;
			((unsigned char *)(&d))[0] = GetByte();
			((unsigned char *)(&d))[1] = GetByte();
			((unsigned char *)(&d))[2] = GetByte();
			((unsigned char *)(&d))[3] = GetByte();

			printf("%08X ", d);

			b = GetByte();
			for (int i=0 ; i< b ; i++)
			{
				unsigned char c;

				c = GetByte();
				printf("%02x ", c);
			}
			printf("\n");
		}

		// Clear the filter
		SendByte('f');
		b = GetByte();

		// Set 8 Handshake filters
		for (int z=0 ; z < 8 ; z++)
		{
			DWORD dw;

			// What we hear
			dw = 0x7E8+z;

			SendByte('E');
			SendByte((BYTE)(dw &0xFF));
			SendByte((BYTE)((dw >> 8) & 0xFF));
			SendByte((BYTE)((dw >> 16) & 0xFF));
			SendByte((BYTE)((dw >> 24) & 0xFF));

			// Where we reply
			dw = 0x7E0+z;
			SendByte((BYTE)(dw &0xFF));
			SendByte((BYTE)((dw >> 8) & 0xFF));
			SendByte((BYTE)((dw >> 16) & 0xFF));
			SendByte((BYTE)((dw >> 24) & 0xFF));

			b = GetByte();
		}

// O<timeout><replies><ext><id><len><data>
		unsigned char Packet[] = { 'O',		// Ouptut
								   100,		// 100 ms (bigger than normal P2)
								   8,		// Up to 8 responses
								   0,		// Standard mode
								   0xDF, 7, 0, 0, // We'll send on 0x7DF (little endian)
								   8,		// We send 8 bytes (dlc = 8), even though we don't use all of them
								   2, 1, 0, 0, 0, 0, 0, 0 };	// Payload, this is header (2 bytes, one packet)
																// 1 (mode 1)
																// pid 0
		// Send it
		SendBytes(sizeof(Packet), Packet);

		// Print the results
		printf("\n");

		while (1)
		{
			b = GetByte();
			if (b == 0xFF)
				break;

			if (b)
				printf("ext:");
			else
				printf("std:");

			DWORD d;
			((unsigned char *)(&d))[0] = GetByte();
			((unsigned char *)(&d))[1] = GetByte();
			((unsigned char *)(&d))[2] = GetByte();
			((unsigned char *)(&d))[3] = GetByte();

			printf("%08X ", d);

			b = GetByte();
			for (int i=0 ; i< b ; i++)
			{
				unsigned char c;

				c = GetByte();
				printf("%02x ", c);
			}
			printf("\n");
		}

// Now something that normally gets a FC response...
// O<timeout><replies><ext><id><len><data>
		unsigned char Packet2[] = { 'O',		// Ouptut
								   100,		// 100 ms (bigger than normal P2)
								   8,		// Up to 8 responses
								   0,		// Standard mode
								   0xDF, 7, 0, 0, // We'll send on 0x7DF (little endian)
								   8,		// We send 8 bytes (dlc = 8), even though we don't use all of them
								   2, 9, 2, 0, 0, 0, 0, 0 };	// Payload, this is header (2 bytes, one packet)
																// 9 (mode 9)
																// 2 (VIN)
		// Send it
		SendBytes(sizeof(Packet2), Packet2);

		// Print the results
		printf("\n");

		while (1)
		{
			b = GetByte();
			if (b == 0xFF)
				break;

			if (b)
				printf("ext:");
			else
				printf("std:");

			DWORD d;
			((unsigned char *)(&d))[0] = GetByte();
			((unsigned char *)(&d))[1] = GetByte();
			((unsigned char *)(&d))[2] = GetByte();
			((unsigned char *)(&d))[3] = GetByte();

			printf("%08X ", d);

			b = GetByte();
			for (int i=0 ; i< b ; i++)
			{
				unsigned char c;

				c = GetByte();
				printf("%02x ", c);
			}
			printf("\n");
		}

		// Exit Expert Mode
		SendByte('s');

		// Exit Setup Mode
		SendByte('s');

		// Close our connection
		CloseConnection();
	}

	// Cleanup sockets
	WSACleanup();
	return 0;
}

// Helper Functions ..........................................................

// Open/Close Connecitons
static int
OpenConnection()
{
	int rval;

	if (imsnetOpen())
		rval = _OTC_NET;
	else if (imsusbOpen())
		rval = _OTC_USB;
	else
		rval = _OTC_NONE;

	OtcConnection = rval;
	return rval;
}

static void
CloseConnection()
{
	if (OtcConnection == _OTC_NET)
		imsnetClose();
	else if (OtcConnection == _OTC_USB)
		imsusbClose();
}

// Data I/O
static void SendByte(unsigned char dat)
{
	if (OtcConnection == _OTC_NET)
		imsnetSendBytes(1, &dat);
	else
		imsusbSend(1, &dat);
}

static void SendBytes(int len, void *dat)
{
	if (OtcConnection == _OTC_NET)
		imsnetSendBytes(len, (BYTE *)dat);
	else
		imsusbSend(len, (BYTE *)dat);
}

static void Flush()
{
	if (OtcConnection == _OTC_NET)
		imsnetFlush();
	else
		imsusbFlush();
}

static bool IsByte()
{
	if (OtcConnection == _OTC_NET)
		return imsnetIsByte();
	else
		return imsusbIsByte();
}

static BYTE GetByte()
{
	if (OtcConnection == _OTC_NET)
		return imsnetGetByte();
	else
		return imsusbGetByte();
}

static int GetBytes(int len, void *buf)
{
	if (OtcConnection == _OTC_NET)
		return imsnetGetBytes(len, (BYTE *)buf);
	else
		return imsusbGetBytes(len, (BYTE *)buf);
}

// Enter setup mode
// !!!! This will hang if we connected to something other than OT-2
void SetupMode()
{
	// Go into setup mode
	SendByte('S');
	
	// We could be behind, so look for "OT2 "
	while (1)
	{
		unsigned char b = GetByte();
		if (b == 'O')
		{
			b = GetByte();
			if (b == 'T')
			{
				b = GetByte();
				if (b == '2')
				{
					b = GetByte();
					if (b == ' ')
						break;
				}
			}
		}
	}

	// Eat the rest of the header
	for (int i=0 ; i < 9 ; i++)
		GetByte();
}
