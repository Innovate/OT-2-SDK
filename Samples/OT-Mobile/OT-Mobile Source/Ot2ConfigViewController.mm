/*
	Ot2ConfigViewController.mm
 
	Our OT-2 'Configuration Dialog'
*/

#import "ot2.h"
#import "Ot2ConfigViewController.h"

// A helper object for 'active PIDs'

@interface ActivePid : NSObject {
	NSString *Name;
	U16 Pid;
}

- (ActivePid *)initWithName: (NSString *)pname andId: (U16)pid;
- (NSString *)name;
- (U16)pid;

@end

@implementation ActivePid

- (ActivePid *)initWithName: (NSString *)pname andId: (U16)pid
{
	Name = [NSString stringWithString:pname];
	Pid = pid;
	return self;
}

- (NSString *)name
{
	return Name;
}

- (U16)pid
{
	return Pid;
}

- (void)dealloc 
{
	[Name release];
	[super dealloc];
}

@end


@implementation Ot2ConfigViewController

@synthesize channelsButton, protocolButton, channelButton1,  channelButton2,  channelButton3,  channelButton4;
@synthesize channelButton5, channelButton6, channelButton7, channelButton8, channelButton9, channelButton10, channelButton11;
@synthesize channelButton12, channelButton13, channelButton14, channelButton15, channelButton16;
@synthesize setView, setLabel, ourPickerView, okButton;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

/*
	testPidAvailability:
 
	Test an ECU pid against the Connection Status Mask
	*if* we are connected. If we aren't connected, always
	say yes!
 
	This let's us edit with no ECU connected, but let's
	the user pick bogus choices too.
*/

// A list of ECU pids used by the 'normative pids'

const U8 EcuPidTable[] = {
	0,		// 0 NONE
	0x0C,	// 1 RPM
	0x11,	// 2 TP
	0x04,	// 3 LOAD_PCT
	0x0E,	// 4 SPARKADV
	0x10,	// 5 MAF
	0x0B,	// 6 MAP
	0x0D,	// 7 VSS
	0x05,	// 8 ECT
	0x0F,	// 9 IAT
	0x1E,	// 10 PTO_STAT
	0x03,	// 11 FUEL1_OL
	0x03,	// 12 FUEL2_OL
	0x06,	// 13 SHRTFT1
	0x07,	// 14 LONGFT1
	0x08,	// 15 SHRTFT2
	0x09,	// 16 LONGFT2
	0x06,	// 17 SHRTFT3
	0x07,	// 18 LONGFT3
	0x08,	// 19 SHRTFT4
	0x09,	// 20 LONGFT4
	0x0A,	// 21 FRP
	0x22,	// 22 FRP_MED
	0x23,	// 23 FRP_HIGH
	0x44,	// 24 EQ_RAT
	0x43,	// 25 LOAD_ABS (Clipped to 802.75)
	0x2C,	// 26 EGR_PCT
	0x2D,	// 27 EGR_ERR
	0x45,	// 28 TP_R
	0x47,	// 29 TP_B
	0x48,	// 30 TP_C
	0x49,	// 31 APP_D
	0x4A,	// 32 APP_E
	0x4B,	// 33 APP_F
	0x4C,	// 34 TAC_PCT
	0x2E,	// 35 EVAP_PCT
	0x32,	// 36 EVAP_VP Signed?
	0x12,	// 37 AIR_UPS
	0x12,	// 38 AIR_DNS
	0x12,	// 39 AIR_OFF
	0x2F,	// 40 FLI
	0x33,	// 41 BARO
	0x46,	// 42 AAT
	0x42,	// 43 VPWR
	0x01,	// 44 MIL
	0x01,	// 45 DTC_CNT
	0x21,	// 46 MIL_DIST
	0x4D,	// 47 MIL_TIME (mins->hours)
	0x31,	// 48 CLR_DIST
	0x30,	// 49 WARM_UPS
	0x1F,	// 50 RUNTM (secs->minutes)
	0x14,	// 51 OS211
	0x14,	// 52 SHRTFT11
	0x15,	// 53 OS212
	0x15,	// 54 SHRTFT12
	0x16,	// 55 OS221
	0x16,	// 56 SHRTFT21
	0x17,	// 57 OS222
	0x17,	// 58 SHRTFT22
	0x18,	// 59 OS231
	0x18,	// 60 SHRTFT31
	0x19,	// 61 OS232
	0x19,	// 62 SHRTFT32
	0x1A,	// 63 OS241
	0x1A,	// 64 SHRTFT41
	0x1B,	// 65 OS242
	0x1B,	// 66 SHRTFT42
	0x24,	// 67 EQ_RAT11
	0x24,	// 68 WOS211
	0x25,	// 69 EQ_RAT12
	0x25,	// 70 WOS212
	0x26,	// 71 EQ_RAT21
	0x26,	// 72 WOS221
	0x27,	// 73 EQ_RAT22
	0x27,	// 74 WOS222
	0x28,	// 75 EQ_RAT31
	0x28,	// 76 WOS231
	0x29,	// 77 EQ_RAT32
	0x29,	// 78 WOS232
	0x2A,	// 79 EQ_RAT41
	0x2A,	// 80 WOS241
	0x2B,	// 81 EQ_RAT42
	0x2B,	// 82 WOS242
	0x34,	// 83 WBEQ_RAT11
	0x34,	// 84 WBOS211
	0x35,	// 85 WBEQ_RAT12
	0x35,	// 86 WBOS212
	0x36,	// 87 WBEQ_RAT21
	0x36,	// 88 WBOS221
	0x37,	// 89 WBEQ_RAT22
	0x37,	// 90 WBOS222
	0x38,	// 91 WBEQ_RAT31
	0x38,	// 92 WBOS231
	0x39,	// 93 WBEQ_RAT32
	0x39,	// 94 WBOS232
	0x3A,	// 95 WBEQ_RAT41
	0x3A,	// 96 WBOS241
	0x3B,	// 97 WBEQ_RAT42
	0x3B,	// 98 WBOS242
	0x3C,	// 99 CATEMP11
	0x3D,	// 100 CATEMP21
	0x3E,	// 101 CATEMP12
	0x3F,	// 102 CATEMP22
	0x0C	// 103 RPM_EXT
};

