/*
	Byte2MTS.mm
 
	Convert Byte Stream to MTS packets/information
 
	This is a long, and unfortunately a bit complicated, state machine
	that takes bytes in and syncs to an MTS data stream and parses
	out data channels and query responses.
 
	It is really an old 'C' module, but it is stuffed in a C++ class
	so that it is easy to create more than one instance of it.
 
	This module could be a lot simpler if LM-1 support was not included.
*/

// Includes ..................................................................

#include "Byte2MTS.h"


// Defines ...................................................................

// Masks to help identify AFR packet types
#define IDENTLM1(x) ((x & 0xA2) == 0x80)
#define IDENTLC1(x) ((x & 0xE2) == 0x42)

// The various 'states' our engine can be in

typedef enum {
	RXSYNCWAIT = 0, //0
	RXGETLEN,		//1
	RXGETCMDRESPONSE,	//2
	RXWAITNXTPKT,	//3
	RXLM1LOW,		//4
	RXLAMBDAHIGH,	//5
	RXLAMBDALOW,	//6
	RXUBATH,		//7
	RXUBATL,		//8
	RXCMDRESPH,		//9
	RXCMDRESPL,		//10
}RXSTATE;


#define LISTN_CMD_BYTE  	0xCC // 'L' with high bit set
#define UNLSTN_CMD_BYTE 	0xEC // 'l' with high bit set


 
// Constructor / Destructor ..................................................

/*
	Byte2MTS
 
	Constructor, just initializes the states to good values
*/

Byte2MTS::Byte2MTS()
{
	rxstate = RXSYNCWAIT;
	rcvLM1 = 0;
	hdrword = 0;
	rx2synccnt = 0;
	rxlm1cnt = 0;
}

/*
	~Byte2MTS
 
	Destructor, empty
*/

Byte2MTS::~Byte2MTS()
{
}


// Helper Functions ..........................................................

/*
	initRxPacket
 
	Initialize our higher level packet for reception
*/

void Byte2MTS::initRxPacket(void)
{
	int i;
	for (i = 0; i< MTS_MAX_CHANS; i++)
		rxpacket.chan[i].func = MTS_FUNC_INVALID;
	rxpacket.ubat = -1;
	rxpacket.afrmult = -1;
	rxpacket.numchans = 0;
}


// Public Interface ..........................................................

/*
	addByte
 
	Feed a byte in, hopefully get parsed MTS packets out

	Returns: TRUE if we have a new packet, FALSE if we are still looking
*/

