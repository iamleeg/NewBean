/*
	JHDocument_Window.m
	Bean
		
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
 
#import "JHDocument_Window.h"
#import "JHDocument_View.h" //updateZoomSlider
#import "JHDocument_FullScreen.h" //fullScreen methods
#import "NSTextViewExtension.h" //characterRangeForRect

//	note that we do not explicitly set the delegate for NSWindow...
//	if we wanted to setDelegate for NSWindow to a WindowDelegate
//object created by each document, we can use the following code:
//		doc = [[[notification object] windowController] document]
//		scrollView: [[doc firstTextView] enclosingScrollView]

@implementation JHDocument ( JHDocument_Window )

#pragma mark -
#pragma mark ---- NSWindow Delegate Methods ----

// ******************* NSWindow Delegate Methods ********************

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
	if (fullScreen)
		return [docWindow frame].size;
	return proposedFrameSize;
}

//	adjusts zoom scale when 'Fit to Width' or 'Fit to Page' are active and window is changed
- (void)windowDidResize:(NSNotification *)aNotification
{
	//remember visible text range
	if (![self hasMultiplePages] && ![self suppressRestoringTextRange])
		[self rememberVisibleTextRange];

	//	window was resized in VIEW > SHOW LAYOUT mode, so recalculate scaleFactor of fitWidth/fitPage view to fit clipView
	if ([theScrollView isFitWidth] || [theScrollView isFitPage])
	{
		//	determine new scaleFactor and set it
		float scaleFactor = [[[theScrollView documentView] superview] frame].size.width / [[theScrollView documentView] frame].size.width;
		[theScrollView setScaleFactor:scaleFactor];
		//	adjust zoomSlider for fitPage / fitScreen / clicked 'zoom' button changes 
		[self updateZoomSlider];
	}

	//	window was resized in VIEW > HIDE LAYOUT mode, so rescale continuous textView to fit clipView
	if (![self hasMultiplePages])
	{
		[self adjustZoomOfTextViewWithFloat:[theScrollView scaleFactor]];
		
		//	calling perform with delay below allows us to reset visible range to previous; without it, anytime the insertion point is visible, the scrollview scrolls to centerSelectionInVisibleArea (=scrollToRange:selectedRange) (note: can't override this in scrollRangeToVisible, tried it); view does jump right before reposition, but it also jumps when centeringSelection -- would be nice to know where this is called from (via GnuSTEP code?). 
		//	NOTE: to get rid of the visual jump described above, I put a [doc restoreVisibleTextRange] message inside
		//		[theScrollView viewDidEndLiveResize]
		
		if (![self suppressRestoringTextRange])
		{
			id tv = [self firstTextView];
			NSRange selRange = NSMakeRange([tv selectedRange].location, [tv selectedRange].length + 1);
			NSRange visRectRange = [tv characterRangeForRect:[tv visibleRect]];
			NSRange r = NSIntersectionRange(selRange, visRectRange);
			//if selectedRange is visible, force restoration of scroll position after textView does centerSelectionInVisibleArea
			if (r.length > 0)
			{
				//see [JHScrollView viewDidEndLiveResize] for another method that prevents a 'jump' when resize is done and
				//text caret is visible
				[self performSelector:@selector(restoreVisibleTextRange) withObject:self afterDelay:0.0f];
			}
			//else, no need to delay cause it just works
			else
			{
				[self restoreVisibleTextRange];
			}
		}
		
		//purpose?
		[theScrollView setNeedsDisplay:YES];
		[theScrollView drawRect:NSZeroRect];
	}
}

-(IBAction)windowResignedMain:(id)notification
{
	if ([notification object]==docWindow)
	{
		//	un-enable these buttons when window focus is lost
		if ([theScrollView respondsToSelector:@selector(setPageUpAndDownButtonsEnabled:)])
			[theScrollView setPageUpAndDownButtonsEnabled:NO];
		//	restore normal UI mode
		if ([self fullScreen])
		{
			[self showFullScreen:NO withAnimation:NO];
			[self setShouldRestoreFullScreen:YES];
		}
	}
	//erase non-blinking cursor -- should not be active when window is not main (there is only one global cursor)
	if (2==[[[NSUserDefaults standardUserDefaults] objectForKey:@"prefCursorShape"] intValue])
		[[self firstTextView] setNeedsDisplay:YES];
}

-(IBAction)windowBecameMain:(id)notification
{
	//note: mainWindow & currentDocument are nil (!) when switching back from another
	if ([notification object]==docWindow)
	{
		if ([self shouldRestoreFullScreen]) 
		{
			[self showFullScreen:YES withAnimation:NO];
			[self setShouldRestoreFullScreen:NO];
		}
		//	enable these buttons when window focus is lost
		if ([theScrollView respondsToSelector:@selector(setPageUpAndDownButtonsEnabled:)])
			[theScrollView setPageUpAndDownButtonsEnabled:YES];	
	}
}


#pragma mark -
#pragma mark ---- Window Action Methods ----

// ******************* Window Action Methods ********************

//	make window float a la stickies ;)
- (IBAction)floatWindow:(id)sender
{
	//NSLog(@"floatWindow");
	if ([docWindow level] == NSFloatingWindowLevel)
	{
		[docWindow setLevel:NSNormalWindowLevel];
		if ([sender tag]==100) { [sender setState:0]; }
		[self setFloating:NO];
		[floatButton setHidden:YES];
		[floatButton setEnabled:NO];
	}
	else
	{
		[docWindow setLevel:NSFloatingWindowLevel];
		if ([sender tag]==100) { [sender setState:1]; }
		[self setFloating:YES];
		//	image in status bar hints that window is floating
		[floatButton setHidden:NO];
		[floatButton setEnabled:YES];
	}
}

@end