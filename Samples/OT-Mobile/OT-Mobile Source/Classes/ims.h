/*
	ims.h
 
	This is a collection of IMS stuff
 
	Unlike most IMS files, this is not divided up as #defines, data
	types, public functions, helpers...
 
	It is more like a series of header files, one included after another.
	They are all in one so that you can just get everything in one
	swoop.
 
	IMPORTANT!!!! This file assumes that the host using it is Little Endian!
*/

#ifndef _IMS_H
#define _IMS_H


// IMS Data Types ...............................................................

typedef unsigned char U8;
typedef unsigned short U16;
typedef unsigned long U32;
typedef signed char S8;
typedef signed short S16;
typedef signed long S32;

#ifndef TRUE
#define TRUE (1)
#endif

#ifndef FALSE
#define FALSE (0)
#endif


// Basic MTS Protocol ...........................................................

// Inband queries
#define MTS_NAMELIST_QUERY	0xCE //	Get all the device names
#define MTS_TYPELIST_QUERY	0xF3 // Get all the device type information
#define MTS_BOGUS_QUERY		0xFF // Useful for defeating 'delayed ack' on networks

// Inband commands
#define MTS_REC_CMD			'R'	 // Start Recording command
#define MTS_RECSTOP_CMD		'r'	 // Stop Recording command
#define MTS_ERASENEW_CMD	'e'	 // Erase (LM-1) force new (DL-32/LM-2) command
#define MTS_CALIB_CMD  	    'c'	 // Calibration command
#define MTS_SETUPMODE_CMD	'S'  // Enter Setup mode
#define MTS_SETUPEXIT_CMD	's'  // Exit Setup mode

// Maximum channels we ever expect
// Note: that many devices expect 32 max, but we'll handle up to 64, which is
// also the LogWorks software max
#define MTS_MAX_CHANS	(64)

// Channel Function Codes
#define MTS_FUNC_LAMBDA			0	// Lambda (old or new)
#define MTS_FUNC_O2				1
#define MTS_FUNC_INCALIB		2
#define MTS_FUNC_RQCALIB		3
#define MTS_FUNC_WARMUP			4
#define MTS_FUNC_HTRCAL			5
#define MTS_FUNC_ERROR			6
#define MTS_FUNC_FLASHLEV		7
#define MTS_FUNC_SERMODE		8
#define MTS_FUNC_NOTLAMBDA		9	// Aux
#define MTS_FUNC_AUX			9	// We use to names for legacy reasons
#define MTS_FUNC_INVALID		10


// A little bit higher level of looking at MTS data packets
// Each channel is represented as this:

typedef struct
{
	U8  lm1data;	// From LM1? Tagged because of weird LM1 behavior without sensor
	U8 func;		// What function is the channel (see above)
	U16 value;		// What is the value
} MTS_CHAN;


// A collection of channels then goes in this for a packet:

typedef struct
{
	S16  afrmult;	// The first AFR multipler placed here for convenience
	float ubat;		// The weird LM-1 ubat reading turned into a float
	int	  numchans;	// How many valid channels in this packet
	MTS_CHAN chan[MTS_MAX_CHANS];	// The channels themselves
} MTS_DATA_STRUCT;

// Maximum number of devices
// We set it to 32, but that really should never happen
#define MTS_MAX_DEVICE (32)	

// Device TYPE response
typedef struct
{
	U8 versionH;		// High byte of firwmare version (big endian)
	U8 versionL;		// Low byte of firmware version (big endian)
	char devtype[4];	// Unique 4 character device ID, should be
	U8 cputype;			// Represents CPU type and clock speed
	U8 channelinfo;		// Could be (but not always) the count of channels
} MTS_DEVICE_TYPE;


// Device NAME response
typedef struct
{
	char devname[8];
} MTS_DEVICE_NAME;


// OT1b/2 Specific Stuff ........................................................

// Max Channel
#define OT_MAX_CHANNEL (16)			// Max channels of OBD-II for MTS stream
#define OT_MAX_DTC (16)				// Max number of DTCs the 'k' command will return
#define OT_MAX_VIN (17)				// Max number of VIN characters we'll accept

