/*
	OT2.mm
 
	This is a 'singleton' object (only one!) that interfaces
	to the Innovate Motorsports OT-2
 
	The general model is 'background', 'autonomous', and 'asynchronous'.
 
	It takes care of finding, connecting, syncing, and extracting data,
	then sends notificaitons on important events.
 
	Similarly, you can make requests of it, but you only know of the
	results via a notification.
*/

#define KILLBATTERY	// Comment out to let hybernation work normally

// Discovery loops through all adapters and uses UDP
// broadcasts, this is the recommended way find an IMS Net device
// and connect to it, but if you comment out the following, the
// OT-2 static IP address and port will be used.

#define DISCOVERY	// Comment out to use static IP and port

#import "NetworkDiscovery.h"
#import "ot2.h"

// Forward references ........................................................

@interface OT2 (PrivateMethods)
- (void)waitForThreadToFinish;
- (void)run:(id)info;
@end


@implementation OT2

static OT2 *Ot2Instance = nil;	// Our only instance


// Public Interface ..........................................................

/*
	+instance
 
	Accesses our only instance of the OT2 object

    One way to handle that would be to make ourselves a global in
	the app delegate, then find the app delegate and access us that
	way.
 
	This is closer to the way the other language implementations
	of this object work.
*/

+ (OT2 *)instance 
{
	
	@synchronized(self) 
	{
		if(!Ot2Instance)
			Ot2Instance = [[OT2 alloc] init];
	}
	
	return Ot2Instance;
}

/*
	start
 
	Start our thread and get things going
*/

- (void)start 
{
	// Are we already running
    if (Ot2Thread != nil) 
		return;

    // Create a parser
	Ot2MtsParser = new Byte2MTS();
	
	Ot2ChannelMap = new ChannelMap();
	
	// A mutex to protect shared data
	Ot2Mutex = [NSLock new];
	
	// No devices
	Ot2DeviceCount = 0;
	Ot2PendingCmd = Ot2CompletedCmd = OT2_CMD_NONE;
	
	// Ot2
	// Start our thread
    Ot2Thread = [[NSThread alloc] initWithTarget:self selector:@selector(run:) object:nil];
    [Ot2Thread start];
}

/*
	stop
 
	Stop our thread and kill our lone instance
*/

- (void)stop 
{
	if (Ot2Thread != nil) 
	{
		[Ot2Thread cancel];
		[self waitForThreadToFinish];
		[Ot2Thread release];
		
		[Ot2Mutex release];
		
		delete Ot2MtsParser;
		delete Ot2ChannelMap;
	}
	
	if (Ot2Instance)
		[Ot2Instance release];
}

/*
	state
 
	Get the current state of the object
*/

- (OT2_STATE)state 
{
	OT2_STATE s;
	
	[Ot2Mutex lock];
	s = Ot2State;
	[Ot2Mutex unlock];
	
	return s;
}

/*
	deviceCount
 
	Get the current deviceCount
*/

- (int)deviceCount
{
	int d;
	
	[Ot2Mutex lock];
	d = Ot2DeviceCount;
	[Ot2Mutex unlock];
	
	return d;
}

/*
	deviceTypes:
 
	Fetch the device types into a buffer
*/

- (void)deviceTypes: (MTS_DEVICE_TYPE *)dtypes
{
	[Ot2Mutex lock];
	memcpy(dtypes, Ot2DeviceTypes, sizeof(Ot2DeviceTypes));
	[Ot2Mutex unlock];
}

/*
	deviceNames:
 
	Fetch the device names into a buffer
*/

- (void)deviceNames: (MTS_DEVICE_NAME *)dnames
{
	[Ot2Mutex lock];
	memcpy(dnames, Ot2DeviceNames, sizeof(Ot2DeviceNames));
	[Ot2Mutex unlock];
}


/*
	wifiInfo:
 
	Fetch the wifi info
*/

- (void)wifiInfo: (OT_WIFI_SETTINGS *)winfo
{
	[Ot2Mutex lock];
	memcpy(winfo, &Ot2WiFiSet, sizeof(Ot2WiFiSet));
	[Ot2Mutex unlock];	
}

/*
	otConfig:
 
	Fetch the current OTx configuration
*/

- (void)otConfig: (OT_CONFIGURATION *)oconfig
{
	[Ot2Mutex lock];
	memcpy(oconfig, &Ot2Config, sizeof(Ot2Config));
	[Ot2Mutex unlock];		
}

/*
	sdk
 
	Get the SDK availability flag
*/

- (bool)sdk
{
	bool b;
	
	[Ot2Mutex lock];
	b = Ot2SdkAvailable;
	[Ot2Mutex unlock];
	
	return b;
}

