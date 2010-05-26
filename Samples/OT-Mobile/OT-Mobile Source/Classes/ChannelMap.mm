/*
	ChannelMap.mm
 
	This class builds a map of channels from device info.
 
	Then it keeps track of a current value, which can be polled
	as a raw sample, or an ASCII string in either imperial or
	metric
*/

// Includes ..................................................................

#include "normpid.h"	// Defines for the 'standard' PIDs
#include "imspid.h"

#include "ChannelMap.h"


// Local Statics .............................................................

/*
	These are for the copy and paste units->string code
	we lifted from firmware
*/

static U8 UiImperial;
static char UiOutStr[32];
static U8 UiAFR;


/*
	And some big string tables that we'll use
*/

#include "NameUnitStrings.h"


// Constructor/Destructor ....................................................

/*
	ChannelMap
 
	Constructor
 
	Just initialize everything to 0
*/

ChannelMap::ChannelMap()
{
	memset(&Channels, 0, sizeof(Channels));
	ChannelCount = 0;
}

/*
	~ChannelMap
 
	Destructor
*/

ChannelMap::~ChannelMap()
{
	
}


// Build the table ...........................................................

/*
	ChannelMap::ChannelMapBuild
 
	This takes names and types and converts to channels
	It defaults to simplest channels suitable for each type,
	except the one closest. If we have a config, it gets
	the channels right
*/

void 
ChannelMap::ChannelMapBuild(U16 dcount,					// Number of devices
							MTS_DEVICE_TYPE *dtypes,	// Their types
							MTS_DEVICE_NAME *dnames,	// Their names
							OT_CONFIGURATION *oconfig)	// Configuration for the OT-2
{
	// Clear out the old map
	memset(&Channels, 0, sizeof(Channels));
	ChannelCount = 0;

	// We'll add all the devices, but only give a config
	// to the last one (since that is the one we have it from
	for (int n=0 ; n<dcount ; n++)
	{
		if (n==(dcount-1))
			AddDevice(&dtypes[n], &dnames[n], oconfig);
		else 
			AddDevice(&dtypes[n], &dnames[n], (OT_CONFIGURATION *)0);
	}
}

/*
	ChannelMap::AddDevice
 
	A big ugly if/else tree to add channels
*/


void
ChannelMap::AddDevice(MTS_DEVICE_TYPE *type,
					  MTS_DEVICE_NAME *name,
					  OT_CONFIGURATION *config)
{
	int n;
	
	if (!strncmp(((char *)type)+2, "LC1 ", 4))
		AddLamda(name, type, 1);
	else if (!strncmp(((char *)type)+2, "LMTR", 4))
	{
		AddLamda(name, type, 0);
		for (n=0 ; n<5 ; n++)
		{
			AddAux(name, type, n+1);
		}
	}
	else if (!strncmp(((char *)type)+2, "AXB1", 4))
	{
		for (n=0 ; n<5 ; n++)
			AddAux(name, type, n+1);
	}
	else if (!strncmp(((char *)type)+2, "DL32", 4))
	{
		for (n=0 ; n<5 ; n++)
			AddAux(name, type, n+1);
	}
	else if (!strncmp(((char *)type)+2, "ST12", 4))
	{
		for (n=0 ; n<5 ; n++)
			AddAux(name, type, n+1);
	}
	else if (!strncmp(((char *)type)+2, "SSI4", 4))
	{
		for (n=0 ; n<4 ; n++)
			AddAux(name, type, n+1);
	}
	else if (!strncmp(((char *)type)+2, "TC4 ", 4))
	{
		for (n=0 ; n<4 ; n++)
			AddTemp(name, type, n+1);
	}
	else if (!strncmp(((char *)type)+2, "OT1 ", 4))
	{
		// We're taking a wild guess...
		for (n=0 ; n< type->channelinfo ; n++)
			AddObd(name, type, n+1, n+1);
	}
	else if (!strncmp(((char *)type)+2, "LM2 ", 4))
	{
		int chans = 1;
		
		// At least one lambda
		AddLamda(name, type, 1);
		// Second?
		if (type->channelinfo & 0x80)
		{
			chans++;
			strcat(Channels[ChannelCount-1].Name, "a");
			AddLamda(name, type, 2);
			strcat(Channels[ChannelCount-1].Name, "b");
		}
		
		// Add an RPM channel?
		if (type->channelinfo & 0x40)
		{
			chans++;			
			memcpy(Channels[ChannelCount].DevId, type+2, 4);	// Save Type
			Channels[ChannelCount].DevChannel = chans;
			Channels[ChannelCount].Pid = IMS_PID_RPM;
			sprintf(Channels[ChannelCount].Name, "%s %s", (char *)name, ChannelMapGetPidName(Channels[ChannelCount].Pid));

			ChannelCount++;			
		}
		
		// Aux Channels?
		if (type->channelinfo & 0x20)
		{
			for (n=0 ; n<4 ; n++)
			{
				chans++;
				AddAux(name, type, n+1);
				Channels[ChannelCount-1].DevChannel += chans;
			}
		}
		
		// Obd channels?
		for (n=0 ; n < (type->channelinfo & 0x1F) ; n++)
		{
			chans++;
			AddObd(name, type, chans, n+1);
		}
	}
	else if ( (!strncmp(((char *)type)+2, "OT1B", 4)) || (!strncmp(((char *)type)+2, "OT2 ", 4)) )
	{
		// Finally, us... Use your config if you've got one!
		for (n=0 ; n< type->channelinfo ; n++)
		{
			if (!config)
				AddObd(name, type, n+1, n+1);
			else
				AddObd(name, type, n+1, config->NormPid[n]);
		}
	}
}

