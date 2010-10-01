/*
	imsnet.h
 
	The IMSNET Interface
*/

#ifndef _IMSNET_H
#define _IMSNET_H

// IMSNET functions
int imsnetOpen();
void imsnetClose();

void imsnetSendBytes(int len, void *dat);
void imsnetFlush();
bool imsnetIsByte();
BYTE imsnetGetByte();
int imsnetGetBytes(int len, void *buf);

#endif	_IMSNET_H

