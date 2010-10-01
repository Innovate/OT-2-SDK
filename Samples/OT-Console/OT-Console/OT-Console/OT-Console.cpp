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
#include <conio.h>
#include "ims.h"		// Basic MTS/OT-2 stuff

#include "imspid.h"		// PID stuff
#include "normpid.h"
#include "NameUnitStrings.h"
#include "MinMax.h"

#include "imsnet.h"		// Network services
#include "imsusb.h"		// USB services

#include "Byte2Mts.h"	// MTS parser class


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

static void PrintMenu();
static void PrintPrompt();

static void SetupMode();

static void ReadConfiguration();
static void SetTempConfiguration();
static void KillTempConfiguration();
static void DumpData();
static void TestCANExpertMode();


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
		// At this point, we expect the device to be in-band, streaming MTS packets
		// so we will throw away data while we are waiting for the user to make a selection
		PrintMenu();

		bool run = true;
		while (run)
		{
			PrintPrompt();

			// Discard MTS stream and look for keystroke
			while (1)
			{
				if (IsByte())
					GetByte();

				if (_kbhit())
					break;
			}

			// Process our keystroke
			switch (_getch())
			{
				case '1':
					printf("Read Config\n\n");
					ReadConfiguration();
					break;

				case '2':
					printf("Set Temp Config\n\n");
					SetTempConfiguration();
					break;

				case '3':
					printf("Kill Temp Config\n\n");
					KillTempConfiguration();
					break;

				case '4':
					printf("Dump Data\n\n");
					DumpData();
					break;

				case '5':
					printf("CAN Expert\n\n");
					TestCANExpertMode();
					break;

				case '?':
					printf ("Menu\n");
					PrintMenu();
					break;

				case 0x1B:
					printf("Exit\n");
					run = false;
					break;

				default:
					printf("Huh?\n");
			}
		}

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

static void PrintMenu()
{
	printf("\nMENU\n");
	printf("<1> Read Configuration\n");
	printf("<2> Set Temp Configuration\n");
	printf("<3> Kill Temp Configuration\n");
	printf("<4> Dump Data\n");
	printf("<5> Test CAN expert mode\n");
	printf("<?> Print this menu\n");
	printf("<ESC> Exit\n");
}

static void PrintPrompt()
{
	printf("\nSelection> ");
}

