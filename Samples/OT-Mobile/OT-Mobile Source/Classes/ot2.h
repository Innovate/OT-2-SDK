/*
	OT2.h
 
	This is a 'singleton' object (only one!) that interfaces
	to the Innovate Motorsports OT-2
 
	The general model is 'background', 'autonomous', and 'asynchronous'.
	
	It takes care of finding, connecting, syncing, and extracting data,
	then sends notificaitons on important events.
 
	Similarly, you can make requests of it, but you only know of the
	results via a notification.
*/

#import <Foundation/Foundation.h>

#include "Byte2MTS.h"
#include "ChannelMap.h"

// Notifications we send out
#define OT2_NOTIFICATION_STATE @"OT2StateChanged"
#define OT2_NOTIFICATION_PACKET @"OT2NewPacket"
#define OT2_NOTIFICATION_CMD @"OT2CommandComplete"

// Commands we accept
typedef enum {
	OT2_CMD_NONE = 0,
	OT2_CMD_CONNECT_STATE,
	OT2_CMD_GET_DTCS,
	OT2_CMD_CLEAR_DTCS,
	OT2_CMD_GET_VIN,
	OT2_CMD_TEMP_CONFIG,		// Requires data
	OT2_CMD_PERMANENT_CONFIG	// Requires data
} OT2_CMD;

// Command Response
typedef struct {
	OT2_CMD command;	// Command this response is for
	bool result;		// YES=success
	U8 data[256];		// Probably should be a union, but contains OT_ struct
						// or c string on error
} OT2_CMD_RESPONSE;

// The current state of the OT2 Obect
typedef enum {
	OT2_DISCONNECTED = 0,
	OT2_SYNCING,
	OT2_GETTYPES,
	OT2_GETNAMES,
	OT2_CONNECTED
} OT2_STATE;

// The 'mixed' (C, C++, Objective C...) object
@interface OT2 : NSObject {
 @private
	NSThread *Ot2Thread;	// Our communication thread
	int Ot2Socket;			// For our TCP socket (when we connect)
	Byte2MTS *Ot2MtsParser;	// This will parse out bytes to MTS data

	NSLock *Ot2Mutex;		// For sharing the data that follows between threads
	
	OT2_STATE Ot2State;		// It is a state engine	
	int Ot2DeviceCount;		// MTS chain info
	MTS_DEVICE_NAME Ot2DeviceNames[MTS_MAX_DEVICE];
	MTS_DEVICE_TYPE Ot2DeviceTypes[MTS_MAX_DEVICE];
	bool Ot2SdkAvailable;	// Are we talking to an OT-1b/2 SDK compatible device
	OT_CONFIGURATION Ot2Config;	// Then we'll have it's current config
	OT_WIFI_SETTINGS Ot2WiFiSet;// And the WIFI Settings
	ChannelMap *Ot2ChannelMap;	// A map of the channels
	MTS_DATA_STRUCT Ot2LastPacket;	// Last reading
	
	OT2_CMD Ot2PendingCmd;		// Pending Command
	U8		Ot2PendingData[256];	// And optional data
	OT2_CMD Ot2CompletedCmd;	// Command last completed
	bool	Ot2CmdResult;		// Result
	U8		Ot2CmdData[256];	// Command data
}

+ (OT2 *)instance;			// We have only one instance, so we retrieve it
							// instead of calling alloc again and again

- (void)start;				// For starting and stopping us, though you
- (void)stop;				// really should only start and stop once

- (OT2_STATE)state;			// Fetch our state
- (int)deviceCount;			// How many MTS devices (if connected)
- (void)deviceTypes: (MTS_DEVICE_TYPE *)dtypes; // Copy Type info
- (void)deviceNames: (MTS_DEVICE_NAME *)dnames;	// or names
- (void)wifiInfo: (OT_WIFI_SETTINGS *)winfo;	// or WiFi info
- (void)otConfig: (OT_CONFIGURATION *)oconfig;	// or OT configuration
- (bool)sdk;				// Can we use SDK features?
- (NSString *)getPidName: (U16)pid;	// Name of a PID

// Channel Info (if connected)
- (U16)channelCount;
- (NSString *)channelName: (U16)channel;
- (NSString *)channelUnits: (U16)channel isImperial:(bool)imperial isAFR:(bool)afr;
- (NSString *)channelValue: (U16)channel isImperial:(bool)imperial isAFR:(bool)afr;
- (U16)channelRaw: (U16)channel;
- (U16)channelFunction: (U16)channel;

// Command Interface
- (void)commandRequest: (OT2_CMD)command;
- (void)commandRequest: (OT2_CMD)command withData: (void *)data ofSize: (U16)size;
- (bool)commandGetResponse: (OT2_CMD_RESPONSE *)response;

@end

