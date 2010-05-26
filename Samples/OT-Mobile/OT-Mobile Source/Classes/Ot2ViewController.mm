/*
	Ot2ViewController.mm

	Basic OT2 stats and configuration
*/

#import "ot2.h"
#import "Ot2ViewController.h"


@implementation Ot2ViewController

@synthesize yellowStatusImage, greenStatusImage, ot2Text;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

// User pressed the info button
- (IBAction)infoPress:(id)sender
{
	OT2 *ot2;
	

	ot2 = [OT2 instance];
	if ([ot2 state] != OT2_CONNECTED)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" 
														message:@"You cannot configure the OT-2 when you are not connected. Check your Wi-Fi settings."
													   delegate:nil 
											  cancelButtonTitle:@"OK" 
											  otherButtonTitles: nil];
		[alert show];
		[alert release];		
	}
    else
	{
		// Ease in our configuration dialog
		// We create it here, it will self release
		// when done.
		Ot2ConfigViewController *configController = [[Ot2ConfigViewController alloc] initWithConnectionStatus: &otConnectStatus];
		
		// Shift it down, then tell the system to animate it up into position
		CGRect frame;	
		frame = [[configController view] frame];
		frame.origin.y += 460;
		[[configController view] setFrame:frame];
		frame.origin.y -= 460;
		[[self view] addSubview:[configController view]];

		CGContextRef context = UIGraphicsGetCurrentContext();
		[UIView beginAnimations:nil context:context];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		[UIView setAnimationDuration:0.5];
		[[configController view] setFrame:frame];
		[UIView commitAnimations];
	}
}

// Collect basic information about the unit/setup
- (NSString *) baseInfo
{
	char macstr[20];
	char ipstr[20];
	char verstr[6];
	char mtsstr[MTS_MAX_DEVICE * 7];
	char outstr[512];
	
	OT_WIFI_SETTINGS wset;
	MTS_DEVICE_TYPE dtypes[MTS_MAX_DEVICE];
	
	OT2 *ot2 = [OT2 instance];
	
	// Device count and dtypes
	U16 devcount = [ot2 deviceCount];
	[ot2 deviceTypes:dtypes];
	
	// Channel count
	U16 channelcount = [ot2 channelCount];
	
	// WiFi Info
	[ot2 wifiInfo:&wset];
	
	// Now we can build our version, MAC, and MTS strings
	// Network
	sprintf(macstr, "%02x:%02x:%02x:%02x:%02x:%02x", 
			wset.HWAddr[0], wset.HWAddr[1],wset.HWAddr[2],
			wset.HWAddr[3], wset.HWAddr[4], wset.HWAddr[5]);
	
	sprintf(ipstr, "%ld.%ld.%ld.%ld", (wset.IPAddr & 0xFF), ((wset.IPAddr >> 8) & 0xFF),
			((wset.IPAddr >> 16) & 0xFF), ((wset.IPAddr >> 24) & 0xFF));
	
	// Version string
	U8 versionH = dtypes[devcount-1].versionH;
	U8 versionL = dtypes[devcount-1].versionL;

	if (versionL & 0xF)
		sprintf(verstr, "%d.%d%d%x", (versionH >> 4), (versionH & 0xF), (versionL >> 4), (versionL & 0xF));
	else 
		sprintf(verstr, "%d.%d%d", (versionH >> 4), (versionH & 0xF), (versionL >> 4));
	
	// MTS
	mtsstr[0] = 0;
	for (int n=0 ; n<devcount ; n++)
	{
		if (n)
			strcat(mtsstr, "-> ");
		
		// Kludgy way to turn ID into string
		dtypes[n].cputype = 0;
		strcpy(mtsstr + strlen(mtsstr), (char *)(&dtypes[n])+2);
	}
	
	// combine them
	sprintf(outstr, "OT-2:\rFirmware: %s\rIP Address: %s\rMAC: %s\r\rMTS (%d channels):\r%s", 
			verstr, ipstr, macstr, channelcount, mtsstr);
	
	// Build an NSString to return
	NSString *valStr = [[NSString alloc] initWithCString:outstr];
	return valStr;
}


// Update our display to match state
- (void) updateStatus
{
	OT2 *ot2;
	NSString *valStr;
	
	ot2 = [OT2 instance];
	
	switch ([ot2 state])
	{
		case OT2_CONNECTED:
			if ([ot2 sdk])
			{
				valStr = [self baseInfo];
				ot2Text.text = valStr;
				[valStr release];
			}
			else
			{
				valStr = [[NSString alloc] initWithString:@"No Information Available"];
				ot2Text.text = valStr;
				[valStr release];				
			}
			yellowStatusImage.alpha = 0.0;
			greenStatusImage.alpha = 1.0;
			
			// Request our Connection State
			[ot2 commandRequest:OT2_CMD_CONNECT_STATE];
			break;
			
		case OT2_DISCONNECTED:
			valStr = [[NSString alloc] initWithString:@"Not Connected"];
			ot2Text.text = valStr;
			[valStr release];
			
			yellowStatusImage.alpha = 0.0;
			greenStatusImage.alpha = 0.0;
			break;
			
		default:
			valStr = [[NSString alloc] initWithString:@"Establishing connection..."];
			ot2Text.text = valStr;
			[valStr release];
			yellowStatusImage.alpha = 1.0;
			greenStatusImage.alpha = 0.0;
			break;
	}	
}

// Tracking state changes
// For state changes from the OT-2 object
- (void) onStatusChanged: (NSNotification *)aNotification
{
	// Update the display, our status has changed.
	[self updateStatus];
}