/*
	getPidName
 
	Fetch the name of a pid as an NSString (caller must free!)
*/

- (NSString *)getPidName: (U16)pid;	// Name of a PID
{
	[Ot2Mutex lock];
	NSString *valStr = [[NSString alloc] initWithCString:Ot2ChannelMap->ChannelMapGetPidName(pid)];
	[Ot2Mutex unlock];
	
	return valStr;
}


/*
	channelCount
 
	Get the number of channels
*/

- (U16)channelCount
{
	U8 count;
	
	if ([self state] != OT2_CONNECTED)
		return 0;
	[Ot2Mutex lock];
	count = Ot2ChannelMap->ChannelMapGetCount();
	[Ot2Mutex unlock];
	return (U16)count;
}


/*
	channelName:
 
	Get the Channel name
 
	Returns: NSString * (callers responsibilty to release!)
*/

 - (NSString *)channelName: (U16)channel
{
	[Ot2Mutex lock];
	NSString *valStr = [[NSString alloc] initWithCString:Ot2ChannelMap->ChannelMapGetName(channel)];
	[Ot2Mutex unlock];
	
	return valStr;
}

/*
	channelUnits:
 
	Get the Channel units (imperial or metric)
 
	Returns: NSString * (callers responsibilty to release!)
*/

- (NSString *)channelUnits: (U16)channel isImperial:(bool)imperial isAFR:(bool)afr
{
	NSString *valStr;
	[Ot2Mutex lock];

	// Default to gasoline if no type is set
	if (afr == YES)
	{
		if (!Ot2LastPacket.afrmult)
			Ot2LastPacket.afrmult=147;
	}
	else
		Ot2LastPacket.afrmult = 0;
	
	if (imperial == YES)
			valStr = [[NSString alloc] initWithCString:Ot2ChannelMap->ChannelMapGetUnits(channel, 1,
																						 Ot2LastPacket.afrmult)];
		else
			valStr = [[NSString alloc] initWithCString:Ot2ChannelMap->ChannelMapGetUnits(channel, 0,
																						 Ot2LastPacket.afrmult)];
	[Ot2Mutex unlock];
	
	return valStr;
}

/*
	channelValue
 
	Get the current Channel value (imperial or metric)
	
	Returns: NSString * (callers responsibilty to release!)
*/

- (NSString *)channelValue: (U16)channel isImperial:(bool)imperial isAFR:(bool)afr
{
	NSString *valStr;
	[Ot2Mutex lock];
	
	// Default to gasoline if no type is set
	if (afr == YES)
	{
		if (!Ot2LastPacket.afrmult)
			Ot2LastPacket.afrmult=147;
	}
	else
		Ot2LastPacket.afrmult = 0;
	
	if (imperial == YES)
		valStr = [[NSString alloc] initWithCString:Ot2ChannelMap->ChannelMapValueString(channel, 
																	Ot2LastPacket.chan[channel].value,
																	Ot2LastPacket.chan[channel].func, 1,
																	Ot2LastPacket.afrmult)];
	else
		valStr = [[NSString alloc] initWithCString:Ot2ChannelMap->ChannelMapValueString(channel, 
																	Ot2LastPacket.chan[channel].value, 
																	Ot2LastPacket.chan[channel].func, 0,
																	Ot2LastPacket.afrmult)];
	[Ot2Mutex unlock];
	
	return valStr;	
}

/*
	channelRaw: 
 
	Fetch a raw sample for a channel (0 to  (ChannelCount -1))
 
	Returns: Sample (0-1023, or 0 if bad channel)
*/

- (U16)channelRaw: (U16)channel
{
	if (channel >= [self channelCount])
		return 0;
	
	U16 sample;
	
	[Ot2Mutex lock];
	sample = Ot2LastPacket.chan[channel].value;
	[Ot2Mutex unlock];
	
	return sample;
}


/*
	channelFunction: 
 
	Fetch the current function for a channel
	Needed for AFR channels

	Returns: U16 (see MTS_FUNC_xxx defines in ims.h)
*/

- (U16)channelFunction: (U16)channel
{
	if (channel >= [self channelCount])
		return 0;
	
	U16 function;
	
	[Ot2Mutex lock];
	function = Ot2LastPacket.chan[channel].func;
	[Ot2Mutex unlock];
	
	return function;
}

/*
	commandRequest:
 
	Request that a command be executed
*/