// Helpers to stuff different channel types ..................................

void
ChannelMap::AddLamda(MTS_DEVICE_NAME *name, 
					 MTS_DEVICE_TYPE *type,
					 U8 dchannel)
{
	memcpy(Channels[ChannelCount].DevId, type+2, 4);	// Save Type
	Channels[ChannelCount].DevChannel = dchannel;
	Channels[ChannelCount].Pid = IMS_PID_LAMBDA;
	strcpy(Channels[ChannelCount].Name, (char *)name);
	strcat(Channels[ChannelCount].Name, " ");
	strcat(Channels[ChannelCount].Name, ChannelMapGetPidName(Channels[ChannelCount].Pid));
	ChannelCount++;
}

void
ChannelMap::AddAux(MTS_DEVICE_NAME *name, 
				   MTS_DEVICE_TYPE *type,
				   U8 dchannel)
{
	memcpy(Channels[ChannelCount].DevId, type+2, 4);	// Save Type
	Channels[ChannelCount].DevChannel = dchannel;
	Channels[ChannelCount].Pid = IMS_PID_AUXVOLTS;
	sprintf(Channels[ChannelCount].Name, "%s %s%d", (char *)name, ChannelMapGetPidName(Channels[ChannelCount].Pid), dchannel);

	ChannelCount++;
}

void
ChannelMap::AddTemp(MTS_DEVICE_NAME *name, 
					MTS_DEVICE_TYPE *type,
					U8 dchannel)
{
	memcpy(Channels[ChannelCount].DevId, type+2, 4);	// Save Type
	Channels[ChannelCount].DevChannel = dchannel;
	Channels[ChannelCount].Pid = IMS_PID_EGT;
	sprintf(Channels[ChannelCount].Name, "%s %s%d", (char *)name, ChannelMapGetPidName(Channels[ChannelCount].Pid), dchannel);
	ChannelCount++;
}

void
ChannelMap::AddObd(MTS_DEVICE_NAME *name, 
				   MTS_DEVICE_TYPE *type,
				   U8 dchannel,
				   U16 pid)
{
	memcpy(Channels[ChannelCount].DevId, type+2, 4);	// Save Type
	Channels[ChannelCount].DevChannel = dchannel;
	Channels[ChannelCount].Pid = pid;
	strcpy(Channels[ChannelCount].Name, ChannelMapGetPidName(Channels[ChannelCount].Pid));
	ChannelCount++;
}


// Fetch Stuff ...............................................................

/*
	ChannelMap::ChannelMapGetCount
 
	Get the number of channels
*/

U8 
ChannelMap::ChannelMapGetCount()
{
	return ChannelCount;
}


/*
	ChannelMap::ChannelMapGetUnits
 
	Get the units in metric or imperial for a channel
*/

const char *
ChannelMap::ChannelMapGetUnits(U16 channel,		// Channel to fetch
							   U8 units,		// 1 for imperial
							   U8 afr)			// AFR multiplier (*10)
{		
	if (channel >= ChannelCount)
		return (char *)0;
	
	if (Channels[channel].Pid >= 0x1000)
	{
		// Special handling for AFR
		if (Channels[channel].Pid == IMS_PID_LAMBDA)
		{
			if (afr)
				return "AFR";
			else
				return "lambda";
		}
		else
		{
			if (units)
				return ImsIUnits[Channels[channel].Pid - 0x1000];
			else
				return ImsUnits[Channels[channel].Pid - 0x1000];
		}
	}
	else 
	{
		if (units)
			return ObdiiIUnits[Channels[channel].Pid];
		else
			return ObdiiUnits[Channels[channel].Pid];		
	}
}


/*
	ChannelMap::ChannelMapGetPidName
 
	Fetch the name of a given norm/ims PID
*/

const char *
ChannelMap::ChannelMapGetPidName(U16 pid)
{
	if (pid >= 0x1000)
		return ImsNames[pid-0x1000];
	else
		return ObdiiName[pid];
}


/*
	ChannelMap::ChannelMapGetName
 
	Get the name of a channel
*/

const char *
ChannelMap::ChannelMapGetName(U16 channel)
{	
	if (channel >= ChannelCount)
		return (char *)0;
	
	return (Channels[channel].Name);
}



// Calc Functions ............................................................

