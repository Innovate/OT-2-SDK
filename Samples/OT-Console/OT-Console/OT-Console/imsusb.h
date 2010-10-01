/*
	imsusb.h

	Public Interface for accessing IMS devices via USB
	For historical reasons, it is a lot like a serial interface
*/

#ifndef _IMSUSB_H
#define _IMSUSB_H

int imsusbOpen();
void imsusbClose();

void imsusbSend(int len, BYTE *buf);
void imsusbFlush();
bool imsusbIsByte();
BYTE imsusbGetByte();
int imsusbGetBytes(int len, BYTE *buf);

#endif // _IMSUSB_H
