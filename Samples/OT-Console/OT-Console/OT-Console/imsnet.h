/*
	imsnet.h
 
	The IMSNET Interface
*/

#ifndef _IMSNET_H
#define _IMSNET_H

// IMS Data Types ...............................................................

#ifndef U8
typedef unsigned char U8;
typedef unsigned short U16;
typedef unsigned long U32;
#endif

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
#pragma pack(push)
#pragma pack(1)

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

// IMSNET functions
int imsnetOpen();
void imsnetClose();

void imsnetSendBytes(int len, void *dat);
void imsnetFlush();
bool imsnetIsByte();
BYTE imsnetGetByte();
int imsnetGetBytes(int len, void *buf);

#endif	_IMSNET_H

