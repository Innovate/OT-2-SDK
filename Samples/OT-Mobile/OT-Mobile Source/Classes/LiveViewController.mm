/*
	LiveViewController.mm

	This view controller shows live data from the OT-2
*/

#import "ot2.h"
#import "LiveConfigViewController.h"
#import "LiveViewController.h"


@implementation LiveViewController

@synthesize yellowStatusImage, greenStatusImage;
@synthesize nameOne, nameTwo, nameThree;
@synthesize unitsOne, unitsTwo, unitsThree;
@synthesize valueOne, valueTwo, valueThree;
@synthesize g1l1, g1l2, g1l3, g1l4, g1l5, g1l6, g1l7, g1l8, g1l9, g1l10, g1l11;
@synthesize g1l12, g1l13, g1l14, g1l15, g1l16, g1l17, g1l18, g1l19, g1l20, g1l21;
@synthesize g2l1, g2l2, g2l3, g2l4, g2l5, g2l6, g2l7, g2l8, g2l9, g2l10, g2l11;
@synthesize g2l12, g2l13, g2l14, g2l15, g2l16, g2l17, g2l18, g2l19, g2l20, g2l21;
@synthesize g3l1, g3l2, g3l3, g3l4, g3l5, g3l6, g3l7, g3l8, g3l9, g3l10, g3l11;
@synthesize g3l12, g3l13, g3l14, g3l15, g3l16, g3l17, g3l18, g3l19, g3l20, g3l21;

/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

// Helper to turn off all the 'leds' in a gauge
- (void)ledsOff: (int)gauge
{
	for (int n=0 ; n<21 ; n++)
		leds[gauge][n].alpha = 0;
}

// Display a 0-1023 value proportionally along the 21 'leds'
- (void)ledsDisplay: (int)gauge withValue: (U16)value
{
	// We have to do every 'led' every time
	for (int n=0 ; n<21 ; n++)
	{
		// Full LEDs
		if (value >= 48)
		{
			leds[gauge][n].alpha = 1.0;
			value -= 48;
		}
		else if (value)	// Anything left over?
		{
			CGFloat f = value;
			
			f *= 4.0;	// Turn into fourths
			f /= 48.0;
			
			if (f < 1.0)	// At least 1
				f = 1.0;
			
			leds[gauge][n].alpha = f * 0.25;
			value = 0;
		}
		else	// Rest are off
			leds[gauge][n].alpha = 0.0;
	}	
}

// Set the alphas to match function and value for the 'leds' in a gauge
- (void)ledsSet: (int)gauge withValue: (U16)value andFunc: (U16)func
{
	// We handle the functions specially
	// First, aux channels and lambda
	if (func == MTS_FUNC_NOTLAMBDA || func == MTS_FUNC_LAMBDA)
	{
		// We'll display the whole range, but tweak 0 to be a value
		if (value == 0)
			value = 1;	// At least one led 'dim'
		else if (value > 1023)
			value = 1023;
		
		[self ledsDisplay:gauge withValue:value];
	}
	else if (func == MTS_FUNC_O2)		// O2 display
	{
		// Really lean...
		[self ledsOff:gauge];
		leds[gauge][20].alpha = 1.0;
	}
	else	// All others, LED's are off
		[self ledsOff:gauge];
}

// Update gauge units/names
- (void) updateGaugeFaces
{
	U16 count = [[OT2 instance] channelCount];
	
	for (int i=0 ; i<3 ; i++)
	{
		NSString *valStr;
		
		// Valid channel?
		if ( (configInfo.gaugeChannels[i] != -1) &&
			 (configInfo.gaugeChannels[i] < count) )
		{		
			// Get the channel name
			valStr = [[OT2 instance] channelName:configInfo.gaugeChannels[i]];
			names[i].text = valStr;
			[valStr release];
			
			// Get the units
			// We only ask for imperial, but we could say 'No' for 
			// Metric
			valStr = [[OT2 instance] channelUnits:configInfo.gaugeChannels[i] 
									   isImperial:configInfo.isImperial 
											isAFR:configInfo.isAFR];
			units[i].text = valStr;
			[valStr release];
		}
		else
		{
			names[i].text = [gaugeNames objectAtIndex:i];
			valStr = [[NSString alloc] initWithString:@""];
			units[i].text = valStr;
			[valStr release];
		}
	}
	
}

