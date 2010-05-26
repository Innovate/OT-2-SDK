/*
	LiveViewController.h
 
	Our Live Data view (gauges)
*/

#import "LiveConfigViewController.h"
#import <UIKit/UIKit.h>


@interface LiveViewController : UIViewController <LiveConfigViewDelegate> {
	// Status light
	UIImageView	*yellowStatusImage;
	UIImageView	*greenStatusImage;

	// Gauge Leds
	UIImageView *g1l1;
	UIImageView *g1l2;
	UIImageView *g1l3;
	UIImageView *g1l4;
	UIImageView *g1l5;
	UIImageView *g1l6;
	UIImageView *g1l7;
	UIImageView *g1l8;
	UIImageView *g1l9;
	UIImageView *g1l10;
	UIImageView *g1l11;
	UIImageView *g1l12;
	UIImageView *g1l13;
	UIImageView *g1l14;
	UIImageView *g1l15;
	UIImageView *g1l16;
	UIImageView *g1l17;
	UIImageView *g1l18;
	UIImageView *g1l19;
	UIImageView *g1l20;
	UIImageView *g1l21;

	UIImageView *g2l1;
	UIImageView *g2l2;
	UIImageView *g2l3;
	UIImageView *g2l4;
	UIImageView *g2l5;
	UIImageView *g2l6;
	UIImageView *g2l7;
	UIImageView *g2l8;
	UIImageView *g2l9;
	UIImageView *g2l10;
	UIImageView *g2l11;
	UIImageView *g2l12;
	UIImageView *g2l13;
	UIImageView *g2l14;
	UIImageView *g2l15;
	UIImageView *g2l16;
	UIImageView *g2l17;
	UIImageView *g2l18;
	UIImageView *g2l19;
	UIImageView *g2l20;
	UIImageView *g2l21;

	UIImageView *g3l1;
	UIImageView *g3l2;
	UIImageView *g3l3;
	UIImageView *g3l4;
	UIImageView *g3l5;
	UIImageView *g3l6;
	UIImageView *g3l7;
	UIImageView *g3l8;
	UIImageView *g3l9;
	UIImageView *g3l10;
	UIImageView *g3l11;
	UIImageView *g3l12;
	UIImageView *g3l13;
	UIImageView *g3l14;
	UIImageView *g3l15;
	UIImageView *g3l16;
	UIImageView *g3l17;
	UIImageView *g3l18;
	UIImageView *g3l19;
	UIImageView *g3l20;
	UIImageView *g3l21;
	
	// Labels on gauges
	UILabel *nameOne;
	UILabel *nameTwo;
	UILabel *nameThree;
	
	UILabel *unitsOne;
	UILabel *unitsTwo;
	UILabel *unitsThree;
	
	UILabel *valueOne;
	UILabel *valueTwo;
	UILabel *valueThree;

@private
	UILabel *names[3];		// So we can loop in notificaitons
	UILabel *units[3];
	UILabel *values[3];
	
	UIImageView *leds[3][21];
	
	NSMutableArray *gaugeNames;	// For persistance
	
	LIVECONFIG_INFO configInfo;
}

// Must have! The AppDelegate invokes it for Tab Bar changes!
- (void)viewSelected;
- (void)viewDeselected;

// Info button press
- (IBAction)infoPress:(id)sender;