/*
	The following is all in integer math because it was first used
	on a tiny CPU.
 
	This could just be a table of min/max and 1023 to float scaling
	(see the #if 0 tables at the end of this file) but I had this
	already, and it seems to perform faster on the iPhone than floating
	point calculations so...
 
	The basic scheme is that conversions are looked up from a table and 
	everything is already prescaled up so that everthing is in integer.
*/

// OBDII UI Scaling Functions ................................................

/*
	This first one looks complicated, but it really just does
	integer scalling.
 
	val is what we are converting, target is the TOTAL range, offset
	is for things that run negative, divider scales back down for display,
	and iconv is which fixed metric to imperial conversion to use.
 
	So, for display volts as 0.00 to 5.00:
 
		target = 500, div = 2, offset = 0, no imperial conversion
 
	Volts that are -1.0 to 5.0
 
		target = 60 (total range), div=1, offset = 10...
 
	The other routines are for special cases (bit fields, etc.)
*/

void ScaleTo(U16 val, long target, U8 div, long offset, U8 iconv)
{
	long val1;
	long val2;
	
	// convert to target units
	val1 = (long)val * target;
	val1 = val1 / 1023;
	
	// apply offset
	val1 -= offset;
	
	// Imperial conversion (if nec.)
	if (UiImperial && iconv)
	{
		switch (iconv)
		{
			case 1:		// degC to degF (assumes no divider !!!!)
				val1 *=  9;
				val1 += 3;
				val1 /= 5;
				val1 += 32;
				break;
				
			case 2:		// km to miles (assumes no divider !!!!)
				val1 *= 100;
				val1 += 80;
				val1 /= 161;
				break;
				
			case 3:		// kPa to inHg (assumes no divider, adds one!!!!)
				val1 *= 295300;
				val1 += 5000;
				val1 /= 10000;
				div = 2;	// Force to .xx
				break;
				
			case 4:		// kPa to PSI (assumes no divider, adds one!!!!)
				val1 *= 1450380;
				val1 += 50000;
				val1 /= 100000;
				div = 2;	// Force to .xx
				break;
		}
	}
	
	// Last, handle division
	if (!div)
		sprintf(UiOutStr, "%ld", val1);
	else if (div == 1)
	{
		val2 = abs(val1) % 10;
		val1 = val1 / 10;
		sprintf(UiOutStr, "%ld.%ld", val1, val2);
	}
	else if (div == 2)
	{
		val2 = abs(val1) % 100;
		val1 = val1 / 100;
		sprintf(UiOutStr, "%ld.%02ld", val1, val2);
	}
	else
	{
		val2 = abs(val1) % 1000;
		val1 = val1 / 1000;
		sprintf(UiOutStr, "%ld.%03ld", val1, val2);
	}
}

void DispNone(U16 val, long target, U8 div, long offset, U8 iconv)
{
	UiOutStr[0] = '0';
	UiOutStr[1] = 0;
}

void DispRPM(U16 val, long target, U8 div, long offset, U8 iconv)
{
	if (! target)
		sprintf(UiOutStr, "%d", val * 10);
	else
		sprintf(UiOutStr, "%d", val * 20);
}

void DispBit(U16 val, long target, U8 div, long offset, U8 iconv)
{
	if (val)
		strcpy(UiOutStr, "ON");
	else
		strcpy(UiOutStr, "off");
}

void DispRaw(U16 val, long target, U8 div, long offset, U8 iconv)
{
	sprintf(UiOutStr, "%d", val);
}

// This is an odd ball, because it actually cares about function
void DisplayLambda(U8 sfunc, U16 svalue)
{
	unsigned short dval;
	unsigned long lval1;
	unsigned long lval2;
	
	if (sfunc == MTS_FUNC_LAMBDA)
	{
		svalue += 500;
		
		if (! UiAFR)
		{
			dval = svalue / 1000;
			svalue = (svalue % 1000) / 10;		
			sprintf(UiOutStr, "%d.%02d", dval, svalue);
		}
		else
		{
			lval1 = svalue;
			lval1 = lval1 * UiAFR;
			lval2 = lval1 % 10000;
			lval2 = (lval2+500) / 1000;
			lval1 = lval1 / 10000;
			if (lval2 > 9)
			{
				lval2 = 0;
				lval1++;
			}
			sprintf(UiOutStr, "%ld.%ld", lval1, lval2); 
		}
	}
	else if (sfunc == MTS_FUNC_O2)
	{
		dval = svalue / 10;
		svalue = svalue %10;
		sprintf(UiOutStr, "%d.%d", dval, svalue);
	}
	else if (sfunc == MTS_FUNC_ERROR) // error code
		sprintf(UiOutStr, "E%d", svalue);
	else if (sfunc == MTS_FUNC_WARMUP) //heater warmup
		sprintf(UiOutStr, "W%d", svalue/10);
	else if (sfunc == MTS_FUNC_HTRCAL) //heater calibration 
		sprintf(UiOutStr, "HC");
	else if (sfunc == MTS_FUNC_INCALIB) //free air calibration 
		sprintf(UiOutStr, "Cal");
}


