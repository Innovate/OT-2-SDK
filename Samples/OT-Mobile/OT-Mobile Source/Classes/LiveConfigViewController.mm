//
//  LiveConfigViewController.m
//  OT Mobile
//
//  Created by Joe Fitzpatrick on 12/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "LiveConfigViewController.h"


@implementation LiveConfigViewController

@synthesize afrSwitch, imperialSwitch, gaugeButton1, gaugeButton2, gaugeButton3;
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

- (LiveConfigViewController *) initWithInfo: (LIVECONFIG_INFO *)info delegate: (id<LiveConfigViewDelegate>)delegate
{
	_owner = delegate;
	memcpy(&Info, info, sizeof(Info));
	return self;
}

// Update our display
- (void)updateDisplay
{
	for (int n= 0 ; n<3 ; n++)
	{
		if (Info.gaugeChannels[n] == -1)
			[buttons[n] setTitle:[NSString stringWithString:@"None"] forState:UIControlStateNormal];
		else
		{
			NSString *valStr = [[OT2 instance] channelName:Info.gaugeChannels[n]];
			[buttons[n] setTitle:[NSString stringWithString:valStr] 
						forState:UIControlStateNormal];
			[valStr release];
		}
	}
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
	// Save the switches, the channel changes where handled
	// by the fancy picker and OK button
	Info.isAFR = afrSwitch.on;
	Info.isImperial = imperialSwitch.on;
	
	// Tell our owner we are done
	if (_owner != nil)
		[_owner LiveConfigViewDone:&Info];
	
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

// Pid Button pressed
- (IBAction)gaugePress:(id)sender
{
	int n;
	
	// Find which button
	for (n=0 ; n< 3 ; n++)
		if (buttons[n] == sender)
			break;
	
	// Huh?
	if (n == 3)
		return;
	
	selectionIndex = n;
	
	// Now see if the current Label is a selection
	n = Info.gaugeChannels[selectionIndex];
	n++; // turn -1 into 0
	
	if (n > [[OT2 instance] channelCount])
		n = 0;
	
	setLabel.text = [NSString stringWithString:@"Channel to Display:"];
	ourPickerView.delegate = self;
	ourPickerView.showsSelectionIndicator = YES;
	
	// Set our channel
	[ourPickerView selectRow:n inComponent:0 animated:NO];	
	
	selectionCurrent = selectionNew = n;
		
	CGContextRef context = UIGraphicsGetCurrentContext();
	[UIView beginAnimations:nil context:context];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:.5];
	[setView setAlpha:1.0];	
	[UIView commitAnimations];
}


// The user may have changed something
// If so, store it and refresh our display
- (IBAction)okPress:(id)sender
{
	if (selectionCurrent != selectionNew)
	{
		Info.gaugeChannels[selectionIndex] = selectionNew - 1;
		[self updateDisplay];
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



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	buttons[0] = gaugeButton1;
	buttons[1] = gaugeButton2;
	buttons[2] = gaugeButton3;
	
	afrSwitch.on = Info.isAFR;
	imperialSwitch.on = Info.isImperial;
	
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

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
	[afrSwitch release];
	[imperialSwitch release];
	[gaugeButton1 release];
	[gaugeButton2 release];
	[gaugeButton3 release];
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
	return 1;
}

// Number of Rows
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent: (NSInteger)component
{
	return ([[OT2 instance] channelCount] + 1);
}

// Widths
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
	return 200.0;
}

// Names
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	if (!row)
		return [NSString stringWithString:@"None"];
	else
	{
		NSString *valStr = [[OT2 instance] channelName:(U16)(row-1)];
		NSString *retStr = [NSString stringWithString:valStr];
		[valStr release];
		return retStr;
	}
}


// Selection
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component;
{
	// We just save the changes here and act on them when OK is pressed later
	selectionNew = row;
}

@end
