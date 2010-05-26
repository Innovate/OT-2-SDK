/*
	NetworkDiscovery.mm
 
	Find all the network interfaces and addresses
 
	From: "iPhone Advanced Projects", Apress
*/


#include <CoreFoundation/CoreFoundation.h>

#import <Foundation/Foundation.h>

@interface NetworkDiscovery : NSObject {
}

+ (NSArray*)interfaceNamesAddresses;
+ (short) interfaceFlags:(NSString*)interface;
@end