// Calc Table ................................................................

typedef struct {
	void (*CalcFunc)(U16, long, U8, long, U8);
	long P1;
	U8 P2;
	long P3;
	U8 IConv;
} _OBDII_DISP;

const _OBDII_DISP OBDispTable[] = {
	/*	Func,			P1,	P2,	P3,		IConv */
	{DispNone,	0,		0,		0,			0, },	// 0 NONE
	{DispRPM,	0,		0,		0,			0, },	// 1 RPM
	{ScaleTo,	100,	0,		0,			0, },	// 2 TP
	{ScaleTo,	100,	0,		0,			0, },	// 3 LOAD_PCT
	{ScaleTo,	1275,	1,		640,		0, },	// 4 SPARKADV
	{ScaleTo,	65535, 2,	0,			0, },	// 5 MAF
	{ScaleTo,	255,	0,		0,			3, },	// 6 MAP
	{ScaleTo,	255,	0,		0,			2, },	// 7 VSS
	{ScaleTo,	255,	0,		40, 		1, },	// 8 ECT
	{ScaleTo,	255,	0,		40, 		1, },	// 9 IAT
	{DispBit,	0,		0,		0, 		0, },	// 10 PTO_STAT
	{DispBit,	0,		0,		0, 		0, },	// 11 FUEL1_OL
	{DispBit,	0,		0,		0, 		0, },	// 12 FUEL2_OL
	{ScaleTo,	19922, 2,	10000, 	0, },	// 13 SHRTFT1
	{ScaleTo,	19922, 2,	10000, 	0, },	// 14 LONGFT1
	{ScaleTo,	19922, 2,	10000, 	0, },	// 15 SHRTFT2
	{ScaleTo,	19922, 2,	10000, 	0, },	// 16 LONGFT2
	{ScaleTo,	19922, 2,	10000, 	0, },	// 17 SHRTFT3
	{ScaleTo,	19922, 2,	10000, 	0, },	// 18 LONGFT3
	{ScaleTo,	19922, 2,	10000, 	0, },	// 19 SHRTFT4
	{ScaleTo,	19922, 2,	10000, 	0, },	// 20 LONGFT4
	{ScaleTo,	765, 	 0,	0, 		4, },	// 21 FRP
	{ScaleTo,	5177,  0,	0, 		4, },	// 22 FRP_MED
	{ScaleTo,	655350, 0,	0, 		4, },	// 23 FRP_HIGH
	{ScaleTo,	1999,  3,	0, 		0, },	// 24 EQ_RAT
	{ScaleTo,	803,   0,	0, 		0, },	// 25 LOAD_ABS
	{ScaleTo,	100,   0,	0, 		0, },	// 26 EGR_PCT
	{ScaleTo,	19922, 2,	10000, 	0, },	// 27 EGR_ERR
	{ScaleTo,	100,   0,	0, 		0, },	// 28 TP_R
	{ScaleTo,	100,   0,	0, 		0, },	// 29 TP_B
	{ScaleTo,	100,   0,	0, 		0, },	// 30 TP_C
	{ScaleTo,	100,   0,	0, 		0, },	// 31 APP_D
	{ScaleTo,	100,   0,	0, 		0, },	// 32 APP_E
	{ScaleTo,	100,   0,	0, 		0, },	// 33 APP_F
	{ScaleTo,	100,   0,	0, 		0, },	// 34 TAC_PCT
	{ScaleTo,	100,   0,	0, 		0, },	// 35 EVAP_PCT
	{ScaleTo,	16383, 0,	8192, 	0, },	// 36 EVAP_VP
	{DispBit,	0,		0,		0, 		0, },	// 37 AIR_UPS
	{DispBit,	0,		0,		0, 		0, },	// 38 AIR_DNS
	{DispBit,	0,		0,		0, 		0, },	// 39 AIR_OFF
	{ScaleTo,	100,   0,	0, 		0, },	// 40 FLI
	{ScaleTo,	255,   0,	0, 		3, },	// 41 BARO
	{ScaleTo,	255,   0,	40, 		1, },	// 42 AAT
	{ScaleTo,	655,   1,	0, 		0, },	// 43 VPWR
	{DispBit,	0,		0,		0, 		0, },	// 44 MIL
	{DispRaw,	0,		0,		0, 		0, },	// 45 DTC_CNT
	{ScaleTo,	65535,  0,	0, 		2, },	// 46 MIL_DIST
	{DispRaw,	0,		0,		0, 		0, },	// 47 MIL_TIME
	{ScaleTo,	65535,  0,	0, 		2, },	// 48 CLR_DIST
	{DispRaw,	0,		0,		0, 		0, },	// 49 WARM_UPS
	{DispRaw,	0,		0,		0, 		0, },	// 50 RUNTM
	{ScaleTo,	1275,  3,	0, 		0, },	// 51 O2S11
	{ScaleTo,	19922, 2,	10000, 	0, },	// 52 SHRTFT11
	{ScaleTo,	1275,  3,	0, 		0, },	// 53 O2S11
	{ScaleTo,	19922, 2,	10000, 	0, },	// 54 SHRTFT11
	{ScaleTo,	1275,  3,	0, 		0, },	// 55 O2S11
	{ScaleTo,	19922, 2,	10000, 	0, },	// 56 SHRTFT11
	{ScaleTo,	1275,  3,	0, 		0, },	// 57 O2S11
	{ScaleTo,	19922, 2,	10000, 	0, },	// 58 SHRTFT11
	{ScaleTo,	1275,  3,	0, 		0, },	// 59 O2S11
	{ScaleTo,	19922, 2,	10000, 	0, },	// 60 SHRTFT11
	{ScaleTo,	1275,  3,	0, 		0, },	// 61 O2S11
	{ScaleTo,	19922, 2,	10000, 	0, },	// 62 SHRTFT11
	{ScaleTo,	1275,  3,	0, 		0, },	// 63 O2S11
	{ScaleTo,	19922, 2,	10000, 	0, },	// 64 SHRTFT11
	{ScaleTo,	1275,  3,	0, 		0, },	// 65 O2S11
	{ScaleTo,	19922, 2,	10000, 	0, },	// 66 SHRTFT11
	{ScaleTo,	1999, 3,		0, 		0, },	// 67 EQ_RAT11
	{ScaleTo,	7999, 3,		0, 		0, },	// 68 WO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 69 EQ_RAT11
	{ScaleTo,	7999, 3,		0, 		0, },	// 70 WO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 71 EQ_RAT11
	{ScaleTo,	7999, 3,		0, 		0, },	// 72 WO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 73 EQ_RAT11
	{ScaleTo,	7999, 3,		0, 		0, },	// 74 WO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 75 EQ_RAT11
	{ScaleTo,	7999, 3,		0, 		0, },	// 76 WO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 77 EQ_RAT11
	{ScaleTo,	7999, 3,		0, 		0, },	// 78 WO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 79 EQ_RAT11
	{ScaleTo,	7999, 3,		0, 		0, },	// 80 WO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 81 EQ_RAT11
	{ScaleTo,	7999, 3,		0, 		0, },	// 82 WO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 83 WBEQ_RAT11
	{ScaleTo,	255, 	0,		128, 		0, },	// 84 WBO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 85 WBEQ_RAT11
	{ScaleTo,	255, 	0,		128, 		0, },	// 86 WBO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 87 WBEQ_RAT11
	{ScaleTo,	255, 	0,		128, 		0, },	// 88 WBO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 89 WBEQ_RAT11
	{ScaleTo,	255, 	0,		128, 		0, },	// 90 WBO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 91 WBEQ_RAT11
	{ScaleTo,	255, 	0,		128, 		0, },	// 92 WBO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 93 WBEQ_RAT11
	{ScaleTo,	255, 	0,		128, 		0, },	// 94 WBO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 95 WBEQ_RAT11
	{ScaleTo,	255, 	0,		128, 		0, },	// 96 WBO2S11
	{ScaleTo,	1999, 3,		0, 		0, },	// 97 WBEQ_RAT11
	{ScaleTo,	255, 	0,		128, 		0, },	// 98 WBO2S11
	{ScaleTo,	6553, 0,		40, 		1, },	// 99 CATTEMP11
	{ScaleTo,	6553, 0,		40, 		1, },	// 100 CATTEMP11
	{ScaleTo,	6553, 0,		40, 		1, },	// 101 CATTEMP11
	{ScaleTo,	6553, 0,		40, 		1, },	// 102 CATTEMP11
	{DispRPM,	1,		0,		0,			0, },	// 103 RPM_EXT
};