- (void)commandRequest: (OT2_CMD)command
{
	bool b=NO;
	
	// If we are connected, we'll set the request for the
	// OT-2 thread. If not, we'll issue a failure and notification here
	[Ot2Mutex lock];
	if (Ot2State == OT2_CONNECTED)
		Ot2PendingCmd = command;
	else
	{
		Ot2CompletedCmd = command;
		Ot2CmdResult = NO;
		strcpy((char *)Ot2CmdData, "No OT-2 Connected");
		b=YES;
	}
	[Ot2Mutex unlock];

	// Go ahead and post failure
	if (b==YES)
		[[NSNotificationCenter defaultCenter] postNotificationName:OT2_NOTIFICATION_CMD
															object:self];
}


- (void)commandRequest: (OT2_CMD)command withData: (void *)data ofSize: (U16)size;
{
	bool b=NO;
	
	// If we are connected, we'll set the request for the
	// OT-2 thread. If not, we'll issue a failure and notification here
	[Ot2Mutex lock];
	if (Ot2State == OT2_CONNECTED)
	{
		Ot2PendingCmd = command;
		memcpy(Ot2PendingData, data, size);
	}
	else
	{
		Ot2CompletedCmd = command;
		Ot2CmdResult = NO;
		strcpy((char *)Ot2CmdData, "No OT-2 Connected");
		b=YES;
	}
	[Ot2Mutex unlock];
	
	// Go ahead and post failure
	if (b==YES)
		[[NSNotificationCenter defaultCenter] postNotificationName:OT2_NOTIFICATION_CMD
															object:self];
}

/*
	commandGetResponse:

	Get the results from the last command.
	Generally assumed that you will be calling
	this from the Cmd notification.

	Returns: YES=valid response fetced (though response could be 'failure',
		     NO=no response retrieved.
*/

- (bool)commandGetResponse: (OT2_CMD_RESPONSE *)response
{
	bool b;
	
	[Ot2Mutex lock];
	if (Ot2CompletedCmd != OT2_CMD_NONE)
	{
		response->command = Ot2CompletedCmd;
		Ot2CompletedCmd = OT2_CMD_NONE;
		response->result = Ot2CmdResult;
		memcpy(response->data, Ot2CmdData, sizeof(Ot2CmdData));
		b = YES;
	}
	else
		b = NO;
	[Ot2Mutex unlock];
	
	return b;

}

// Private Functions .........................................................

/*
	waitForThreadToFinish
 
    Yield on current thread while the OT2 thread terminates
*/

- (void)waitForThreadToFinish 
{
    while (Ot2Thread && ![Ot2Thread isFinished])
        [NSThread sleepForTimeInterval:0.1];
}


/*
	postStateChange
 
	Post a notification of our current state
 
	We have this split out so we can run it on the main thread
    We also do a terrible kludge here to keep from going into hybernation
    but trying not to constantly kill the poor user's batter
*/

