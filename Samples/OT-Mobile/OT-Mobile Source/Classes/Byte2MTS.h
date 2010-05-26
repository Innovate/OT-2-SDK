/*
	Byte2MTS.h
 
	Convert Byte Stream to MTS packets/information
 
	This is a long, and unfortunately a bit complicated, state machine
	that takes bytes in and syncs to an MTS data stream and parses
	out data channels and query responses.
 
	It is really an old 'C' module, but it is stuffed in a C++ class
	so that it is easy to create more than one instance of it.

	This module could be a lot simpler if LM-1 support was not included.
*/

#ifndef _BYTE2MTS_H
#define _BYTE2MTS_H

// Includes ..................................................................

#include "ims.h"	// Get our basic types and MTS defines

class Byte2MTS
{
public:
	Byte2MTS();
	~Byte2MTS();

	// Here is where we stuff data in
	U8 addByte(U8 cr);
	
	// And here is where we get the results out
	// Yes, ugly, but it is a pretty low level operation
	// anyway
	//
	// We should either get an rxpacket, or a response block

	MTS_DATA_STRUCT rxpacket;	// A 'higher level' data packet out
	U16		rsplen;				// Length
	U8		rxcmdresp;			// Query Response ID
	U8		response[1024];		// Query response
	U8		rxserial1;			// Old LM-1 stream?!
	
private:
	void initRxPacket(void);

	U16		rxlen;
	U8		rxhighbyte;
	U8		rxlm1cnt;
	U8		rx2synccnt;
	int		rxstate;
	U8		rcvLM1;
	U16		hdrword;
};

#endif	// _BYTE2MTS_H