- (bool)testPidAvailability: (U16)pid
{
	U8 index;
	U8 bit;
	
	// Nothing to check against, so default to yes
	if (! otConnectionStatus.ConnectionStatus)
		return 1;
	
	// None is special
	if (! pid)
		return 1;

	// Otherwise, we check the ECU pid against the BIT masks
	pid = EcuPidTable[pid];
	pid--;
	index = pid / 0x20;
	bit = pid % 0x20;
	
	if (otConnectionStatus.PidMasks[index] & (0x80000000 >> bit))
		return 1;
	
	return 0;
}

// We are being asked to initialize, along with a connection status
- (Ot2ConfigViewController *)initWithConnectionStatus: (OT_CONNECTION_STATUS *)status
{
	// Save the status (it will get used in viewDidLoad below)
	memcpy(&otConnectionStatus, status, sizeof(OT_CONNECTION_STATUS));
	
	// Load our nib
	[self initWithNibName:@"Ot2ConfigViewController" bundle:nil];

	return self;
}

- (void)updateDisplay
{
	// Channels
	[channelsButton setTitle:[NSString stringWithFormat: @"%d", otConfiguration.Channels] forState:UIControlStateNormal];
	
	NSString *valStr;
	
	// Current Protocol
	switch (otConfiguration.Protocol)
	{
		case OT_PROTO_CAN:
			valStr = [[NSString alloc] initWithString:@"ISO 15765"];
			break;
		case OT_PROTO_PWM:
			valStr = [[NSString alloc] initWithString:@"J1850 PWM"];
			break;
		case OT_PROTO_VPW:
			valStr = [[NSString alloc] initWithString:@"J1850 VPW"];
			break;
		case OT_PROTO_KWP:
			valStr = [[NSString alloc] initWithString:@"KWP 2000"];
			break;
		case OT_PROTO_ISO:
			valStr = [[NSString alloc] initWithString:@"ISO 9141"];
			break;
		default:
			valStr = [[NSString alloc] initWithString:@"Automatic"];
 	}
	
	[protocolButton setTitle:valStr forState:UIControlStateNormal];
	[valStr release];
	
	for (int n=0 ; n<16 ; n++)
	{
		// Pid Name
		valStr = [[OT2 instance] getPidName:otConfiguration.NormPid[n]];
		[buttons[n] setTitle:valStr forState:UIControlStateNormal];
		[valStr release];
		
		// Blue for low priority, otherwise, black
		if (otConfiguration.Flags & (1 << n))
			[buttons[n] setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
		else
			[buttons[n] setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
	}
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
	// OK, time to populate our 'dialog box'
	// Fetch the current configuration
	[[OT2 instance] otConfig:&otConfiguration];
	
	// We're unchanged
	hasChanged = NO;
	
	// Build a list of available pids
	activePids = [[NSMutableArray alloc] init];
	
	for (int n=0 ; n< (sizeof(EcuPidTable) / sizeof(U8)) ; n++)
	{
		if ([self testPidAvailability:n])
		{
			ActivePid *pid = [[ActivePid alloc] initWithName:[[OT2 instance] getPidName:n] andId:n];
			[activePids addObject:pid];
			[pid release];
		}
	}
	
	// Setup our buttons
	
	// Put the channel buttons in an array for ease of use
	// later
	buttons[0] = channelButton1;
	buttons[1] = channelButton2;
	buttons[2] = channelButton3;
	buttons[3] = channelButton4;
	buttons[4] = channelButton5;
	buttons[5] = channelButton6;
	buttons[6] = channelButton7;
	buttons[7] = channelButton8;
	buttons[8] = channelButton9;
	buttons[9] = channelButton10;
	buttons[10] = channelButton11;
	buttons[11] = channelButton12;
	buttons[12] = channelButton13;
	buttons[13] = channelButton14;
	buttons[14] = channelButton15;
	buttons[15] = channelButton16;
	
	[self updateDisplay];
	
	[setView setAlpha:0.0];
    [super viewDidLoad];
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

// Channel Button pressed
- (IBAction)channelPress:(id)sender
{
	setLabel.text = [NSString stringWithString:@"Number of Channels:"];
	selectionMode = SELECT_CHANNELS;
	ourPickerView.delegate = self;
	ourPickerView.showsSelectionIndicator = YES;

	selectionCurrent[0] = selectionNew[0] = (otConfiguration.Channels - 1);
	[ourPickerView selectRow:(otConfiguration.Channels -1) inComponent:0 animated:NO];	
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	[UIView beginAnimations:nil context:context];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:.5];
	[setView setAlpha:1.0];	
	[UIView commitAnimations];
}

// Protocol button pressed
- (IBAction)protocolPress:(id)sender
{
	setLabel.text = [NSString stringWithString:@"ECU Protocol:"];
	selectionMode = SELECT_PROTOCOL;
	ourPickerView.delegate = self;
	ourPickerView.showsSelectionIndicator = YES;

	selectionCurrent[0] = selectionNew[0] = otConfiguration.Protocol;
	[ourPickerView selectRow:otConfiguration.Protocol inComponent:0 animated:NO];	
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	[UIView beginAnimations:nil context:context];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:.5];
	[setView setAlpha:1.0];	
	[UIView commitAnimations];
}

// Pid Button pressed
- (IBAction)pidPress:(id)sender
{
	int n;
	
	// Find which button
	for (n=0 ; n< 16 ; n++)
		if (buttons[n] == sender)
			break;
	
	// Huh?
	if (n == 16)
		return;
	
	selectionIndex = n;

	// Now see if the current PID is a selection
	U16 pid = otConfiguration.NormPid[n];
	
	for (n=0 ; n< [activePids count] ; n++)
		if ([[activePids objectAtIndex:n] pid] == pid)
			break;

	// Not in our list, default to 'none'
	if (n == [activePids count])
		n = 0;
	
	setLabel.text = [NSString stringWithString:@"ECU Function/Priority:"];
	selectionMode = SELECT_PID;
	ourPickerView.delegate = self;
	ourPickerView.showsSelectionIndicator = YES;
	
	// Set our 'pid'
	[ourPickerView selectRow:n inComponent:0 animated:NO];	
	
	selectionCurrent[0] = selectionNew[0] = n;
	
	// Set our 'priority'
	if (otConfiguration.Flags & (1 << selectionIndex))
		n = 1;
	else
		n = 0;
	
	[ourPickerView selectRow:n inComponent:1 animated:NO];	

	selectionCurrent[1] = selectionNew[1] = n;

	CGContextRef context = UIGraphicsGetCurrentContext();
	[UIView beginAnimations:nil context:context];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:.5];
	[setView setAlpha:1.0];	
	[UIView commitAnimations];
}


