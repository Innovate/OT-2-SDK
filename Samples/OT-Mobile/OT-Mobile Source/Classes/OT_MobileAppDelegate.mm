/*
	
	OT_MobileAppDelegate.m

	Simple OT-2 SDK demonstration
*/

#import	"ot2.h"	// We'll start a background device
#import "LiveViewController.h"	// We cast to this for sending tab select notification
#import "OT_MobileAppDelegate.h"


@implementation OT_MobileAppDelegate

@synthesize window;
@synthesize tabBarController;


- (void)applicationDidFinishLaunching:(UIApplication *)application 
{
    
    // Add the tab bar controller's current view as a subview of the window
    [window addSubview:tabBarController.view];

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"IMPORTANT NOTICE!" 
													message:@"Staring at small screens while driving is dangerous! Use this program responsibly.\r\rThe developers and distributors of this applicaiton are not responsible for any accidents, injuries, or property damage that may occur during its use. Always drive safely and obey traffic laws."
												   delegate:self 
										  cancelButtonTitle:@"OK" 
										  otherButtonTitles: nil];
	[alert show];
	[alert release];

}

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex 
{
	// Start the OT-2 engine running
	// Once we do this, the OT-2 will get connected to automatically
	OT2 *ot2 = [OT2 instance];
	[ot2 start];
}


//- (void)applicationDidBecomeActive:(UIApplication *)application
//{
//	NSLog(@"applicationDidBecomeActive");
//}

- (void)applicationWillResignActive:(UIApplication *)application
{
	// Tell the current view we are going to die
	[(LiveViewController *)(tabBarController.selectedViewController) viewDeselected];	
	
	// Kill the OT-2 engine
	OT2 *ot2 = [OT2 instance];
	[ot2 stop];
}

//- (void)applicationDidEnterBackground:(UIApplication *)application
//{
//	NSLog(@"applicationDidEnterBackground");
//}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Start the OT-2 engine
	OT2 *ot2 = [OT2 instance];
	[ot2 start];
	
	// Tell the current view to refresh state
	[(LiveViewController *)(tabBarController.selectedViewController) viewSelected];		
}

// Called just before we exit, go ahead and kill our engine and free everything up.
- (void)applicationWillTerminate:(UIApplication *)application {

	// Kill the OT-2 engine
	OT2 *ot2 = [OT2 instance];
	[ot2 stop];
}



// Optional UITabBarControllerDelegate method
// We need this because load/unload view does not happen each time the tab bar is
// selected. This gives us a chance to invoke an 'activated'  and 'deactived' method on each view
- (void)tabBarController:(UITabBarController *)tbController didSelectViewController:(UIViewController *)viewController 
{
	static LiveViewController *lastview = nil;
	
	// We pressume that ALL our view controllers can accept this! Even though we
	// are just casting to LiveViewController
	if (lastview != nil)	// First time is a special case, assume tab 0
		[lastview viewDeselected];
	else
		[(LiveViewController *)([tbController.viewControllers objectAtIndex:0]) viewDeselected];

	
	[(LiveViewController *)(tbController.selectedViewController) viewSelected];
	lastview = (LiveViewController *)(tbController.selectedViewController);
}


/*
// Optional UITabBarControllerDelegate method
- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
}
*/


- (void)dealloc {
    [tabBarController release];
    [window release];
    [super dealloc];
}

@end