// In response to our commands
// We basically ignore negative, and append strings in
// response to positive
- (void) onCommandResponse: (NSNotification *)aNotification
{
	OT2_CMD_RESPONSE response;
		
	// First, try to get a response
	if ([[aNotification object] commandGetResponse:&response] == YES)
	{
		// Only deal with positive responses
		if (response.result == YES)
		{
			NSString *valStr;
			
			if (response.command == OT2_CMD_CONNECT_STATE)
			{
				memcpy(&otConnectStatus, response.data, sizeof(otConnectStatus));
				
				if (otConnectStatus.ConnectionStatus == OT_CONN_NONE ||
					otConnectStatus.ConnectionStatus == OT_CONN_PD)
				{
					valStr = [[NSString alloc] initWithString:ot2Text.text];
					ot2Text.text = [valStr stringByAppendingString:@"\r\rOBD-II:\rECU Not Connected"];
					[valStr release];
				}
				else 
				{
					switch (otConnectStatus.ConnectionStatus)
					{
						case OT_CONN_CAN:	// CAN bus
							valStr = [[NSString alloc] initWithString:ot2Text.text];
							ot2Text.text = [valStr stringByAppendingString:@"\r\rOBD-II:\rConnected ISO 15765 (CAN)"];
							[valStr release];
							break;
						case OT_CONN_PWM:	// J1850 pwm (Ford)
							valStr = [[NSString alloc] initWithString:ot2Text.text];
							ot2Text.text = [valStr stringByAppendingString:@"\r\rOBD-II:\rConnected J1850 PWM (Ford)"];
							[valStr release];
							break;
						case OT_CONN_VPW:	// J1850 vpw (GM)
							valStr = [[NSString alloc] initWithString:ot2Text.text];
							ot2Text.text = [valStr stringByAppendingString:@"\r\rOBD-II:\rConnected J1850 VPW (GM)"];
							[valStr release];
							break;
						case OT_CONN_KWP:	// KWP 2000 (European)
							valStr = [[NSString alloc] initWithString:ot2Text.text];
							ot2Text.text = [valStr stringByAppendingString:@"\r\rOBD-II:\rConnected KWP 2000"];
							[valStr release];
							break;
						default:			// ISO 9141 (Japan, Europe)
							valStr = [[NSString alloc] initWithString:ot2Text.text];
							ot2Text.text = [valStr stringByAppendingString:@"\r\rOBD-II:\rConnected ISO 9141"];
							[valStr release];
							break;
					}
					
					// If we're connected, go ahead and request the VIN
					[[aNotification object] commandRequest:OT2_CMD_GET_VIN];
				}
			}
			else if (response.command == OT2_CMD_GET_VIN)
			{
				if (response.data[0] != OT_MAX_VIN)
				{
					valStr = [[NSString alloc] initWithString:ot2Text.text];
					ot2Text.text = [valStr stringByAppendingString:@"\r\rVIN:\rNot Available"];
					[valStr release];					
				}
				else 
				{
					// If NSString is a good string class, I just do not
					// get how to use it...
					char outstr[OT_MAX_VIN+1];
					char outstr2[32];
					NSString *vstring;
					
					// our VIN string
					memset(outstr, 0, sizeof(outstr));
					strncpy(outstr, (char *)(&response.data[1]), OT_MAX_VIN);
					sprintf(outstr2, "\r\rVIN:\r%s", outstr);
					
					// Now into NSStrings, which we have to be careful
					// to delete (since append makes a new one...)
					vstring = [[NSString alloc] initWithCString:outstr2];
					valStr = [[NSString alloc] initWithString:ot2Text.text];
					ot2Text.text = [valStr stringByAppendingString:vstring];
					[valStr release];					
					[vstring release];
				}
				
				// We'll go ahead and append our PID masks at the end, since
				// They can be useful for debugging
				NSString *pstring = [[NSString alloc] initWithFormat:@"\r\rPid Masks:\r%08x\r%08x\r%08x\r%08x\r%08x\r%08x\r%08x\r%08x",
									 otConnectStatus.PidMasks[0], otConnectStatus.PidMasks[1], otConnectStatus.PidMasks[2], otConnectStatus.PidMasks[3],
									 otConnectStatus.PidMasks[4], otConnectStatus.PidMasks[5], otConnectStatus.PidMasks[6], otConnectStatus.PidMasks[7]];
				
				valStr = [[NSString alloc] initWithString:ot2Text.text];
				ot2Text.text = [valStr stringByAppendingString:pstring];
				[valStr release];
				[pstring release];
				
			}
		}
	}
}


// We were selected by the Tab Bar
// All our view controllers are expected to have this
- (void)viewSelected
{
	// We care about OT-2 State changes
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(onStatusChanged:) 
												 name:OT2_NOTIFICATION_STATE 
											   object:nil];	

	// We care about OT-2 Commands
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(onCommandResponse:) 
												 name:OT2_NOTIFICATION_CMD
											   object:nil];
	
	// Clear the connection status (in case the dialog is invoked before
	// We've had a chance to interogate it
	memset(&otConnectStatus, 0, sizeof(otConnectStatus));
	
	// Update Display to match current state
	[self updateStatus];
}

- (void)viewDeselected
{
	// Unsubscribe from notificaitons
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:OT2_NOTIFICATION_STATE 
												  object:nil];	

	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:OT2_NOTIFICATION_CMD 
												  object:nil];		
}

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	
	// Unsubscribe from notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:OT2_NOTIFICATION_STATE 
												  object:nil];
}


- (void)dealloc {
	[yellowStatusImage release];
	[greenStatusImage release];
    [super dealloc];
}


@end