// The user may have changed something
// If so, we do an 'M' here (temporarily change settings)
// And then a 'C' (write to flash) later. We do this because
// They get immediate changes without a zillion flash writes
- (IBAction)okPress:(id)sender
{
	// What were we selecting?
	switch (selectionMode)
	{
		case SELECT_CHANNELS:
			if (selectionCurrent[0] != selectionNew[0])
			{
				otConfiguration.Channels = selectionNew[0] + 1;
				[[OT2 instance] commandRequest:OT2_CMD_TEMP_CONFIG withData:&otConfiguration ofSize: sizeof(otConfiguration)];
				[self updateDisplay];
				hasChanged = YES;
			}
			break;
			
		case SELECT_PROTOCOL:
			if (selectionCurrent[0] != selectionNew[0])
			{
				otConfiguration.Protocol = selectionNew[0];
				[[OT2 instance] commandRequest:OT2_CMD_TEMP_CONFIG withData:&otConfiguration ofSize: sizeof(otConfiguration)];
				[self updateDisplay];
				hasChanged = YES;
			}
			break;

		case SELECT_PID:	// Slightly more complicated, since array is not nec. 1:1 with actual Pids
			// Did either pid or priority change?
			if ( (selectionCurrent[0] != selectionNew[0]) || (selectionCurrent[1] != selectionNew[1]))
			{
				// Update the PID
				otConfiguration.NormPid[selectionIndex] = [[activePids objectAtIndex:selectionNew[0]] pid];
				
				// And the priority
				if (selectionNew[1])
					otConfiguration.Flags |= (1 << selectionIndex);
				else
					otConfiguration.Flags &= ~(1 << selectionIndex);

				[[OT2 instance] commandRequest:OT2_CMD_TEMP_CONFIG withData:&otConfiguration ofSize: sizeof(otConfiguration)];
				[self updateDisplay];
				hasChanged = YES;				
			}
			break;
	}
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	[UIView beginAnimations:nil context:context];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:.5];
	[setView setAlpha:0.0];	
	[UIView commitAnimations];

	ourPickerView.showsSelectionIndicator = NO;	
	ourPickerView.delegate = nil;
}

