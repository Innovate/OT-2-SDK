/*
	DtcViewController.h

	Get and clear DTCs
*/

#import <UIKit/UIKit.h>


@interface DtcViewController : UIViewController {
	UILabel *dtcTitle;
	UITextView *dtcText;
	int dtcCount;
}

// Must have! The AppDelegate invokes it for Tab Bar changes!
- (void)viewSelected;
- (void)viewDeselected;

// 'Clear' button press
- (IBAction)clearPress:(id)sender;

@property (nonatomic, retain) IBOutlet UILabel *dtcTitle;
@property (nonatomic, retain) IBOutlet UITextView *dtcText;

@end
