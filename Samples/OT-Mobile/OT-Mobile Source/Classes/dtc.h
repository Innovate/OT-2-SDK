// DTC Lookup

#ifndef _DTC_H
#define _DTC_H

// Includes ..................................................................

#include "ims.h"	// We use IMS data types


// Public API.................................................................

const char * dtcFind(U16 dtc);
void dtcFormat(U16 dtc, char *outstr);

#endif	// _DTC_H