// Setup Mode commands
#define OT_SETUP_HEADER 'S'			// Get the setup mode header again
#define OT_SETUP_EXIT 's'			// Exit setup mode
#define OT_SETUP_GETCONFIG 'c'		// Get the current configuration
#define OT_SETUP_SETCONFIG 'C'		// Write a new configuration to flash (use carefully!)
#define OT_SETUP_SETMYCONFIG 'M'	// Set a temporary (duration of connection) configuration
#define OT_SETUP_KILLMYCONFIG 'm'	// Clear the temporary configuration
#define OT_SETUP_LOOPTIME 'l'		// Get the last OBD-II loop time
#define OT_SETUP_CONSTATUS 'j'		// Get the current connection status
#define OT_SETUP_GETDTCS 'k'		// Get any current DTCs
#define OT_SETUP_CLEARDTCS 'K'		// Request that DTCs be cleared
#define OT_SETUP_GETVIN 'v'			// Get the vehicle VIN (if available)
#define OT_SETUP_TESTSTATUS 't'		// Get basic emission test status
#define OT_SETUP_GETWIFI 'w'		// Get Wi-Fi Info
#define OT_SETUP_EXPERT 'e'			// Enter an expert mode
#define OT_SETUP_KEEPALIVE 0xFF		// Dummy command to reset watchdog timer 

// Protocols
#define OT_PROTO_AUTO (0)			// Automatic
#define OT_PROTO_CAN (1)			// CAN bus
#define OT_PROTO_PWM (2)			// J1850 pwm (Ford)
#define OT_PROTO_VPW (3)			// J1850 vpw (GM)
#define OT_PROTO_KWP (4)			// KWP 2000 (European)
#define OT_PROTO_ISO (5)			// ISO 9141 (Japan, Europe)

// Connection State
#define OT_CONN_NONE (0)			// No ECU Connection
#define OT_CONN_CAN (1)				// CAN bus
#define OT_CONN_PWM (2)				// J1850 pwm (Ford)
#define OT_CONN_VPW (3)				// J1850 vpw (GM)
#define OT_CONN_KWP (4)				// KWP 2000 (European)
#define OT_CONN_ISO (5)				// ISO 9141 (Japan, Europe)
#define OT_CONN_PD (0xFF)			// Unit is in powerdown state

// DTC count/response
#define OT_DTC_ERROR (0xFF)			// Count could not be fetched

#pragma pack(push,1)

typedef struct {
	U8 Channels;					// Number of channels
	U8 Protocol;					// OBD-II Protocol
	U16 NormPid[OT_MAX_CHANNEL];	// Normalized PIDs to scan
	U16 Flags;						// Priority Flags
} OT_CONFIGURATION;

typedef struct {
	U8 ConnectionStatus;			// Current Protocol (0=none, FF=powerdown)
	U32 PidMasks[8];				// ECU Pid Masks
} OT_CONNECTION_STATUS;

typedef struct {
	U8 HWAddr[6];					// MAC address
	U32 IPAddr;						// IPV4 address (in network order!)
	U32 IPMask;						// IPV4 mask (in network order!)
} OT_WIFI_SETTINGS;

typedef struct {
	U8 DtcCount;					// Number of DTCs
	U16 Dtcs[OT_MAX_DTC];			// The actual DTCs
} OT_GET_DTCS;

typedef struct {
	U8 Result;						// 0=failed, 1=sent (not nec. cleared)
} OT_CLEAR_DTCS;

typedef struct {
	U8 VinLen;						// Length or 0xFF for invalid
	U8 Vin[OT_MAX_VIN];				// Actual VIN characters
} OT_GET_VIN;


#pragma pack(pop)

// IMS Net Discovery ............................................................

// Protocol ID
#define IMSNET_PROTO_ID "IMS Net"

// Interface Version
#define IMSNET_VERSION (1)

// UDP Discovery Port
#define IMSNET_DISCOVERY (0x1936)

// Standard Service Port
#define IMSNET_SERVICE (0x1001)

// OpCodes
#define IMSNET_OPCODE_POLL (0x4000)
#define IMSNET_OPCODE_POLLREPLY (0x4100)

// Flags
#define IMSNET_FLAG_INUSE (0x1)

// Poll Structures
#pragma pack(push,1)

// All in BIG Endian !!!!
typedef struct {
	U8 ProtoID[8];               // protocol ID = "IMS Net"
	U16 OpCode;                  // == IMSNET_OPCODE_POLL
	U8 VersionH;                 // 0
	U8 VersionL;                 // protocol version, set to IMSNET_VERSION
} IMSNET_POLL;

typedef struct {
	U8 ProtoID[8];               // protocol ID = "IMS Net"
	U16 OpCode;                  // == IMSNET_OPCODE_POLLREPLY
	U8 VersionH;                 // 0
	U8 VersionL;                 // protocol version, set to IMSNET_VERSION
	U32 Address;				 // IP Address
	U16 Port;					 // Port for service
	U16 Flags;					 // See Flags above
	U32 Info;					 // When IMSNET_FLAG_INUSE, IP Address of user
} IMSNET_POLLREPLY;

#pragma pack(pop)

// IMS NET Down and Dirty (Fixed) ............................................

#define IMSNET_FIXED_IP 0x0A030201L
#define IMSNET_FIXED_SERVICE 0xC001

#endif	_IMS_H

