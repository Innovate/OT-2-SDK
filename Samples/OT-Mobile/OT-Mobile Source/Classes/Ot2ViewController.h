/*
	Ot2ViewController.h
 
	Basic OT2 stats and configuration
*/

#import "Ot2ConfigViewController.h"
#import <UIKit/UIKit.h>

#include "ims.h"

@interface Ot2ViewController : UIViewController {
	// Status light
	UIImageView	*yellowStatusImage;
	UIImageView	*greenStatusImage;	

	// Status Text
	UITextView *ot2Text;

@private
	// We keep the connection status to pass to
	// the config 'dialog'
	OT_CONNECTION_STATUS otConnectStatus;
}

// Must have! The AppDelegate invokes it for Tab Bar changes!
- (void)viewSelected;
- (void)viewDeselected;

// Info button press
- (IBAction)infoPress:(id)sender;

@property (nonatomic, retain) IBOutlet UIImageView *yellowStatusImage;
@property (nonatomic, retain) IBOutlet UIImageView *greenStatusImage;
@property (nonatomic, retain) IBOutlet UITextView *ot2Text;

@end