U8 Byte2MTS::addByte(U8 cr)
{
	U8 syncerr = FALSE;
	short rword;
	
	syncerr = FALSE;
	switch(rxstate)
	{
		case RXSYNCWAIT: //waiting for next packet
			hdrword <<= 8;
			hdrword += cr;
			rxcmdresp = 0;
			if ((cr & 0xA2) == 0xA2) //Serial Prot. 2 header found
			{
				initRxPacket();
				rxstate = RXGETLEN;
				rxlen = (cr & 1) << 7;
				rxhighbyte = cr;
				rxserial1 = FALSE;
				rcvLM1 = 0;
			}
			else if (((cr & 0xA2) == 0x80) && !(hdrword & 0x8000))//LM-1 packet header found
			{
				initRxPacket();
				rxlen = 15; //LM-1 packet is 16 bytes, but we received one already
				rxstate = RXLM1LOW;
				rxhighbyte = cr;
				rxserial1 = TRUE;
				rcvLM1 = 6;
			}	
			break;
		case RXGETLEN:
			syncerr = !(cr & 0x80);
			if (!syncerr)
			{
				rxlen += cr & 0x7F; //get length in bytes
				rxlen <<= 1;
				rxcmdresp = 0;
				if (rxhighbyte & 0x10) //it's not a command response
					rxstate = RXWAITNXTPKT; //but we wait to the end of this packet
				else
				{
					rxstate = RXCMDRESPH; //interpret response command
				}
			}
			break;
		case RXGETCMDRESPONSE:
			rxlen--;
			response[rsplen] = cr;
			rsplen++;
			if (!rxlen)
			{
				rxstate = RXSYNCWAIT; //wait for next packet
				return TRUE;
			}
			break;
			
			
		case RXWAITNXTPKT:
			rxlen--;
			if (rxlen & 1) //high byte
			{
				rxhighbyte = cr;
				if (IDENTLM1(cr) || IDENTLC1(cr))
				{
					rxstate = RXLM1LOW;
					
				}
				else if (syncerr = (cr & 0x80))
					break;
				
			}
			else //low byte
			{
				if (syncerr = (cr & 0x80))
					break;
				rword = (rxhighbyte & 0x3F);
				rword <<=7;
				rword += cr & 0x7F;
				rxpacket.chan[rxpacket.numchans].value = rword;
				rxpacket.chan[rxpacket.numchans].lm1data = (rcvLM1 != 0);
				if (rcvLM1)
					rcvLM1--;
				rxpacket.chan[rxpacket.numchans].func = MTS_FUNC_NOTLAMBDA;
				rxpacket.numchans++;
			}
			
			
			if (!rxlen)
			{
				// received the data packet, add our stuff
				hdrword = 0;
				rxstate = RXSYNCWAIT; //wait for next packet
				switch (rxcmdresp) 
				{
					case 0: // no command
						if (rxserial1)
						{
							if (rxlm1cnt >= 1)
								return TRUE;
							rxlm1cnt++;
						}
						else
						{
							if (rx2synccnt >= 1)
								return TRUE;
							rx2synccnt++;
						}
						return FALSE;
					case MTS_TYPELIST_QUERY:
					case MTS_NAMELIST_QUERY:
						break;
					case LISTN_CMD_BYTE:
						break;
					case UNLSTN_CMD_BYTE:
					default:
						break;
				}
				
				return TRUE; //signal that we got a packet
			}
			break;
		case RXLM1LOW:
			rxlen--;
			if (syncerr = (cr & 0x80))
				break;
			rxpacket.chan[rxpacket.numchans].func = (rxhighbyte >> 2 ) & 7;
			if (rxpacket.afrmult == -1)
			{
				rxpacket.afrmult = cr & 0x7F;
				if (rxhighbyte & 1)
					rxpacket.afrmult |= 0x80;
			}
			rcvLM1 = (IDENTLM1(rxhighbyte) ? 6:0);
			
			rxstate = RXLAMBDAHIGH;
			break;
		case RXLAMBDAHIGH:
			rxlen--;
			if (syncerr = (cr & 0x80))
				break;
			rxhighbyte = cr;
			rxstate = RXLAMBDALOW;
			break;
		case RXLAMBDALOW:
			rxlen--;
			if (syncerr = (cr & 0x80))
				break;
			rword = (rxhighbyte & 0x3F);
			rword <<=7;
			rword += cr & 0x7F;
			rxpacket.chan[rxpacket.numchans].value = rword;
			
			if (rxserial1 || rcvLM1)
			{
				rxpacket.chan[rxpacket.numchans].lm1data = 1;
				if (rcvLM1)
					rcvLM1--;
				rxstate = RXUBATH;
			}
			else
			{
				rxpacket.chan[rxpacket.numchans].lm1data = (rcvLM1);
				if (rxlen)
					rxstate = RXWAITNXTPKT;
				else
				{
					rxstate = RXSYNCWAIT;
					if (rx2synccnt >= 3)
					{
						rxpacket.numchans++;
						return TRUE;
					}
					rx2synccnt++;
				}
			}
			rxpacket.numchans++;
			break;
		case RXUBATH:
			rxlen--;
			if (syncerr = (cr & 0x80))
				break;
			rxhighbyte = cr;
			rxstate = RXUBATL;
			break;
		case RXUBATL:
			rxlen--;
			if (syncerr = (cr & 0x80))
				break;
		{
			rword = (rxhighbyte & 7);
			rword <<= 7;
			rword += cr & 0x7F;
			
			float f = (float)((rxhighbyte >> 3) & 0x7);
			f *= rword;
			f *= 5;
			f /= 1023;
			rxpacket.ubat = f;
		}
			rxstate = RXWAITNXTPKT;
			break;
			
		case RXCMDRESPH: //get high byte of command in the response
			rxlen--;
			
			if (cr & 1)
				rxcmdresp = 0x80;
			else
				rxcmdresp = 0;
			rxstate = RXCMDRESPL;
			break;
		case RXCMDRESPL: //get low byte of command response
			rxlen--;
			rxcmdresp |= cr & 0x7F;
			rsplen = 0; 
			rxstate = RXGETCMDRESPONSE;
			break;
	}
	if (syncerr)
	{
		rxstate = RXSYNCWAIT; //error in syncronisation
		rx2synccnt = 0;
		rxlm1cnt = 0;
	}
	
	return FALSE;
}