const _OBDII_DISP IMSDispTable[] = {
	{DispNone,	0,		0,		0,			0, },	// O2	// Never used (see below)
	{DispRPM,	0,		0,		0,			0, },	// RPM
	{DispRPM,	1,		0,		0,			0, },	// RPM2
	{ScaleTo,	1000,	0,		0,			0, },	// FREQ
	{ScaleTo,	100,	0,		0,			0, },	// DWELL
	{ScaleTo,	1093,	0,		0,			1, },	// EGT
	{ScaleTo,	300,	0,		0,			1, },	// CHT
	{ScaleTo,	200,	2,		0,			0, },	// SIDE2
	{ScaleTo,	100,	2,		0,			0, },	// SIDE1
	{ScaleTo,	250,	3,		0,			0, },	// SIDE25
	{ScaleTo,	600,	1,		100,		0, },	// TIMING
	{ScaleTo,	441,	1,		0,			0, },	// MAP3a	// Stuck in PSI !!!!
	{ScaleTo,	147,	1,		0,			0, },	// MAP1a
	{ScaleTo,	441,	1,		147,		0, },	// MAP3g
	{ScaleTo,	147,	1,		147,		0, },	// MAP1g
	{ScaleTo,	200,	2,		0,			0, },	// ACC2
	{ScaleTo,	100,	2,		0,			0, },	// ACC1
	{ScaleTo,	250,	3,		0,			0, },	// ACC25
	{ScaleTo,	500,	2,		0,			0, },	// AUX Volts
	{ScaleTo,	100,	0,		0,			0, },	// AUX Percent
};

