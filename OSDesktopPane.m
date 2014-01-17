#import "OSDesktopPane.h"
#import "missioncontrol/OSMCWindowLayoutManager.h"

#define desktopPath @"/var/mobile/Desktop"
#define widthPercentage 0.99
#define heightPercentage 0.99

@implementation OSDesktopPane
@synthesize wallpaperView = _wallpaperView;
@synthesize fileGridViewController = _fileGridViewController;
@synthesize statusBar = _statusBar;
@synthesize activeWindow = _activeWindow;
@synthesize windows = _windows;
@synthesize desktopViewContainer = _desktopViewContainer;


-(id)init{
	if(![super initWithName:@"Desktop" thumbnail:nil]){
		return nil;
	}

	self.backgroundColor = [UIColor clearColor];
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

	self.wallpaperView = [[objc_getClass("SBWallpaperView") alloc] initWithOrientation:[[UIApplication sharedApplication] statusBarOrientation] variant:1];
	self.wallpaperView.clipsToBounds = true;
	[self.wallpaperView setGradientAlpha:0.0];
	[self addSubview:self.wallpaperView];


	//self.desktopViewContainer = [[UIView alloc] initWithFrame:[self desktopViewContainerFrame]];
	//[self addSubview:self.desktopViewContainer];

	/*self.fileGridViewController = [[OSDesktopFileGridViewController alloc] init];
	self.fileGridViewController.type = OSFileGridViewTypeDesktop;
	self.fileGridViewController.path = [NSURL URLWithString:desktopPath];
	[self.fileGridViewController loadView];
	[self.desktopViewContainer addSubview:self.fileGridViewController.view];*/


	CGRect statusBarFrame = CGRectZero;
	statusBarFrame.size.width = self.bounds.size.width;
	statusBarFrame.size.height = 20;

	self.statusBar = [[objc_getClass("SBFakeStatusBarView") alloc] initWithFrame:statusBarFrame];
	self.statusBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.statusBar requestStyle:1];
	[self addSubview:self.statusBar];
	
	self.windows = [[NSMutableArray alloc] init];

	[self.wallpaperView release];
	//[self.desktopViewContainer release];
	//[self.fileGridViewController release];
	[self.statusBar release];
	[self.windows release];

	return self;
}

- (CGRect)desktopViewContainerFrame{
	CGRect frame = self.bounds;
	frame.origin.x = 0;
	frame.origin.y = self.statusBar.frame.size.height;
	frame.size.height -= self.statusBar.frame.size.height;
	frame.size.height -= [[[OSViewController sharedInstance] dock] frame].size.height;

	frame.origin.x += (frame.size.width * (1 - widthPercentage)) / 2;
	frame.origin.y += (frame.size.height * (1 - heightPercentage)) / 2;

	frame = CGRectApplyAffineTransform(frame, CGAffineTransformMakeScale(widthPercentage, heightPercentage));

	return frame;
}

- (void)layoutSubviews{
	self.desktopViewContainer.frame = [self desktopViewContainerFrame];

	self.fileGridViewController.view.frame = [self.desktopViewContainer bounds];
	[self.fileGridViewController layoutView];
}

- (void)addSubview:(UIView*)arg1{
	[super addSubview:arg1];
	if([arg1 isKindOfClass:[OSWindow class]]){
		if(![self.windows containsObject:arg1]){
			[self.windows addObject:arg1];
			[(OSWindow*)arg1 setDelegate:self];
		}
	}
}

- (BOOL)showsDock{
	return true;
}

- (OSWindow*)activeWindow{
	if(![self.subviews containsObject:_activeWindow])
		return nil;
	return _activeWindow;
}

