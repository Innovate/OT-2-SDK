/*
	NetworkDiscovery.mm
 
	Find all the network interfaces and addresses

	From: "iPhone Advanced Projects", Apress
*/

#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <netinet/in.h>

#include <CoreFoundation/CoreFoundation.h>

#import "NetworkDiscovery.h"

@implementation NetworkDiscovery


+ (NSArray*)interfaceNamesAddresses {
	struct ifconf cfg;
	size_t buffer_capacity;
	char* buffer;
	NSMutableArray* names;
	NSString* name;
	int interface;
	
	/* Compute the sizes of ifreq structures
	 containing an IP and an IPv6 address */
	const size_t ifreq_size_in = IFNAMSIZ + sizeof(struct sockaddr_in);
	const size_t ifreq_size_in6 = IFNAMSIZ + sizeof(struct sockaddr_in6);
	
	NSArray* result = nil;
	
	/* Create a dummy socket to execute the IO control on */
	int sock = socket(AF_INET, SOCK_DGRAM, 0);
	if (sock < 0)
		goto done;
	
	/* Repeatedly call the IO control with increasing buffer sizes
	 until the IO control leaves enough space unused to convice us
	 that it didn't skip results due to missing buffer space.
	 */
	buffer_capacity = ifreq_size_in6;
	buffer = NULL;
	do {
		buffer_capacity *= 2;
		char* buffer_new = (char*)realloc(buffer, buffer_capacity);
		if (buffer_new)
			buffer = buffer_new;
		else
			goto done;
		cfg.ifc_len = buffer_capacity;
		cfg.ifc_buf = buffer;
		
		if ((ioctl(sock, SIOCGIFCONF, &cfg) < 0) && (errno != EINVAL))
			goto done;
	} while ((buffer_capacity - cfg.ifc_len) < 2*ifreq_size_in6);
	
	/* Copy the interface names and associated addresses into the result array */
	interface = 0;
	
	names = [NSMutableArray arrayWithCapacity:(buffer_capacity / ifreq_size_in)];
	while(cfg.ifc_len >= ifreq_size_in) {
		/* Skip entries for non-internet addresses */
		if (cfg.ifc_req->ifr_addr.sa_family == AF_INET) {
			name = [NSString stringWithCString:cfg.ifc_req->ifr_name encoding: NSASCIIStringEncoding];
			const struct sockaddr_in* addr_in = (const struct sockaddr_in*) &cfg.ifc_req->ifr_addr;
			in_addr_t addr = addr_in->sin_addr.s_addr;
			/* Skip entries without an interface name or address */
			if ((name.length > 0) && (addr != INADDR_NONE))
				[names addObject:[NSDictionary dictionaryWithObjectsAndKeys:
								  name, @"name",
								  [NSNumber numberWithInt:interface], @"interface",
								  [NSNumber numberWithUnsignedInt:ntohl(addr)], @"address",
								  nil]];
		}
		
		/* Move to the next structure in the buffer */
		cfg.ifc_len -= IFNAMSIZ + cfg.ifc_req->ifr_addr.sa_len;
		cfg.ifc_buf += IFNAMSIZ + cfg.ifc_req->ifr_addr.sa_len;
		interface++;
	}
	result = names;
	
done:
	/* Free the buffer and close the socket if necessary */
	if (buffer)
		free(buffer);
	if (sock >= 0)
		close(sock);
	
	return result;
}


+ (short) interfaceFlags:(NSString*)interface {
	short flags = 0;
	
	/* Create a dummy socket to execute the IO control on */
	int sock = socket(AF_INET, SOCK_DGRAM, 0);
	if (sock < 0)
		goto done;
	
	/* Request structure for SIOCGIFFLAGS */
	struct ifreq req;
	
	/* Copy the interface name into the structure */
	if (![interface getCString:req.ifr_name
					 maxLength:IFNAMSIZ
					  encoding:NSASCIIStringEncoding])
		goto done;
	
	/* Execute the IO control */
	if (ioctl(sock, SIOCGIFFLAGS, &req) != 0)
		goto done;
	
	flags = req.ifr_flags;
	
done:
	close(sock);
	return flags;
}

- (void)dealloc {
	[super dealloc];
}


@end
