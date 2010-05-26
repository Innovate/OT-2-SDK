/*
	Ot2ConfigViewController.h

	Our OT-2 'Configuration Dialog'
*/

#import <UIKit/UIKit.h>

typedef enum {
	SELECT_CHANNELS,
	SELECT_PROTOCOL,
	SELECT_PID
} OT2CONFIG_SELECTION;

@interface Ot2ConfigViewController : UIViewController <UIPickerViewDelegate> {
	UIButton *channelsButton;
	UIButton *protocolButton;
	UIButton *channelButton1;
	UIButton *channelButton2;
	UIButton *channelButton3;
	UIButton *channelButton4;
	UIButton *channelButton5;
	UIButton *channelButton6;
	UIButton *channelButton7;
	UIButton *channelButton8;
	UIButton *channelButton9;
	UIButton *channelButton10;
	UIButton *channelButton11;
	UIButton *channelButton12;
	UIButton *channelButton13;
	UIButton *channelButton14;
	UIButton *channelButton15;
	UIButton *channelButton16;
	
	UIView *setView;
	UILabel *setLabel;
	UIPickerView *ourPickerView;
	UIButton *okButton;
	
@private
	NSMutableArray *activePids;		// We'll build a list of active PIDs
	OT2CONFIG_SELECTION selectionMode;	// How we want our picker to behave
	NSInteger selectionIndex;		// Object we are adjusting (if array)
	NSInteger selectionCurrent[2];	// What goes in/out of the picker
	NSInteger selectionNew[2];
	bool hasChanged;
	UIButton *buttons[16];		// For ease of access
	OT_CONNECTION_STATUS otConnectionStatus;
	OT_CONFIGURATION otConfiguration;
}

// Initialize us with status
- (Ot2ConfigViewController *)initWithConnectionStatus: (OT_CONNECTION_STATUS *)status;

- (IBAction)donePress:(id)sender;
- (IBAction)okPress:(id)sender;
- (IBAction)channelPress:(id)sender;
- (IBAction)protocolPress:(id)sender;
- (IBAction)pidPress:(id)sender;

@property (nonatomic, retain) IBOutlet UIButton *channelsButton;
@property (nonatomic, retain) IBOutlet UIButton *protocolButton;
@property (nonatomic, retain) IBOutlet UIButton *channelButton1;
@property (nonatomic, retain) IBOutlet UIButton *channelButton2;
@property (nonatomic, retain) IBOutlet UIButton *channelButton3;
@property (nonatomic, retain) IBOutlet UIButton *channelButton4;
@property (nonatomic, retain) IBOutlet UIButton *channelButton5;
@property (nonatomic, retain) IBOutlet UIButton *channelButton6;
@property (nonatomic, retain) IBOutlet UIButton *channelButton7;
@property (nonatomic, retain) IBOutlet UIButton *channelButton8;
@property (nonatomic, retain) IBOutlet UIButton *channelButton9;
@property (nonatomic, retain) IBOutlet UIButton *channelButton10;
@property (nonatomic, retain) IBOutlet UIButton *channelButton11;
@property (nonatomic, retain) IBOutlet UIButton *channelButton12;
@property (nonatomic, retain) IBOutlet UIButton *channelButton13;
@property (nonatomic, retain) IBOutlet UIButton *channelButton14;
@property (nonatomic, retain) IBOutlet UIButton *channelButton15;
@property (nonatomic, retain) IBOutlet UIButton *channelButton16;

@property (nonatomic, retain) IBOutlet UIView *setView;
@property (nonatomic, retain) IBOutlet UIView *setLabel;
@property (nonatomic, retain) IBOutlet UIPickerView *ourPickerView;
@property (nonatomic, retain) IBOutlet UIButton *okButton;

@end
