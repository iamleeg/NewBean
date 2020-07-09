/*
 JHScrollView.m
 Bean

 Copyright (c) 2007-2011 James Hoover

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import <Cocoa/Cocoa.h>
#import "JHScrollView.h"
#import "PageView.h"
#import "JHDocument_FullScreen.h" //toggleFullScreen, fullScreen
#import "JHDocument_View.h" //restoreVisibleTextRange
//FIXME: ask his permission!
#import "KBRulerView.h" //Keith's code was better than mine!

//	subclass of NSScrollView based on ScalingScrollView.m Copyright (c) 1995-2005 by Apple Computer Author: Mike Ferris
@implementation JHScrollView

#pragma mark -
#pragma mark ---- Init, Dealloc ----

// ******************* Init, Dealloc ********************

- (id)initWithFrame:(NSRect)rect
{
	self = [super initWithFrame:rect];
	if (self)
	{
		[self setHasVerticalRuler:NO];
		[self setRulersVisible:YES];
		[self setAutoresizingMask:NSViewMinXMargin];
		scaleFactor = 1.0;
	}
	return self;
}

- (void) dealloc
{
	[placard release];
	[super dealloc];
}

- (BOOL) isOpaque { return YES; }

- (void) setPlacard:(NSView *)inView
{
	[inView retain];
	if (nil != placard)
	{
		[placard removeFromSuperview];
		[placard release];
	}
	placard = inView;
	[self addSubview:placard];
}

- (NSView *) placard
{
	return placard;
}

#pragma mark -
#pragma mark ---- Drawing Methods ----

// ******************* Drawing Methods ********************

- (void)tile
{
	//	superclass does most of the work, drawing the scroll view's components
	[super tile];
	//	this shortens the vertical scroller to make room for page up/down buttons
	NSScroller *vScroller;
	vScroller = [self verticalScroller];
	NSRect vScrollerFrame;
	vScrollerFrame = [vScroller frame];
	//	now we'll adjust the vertical scroller size to accomodate the page up/down button locations.
	int spacer = 0;
	if ([self hasHorizontalScroller])
	{
		spacer = vScrollerFrame.size.width;
	}
	//	space adjusts for presence of horizontal scroller (14 May 2007 BH)
	vScrollerFrame.size.height = vScrollerFrame.size.height - 33 + spacer;
	[vScroller setFrameSize:vScrollerFrame.size];
	[vScroller setFrame:vScrollerFrame];
		
	if (placard)
	{
		NSRect placardFrame = [placard frame];
		// Put placard where the horizontal scroller is
		placardFrame.origin.x = NSMinX(vScrollerFrame);
		// Move horizontal scroller over to the right of the placard
		// Adjust height of placard
		placardFrame.size.height = 33;
		placardFrame.size.width = vScrollerFrame.size.width;
		placardFrame.origin.y = vScrollerFrame.origin.y + vScrollerFrame.size.height;
		// Move the placard into place
		[placard setFrame:placardFrame];
	}
		
	//this message has NO EFFECT in the init method, so it's here instead!
	[self setLineScroll:20.0];
}

#pragma mark -
#pragma mark ---- Scale Factor ----

// ******************* Scale Factor ********************

//	Scale Factor = View Scale = Zoom Amount
//	isFitWidth causes page WIDTH to fit to width of window; isFitPage causes WHOLE PAGE to fit to window
//	otherwise, the scale factor is determined by the slider control in the status bar or by a user pref
- (void)setScaleFactor:(float)newScaleFactor
{
	if (scaleFactor != newScaleFactor)
	{
		NSSize curDocFrameSize, newDocBoundsSize;
		NSView *clipView = [[self documentView] superview];
		//	save spot in document to restore after resizing bounds for zoom! Here we save the position (point) in the pageView, not the character position as with continuous textView (due to wordwrap changing layout, which doesn't happen here)
		NSRect saveScrollPoint;
		//saveScrollPoint = NSZeroRect;
		saveScrollPoint = [self documentVisibleRect];
			
		if ([self isFitWidth])
		{
			//	make page width fit clipView
			scaleFactor = [clipView frame].size.width / [[self documentView] frame].size.width;
		} 
		else if ([self isFitPage])
		{
			//	make page height fit clipView
			NSPrintInfo *thePrintInfo = [NSPrintInfo sharedPrintInfo];
			NSSize thePaperSize = [thePrintInfo paperSize]; 
			float  ratioPaperSize;
			ratioPaperSize = thePaperSize.width / thePaperSize.height;
			float  clipViewRatio;
			clipViewRatio = [clipView frame].size.width / [clipView frame].size.height;
			if (ratioPaperSize > clipViewRatio)
			{
				//	we fudge a little (1.05) for aesthetic reasons
				scaleFactor = [clipView frame].size.width / (thePaperSize.width * 1.05);
			}
			else
			{
				scaleFactor = [clipView frame].size.height / (thePaperSize.height * 1.05);
			}
		}
		//	arbitrary scale factor set by slider control
		else
		{
			scaleFactor = newScaleFactor;
		}
		//	get the frame.  The frame must stay the same.
		curDocFrameSize = [clipView frame].size;
		//	the new bounds will be frame divided by scale factor
		newDocBoundsSize.width = curDocFrameSize.width / scaleFactor;
		newDocBoundsSize.height = curDocFrameSize.height / scaleFactor;
		[clipView setBoundsSize:newDocBoundsSize];

		// prevent scroll of one extra line (bug?) that occurs in Text Edit as well
		saveScrollPoint.origin.y = saveScrollPoint.origin.y + 0.5; 
		//	since the clipView scrolls when bounds of documentView frame are resized, we remember visible rect and make it's origin the origin of clipView after scrollView frame resizes!
		[[self documentView] scrollRectToVisible:saveScrollPoint];
	}
}

- (void)setScaleFactorWithoutDisplay:(float)newScaleFactor
{
	if (scaleFactor != newScaleFactor) scaleFactor = newScaleFactor;
}

- (float)scaleFactor
{
	return scaleFactor;
}

#pragma mark -
#pragma mark ---- Accessors ----

// ******************* Accessors ********************

- (void)setHasHorizontalScroller:(BOOL)flag
{
	[super setHasHorizontalScroller:flag];
}

- (BOOL)isFitWidth
{
	return isFitWidth;
}

- (void)setIsFitWidth:(BOOL)flag
{
	isFitWidth = flag;
}

- (BOOL)isFitPage
{
	return isFitPage;
}

- (void)setIsFitPage:(BOOL)flag
{
	isFitPage = flag;
}

#pragma mark -
#pragma mark ---- Misc ----

// ******************* Misc ********************

//	enabled or unenabled page up and down buttons depending on if window is active 4 OCT 07 JH
- (void)setPageUpAndDownButtonsEnabled:(BOOL)flag;
{
	[pageUpButton setEnabled:flag];
	[pageDownButton setEnabled:flag];
}

//	escape key exits full screen if in full screen; otherwise calls autocomplete 4 AUG 08 JH
- (void)cancelOperation:(id)sender
{
	id window = [self window];
	id doc = [[window windowController] document];
	NSTextView *textView = [doc firstTextView];

	if ([doc fullScreen])
		[doc bean_toggleFullScreen:nil];
	else
		[textView complete:nil];
}

//	allows us to test for option key during color panel click without using carbon GetCurrentKeyModifiers() - 12 OCT 08 JH
//	we do it here since textView is not subclassed, so we couldn't call super there
- (void)flagsChanged:(NSEvent *)theEvent
{
	//option key pressed -- set accessor that textView looks at before changeColor method
	if ([theEvent modifierFlags] & NSAlternateKeyMask)
		[self setOptionKeyDown:YES];
	else
		[self setOptionKeyDown:NO];

	//shift key pressed -- set accessor that reports shift key up or down
	if ([theEvent modifierFlags] & NSShiftKeyMask)
		[self setShiftKeyDown:YES];
	else
		[self setShiftKeyDown:NO];

	[super flagsChanged:theEvent];
}

-(BOOL)isOptionKeyDown
{
	return isOptionKeyDown;
}

-(void)setOptionKeyDown:(BOOL)flag
{
	isOptionKeyDown = flag;
}

-(BOOL)isShiftKeyDown
{
	return isShiftKeyDown;
}

-(void)setShiftKeyDown:(BOOL)flag
{
	isShiftKeyDown = flag;
}

+ (Class)rulerViewClass
{
	return [KBRulerView class];
}

//this works hand-in-hand with [JHDocument_Window windowDidResize] method
- (void)viewDidEndLiveResize
{
	//NSLog(@"scrollView viewDidEndLiveResize");
	id window = [self window];
	id doc = [[window windowController] document];
	if (![doc hasMultiplePages] && ![doc suppressRestoringTextRange])
	{
		[doc restoreVisibleTextRange];
	}
}

@end