- (void)window:(OSWindow*)window didRecievePanGesture:(UIPanGestureRecognizer*)gesture{
	if([[OSViewController sharedInstance] missionControlIsActive]){
		return;
	}

	if([gesture state] == UIGestureRecognizerStateBegan){
		[window setGrabPoint:[gesture locationInView:window]];
		[self bringSubviewToFront:window];
		[self setActiveWindow:window];
	}else if([gesture state] == UIGestureRecognizerStateChanged){
		CGRect frame = window.frame;
		frame.origin = CGPointSub([gesture locationInView:self], [window grabPoint]);
		if(frame.origin.y < self.statusBar.bounds.size.height)
			frame.origin.y = self.statusBar.bounds.size.height;
		window.frame = frame;
	}
}

- (void)window:(OSWindow*)window didRecieveResizePanGesture:(UIPanGestureRecognizer*)gesture{
	if([[OSViewController sharedInstance] missionControlIsActive]){
		return;
	}
	
	if([gesture state] == UIGestureRecognizerStateBegan){

		window.resizeAnchor = CGPointMake(window.frame.origin.x, window.frame.origin.y + window.frame.size.height);
		window.grabPoint = CGPointSub(CGPointMake(window.frame.size.width, 0), [gesture locationInView:window]);
	}else if([gesture state] == UIGestureRecognizerStateChanged){

		CGRect frame = [window CGRectFromCGPoints:window.resizeAnchor p2:CGPointAdd(window.grabPoint, [gesture locationInView:self])];

		if(frame.origin.y < self.statusBar.bounds.size.height){
			frame.origin.y = self.statusBar.bounds.size.height;
			frame.size = window.bounds.size;
		}

		window.frame = frame;
	}
}

- (void)missionControlWillActivate{
	for(OSWindow *window in self.subviews){
		if(![window isKindOfClass:[OSWindow class]])
			continue;
		[window setOriginInDesktop:window.frame.origin];
		window.windowBar.userInteractionEnabled = false;

		CGRect frame = [OSMCWindowLayoutManager convertRectToSlider:window.frame fromPane:self];
		window.frame = frame;

		[[OSSlider sharedInstance] addSubview:window];
	}
}

- (void)missionControlWillDeactivate{
	for(OSWindow *window in self.windows){
		if(![window isKindOfClass:[OSWindow class]])
			continue;
		
		window.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1, 1);
		
		CGRect frame = window.frame;
		frame.origin = [self convertPoint:window.originInDesktop toView:[self superview]];
		[window setFrame:frame];
	}
}

- (void)missionControlDidDeactivate{
	for(OSWindow *window in self.windows){
		if(![window isKindOfClass:[OSWindow class]])
			continue;

		CGRect frame = window.frame;
		frame.origin = window.originInDesktop;
		[window setFrame:frame];

		[self addSubview:window];
		window.windowBar.userInteractionEnabled = true;
	}
}

- (void)paneIndexWillChange{
	for(OSWindow *window in self.windows){
		if(![window isKindOfClass:[OSWindow class]])
			continue;
		window.desktopPaneOffset = CGPointSub(window.frame.origin, self.frame.origin);
	}
}

- (void)paneIndexDidChange{
	[self setName:[NSString stringWithFormat:@"Desktop %i", [self desktopPaneIndex]]];

	for(OSWindow *window in self.windows){
		if(![window isKindOfClass:[OSWindow class]] || [[self subviews] containsObject:window])
			continue;
		CGPoint newOffset = CGPointSub(window.frame.origin, self.frame.origin);

		CGPoint difference = CGPointSub(window.desktopPaneOffset, newOffset);

		CGRect frame = window.frame;
		frame.origin = CGPointAdd(difference, frame.origin);

		[window setFrame:frame];
	}
}

- (int)desktopPaneIndex{
	int count = 0;
	for(OSDesktopPane *pane in [[OSPaneModel sharedInstance] panes]){
		if(![pane isKindOfClass:[OSDesktopPane class]])
			continue;
		count++;
		if(pane == self)
			break;
	}
	return count;
}

-(void)dealloc{
	[self.wallpaperView release];
	[self.desktopViewContainer release];
	[self.fileGridViewController release];
	[self.statusBar release];
	[self.windows release];

	[super dealloc];
}



@end