- (void)postState
{
	[[NSNotificationCenter defaultCenter] postNotificationName:OT2_NOTIFICATION_STATE
														object:self];
#ifdef KILLBATTERY
	// If we are connected, turn off hibernation, otherwise, turn it back on
	if ([self state] == OT2_CONNECTED)
		[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	else 
		[[UIApplication sharedApplication] setIdleTimerDisabled:NO];
#endif
}

/*
	postNewPacket
 
	Post a notification that we have new data
 
	We have this split out so we can run it on the main thread
*/

- (void)postNewPacket
{
	[[NSNotificationCenter defaultCenter] postNotificationName:OT2_NOTIFICATION_PACKET
														object:self];
}


/*
	postCmdComplete
 
	Post a notification that we have finished processing a command
 
	We have this split out so we can run it on the main thread
*/

- (void)postCmdComplete
{
	[[NSNotificationCenter defaultCenter] postNotificationName:OT2_NOTIFICATION_CMD
														object:self];
}


/*
	setState
 
	Set our currrent state with Mutex protection
*/

- (void)setState: (OT2_STATE)state
{
	[Ot2Mutex lock];
	Ot2State = state;
	[Ot2Mutex unlock];
	[self performSelectorOnMainThread:@selector(postState) 
						   withObject:nil 
						waitUntilDone:NO];		
}


/*
	setSdk
 
	Set our SDK available flag
*/

- (void)setSdk: (bool)state
{
	[Ot2Mutex lock];
	Ot2SdkAvailable = state;
	[Ot2Mutex unlock];
}



/*
	saveDeviceTypesFromBlock: ofLength:
 
	Save the Device Type info with Mutex protection.
	Also figures out number of devices
*/

- (void)saveDeviceTypesFromBlock: (U8 *)block ofLength: (U16)length
{
	[Ot2Mutex lock];
	Ot2DeviceCount = length / sizeof(MTS_DEVICE_TYPE);
	if (Ot2DeviceCount <= MTS_MAX_DEVICE)
		memcpy(Ot2DeviceTypes, block, length);
	else
		Ot2DeviceCount = 0;
	[Ot2Mutex unlock];
}


/*
	saveDeviceNamesFromBlock: ofLength:
 
	Save the Device Names with Mutex protection.
*/

- (void)saveDeviceNamesFromBlock: (U8 *)block ofLength: (U16)length
{
	[Ot2Mutex lock];
	if (length <= (sizeof(MTS_DEVICE_NAME) * MTS_MAX_DEVICE))
		memcpy(Ot2DeviceNames, block, length);
	else
		memset(Ot2DeviceNames, 0, sizeof(Ot2DeviceNames));
	[Ot2Mutex unlock];
}
		
		
// We need BSD Sockets from here on...
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <unistd.h>
#include <fcntl.h>
#include <netdb.h>
#include <sys/ioctl.h>
#include <net/if.h>

#include "ims.h"

// Yes, like WinSock, but kind of nice
typedef int SOCKET;
typedef struct sockaddr_in SOCKADDR_IN;
typedef struct sockaddr SOCKADDR;

#define INVALID_SOCKET (-1)
#define SOCKET_ERROR (-1)

/*
	findOT2:
 
	Look for an OT-2 via UDP broadcast, the top function (withAddr: version)
	Actually sends via a specific adapter.
 
	The bottom function (the one we call) is the outer loop, it loops through
	all interfaces on the iPhone. Finding them all is done with iocnt, which 
	I have used	before, but I lifted the 'find all adapters' code direct from 
	iPhone Advanced Projects (Apress), and then just tweaked it for our purposes.
 
    Returns: YES or NO
*/


- (bool)findOT2: (SOCKADDR_IN *)IMSDevice withAddr: (SOCKADDR_IN *)addr
{
	// Create a socket and configure it
	SOCKET udpsocket = INVALID_SOCKET;
	
	do {	// Poor Man's Try
		// Create a UDP Socket
		udpsocket = socket(AF_INET,				// Address family
						   SOCK_DGRAM,			// Socket type
						   IPPROTO_UDP);		// Protocol
		
		if (udpsocket == INVALID_SOCKET)
			break;
		
		// Allow address to be shared
		int bOptVal = 1;
		int bOptLen = sizeof(int);

		if (setsockopt(udpsocket, SOL_SOCKET, SO_REUSEADDR, (char*)addr, sizeof(SOCKADDR_IN)) == SOCKET_ERROR)
			break;

		// Allow broadcasts		
		if (setsockopt(udpsocket, SOL_SOCKET, SO_BROADCAST, (char*)&bOptVal, bOptLen) == SOCKET_ERROR)
			break;
		
		// 1/5 second timeout
		struct timeval time;
		time.tv_sec = 0;
		time.tv_usec = 200000;
		bOptLen = sizeof(time);

		if (setsockopt(udpsocket, SOL_SOCKET, SO_RCVTIMEO, (char*)&time, bOptLen) == SOCKET_ERROR)
			break;
		
		// Bind to the specified addapter
		if (bind(udpsocket, (SOCKADDR *)addr, sizeof(SOCKADDR)) == SOCKET_ERROR)
			break;		
				
		// We want to broadcast
		IMSDevice->sin_family = AF_INET;
		IMSDevice->sin_addr.s_addr = htonl(INADDR_BROADCAST);
		IMSDevice->sin_port = htons(IMSNET_DISCOVERY);

		// Construct a Poll Packet
		IMSNET_POLL outblock;
		memset(&outblock, 0, sizeof(outblock));
		strcpy((char *)outblock.ProtoID, IMSNET_PROTO_ID);
		outblock.OpCode = htons(IMSNET_OPCODE_POLL);
		outblock.VersionL = IMSNET_VERSION;

		//Send to ourselves first to make sure that the socket is bound to the right address
		int nRet = sendto(udpsocket, (char *)(&outblock), sizeof(outblock), 0, (SOCKADDR *)addr, sizeof(struct sockaddr));
		
		//Broadcast it
		nRet = sendto(udpsocket, (char *)(&outblock), sizeof(outblock), 0, (SOCKADDR *)IMSDevice, sizeof(struct sockaddr));
		
		// Wait for data from the IMS Net device (if any)
		unsigned int nLen;
		char szBuf[128];
		
		memset(szBuf, 0, sizeof(szBuf));
		nLen = sizeof(SOCKADDR);
		
		nRet = recvfrom(udpsocket,				// Bound socket (from sendto above)
						szBuf,					// Receive buffer
						sizeof(szBuf),			// Size of buffer in bytes
						0,						// Flags
						(SOCKADDR *)IMSDevice,	// Buffer to receive client address 
						&nLen);					// Length of client address buffer
		
		// We don't care why we got an error (timeout, whatever)
		if (nRet == SOCKET_ERROR || nRet == 0)
			break;
		
		// Is what we received a valid Poll Reply?
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
					
					// We're done with the socket, rather we are going to return
					// Yes or No.
					close(udpsocket);
					
					// Check if inuse
					// We just fail here, but you could tell the user that one
					// is present, but being used. You could also use this to check
					// for recovery and timout from a failed prior connection.
					// If inuse is set, the extra DWORD contains the IP address of
					// the current user
					if (reply->Flags & htons(IMSNET_FLAG_INUSE))
						return NO;
					else
						return YES;
				}
			}
		}
		
	} while (0);
	
	// If we fell through, we might need to close the socket
	if (udpsocket != INVALID_SOCKET)
		close(udpsocket);

	return NO;
}

