/*
	ChannelMap.mm
 
	This class builds a map of channels from device info.
 
	Then it keeps track of a current value, which can be polled
	as a raw sample, or an ASCII string in either imperial or
	metric
*/

#ifndef _CHANNELMAP_H
#define _CHANNELMAP_H

// Includes ..................................................................

#include "ims.h"	// Get our basic types and MTS defines

// Types .....................................................................

typedef struct {
	U8	DevId[4];		// ID of the device that this is from
	U8	DevChannel;		// Channel on the Device
	char Name[32];		// Name for the channel
	U16	Pid;			// Normalized PID for the channel
} _CMChannel;


class ChannelMap
{
private:
	U8 ChannelCount;
	_CMChannel Channels[MTS_MAX_CHANS];

	void AddLamda(MTS_DEVICE_NAME *name, MTS_DEVICE_TYPE *type, U8 dchannel);
	void AddAux(MTS_DEVICE_NAME *name, MTS_DEVICE_TYPE *type, U8 dchannel);
	void AddTemp(MTS_DEVICE_NAME *name, MTS_DEVICE_TYPE *type, U8 dchannel);
	void AddObd(MTS_DEVICE_NAME *name, MTS_DEVICE_TYPE *type, U8 dchannel, U16 opid);
	void AddDevice(MTS_DEVICE_TYPE *type, MTS_DEVICE_NAME *name, OT_CONFIGURATION *config);

public:
	ChannelMap();
	~ChannelMap();
	
	// Build the map
	void ChannelMapBuild(U16 dcount, MTS_DEVICE_TYPE *dtypes, MTS_DEVICE_NAME *dnames, OT_CONFIGURATION *oconfig);

	// Get stuff we need
	U8 ChannelMapGetCount();
	const char *ChannelMapGetName(U16 channel);
	const char *ChannelMapGetUnits(U16 channel, U8 units, U8 afr);
	const char *ChannelMapValueString(U16 channel, U16 value, U16 func, U8 imperial, U8 afr);
	
	const char *ChannelMapGetPidName(U16 pid);
};

#endif