@property (nonatomic, retain) IBOutlet UIImageView *yellowStatusImage;
@property (nonatomic, retain) IBOutlet UIImageView *greenStatusImage;
@property (nonatomic, retain) IBOutlet UILabel *nameOne;
@property (nonatomic, retain) IBOutlet UILabel *nameTwo;
@property (nonatomic, retain) IBOutlet UILabel *nameThree;
@property (nonatomic, retain) IBOutlet UILabel *unitsOne;
@property (nonatomic, retain) IBOutlet UILabel *unitsTwo;
@property (nonatomic, retain) IBOutlet UILabel *unitsThree;
@property (nonatomic, retain) IBOutlet UILabel *valueOne;
@property (nonatomic, retain) IBOutlet UILabel *valueTwo;
@property (nonatomic, retain) IBOutlet UILabel *valueThree;
@property (nonatomic, retain) IBOutlet UIImageView *g1l1;
@property (nonatomic, retain) IBOutlet UIImageView *g1l2;
@property (nonatomic, retain) IBOutlet UIImageView *g1l3;
@property (nonatomic, retain) IBOutlet UIImageView *g1l4;
@property (nonatomic, retain) IBOutlet UIImageView *g1l5;
@property (nonatomic, retain) IBOutlet UIImageView *g1l6;
@property (nonatomic, retain) IBOutlet UIImageView *g1l7;
@property (nonatomic, retain) IBOutlet UIImageView *g1l8;
@property (nonatomic, retain) IBOutlet UIImageView *g1l9;
@property (nonatomic, retain) IBOutlet UIImageView *g1l10;
@property (nonatomic, retain) IBOutlet UIImageView *g1l11;
@property (nonatomic, retain) IBOutlet UIImageView *g1l12;
@property (nonatomic, retain) IBOutlet UIImageView *g1l13;
@property (nonatomic, retain) IBOutlet UIImageView *g1l14;
@property (nonatomic, retain) IBOutlet UIImageView *g1l15;
@property (nonatomic, retain) IBOutlet UIImageView *g1l16;
@property (nonatomic, retain) IBOutlet UIImageView *g1l17;
@property (nonatomic, retain) IBOutlet UIImageView *g1l18;
@property (nonatomic, retain) IBOutlet UIImageView *g1l19;
@property (nonatomic, retain) IBOutlet UIImageView *g1l20;
@property (nonatomic, retain) IBOutlet UIImageView *g1l21;
@property (nonatomic, retain) IBOutlet UIImageView *g2l1;
@property (nonatomic, retain) IBOutlet UIImageView *g2l2;
@property (nonatomic, retain) IBOutlet UIImageView *g2l3;
@property (nonatomic, retain) IBOutlet UIImageView *g2l4;
@property (nonatomic, retain) IBOutlet UIImageView *g2l5;
@property (nonatomic, retain) IBOutlet UIImageView *g2l6;
@property (nonatomic, retain) IBOutlet UIImageView *g2l7;
@property (nonatomic, retain) IBOutlet UIImageView *g2l8;
@property (nonatomic, retain) IBOutlet UIImageView *g2l9;
@property (nonatomic, retain) IBOutlet UIImageView *g2l10;
@property (nonatomic, retain) IBOutlet UIImageView *g2l11;
@property (nonatomic, retain) IBOutlet UIImageView *g2l12;
@property (nonatomic, retain) IBOutlet UIImageView *g2l13;
@property (nonatomic, retain) IBOutlet UIImageView *g2l14;
@property (nonatomic, retain) IBOutlet UIImageView *g2l15;
@property (nonatomic, retain) IBOutlet UIImageView *g2l16;
@property (nonatomic, retain) IBOutlet UIImageView *g2l17;
@property (nonatomic, retain) IBOutlet UIImageView *g2l18;
@property (nonatomic, retain) IBOutlet UIImageView *g2l19;
@property (nonatomic, retain) IBOutlet UIImageView *g2l20;
@property (nonatomic, retain) IBOutlet UIImageView *g2l21;
@property (nonatomic, retain) IBOutlet UIImageView *g3l1;
@property (nonatomic, retain) IBOutlet UIImageView *g3l2;
@property (nonatomic, retain) IBOutlet UIImageView *g3l3;
@property (nonatomic, retain) IBOutlet UIImageView *g3l4;
@property (nonatomic, retain) IBOutlet UIImageView *g3l5;
@property (nonatomic, retain) IBOutlet UIImageView *g3l6;
@property (nonatomic, retain) IBOutlet UIImageView *g3l7;
@property (nonatomic, retain) IBOutlet UIImageView *g3l8;
@property (nonatomic, retain) IBOutlet UIImageView *g3l9;
@property (nonatomic, retain) IBOutlet UIImageView *g3l10;
@property (nonatomic, retain) IBOutlet UIImageView *g3l11;
@property (nonatomic, retain) IBOutlet UIImageView *g3l12;
@property (nonatomic, retain) IBOutlet UIImageView *g3l13;
@property (nonatomic, retain) IBOutlet UIImageView *g3l14;
@property (nonatomic, retain) IBOutlet UIImageView *g3l15;
@property (nonatomic, retain) IBOutlet UIImageView *g3l16;
@property (nonatomic, retain) IBOutlet UIImageView *g3l17;
@property (nonatomic, retain) IBOutlet UIImageView *g3l18;
@property (nonatomic, retain) IBOutlet UIImageView *g3l19;
@property (nonatomic, retain) IBOutlet UIImageView *g3l20;
@property (nonatomic, retain) IBOutlet UIImageView *g3l21;

@end