// High level version, loops through all adapters (or just fakes 'yes' for the fixed address
// if DISCOVERY is turned off at the top of this file
- (bool)findOT2: (SOCKADDR_IN *)IMSDevice
{
#ifdef DISCOVERY
	short flags_on = IFF_BROADCAST | IFF_UP;
	short flags_off = IFF_POINTOPOINT | IFF_LOOPBACK;

	// We want on/broadcast, and not PtoP or Loopback addresses only
	for(NSDictionary* iface in [NetworkDiscovery interfaceNamesAddresses]) 
	{
		NSString* iface_name = [iface objectForKey:@"name"];
		short iface_flags = [NetworkDiscovery interfaceFlags:iface_name];
		if (((iface_flags & flags_on) == flags_on) && !(iface_flags & flags_off)) 
		{
			NSNumber* iface_addr = (NSNumber*)[iface objectForKey:@"address"];
			SOCKADDR_IN saddr;

			memset(&saddr, 0, sizeof(saddr));
			saddr.sin_family = AF_INET;
			saddr.sin_addr.s_addr = htonl([iface_addr longValue]);
			saddr.sin_port = 0;
			
			if ([self findOT2:IMSDevice withAddr: &saddr] == YES)
				return YES;
		}
	}
	
	return NO;
#else
	memset(IMSDevice, 0, sizeof(SOCKADDR_IN));
	IMSDevice.sin_family = AF_INET;
	IMSDevice.sin_addr.s_addr = htonl(IMSNET_FIXED_IP);
	IMSDevice.sin_port = htons(IMSNET_FIXED_SERVICE);	
	return YES;
#endif
}


/*
	connectToOT2:
 
	Try to open a TCP socket to the OT-2
	Returns: YES or NO
*/


- (bool)connectToOT2: (SOCKADDR_IN *)IMSDevice 
{
	do
	{
		Ot2Socket = socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);
		if (Ot2Socket == INVALID_SOCKET)
			return NO;

		// No Nagle
		int bOptVal = 1;
		int bOptLen = sizeof(int);
		
		if (setsockopt(Ot2Socket, IPPROTO_TCP, TCP_NODELAY, (char*)&bOptVal, bOptLen) == SOCKET_ERROR)
			break;
		
		// 5 second timeout
		struct timeval time;
		time.tv_sec = 5;
		time.tv_usec = 0;
		bOptLen = sizeof(time);
		
		if (setsockopt(Ot2Socket, SOL_SOCKET, SO_RCVTIMEO, (char*)&time, bOptLen) == SOCKET_ERROR)
			break;
		
		// Try to connect
		if (connect(Ot2Socket, (SOCKADDR *)IMSDevice, sizeof(SOCKADDR_IN)) != SOCKET_ERROR)
			return YES;

	} while(0);

	close(Ot2Socket);
	Ot2Socket = INVALID_SOCKET;
	return NO;
}

/*
	getByte
 
	Fetch a byte from the socket 
 
	If we fail reset the state engine and 
	return NO
 
	Returns: NO, YES (val = byte recieved)
*/

- (bool)getByte:(U8 *)val
{
	int rval;
	
	rval = recv(Ot2Socket, val, 1, 0);
	if ((rval == SOCKET_ERROR) || (rval == 0))
	{
		close(Ot2Socket);
		Ot2Socket = INVALID_SOCKET;
		[self setState: OT2_DISCONNECTED];
		return NO;
	}	

	return YES;
}

/*
	putByte
 
	Send a byte to the socket
 
	If we fail, reset the state and and return
	NO
 
	Returns: NO, YES
*/

- (bool)putByte: (U8)val
{
	if (send(Ot2Socket,&val, 1, 0) == SOCKET_ERROR)
	{
		close(Ot2Socket);
		Ot2Socket = INVALID_SOCKET;
		[self setState: OT2_DISCONNECTED];
		return NO;
	}

	return YES;
}


