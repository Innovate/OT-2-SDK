/*
	LiveConfigViewController.h

	Configure our 'live' data view
*/

#import "ot2.h"
#import <UIKit/UIKit.h>

@protocol LiveConfigViewDelegate;

// What we need to configure (no, it isn't an object...)
typedef struct {
	bool isImperial;
	bool isAFR;
	NSInteger gaugeChannels[3];
} LIVECONFIG_INFO;

@interface LiveConfigViewController : UIViewController <UIPickerViewDelegate> {
	UISwitch *imperialSwitch;
	UISwitch *afrSwitch;
	UIButton *gaugeButton1;
	UIButton *gaugeButton2;
	UIButton *gaugeButton3;

	UIView *setView;
	UILabel *setLabel;
	UIPickerView *ourPickerView;
	UIButton *okButton;
	
@private
	NSInteger selectionIndex;		// Object we are adjusting (if array)
	NSInteger selectionCurrent;		// What goes in/out of the picker
	NSInteger selectionNew;	
	UIButton *buttons[3];	// For easy access
	LIVECONFIG_INFO Info;
	id<LiveConfigViewDelegate> _owner;
}

- (LiveConfigViewController *) initWithInfo: (LIVECONFIG_INFO *)info delegate: (id<LiveConfigViewDelegate>)delegate;

- (IBAction)donePress:(id)sender;
- (IBAction)gaugePress:(id)sender;
- (IBAction)okPress:(id)sender;

@property (nonatomic, retain) IBOutlet UISwitch *imperialSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *afrSwitch;
@property (nonatomic, retain) IBOutlet UIButton *gaugeButton1;
@property (nonatomic, retain) IBOutlet UIButton *gaugeButton2;
@property (nonatomic, retain) IBOutlet UIButton *gaugeButton3;
@property (nonatomic, retain) IBOutlet UIView *setView;
@property (nonatomic, retain) IBOutlet UIView *setLabel;
@property (nonatomic, retain) IBOutlet UIPickerView *ourPickerView;
@property (nonatomic, retain) IBOutlet UIButton *okButton;

@end

@protocol LiveConfigViewDelegate<NSObject>
@required

// Give back the info
- (void)LiveConfigViewDone: (LIVECONFIG_INFO *)info;

@end