const char *
ChannelMap::ChannelMapValueString(U16 channel,		// Channel we want
								  U16 value,		// Value to convert
								  U16 func,			// Channel function (only for lambda)
								  U8 imperial,		// 1=imperial
								  U8 afr)			// AFR multiplier (x10)
{
	if (channel > ChannelCount)
		return (char *)0;
	
	UiImperial = imperial;
	UiAFR = afr;
	
	U16 i = Channels[channel].Pid;

	// !!!! Should handle regular IMS channels !!!!
	if (i >= 0x1000)
	{
		// Special handling for lambda functions
		if (i == IMS_PID_LAMBDA)
			DisplayLambda(func, value);
		else
		{
			i -= 0x1000;
			(*IMSDispTable[i].CalcFunc)(value, IMSDispTable[i].P1, IMSDispTable[i].P2, IMSDispTable[i].P3, IMSDispTable[i].IConv);			
		}
	}
	else	// OBD-II channels
		(*OBDispTable[i].CalcFunc)(value, OBDispTable[i].P1, OBDispTable[i].P2, OBDispTable[i].P3, OBDispTable[i].IConv);

	return UiOutStr;
}

// Reference Tables .................................................................

/*
	These are not used, but are put here so you can understand what the
	compicated fixed point stuff above is converting to. Or, if you just
	want to use your own floating point math conversions.
*/

#if 0

typedef struct {
	char	name[26];
	char description[32];
	char  units[12];
	double min;
	double max;
} _NORM_PID;