// After we've slid offscreen, remove us from the superview
// and put us back into position
- (void) animationCallback
{
	[[self view] removeFromSuperview];
	[self release];
}

// The 'done' button has been pressed
// We do a fancy exit
- (IBAction)donePress:(id)sender
{
	// Did we make any changes?
	// Then commit them to flash
	// Note! You should not update flash unless you have a compelling reason to do so
	// In this case, we're letting the user edit the settings in the device, so it makes
	// sense, but if you just need specific channels for the duration of your app, just
	// use temp changes (like this sample does when the 'dialog' is still up).
	// These go away when you exit (or send an 'm' to the hardware).
	if (hasChanged == YES)
		[[OT2 instance] commandRequest:OT2_CMD_PERMANENT_CONFIG withData:&otConfiguration ofSize: sizeof(otConfiguration)];

	CGRect frame;
	
	frame = [[self view] frame];
	frame.origin.y += 460;
		
	CGContextRef context = UIGraphicsGetCurrentContext();
	[UIView beginAnimations:nil context:context];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:0.5];

	[[self view] setFrame:frame];
	[UIView commitAnimations];
	
	[self performSelector:@selector(animationCallback) withObject:nil afterDelay: 0.5];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload 
{
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc 
{
	[activePids release];
	[channelsButton release];
	[protocolButton release];
	[channelButton1 release];
	[channelButton2 release];
	[channelButton3 release];
	[channelButton4 release];
	[channelButton5 release];
	[channelButton6 release];
	[channelButton7 release];
	[channelButton8 release];
	[channelButton9 release];
	[channelButton10 release];
	[channelButton11 release];
	[channelButton12 release];
	[channelButton13 release];
	[channelButton14 release];
	[channelButton15 release];
	[channelButton16 release];
	[setLabel release];
	[ourPickerView release];
	[okButton release];
	[setView release];
    [super dealloc];
}

// Picker View Stuff
// We conditionally configure it depending on what we are selecting

// Number of Wheels
- (NSInteger)numberOfComponentsInPickerView: (UIPickerView *)pickerView
{
	if (selectionMode != SELECT_PID)
		return 1;
	else 
		return 2;
}

// Number of Rows
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent: (NSInteger)component
{
	if (component == 1)
		return 2;
	else 
	{
		if (selectionMode == SELECT_CHANNELS)
			return 16;
		else if (selectionMode == SELECT_PROTOCOL)
			return 6;
		else
			return [activePids count];
	}
}

// Widths
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
	if (selectionMode == SELECT_CHANNELS)
		return 42.0;
	else if (selectionMode == SELECT_PID && component)
		return 90.0;
	else if (selectionMode == SELECT_PROTOCOL)
		return 140.0;
	else
		return 200.0;
}

// Names
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	if (component)
	{
		if (! row)
			return [NSString stringWithString:@"Normal"];
		else 
			return [NSString stringWithString:@"Low"];
	}
	else
	{
		if (selectionMode == SELECT_CHANNELS)
			return [NSString stringWithFormat:@"%d", row+1];
		else if (selectionMode == SELECT_PROTOCOL)
		{
			switch (row)
			{
				case 1:
					return [NSString stringWithString:@"ISO 15765"];
				case 2:
					return [NSString stringWithString:@"J1850 PWM"];
				case 3:
					return [NSString stringWithString:@"J1850 VPW"];
				case 4:
					return [NSString stringWithString:@"KWP 2000"];
				case 5:
					return [NSString stringWithString:@"ISO 9141"];
				default:
					return [NSString stringWithString:@"Automatic"];
			}
		}
		else 
			return [[activePids objectAtIndex:row] name];
	}
}


// Selection
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component;
{
	// We just save the changes here and act on them when OK is pressed later
	selectionNew[component] = row;
}

@end