// For state changes from the OT-2 object
- (void) onStatusChanged: (NSNotification *)aNotification
{
	// Get the state
	int n = [[aNotification object] state];
	
	// Set our state 'lights'
	if (n == OT2_DISCONNECTED)		
	{
		yellowStatusImage.alpha = 0.0;
		greenStatusImage.alpha = 0.0;
		
		NSString *valStr = [[NSString alloc] initWithString:@""];
		for (int i=0 ; i<3 ; i++)
		{
			names[i].text = valStr;
			units[i].text = valStr;
			values[i].text = valStr;
			
			[self ledsOff: i];
		}
		[valStr release];
	}
	else if (n == OT2_CONNECTED)
	{
		yellowStatusImage.alpha = 0.0;
		greenStatusImage.alpha = 1.0;

		// Try to resolve our channels
		for (int i=0 ; i<3 ; i++)
		{
			// Start with 'nope'
			configInfo.gaugeChannels[i] = -1;
			
			for (int x=0 ; x < [[OT2 instance] channelCount] ; x++)
			{
				NSString *valStr = [[OT2 instance] channelName:x];
				NSComparisonResult rslt = [(NSString *)([gaugeNames objectAtIndex:i]) compare:valStr];
				[valStr release];
				if (! rslt)
				{
					configInfo.gaugeChannels[i] = x;
					break;
				}
			}
		}
		[self updateGaugeFaces];
	}
	else
	{
		yellowStatusImage.alpha = 1.0;
		greenStatusImage.alpha = 0.0;
	}	
}

- (void) onNewPacket: (NSNotification *)aNotification
{
	// Get our value as a string
	U16 ChannelCount = [[aNotification object] channelCount];
	
	for (int i=0 ; i<3 ; i++)
	{
		NSInteger chan = configInfo.gaugeChannels[i];
		
		// Valid channel?
		if ((chan < ChannelCount) && (chan != -1))
		{
			// O2 is grey, errors in red, everything else in orange
			U16 n = [[aNotification object] channelFunction:chan];
			if (n == MTS_FUNC_O2)
				values[i].textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];		
			else if (n == MTS_FUNC_ERROR)
				values[i].textColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0];				
			else
				values[i].textColor = [UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:1.0];		
		
			// Get the actual value
			NSString *valStr = [[aNotification object] channelValue:chan 
														 isImperial:configInfo.isImperial 
															  isAFR:configInfo.isAFR];
			values[i].text = valStr;
			[valStr release];
			
			// Get the raw value and update the LED
			U16 raw = [[aNotification object] channelRaw:chan];
			[self ledsSet:i withValue:raw andFunc:n];
		}
		else
		{
			[self ledsOff:i];
			values[i].text = [NSString stringWithString:@""];
		}
	}
}