/*
	setupMode
 
	Enter setup mode (if possible)
 
	If we fail, the state is reset
 
	Returns: NO, YES
*/

- (bool)setupMode
{
	char dtype[4];
	
	// Don't enter Setup Mode if we don't know the device!
	if ([self sdk] == NO)
		return NO;
	
	// Copy the device type so we can compare against it
	[Ot2Mutex lock];
	memcpy(dtype, &(Ot2DeviceTypes[Ot2DeviceCount-1].devtype), sizeof(dtype));
	[Ot2Mutex unlock];
	
	// Send the MTS command
	if ([self putByte: MTS_SETUPMODE_CMD] == NO)
		return NO;
	
	while (1)
	{
		U8 b;
		
		// Keep reading until we get the "OTxx" part of the setup response
		// We could also compare the version, but 4 seems error resistant
		// enough
		if ([self getByte: &b] == NO)
			return NO;
		else if (b == dtype[0])
		{
			if ([self getByte: &b] == NO)
				return NO;
			else if (b == dtype[1])
			{
				if ([self getByte: &b] == NO)
					return NO;
				else if (b == dtype[2])
				{
					if ([self getByte: &b] == NO)
						return NO;
					else if (b == dtype[3])
					{
						// Read the rest of the Setup mode response
						for (int n=0 ; n<9 ; n++)
							if ([self getByte: &b] == NO)
								return NO;
						
						// We should be ready for commands!
						return YES;
					}
				}
			}
		}
	}
}


/*
	setupExit
 
	Exit setup mode (if possible)
 
	If we fail, the state is reset
 
	Returns: NO, YES
*/

- (bool)setupExit
{		
	// Send the MTS command
	if ([self putByte: MTS_SETUPEXIT_CMD] == NO)
		return NO;

	return YES;
}


/*
	getCommandValue
 
	Send a command and fetch a designated number of bytes
 
	If we fail, we went disconnected
 
	Returns: NO, YES
*/

- (bool)getCommandValue: (U8)command ofSize: (U16)vsize to: (void *)dest
{	
	U8 buf[vsize];
	
	// Send the MTS command
	if ([self putByte: command] == NO)
		return NO;
	
	// Try to fetch the response
	for (int n=0 ; n < vsize ; n++)
	{
		U8 b;
		
		if ([self getByte: &b] == NO)
			return NO;
		
		buf[n] = b;
	}
	
	// Save it (if we got it)
	[Ot2Mutex lock];
	memcpy(dest, buf, vsize);
	[Ot2Mutex unlock];
	
	return YES;
}


/*
	setTempConfig:
 
	Set a temporary configuration from a buffer
 
	If we fail, we went disconnected
 
	Returns: NO, YES
*/

- (bool)setTempConfig: (U8 *)configuration
{	
	U8 b;
	
	// Send the MTS command
	if ([self putByte: OT_SETUP_SETMYCONFIG] == NO)
		return NO;
	
	// Try to put the configuration
	for (int n=0 ; n < sizeof(OT_CONFIGURATION) ; n++)
	{
		if ([self putByte:configuration[n]] == NO)
			return NO;
	}

	// Get the response
	if ([self getByte: &b] == NO)
		return NO;
	
	// Save it (if we got it)
	[Ot2Mutex lock];
	Ot2CmdData[0] = b;
	Ot2State = OT2_SYNCING;	// Refetch the config and build channels
	[Ot2Mutex unlock];
	
	return YES;
}

/*
	setConfig:
 
	Set the permanent configuration from a buffer
 
	If we fail, we went disconnected
 
	Returns: NO, YES
*/

- (bool)setConfig: (U8 *)configuration
{	
	U8 b;
	
	// Send the MTS command
	if ([self putByte: OT_SETUP_SETCONFIG] == NO)
		return NO;
	
	// Try to put the configuration
	for (int n=0 ; n < sizeof(OT_CONFIGURATION) ; n++)
	{
		if ([self putByte:configuration[n]] == NO)
			return NO;
	}
	
	// Get the response
	if ([self getByte: &b] == NO)
		return NO;
	
	// Save it (if we got it)
	[Ot2Mutex lock];
	Ot2CmdData[0] = b;
	Ot2State = OT2_SYNCING;	// Refetch the config and build channels
	[Ot2Mutex unlock];
	
	return YES;
}

/*
	doCommands:
 
	Process and command requests
*/

// Helpers
- (void)ModeGood
{
	[self setupExit];
	[Ot2Mutex lock];
	Ot2CmdResult = YES;
	[Ot2Mutex unlock];	
}