static _NORM_PID NormPids[] = {
	"OBD_None",		"None",							"Volts",		0.0,		5.0,
	"OBD_RPM",		"Engine RPM",							"RPM",		0.0,		10230.0,
	"OBD_TP",		"Throttle Position(abs)",			"%",			0.0,		100.0,
	"OBD_LOAD_PCT","Engine Load(calc)",			"%",			0.0,		100.0,
	"OBD_SPARKADV","Timing Advance(cyl1)",		"degBTDC",	-64.0,	63.5,
	"OBD_MAF",		"Mass Air Flow",						"g/s",		0.0,		655.35,
	"OBD_MAP",		"Manifold Abs. Presure",			"kPa",		0.0,		255.0,
	"OBD_VSS",		"Vehicle Speed Sensor",				"km/h",		0.0,		255.0,
	"OBD_ECT",		"Engine Coolant Temp",				"degC",		-40.0,	215.0,
	"OBD_IAT",		"Intake Air Temp",					"degC",		-40.0,	215.0,
	"OBD_PTO_STAT","PTO Status",					"PTO",		0.0,		1.0,
	"OBD_FUEL1_OL","Fuel Sys1 Open Loop",		"OL",			0.0,		1.0,
	"OBD_FUEL2_OL","Fuel Sys2 Open Loop",		"OL",			0.0,		1.0,
	"OBD_SHRTFT1", "Short Term Fuel Trim 1",		"%",			-100.0,	99.22,
	"OBD_LONGFT1", "Long Term Fuel Trim 1",		"%",			-100.0,	99.22,
	"OBD_SHRTFT2", "Short Term Fuel Trim 2",		"%",			-100.0,	99.22,
	"OBD_LONGFT2", "Long Term Fuel Trim 2",		"%",			-100.0,	99.22,
	"OBD_SHRTFT3", "Short Term Fuel Trim 3",		"%",			-100.0,	99.22,
	"OBD_LONGFT3", "Long Term Fuel Trim 3",		"%",			-100.0,	99.22,
	"OBD_SHRTFT4", "Short Term Fuel Trim 4",		"%",			-100.0,	99.22,
	"OBD_LONGFT4", "Long Term Fuel Trim 4",		"%",			-100.0,	99.22,
	"OBD_FRP",		"Fuel Rail Pressure",				"kPa",		0.0,		765.0,
	"OBD_FRP_MED", "Fuel Rail Pressure",			"kPa",		0.0,		5177.27,
	"OBD_FRP_HIGH","Fuel Rail Pressure",			"kPa",		0.0,		655350.0,
	"OBD_EQ_RAT",	"Commanded Equiv. Ratio",		"lambda",	0.0,		1.999,
	"OBD_LOAD_ABS","Absolute Load Value",		"%",			0.0,		802.75,	// Clipped from 25700.0!
	"OBD_EGR_PCT", "Commanded EGR",					"%",			0.0,		100.0,
	"OBD_EGR_ERR", "EGR Error",						"%",			-100.0,	99.22,
	"OBD_TP_R",		"Throttle Position(rel)",			"%",			0.0,		100.0,
	"OBD_TP_B",		"Throttle Position B(abs)",		"%",			0.0,		100.0,
	"OBD_TP_C",		"Throttle Position C(abs)",		"%",			0.0,		100.0,
	"OBD_APP_D",	"Acc. Pedal Position D",			"%",			0.0,		100.0,
	"OBD_APP_E",	"Acc. Pedal Position D",			"%",			0.0,		100.0,
	"OBD_APP_F",	"Acc. Pedal Position D",			"%",			0.0,		100.0,
	"OBD_TAC_PCT", "Commanded Throttle",			"%",			0.0,		100.0,
	"OBD_EVAP_PCT","Commanded Evap. Purge",		"%",			0.0,		100.0,
	"OBD_EVAP_VP", "Evap. Vapor Pressure",		"Pa",			-8192.0,	8191.0,
	"OBD_AIR_UPS", "Secondary Air DNS",			"UPS",		0.0,		1.0,
	"OBD_AIR_DNS", "Secondary Air DNS",			"DNS",		0.0,		1.0,
	"OBD_AIR_OFF", "Secondary Air DNS",			"OFF",		0.0,		1.0,
	"OBD_FLI",		"Fuel Level Indicator",				"%",			0.0,		100.0,
	"OBD_BARO",		"Barometric Pressure",				"kPa",		0.0,		255.0,
	"OBD_AAT",		"Ambient Air Temp",					"degC",		-40.0,	215.0,
	"OBD_VPWR",		"Control Module Voltage",			"Volts",		0.0,		65.535,
	"OBD_MIL",		"Malfunction Indicator Lamp",		"MIL",		0.0,		1.0,
	"OBD_DTC_CNT", "DTC Count",						"DTCs",		0.0,		1023.0,
	"OBD_MIL_DIST","Distance MIL active",		"km",			0.0,		65535.0,
	"OBD_MIL_TIME","Hours MIL active",			"hours",		0.0,		1023.0,
	"OBD_CLR_DIST","Distance MIL clear",			"km",			0.0,		65535.0,
	"OBD_WARM_UPS","Warm Ups MIL clear",			"WUs",		0.0,		1023.0,
	"OBD_RUNTM",	"Run Time",							"mins",		0.0,		1023.0,
	"OBD_O2S11",	"O2 Sensor(NB) 1-1",				"Volts",		0.0,		1.275,
	"OBD_SHRTFT11","O2 Fuel Trim 1-1",			"%",			-100.0,	99.22,
	"OBD_O2S12",	"O2 Sensor(NB) 1-2",				"Volts",		0.0,		1.275,
	"OBD_SHRTFT12","O2 Fuel Trim 1-2",			"%",			-100.0,	99.22,
	"OBD_O2S21",	"O2 Sensor(NB) 2-1",				"Volts",		0.0,		1.275,
	"OBD_SHRTFT21","O2 Fuel Trim 2-1",			"%",			-100.0,	99.22,
	"OBD_O2S22",	"O2 Sensor(NB) 2-2",				"Volts",		0.0,		1.275,
	"OBD_SHRTFT22","O2 Fuel Trim 2-2",			"%",			-100.0,	99.22,
	"OBD_O2S31",	"O2 Sensor(NB) 3-1",				"Volts",		0.0,		1.275,
	"OBD_SHRTFT31","O2 Fuel Trim 3-1",			"%",			-100.0,	99.22,
	"OBD_O2S32",	"O2 Sensor(NB) 3-2",				"Volts",		0.0,		1.275,
	"OBD_SHRTFT32","O2 Fuel Trim 3-2",			"%",			-100.0,	99.22,
	"OBD_O2S41",	"O2 Sensor(NB) 4-1",				"Volts",		0.0,		1.275,
	"OBD_SHRTFT41","O2 Fuel Trim 4-1",			"%",			-100.0,	99.22,
	"OBD_O2S42",	"O2 Sensor(NB) 4-2",				"Volts",		0.0,		1.275,
	"OBD_SHRTFT42","O2 Fuel Trim 4-2",			"%",			-100.0,	99.22,
	"OBD_EQ_RAT11","WideO2 Equiv-Ratio 1-1",	"lambda",	0.0,		1.999,
	"OBD_WO2S11",	"WideO2 Voltage 1-1",			"Volts",		0.0,		7.999,
	"OBD_EQ_RAT12","WideO2 Equiv-Ratio 1-2",	"lambda",	0.0,		1.999,
	"OBD_WO2S12",	"WideO2 Voltage 1-2",			"Volts",		0.0,		7.999,
	"OBD_EQ_RAT21","WideO2 Equiv-Ratio 2-1",	"lambda",	0.0,		1.999,
	"OBD_WO2S21",	"WideO2 Voltage 2-1",			"Volts",		0.0,		7.999,
	"OBD_EQ_RAT22","WideO2 Equiv-Ratio 2-2",	"lambda",	0.0,		1.999,
	"OBD_WO2S22",	"WideO2 Voltage 2-2",			"Volts",		0.0,		7.999,
	"OBD_EQ_RAT31","WideO2 Equiv-Ratio 3-1",	"lambda",	0.0,		1.999,
	"OBD_WO2S31",	"WideO2 Voltage 3-1",			"Volts",		0.0,		7.999,
	"OBD_EQ_RAT32","WideO2 Equiv-Ratio 3-2",	"lambda",	0.0,		1.999,
	"OBD_WO2S32",	"WideO2 Voltage 3-2",			"Volts",		0.0,		7.999,
	"OBD_EQ_RAT41","WideO2 Equiv-Ratio 4-1",	"lambda",	0.0,		1.999,
	"OBD_WO2S41",	"WideO2 Voltage 4-1",			"Volts",		0.0,		7.999,
	"OBD_EQ_RAT42","WideO2 Equiv-Ratio 4-2",	"lambda",	0.0,		1.999,
	"OBD_WO2S42",	"WideO2 Voltage 4-2",			"Volts",		0.0,		7.999,
	"OBD_WBEQ_RAT11", "WB-O2 Equiv-Ratio 1-1",	"lambda",	0.0,		1.999,
	"OBD_WBO2S11", "WB-O2 Voltage 1-1",			"mA",			-128.0,	127.996,
	"OBD_WBEQ_RAT12", "WB-O2 Equiv-Ratio 1-2",	"lambda",	0.0,		1.999,
	"OBD_WBO2S12", "WB-O2 Voltage 1-2",			"mA",			-128.0,	127.996,
	"OBD_WBEQ_RAT21", "WB-O2 Equiv-Ratio 2-1",	"lambda",	0.0,		1.999,
	"OBD_WBO2S21", "WB-O2 Voltage 2-1",			"mA",			-128.0,	127.996,
	"OBD_WBEQ_RAT22", "WB-O2 Equiv-Ratio 2-2",	"lambda",	0.0,		1.999,
	"OBD_WBO2S22", "WB-O2 Voltage 2-2",			"mA",			-128.0,	127.996,
	"OBD_WBEQ_RAT31", "WB-O2 Equiv-Ratio 3-1",	"lambda",	0.0,		1.999,
	"OBD_WBO2S31", "WB-O2 Voltage 3-1",			"mA",			-128.0,	127.996,
	"OBD_WBEQ_RAT32", "WB-O2 Equiv-Ratio 3-2",	"lambda",	0.0,		1.999,
	"OBD_WBO2S32", "WB-O2 Voltage 3-2",			"mA",			-128.0,	127.996,
	"OBD_WBEQ_RAT41", "WB-O2 Equiv-Ratio 4-1",	"lambda",	0.0,		1.999,
	"OBD_WBO2S41", "WB-O2 Voltage 4-1",			"mA",			-128.0,	127.996,
	"OBD_WBEQ_RAT42", "WB-O2 Equiv-Ratio 4-2",	"lambda",	0.0,		1.999,
	"OBD_WBO2S42", "WB-O2 Voltage 4-2",			"mA",			-128.0,	127.996,
	"OBD_CATEMP11","Catalyst Temp 1-1",			"degC",		-40.0,	6513.5,
	"OBD_CATEMP21","Catalyst Temp 2-1",			"degC",		-40.0,	6513.5,
	"OBD_CATEMP12","Catalyst Temp 1-2",			"degC",		-40.0,	6513.5,
	"OBD_CATEMP22","Catalyst Temp 2-2",			"degC",		-40.0,	6513.5,
	"OBD_RPM2",		"Engine RPM",							"RPM",		0.0,		20460.0,
};