// Enter setup mode
// !!!! This will hang if we connected to something other than OT-2
void SetupMode()
{
	// Go into setup mode
	SendByte(MTS_SETUPMODE_CMD);
	
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

// Read and dump the configuration
static void ReadConfiguration()
{
	OT_CONFIGURATION otconfig;

	// Enter Setup Mode
	// Important! setup and expert modes time out, so be careful
	// single stepping in a debugger.
	//
	// Also, the SetupMode function assumes OT-2 and will loop forever
	// if you are connected to something else
	SetupMode();

	// Get our current configuration
	SendByte(OT_SETUP_GETCONFIG);
	GetBytes(sizeof(otconfig), &otconfig);

	// Exit Setup Mode
	SendByte(OT_SETUP_EXIT);

	printf("Protocol: ");
	switch (otconfig.Protocol)
	{
		case OT_PROTO_AUTO:
			printf("Automatic\n");
			break;
		case OT_PROTO_CAN:
			printf("CAN\n");
			break;
		case OT_PROTO_PWM:
			printf("PWM\n");
			break;
		case OT_PROTO_VPW:
			printf("VPW\n");
			break;
		case OT_PROTO_ISO:
			printf("ISO\n");
			break;
		default:
			printf("?\n");
			break;
	}

	printf("Channels: %d\n", otconfig.Channels);
	for (int n=0 ; n<otconfig.Channels ; n++)
	{
		// Channel number
		printf("%d: ", n+1);

		// Name
		printf(ObdiiName[otconfig.NormPid[n]]);

		// Priority
		if (otconfig.Flags & (1 << n))
			printf(" (Low Priority)");

		printf("\n");
	}
}

// Set a tempoary coniguration (good for the life of this connection)
// We do this so that the user's settings, which might be hooked to 
// gauges or other products, isn't over written
static void SetTempConfiguration()
{
	OT_CONFIGURATION otconfig;

	printf("Setting temporary configuration\n");

	// Enter Setup Mode
	// Important! setup and expert modes time out, so be careful
	// single stepping in a debugger.
	//
	// Also, the SetupMode function assumes OT-2 and will loop forever
	// if you are connected to something else
	SetupMode();

	// Get our current configuration
	SendByte(OT_SETUP_GETCONFIG);
	GetBytes(sizeof(otconfig), &otconfig);

	printf("Setting channels to 2\n");
	otconfig.Channels = 2;

	// Cars should have MAP or MAF
	// We'll test for MAP and default to MAF
	// This will also fail if no ECU connected
	// You can also do this with the ECU PID bitmask, but that is
	// more complicated
	unsigned short normpid = NORM_PID_MAP;
	SendByte(OT_SETUP_TESTNORMPID);
	SendBytes(2, &normpid);
	unsigned char b = GetByte();

	if (b)
	{
		printf("Setting first channel to MAP\n");
		otconfig.NormPid[0] = NORM_PID_MAP;
	}
	else
	{
		printf("Setting first channel to MAF\n");
		otconfig.NormPid[0] = NORM_PID_MAF;
	}

	// RPM should always be available, so we won't test
	printf("Setting second channel to RPM\n");
	otconfig.NormPid[1] = NORM_PID_RPM;

	SendByte(OT_SETUP_SETMYCONFIG);
	SendBytes(sizeof(otconfig), &otconfig);
	b = GetByte();	// <CR> response

	// Exit Setup Mode
	SendByte(OT_SETUP_EXIT);
}

static void KillTempConfiguration()
{
	printf("Killing temp configuration\n");

	// Enter Setup Mode
	// Important! setup and expert modes time out, so be careful
	// single stepping in a debugger.
	//
	// Also, the SetupMode function assumes OT-2 and will loop forever
	// if you are connected to something else
	SetupMode();

	SendByte(OT_SETUP_KILLMYCONFIG);
	GetByte();	// <CR> response

	// Exit Setup Mode
	SendByte(OT_SETUP_EXIT);
}

// Dump MTS data as parsed packets
// This assumes MTS data is flowing and will hang if it is not
static void DumpData()
{
	printf("Reading and dumping 20 packets of MTS data\n");

	// Yet again, we are going to get our configuration
	// We could do this once and keep it around, but hey, this
	// is a crappy command line tool...
	//
	// Anyway, we want it here so that we know how
	// many of these channels are from the OT-2, not other
	// MTS devices chained before it, and what normalized pid
	// each channel represents

	OT_CONFIGURATION otconfig;

	// Enter Setup Mode
	// Important! setup and expert modes time out, so be careful
	// single stepping in a debugger.
	//
	// Also, the SetupMode function assumes OT-2 and will loop forever
	// if you are connected to something else
	SetupMode();

	// Get our current configuration
	SendByte(OT_SETUP_GETCONFIG);
	GetBytes(sizeof(otconfig), &otconfig);

	// Exit Setup Mode
	SendByte(OT_SETUP_EXIT);

	// Now, let's create an instance of the BYTE to parser class
	Byte2MTS *parser = new Byte2MTS();

	// And loop while we have less than 20 packets received
	int packetcount = 0;
	do
	{
		// Read a byte and feed it in until the parser
		// indicates a received packet. The parser will actuall
		// eat several packets at first to make sure we are really
		// synced to the data stream
		unsigned char b = GetByte();
		if (parser->addByte(b))
		{
			// Make sure it isn't a response to an in-band command
			if (!parser->rxcmdresp)
			{
				// Increment data packet count
				packetcount++;

				// OK, we now have an array of parsed data channels in our parser
				// Let's skip channels that aren't from the OT-2 (if any)
				// OT-2 channels will be last in chain
				int channeloffset = parser->rxpacket.numchans - otconfig.Channels;

				// First we'll dump raw values, this will be 10 bit samples (0-1023)
				printf("RAW: ");

				for (int n=0 ; n < otconfig.Channels ; n++)
					printf("%d ", parser->rxpacket.chan[channeloffset + n].value);
				printf("\n");

				// Now we'll scale to float values for the PID's range
				printf("SCALED: ");

				for (int n=0 ; n < otconfig.Channels ; n++)
				{
					// First we'll figure out the range betweein the channels MIN and MAX
					double min = NormPids[otconfig.NormPid[n]].min;
					double max = NormPids[otconfig.NormPid[n]].max;

					double range = max - min;

					// Now we want to figure out how much range equates to our 10 bit sample
					double value = parser->rxpacket.chan[channeloffset + n].value;

					// We are 0-1023, so we'll divide by 1023.0 and then multiply by the range
					value = (value / 1023.0) * range;

					// Last we'll offset to min value
					value += min;

					printf("%0.2f %s ", value, NormPids[otconfig.NormPid[n]].units);
				}
				printf("\n");
			}
		}
	} while(packetcount < 20);

	// Free our parser
	delete parser;
}

// Helper to dump read CAN packets in expert mode to the screen
static void DumpCANPackets()
{
	// We will get at least an 0xFF from the unit, but
	// we also could get a list of packets
	printf("\n");

	while (1)
	{
		unsigned char b = GetByte();
		if (b == 0xFF)
			break;

		// Packet type
		if (b)
			printf("ext:");
		else
			printf("std:");

		// ID
		DWORD d;
		((unsigned char *)(&d))[0] = GetByte();
		((unsigned char *)(&d))[1] = GetByte();
		((unsigned char *)(&d))[2] = GetByte();
		((unsigned char *)(&d))[3] = GetByte();

		printf("%08X ", d);

		// Get length and dump data
		b = GetByte();
		for (int i=0 ; i< b ; i++)
		{
			unsigned char c;

			c = GetByte();
			printf("%02x ", c);
		}
		printf("\n");
	}
}

// Go into expert mode and try sniffing and some other
// things on the CAN bus
static void TestCANExpertMode()
{
	// Enter Setup Mode
	// Important! setup and expert modes time out, so be careful
	// single stepping in a debugger.
	//
	// Also, the SetupMode function assumes OT-2 and will loop forever
	// if you are connected to something else
	SetupMode();

	// Enter expert mode
	printf("Entering CAN Expert Mode\n");

	SendBytes(2, "e\x01");
	unsigned char b = GetByte();	// Can take a LONG time! See SDK doc for details

	if (b != 1)
	{
		printf("Error entering CAN expert MODE!\n");
		return;
	}

	// Dump our current rate
	SendByte('r');
	b = GetByte();
	printf("Current bitrate is: %d\n", b);

	// Set the rate to 500 Kbit
	SendByte('R');
	SendByte(2);
	b = GetByte();
	printf("Set bitrate to: %d\n", b);

	// Toggle the LED on, then off
	// No particular reason, just because we can...
	printf("Vehicle LED on\n");
	SendByte('L');
	SendByte(1);
	b = GetByte();	// Be sure to eat the response!

	// We want to wait, but we don't want to trigger
	// the timeout by not communicating, so we'll send the keep alive
	// command (0xFF)
	for (int n=0 ; n<1000 ; n++)
	{
		SendByte(0xFF);
		b = GetByte();
		if (b != 0xFF)
		{
			printf("CAN keepalive error!\n");
			return;
		}
	}

	// And off
	printf("Vehicle LED off\n");
	SendByte('L');
	SendByte(0);
	b = GetByte();	// Be sure to eat response!

	// Now let's just 'sniff' the bus for activity
	printf("Sniffing Bus for 250 ms or 8 packets\n");

	// Set an 'everything' filter, get response
	SendBytes(9, "F\x00\x00\x00\x00\x00\x00\x00\x00");
	b = GetByte();

	// Listen for 250 mS or up to 8 packets
	SendByte('I');
	SendByte(250);
	SendByte(8);

	// Dump Can Packets (if any)
	DumpCANPackets();

	// Clear the filter
	SendByte('f');
	b = GetByte();

	// Try to read a PID
	printf("Try reading an OBD-II J1979 PID\n");

	// Set 8 Handshake filters
	// for standard ECU responses
	// Note, it is BETTER, network/speed wise, to use
	// SendBytes for a constructed message, but
	// I used SendByte here for clarity of what is being
	// constructed.
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

	// Now we'll send output, and look for a response
	// This time we construct a packet and send it in one swoop
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
	DumpCANPackets();

	// Now something that normally gets a Flow control response...
	printf("Try to read VIN (not available on all vehicles)\n");

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
	DumpCANPackets();

	// Exit Expert Mode
	SendByte(OT_SETUP_EXIT);

	// Exit Setup Mode
	SendByte(OT_SETUP_EXIT);
}