- (void)ModeError
{
	[Ot2Mutex lock];
	Ot2CmdResult = NO;
	strcpy((char *)Ot2CmdData, "Could not enter configuration mode on OT-2");			
	[Ot2Mutex unlock];	
}

- (void)doCommands: (OT2_CMD)cmd
{
	// Some of this could be combined into a smarter parser,
	// but this makes it easy to trace a single command
	if (cmd == OT2_CMD_CONNECT_STATE)
	{
		if (([self setupMode] == YES) && ([self getCommandValue:OT_SETUP_CONSTATUS 
														 ofSize:sizeof(OT_CONNECTION_STATUS) 
															 to:Ot2CmdData] == YES))
			[self ModeGood];
		else
			[self ModeError];
	}
	else if (cmd == OT2_CMD_GET_DTCS)
	{ 
		if (([self setupMode] == YES) && ([self getCommandValue:OT_SETUP_GETDTCS 
														 ofSize:sizeof(OT_GET_DTCS) 
															 to:Ot2CmdData] == YES))
			[self ModeGood];
		else
			[self ModeError];
	}
	else if (cmd == OT2_CMD_CLEAR_DTCS)
	{
		if (([self setupMode] == YES) && ([self getCommandValue:OT_SETUP_CLEARDTCS 
														 ofSize:sizeof(OT_CLEAR_DTCS) 
															 to:Ot2CmdData] == YES))
			[self ModeGood];
		else
			[self ModeError];
	}
	else if (cmd == OT2_CMD_GET_VIN)
	{
		if (([self setupMode] == YES) && ([self getCommandValue:OT_SETUP_GETVIN 
														 ofSize:sizeof(OT_GET_VIN) 
															 to:Ot2CmdData] == YES))
			[self ModeGood];
		else
			[self ModeError];
	}
	else if (cmd == OT2_CMD_TEMP_CONFIG)
	{
		if (([self setupMode] == YES) && ([self setTempConfig: Ot2PendingData] == YES))
			[self ModeGood];
		else
			[self ModeError];
	}
	else if (cmd == OT2_CMD_PERMANENT_CONFIG)
	{
		if (([self setupMode] == YES) && ([self setConfig: Ot2PendingData] == YES))
			[self ModeGood];
		else
			[self ModeError];
	}
	else	// Bummer, we don't know the command
	{
		[Ot2Mutex lock];
		Ot2CmdResult = NO;
		strcpy((char *)Ot2CmdData, "Unrecognized Command");
		[Ot2Mutex unlock];
	}

	// Clear pending and finish up the response
	// Rather we succeed or fail, we always respond
	[Ot2Mutex lock];
	Ot2CompletedCmd = Ot2PendingCmd;
	Ot2PendingCmd = OT2_CMD_NONE;
	[Ot2Mutex unlock];
	
	[self performSelectorOnMainThread:@selector(postCmdComplete) 
						   withObject:nil 
						waitUntilDone:NO];
}


/*
	run
 
	Our OT-2 thread, it is basically a state engine
	that loops until we kill it.
*/