// User pressed the info button
- (IBAction)infoPress:(id)sender
{
	OT2 *ot2;
	
	ot2 = [OT2 instance];
	if ([ot2 state] != OT2_CONNECTED)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" 
														message:@"You cannot configure this view when you are not connected. Check your Wi-Fi settings."
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
		LiveConfigViewController *configController = [[LiveConfigViewController alloc] initWithInfo:&configInfo
																						   delegate:self];
		
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

// Called whent the config dialog is done
- (void)LiveConfigViewDone: (LIVECONFIG_INFO *)info
{
	// Save our working copy
	memcpy(&configInfo, info, sizeof(configInfo));
	
	// Update our string names
	[gaugeNames removeAllObjects];
	for (int n=0 ; n<3 ; n++)
	{
		if (configInfo.gaugeChannels[n] == -1)
			[gaugeNames addObject:[NSString stringWithString:@""]];
		else
		{
			NSString *valString = [[OT2 instance] channelName:configInfo.gaugeChannels[n]];
			[gaugeNames addObject:valString];
			[valString release];
		}
	}
	
	// Save our defaults
	[[NSUserDefaults standardUserDefaults] setObject:gaugeNames forKey:@"gaugenames"];
	[[NSUserDefaults standardUserDefaults] setBool:configInfo.isImperial forKey:@"imperial"];
	[[NSUserDefaults standardUserDefaults] setBool:configInfo.isAFR forKey:@"afr"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[self updateGaugeFaces];	
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	// Build some arrays for use in notificaitons
	names[0] = nameOne;
	names[1] = nameTwo;
	names[2] = nameThree;

	units[0] = unitsOne;
	units[1] = unitsTwo;
	units[2] = unitsThree;

	values[0] = valueOne;
	values[1] = valueTwo;
	values[2] = valueThree;
	
	// And our brute force gauge LED's
	leds[0][0] = g1l1;
	leds[0][1] = g1l2;
	leds[0][2] = g1l3;
	leds[0][3] = g1l4;
	leds[0][4] = g1l5;
	leds[0][5] = g1l6;
	leds[0][6] = g1l7;
	leds[0][7] = g1l8;
	leds[0][8] = g1l9;
	leds[0][9] = g1l10;
	leds[0][10] = g1l11;
	leds[0][11] = g1l12;
	leds[0][12] = g1l13;
	leds[0][13] = g1l14;
	leds[0][14] = g1l15;
	leds[0][15] = g1l16;
	leds[0][16] = g1l17;
	leds[0][17] = g1l18;
	leds[0][18] = g1l19;
	leds[0][19] = g1l20;
	leds[0][20] = g1l21;

	leds[1][0] = g2l1;
	leds[1][1] = g2l2;
	leds[1][2] = g2l3;
	leds[1][3] = g2l4;
	leds[1][4] = g2l5;
	leds[1][5] = g2l6;
	leds[1][6] = g2l7;
	leds[1][7] = g2l8;
	leds[1][8] = g2l9;
	leds[1][9] = g2l10;
	leds[1][10] = g2l11;
	leds[1][11] = g2l12;
	leds[1][12] = g2l13;
	leds[1][13] = g2l14;
	leds[1][14] = g2l15;
	leds[1][15] = g2l16;
	leds[1][16] = g2l17;
	leds[1][17] = g2l18;
	leds[1][18] = g2l19;
	leds[1][19] = g2l20;
	leds[1][20] = g2l21;

	leds[2][0] = g3l1;
	leds[2][1] = g3l2;
	leds[2][2] = g3l3;
	leds[2][3] = g3l4;
	leds[2][4] = g3l5;
	leds[2][5] = g3l6;
	leds[2][6] = g3l7;
	leds[2][7] = g3l8;
	leds[2][8] = g3l9;
	leds[2][9] = g3l10;
	leds[2][10] = g3l11;
	leds[2][11] = g3l12;
	leds[2][12] = g3l13;
	leds[2][13] = g3l14;
	leds[2][14] = g3l15;
	leds[2][15] = g3l16;
	leds[2][16] = g3l17;
	leds[2][17] = g3l18;
	leds[2][18] = g3l19;
	leds[2][19] = g3l20;
	leds[2][20] = g3l21;
	
	// Turn off all the 'leds'
	for (int n=0 ; n<3 ; n++)
		[self ledsOff:n];
	
	// Try to get our last saved names
	// and display options
	NSMutableArray *last = [[NSUserDefaults standardUserDefaults] objectForKey:@"gaugenames"];
	if (last != nil)
	{
		gaugeNames = [[NSMutableArray alloc] initWithArray:last];
		configInfo.isImperial = [[NSUserDefaults standardUserDefaults] boolForKey:@"imperial"];
		configInfo.isAFR = [[NSUserDefaults standardUserDefaults] boolForKey:@"afr"];
	}
	else
	{
		gaugeNames = [[NSMutableArray alloc] init];
		
		[gaugeNames addObject:[NSString stringWithString:@"RPM"]];
		[gaugeNames addObject:[NSString stringWithString:@""]];
		[gaugeNames addObject:[NSString stringWithString:@""]];		
		
		configInfo.isImperial = YES;
		configInfo.isAFR = YES;
	}
	
	// We start with no gauge assignments
	// They will get resolved, or not, to our names
	// when we first connect
	configInfo.gaugeChannels[0] = -1;
	configInfo.gaugeChannels[1] = -1;
	configInfo.gaugeChannels[2] = -1;
	
	// We care about OT-2 State changes
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(onStatusChanged:) 
												 name:OT2_NOTIFICATION_STATE 
											   object:nil];
	// And Packets
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(onNewPacket:) 
												 name:OT2_NOTIFICATION_PACKET 
											   object:nil];
    [super viewDidLoad];
}

// We were selected by the Tab Bar
// All our view controllers are expected to have this!
- (void)viewSelected
{
	
}

- (void)viewDeselected
{
	
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

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

	// Unsubscribe from notificaitons
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:OT2_NOTIFICATION_STATE 
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:OT2_NOTIFICATION_PACKET 
												  object:nil];	
}


- (void)dealloc 
{
	[yellowStatusImage release];
	[greenStatusImage release];

	for (int n=0 ; n<3 ; n++)
	{
		[names[n] release];
		[units[n] release];
		[values[n] release];
		
		for (int i=0 ; i<21 ; i++)
			[leds[n][i] release];
	}
	
	[gaugeNames release];
    [super dealloc];
}

@end
