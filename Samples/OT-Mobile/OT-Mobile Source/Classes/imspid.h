// IMS PIDs
// These are not ECU pids, but values for IMS data modules

#ifndef _IMSPID_H
#define _IMSPID_H

#define IMS_MAX_PID			(0x1013)

#define IMS_PID_LAMBDA		(0x1000)
#define IMS_PID_RPM			(0x1001)
#define IMS_PID_RPMEXT		(0x1002)
#define IMS_PID_FREQ		(0x1003)
#define IMS_PID_DWELL		(0x1004)
#define IMS_PID_EGT			(0x1005)
#define IMS_PID_CHT			(0x1006)
#define IMS_PID_SIDEFORCE2G (0x1007)
#define IMS_PID_SIDEFORCE1G (0x1008)
#define IMS_PID_SIDEFORCE25G (0x1009)
#define IMS_PID_TIMING		(0x100A)
#define IMS_PID_MAP3BA		(0x100B)
#define IMS_PID_MAP1BA		(0x100C)
#define IMS_PID_MAP3BG		(0x100D)
#define IMS_PID_MAP1BG		(0x100E)
#define IMS_PID_ACC2G		(0x100F)
#define IMS_PID_ACC1G		(0x1010)
#define IMS_PID_ACC25G		(0x1011)
#define IMS_PID_AUXVOLTS	(0x1012)
#define IMS_PID_AUXPERCENT	(0x1013)

#endif // _IMSPID_H