- (void)run:(id)info 
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// We'll start disconnected
	[self setState: OT2_DISCONNECTED];
	Ot2Socket = INVALID_SOCKET;
	
	// And we'll run till we are asked to stop
	while ([Ot2Thread isCancelled] != YES)
	{
		SOCKADDR_IN IMSDevice;
		U8 b;
		OT2_CMD cmd;

		// Flush the autorelease toilet...
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];
		
		switch ([self state])
		{
			// If we are disconnected, try to find a unit to connect to
			case OT2_DISCONNECTED:
				if ([self findOT2: &IMSDevice] == YES)
				{
					if ([self connectToOT2: &IMSDevice] == YES)
						[self setState: OT2_SYNCING];
				}
				else
					[NSThread sleepForTimeInterval:1.0];
				break;
			
			// We've connected to a unit, try to sync to the data stream
			case OT2_SYNCING:
				// Read a byte
				if ([self getByte: &b] == NO)
					break;
				
				// See if the byte gives us a packet
				if (Ot2MtsParser->addByte(b))
				{
					// not a query response?
					if (!Ot2MtsParser->rxcmdresp)
						if ([self putByte: MTS_TYPELIST_QUERY] == YES)
							[self setState: OT2_GETTYPES];
				}
				break;
			
			// We're looking for the device types
			case OT2_GETTYPES:
				// Read a byte
				if ([self getByte: &b] == NO)
					break;
				
				// See if the byte gives us a packet
				if (Ot2MtsParser->addByte(b))
				{
					// query response we want?
					if (Ot2MtsParser->rxcmdresp == MTS_TYPELIST_QUERY)
					{
						// Save the types
						[self saveDeviceTypesFromBlock: Ot2MtsParser->response ofLength: Ot2MtsParser->rsplen];

						// Send out a name request
						if ([self putByte: MTS_NAMELIST_QUERY] == YES)
							[self setState: OT2_GETNAMES];
					}
				}
				break;

			// We're looking for the device names
			case OT2_GETNAMES:
				// Read a byte
				if ([self getByte: &b] == NO)
					break;
				
				// See if the byte gives us a packet
				if (Ot2MtsParser->addByte(b))
				{
					// query response we want?
					if (Ot2MtsParser->rxcmdresp == MTS_NAMELIST_QUERY)
					{
						// Save the names
						[self saveDeviceNamesFromBlock: Ot2MtsParser->response ofLength: Ot2MtsParser->rsplen];
						
						// Check if we can use the SDK or not
						// *should* be yes, because this platform is WiFi only, but
						// This should help for future
						//
						// IMPORTANT! This only checks for 1.01, if you are using
						// an expert mode, you should check for the version called
						// for in the current documentation
						if (Ot2DeviceTypes[Ot2DeviceCount-1].devtype[0] == 'O' &&
							Ot2DeviceTypes[Ot2DeviceCount-1].devtype[1] == 'T' &&
							Ot2DeviceTypes[Ot2DeviceCount-1].versionH >= 0x10 &&
							(Ot2DeviceTypes[Ot2DeviceCount-1].versionL & 0xF0) >= 0x10)
						{
							[self setSdk: YES];

							// Enter setup mode
							if ([self setupMode] == NO)
								break;
							
							// Read the OT1b/2 configuration
							if ([self getCommandValue:OT_SETUP_GETCONFIG 
											   ofSize:sizeof(OT_CONFIGURATION) 
												   to:&Ot2Config] == NO)
								break;
							
							// Get the WiFi Settings 
							if ([self getCommandValue:OT_SETUP_GETWIFI 
											   ofSize:sizeof(OT_WIFI_SETTINGS) 
												   to:&Ot2WiFiSet] == NO)
								break;
							
							// Exit setup mode
							if ([self setupExit] == NO)
								break;
							
							// Build a channel map with config
							[Ot2Mutex lock];
							Ot2ChannelMap->ChannelMapBuild(Ot2DeviceCount, 
														   (MTS_DEVICE_TYPE *)&Ot2DeviceTypes,
														   (MTS_DEVICE_NAME *)&Ot2DeviceNames, 
														   &Ot2Config);
							
							memset(&Ot2LastPacket, 0, sizeof(Ot2LastPacket));
							[Ot2Mutex unlock];
						}
						else
						{
							[self setSdk: NO];
							
							// Build a channel map without config
							[Ot2Mutex lock];
							Ot2ChannelMap->ChannelMapBuild(Ot2DeviceCount, 
														   (MTS_DEVICE_TYPE *)&Ot2DeviceTypes,
														   (MTS_DEVICE_NAME *)&Ot2DeviceNames, 
														   (OT_CONFIGURATION *)0);
							
							memset(&Ot2LastPacket, 0, sizeof(Ot2LastPacket));
							[Ot2Mutex unlock];
						}
						
						
						[self setState: OT2_CONNECTED];
					}
				}
				break;
			
			// Cool, we're connected, so let's parse data packets
			case OT2_CONNECTED:
				// Any pending commands?
				[Ot2Mutex lock];
				cmd = Ot2PendingCmd;
				[Ot2Mutex unlock];
				if (cmd != OT2_CMD_NONE)
					[self doCommands: cmd];
				
				// Read a byte
				if ([self getByte: &b] == NO)
					break;
				
				// See if the byte gives us a packet
				if (Ot2MtsParser->addByte(b))
				{
					// not a query response?
					if (!Ot2MtsParser->rxcmdresp)
					{
						// Save the latest value
						[Ot2Mutex lock];
						memcpy(&Ot2LastPacket, &(Ot2MtsParser->rxpacket), sizeof(Ot2LastPacket));
						[Ot2Mutex unlock];
						
						// !!!! Optionally Record
						// This would be a good place to manage a container object
						// which you could commit or discard later
						
						// Tell anyone who cares we have new data
						[self performSelectorOnMainThread:@selector(postNewPacket) 
											   withObject:nil 
											waitUntilDone:NO];
						
						// This should make sure that our ACK gets sent promptly
						// on network stacks using delayed ACK.
						// We only care about this for UI responsiveness, not logging
						// [self putByte:MTS_BOGUS_QUERY];
					}
				}
				break;
				
			// For any unhandled states (should be any), we'll sleep a bit.
			default:
				[NSThread sleepForTimeInterval:0.1];				
		}
	}
	
	[pool release];
}


@end