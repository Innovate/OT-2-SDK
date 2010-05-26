/*
	DtcViewController.h
 
	Get and clear DTCs
*/

#import "ot2.h"
#import "DtcViewController.h"

#include "dtc.h"

@implementation DtcViewController

@synthesize dtcTitle, dtcText;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

// We get this when our commands complete
// When we got activated, we sent a 'Get Connection State' command
// Based on that, we will conditionally send a 'Get DTCs' command here
// Our button sends a 'Clear DTCs' command, we we handle all those
// responses here.

- (void) onCommandResponse: (NSNotification *)aNotification
{
	OT2_CMD_RESPONSE response;
	U8 status;
	OT_GET_DTCS *dtcs;
	// Up to 80 characters per description
	char outstr[80 * OT_MAX_DTC];

	
	// First, try to get a response
	if ([[aNotification object] commandGetResponse:&response] == YES)
	{
		// If the command failed, the response tells us why
		if (response.result == NO)
		{
			// Set our state strings
			dtcTitle.text = [NSString stringWithString:@"Error"];
			
			NSString *valString = [[NSString alloc]initWithCString:(const char *)response.data];
			dtcText.text = valString;
			[valString release];
		}
		else 
		{
			// OK, we got a valid response, conditionally act on that
			switch (response.command)
			{
				case OT2_CMD_CONNECT_STATE:
					status = ((OT_CONNECTION_STATUS *)&(response.data))->ConnectionStatus;

					// If there is no ECU connected, no reason to request DTCs!
					if (status == OT_CONN_NONE || status == OT_CONN_PD)
					{
						// Set our state strings
						NSString *valStr = [[NSString alloc] initWithString:@"Error"];
						dtcTitle.text = valStr;
						[valStr release];	
						
						valStr = [[NSString alloc] initWithString:@"The OT-2 is not currently connected to a vehicle ECU"];
						dtcText.text = valStr;
						[valStr release];
					}
					else // Cool, send our next command
						[[aNotification object] commandRequest:OT2_CMD_GET_DTCS];
					break;
					
				case OT2_CMD_GET_DTCS:
					dtcs = ((OT_GET_DTCS *)&(response.data));
					if (dtcs->DtcCount == OT_DTC_ERROR)
					{
						// Set our state strings
						NSString *valStr = [[NSString alloc] initWithString:@"Error"];
						dtcTitle.text = valStr;
						[valStr release];	
						
						valStr = [[NSString alloc] initWithString:@"An error occured retrieving the DTC information for your vehicle's ECU(s)"];
						dtcText.text = valStr;
						[valStr release];						
					}
					else
					{	
						// Get our DTCs (if any)
						NSString *valStr = [[NSString alloc] initWithString:@"Scan Complete"];
						dtcTitle.text = valStr;
						[valStr release];
						
						if (dtcs->DtcCount == 0)
						{
							sprintf(outstr, "No problems reported!");
						}
						else
						{
							sprintf(outstr, "Responses: %d\r\r", dtcs->DtcCount);
							
							dtcCount = dtcs->DtcCount;
							
							for (int n=0 ; n< dtcs->DtcCount ; n++)
							{
								dtcFormat(dtcs->Dtcs[n], outstr + strlen(outstr));
								strcat(outstr, " - ");
								strcat(outstr, dtcFind(dtcs->Dtcs[n]));
								strcat(outstr, "\r\r");
							}
						}
						
						valStr = [[NSString alloc] initWithCString:outstr];
						dtcText.text = valStr;
						[valStr release];												
					}

					break;
			
				case OT2_CMD_CLEAR_DTCS:
					status = response.data[0];
					
					if (status == 1)	// Yeah! re-scan
					{
						dtcCount = 0;
						[[aNotification object] commandRequest:OT2_CMD_GET_DTCS];
					}
					else
					{
						// Set our state strings
						NSString *valStr = [[NSString alloc] initWithString:@"Error"];
						dtcTitle.text = valStr;
						[valStr release];	
						
						valStr = [[NSString alloc] initWithString:@"An error occured sending the clear command to your vehicle's ECU"];
						dtcText.text = valStr;
						[valStr release];						
					}
					break;
			}
		}
	}
	else 
	{
		// Uggh, unexpected error of some kind !!!!
		// Set our state strings
		NSString *valStr = [[NSString alloc] initWithString:@"Error"];
		dtcTitle.text = valStr;
		[valStr release];	
		
		valStr = [[NSString alloc] initWithString:@"An unexpected error occured communicating with the OT-2 hardware"];
		dtcText.text = valStr;
		[valStr release];			
	}
}

// Clear button was pressed
- (IBAction)clearPress:(id)sender
{
	if (dtcCount)
	{
		// Set our state string
		NSString *valStr = [[NSString alloc] initWithString:@"Clearing..."];
		dtcTitle.text = valStr;
		[valStr release];	

		// OK, try to clear...
		OT2 *instance = [OT2 instance];	
		[instance commandRequest:OT2_CMD_CLEAR_DTCS];
	}
	else
	{
		// Tell the user we don't have anything to do...
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" 
														message:@"Nothing to clear!"
													   delegate:nil 
											  cancelButtonTitle:@"OK" 
											  otherButtonTitles: nil];
		[alert show];
		[alert release];		
	}
}


// We were selected by the Tab Bar
// All our view controllers are expected to have this
- (void)viewSelected
{
	// Set our state strings
	NSString *valStr = [[NSString alloc] initWithString:@"Scanning..."];
	dtcTitle.text = valStr;
	[valStr release];	

	valStr = [[NSString alloc] initWithString:@""];
	dtcText.text = valStr;
	[valStr release];	

	dtcCount = 0;
	
	// We care about OT-2 Commands
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(onCommandResponse:) 
												 name:OT2_NOTIFICATION_CMD
											   object:nil];

	OT2 *instance = [OT2 instance];	
	[instance commandRequest:OT2_CMD_CONNECT_STATE];
}

- (void)viewDeselected
{
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:OT2_NOTIFICATION_CMD 
												  object:nil];						
}

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

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
	// Unsubscribe from notificaitons
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:OT2_NOTIFICATION_CMD 
												  object:nil];	
}


- (void)dealloc {
	[dtcTitle release];
	[dtcText release];
    [super dealloc];
}


@end