static _NORM_PID IMSPids[] = {
	"O2",		"Wideband Measurement",				"lambda",	0.5,		1.523,
	"RPM",	"Engine RPM",							"RPM",		0.0,		10230.0,
	"RPM2",	"Engine RPM",							"RPM",		0.0,		20460.0,
	"FREQ",	"Frequency",							"Hz",			0.0,		1000.0,
	"DWELL",	"Dwell",									"%",			0.0,		100.0,
	"EGT",	"EGT",									"degC",		0.0,		1093.0,
	"CHT",	"CHT",									"degC",		0.0,		300.0,
	"SIDE2",	"Side Force 2G",						"g",			-2.0,		2.0,
	"SIDE1",	"Side Force 1G",						"g",			-1.0,		1.0,
	"SIDE25","Side Force .25G",					"g",			-0.25,	0.25,
	"TIMING","Ignition Timing",					"deg",		-10.0,	50.0,
	"MAP3BA","MAP 3Ba",								"PSIa",		0.0,		44.1,
	"MAP1BA","MAP 1Ba",								"PSIa",		0.0,		14.7,
	"MAP3BG","MAP 3Bg",								"PSIg",		-14.7,	29.4,
	"MAP1BG","MAP 1Bg",								"PSIg",		-14.7,	0.0,
	"ACC2",	"Acceleration 2G",					"g",			-2.0,		2.0,
	"ACC1",	"Acceleration 1G",					"g",			-1.0,		1.0,
	"ACC25",	"Acceleration .25G",					"g",			-0.25,	0.25,
	"AUX",	"Aux. Input Volts",					"Volt",		0.0,		5.0,
	"AUXP",	"Aux. Input Percentage",			"%",			0.0,		100.0,
};

#endif
