/*
	JHDocument_FullScreen.m
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
 
#import "JHDocument_FullScreen.h"
#import "JHDocument_View.h" // for toggleLayoutView, rememberVisibleTextRange, visibleTextRange
#import "JHDocument_AltColors.h" //for alt text colors
#import "JHDocument_PageLayout.h" //doForegroundLayout...

#import <Carbon/Carbon.h> // for SetSystemUIMode

//	This category on JHDocument allows a document window to go full screen and relies on several things...
//	1. #import <Carbon/Carbon.h> // for SetSystemUIMode
//	2. a constrainFrameRect:toScreen: override in JHWindow (to move title bar above visible frame of screen)
//	3. notifications set up for when window resigns and gains Main status so full screen is exited and restored

@implementation JHDocument ( JHDocument_FullScreen )

#pragma mark -
#pragma mark ---- Full Screen  ----

// ******************* Full Screen ********************

//	called by menu action
-(IBAction)bean_toggleFullScreen:(id)sender;
{
	[self fullScreen] ? [self showFullScreen:NO withAnimation:NO] : [self showFullScreen:YES withAnimation:NO];
}

-(void)showFullScreen:(BOOL)flag withAnimation:(BOOL)shouldUseAnimation
{
	[self setFullScreen:flag];

	// make full screen

	// Leopard has a native full screen command, which we won't use until Bean is Leopard+ only.
	// example: [theScrollView enterFullScreenMode:[[NSScreen screens] objectAtIndex:0] withOptions:nil];

	//go full screen
	if (flag==YES)
	{
		[self rememberVisibleTextRange];
		
		[self setSuppressRestoringTextRange:YES];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

		//hide window while doing UI stuff -- make it quicker and cleaner
		[docWindow setAlphaValue:0];

		//	----- Apply Prefs -----
	
		//	hide toolbar?
		if ([defaults boolForKey:@"prefHideFullScreenToolbar"])
		{
			if ([[docWindow toolbar] isVisible])
			{
				[self setShouldRestoreToolbar:YES];
				[[docWindow toolbar] setVisible:NO];
			}
		}
		
		//	hide rulers
		if ([defaults boolForKey:@"prefHideFullScreenRuler"])
		{
			if ([self areRulersVisible])
			{
				[self setShouldRestoreRuler:YES];
				[theScrollView setRulersVisible:NO];
				[self setAreRulersVisible:NO];
			}
		}
		
		//remember window's old frame
		[self setOldFrameRect:[docWindow frame]];
		
		//	the menu bar is hidden by SetSystemUIMode by the time we need to know its height, so we remember it here
		//	window is placed in full screen so that menu bar is hidden just above top of screen (only works in Leopard)
		float theHeight = [[NSApp mainMenu] menuBarHeight];
		if (theHeight) { [docWindow setHeightMenuBar:theHeight]; }
		
		//	remember the window frame before going full screen; if we save the file, we used this is size rather than the full screen window size, so the document doesn't reopen looking huge
		[self setContentSizeBeforeFullScreen:[NSScrollView contentSizeForFrameSize:[docWindow frame].size hasHorizontalScroller:[theScrollView hasHorizontalScroller] hasVerticalScroller:[theScrollView hasVerticalScroller] borderType:[theScrollView borderType]]];		

		//	suppress UI controls (menu, dock) for full screen mode
		int z = kUIModeAllSuppressed; // kUIModeContentSuppressed;
		int y = 0;
		SetSystemUIMode (z, y);
	
		//	tweak window based on prefs

		//	alternate colors (for editing only)
		
		//if altColors needs turning on or off, do it
		if (![self shouldUseAltTextColorsInFullScreen] && [self shouldUseAltTextColors])
		{
			[self switchTextColors:nil];
		}	
		else if ([self shouldUseAltTextColorsInFullScreen] && ![self shouldUseAltTextColors])
		{
			[self switchTextColors:nil];
		}

		//restored post 0.9.12 18 MAR 08 JH
		if ([defaults boolForKey:@"prefFullScreenHideLayoutView"])
		{
			if ([self hasMultiplePages])
			{
				[self setShouldRestoreLayoutView:YES];
				[self toggleLayoutView:nil];
			}
			else
			{
				[self setShouldRestoreLayoutView:NO];
			}
		}
		else
		{
			[self setShouldRestoreLayoutView:NO];
		}

		//	tells constrainFrameRect:toScreen: to adjust (only once) to move title bar out of visible area for full screen 
		[docWindow setShouldAdjustForTitleBar:YES];
		//	resize window
		NSRect theScreenFrame = [[NSScreen mainScreen] frame];
		[docWindow setFrame:theScreenFrame display:YES animate:shouldUseAnimation];	

		// inset text according to amounts stored in user preferences
		[self adjustFullScreenHorizontalPadding:self];

		//	when in full screen mode, we do not allow resizing through windowWillResize delegate method, so hide control to resize
		[docWindow setShowsResizeIndicator:NO];
		
		[self setSuppressRestoringTextRange:NO];

		[self restoreVisibleTextRange];
		
		//fade window back in
		[docWindow enterFullScreen];

	}
	//exit full screen
	else
	{
		[self rememberVisibleTextRange];
		
		//so remember/restoreVisibleTextRange doesn't get called continuously while window is resizing
		[self setSuppressRestoringTextRange:YES];

		//hide window while doing UI stuff -- make it quicker and cleaner
		[docWindow setAlphaValue:0];
			
		//	restore normal UI mode
		int z =kUIModeNormal;
		int y = 0;
		SetSystemUIMode (z, y);
		
		//if altColors needs turning on or off, do it
		if (![self shouldUseAltTextColorsInNonFullScreen] && [self shouldUseAltTextColors])
		{
			[self switchTextColors:nil];
		}	
		else if ([self shouldUseAltTextColorsInNonFullScreen] && ![self shouldUseAltTextColors])
		{
			[self switchTextColors:nil];
		}
		
		//	eliminate full screen text inset
		[[self firstTextView] setTextContainerInset:NSMakeSize(0, 0)];
		//	restore previous remembered frame
		[docWindow setFrame:[self oldFrameRect] display:YES animate:shouldUseAnimation];
		
		//	restore pre-full screen state
		if ([self shouldRestoreRuler])
		{
			[theScrollView setRulersVisible:YES];
			[self setAreRulersVisible:YES];
		}
		
		if ([self shouldRestoreToolbar])
		{
			[[docWindow toolbar] setVisible:YES];
		}
		
		if ([self shouldRestoreLayoutView]) 
		{
			if (![self hasMultiplePages])
			{
				//	if user shows Layout View before layout is finished in Continuous View, force layout to complete first; otherwise NSMutableRLEArray objectAtIndex:effectiveRange:: Out of bounds error
				//	the [docWindow isVisible] condition prevents app toggling layout while initially loading doc;
				if ([docWindow isVisible] && [layoutManager firstUnlaidCharacterIndex] < [textStorage length])
				{
					[self doForegroundLayoutToCharacterIndex:INT_MAX]; // must be INT_MAX
				}
				[self setShowLayoutView:YES];
			}
		}
		
		//allow resizing through window resize grabber again
		[docWindow setShowsResizeIndicator:YES];
		
		[self setSuppressRestoringTextRange:NO];
		
		//so remember/restoreVisibleTextRange doesn't get called continuously while window is resizing
		[self restoreVisibleTextRange];
		
		// fade  window back in
		[docWindow returnFromFullScreen];
		
	}
}

-(IBAction)adjustFullScreenHorizontalPadding:(id)sender;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	// inset text according to amounts stored in user preferences
	if (![self hasMultiplePages] && [self fullScreen])
	{
		//BUGFIX 9 JAN 09 so visible text is only restored when pref control slider is used 
		if (sender != self)
			// 3 JAN 09 code addition;
			[self rememberVisibleTextRange];

		NSRect theScreenFrame = [[NSScreen mainScreen] frame];
		//	percentage taken from slider / pref value
		float horizontalInsert = [[defaults valueForKey:@"prefFullScreenHorizontalPadding"] floatValue] * .01;
		//	percentage of screen's frame
		float horizontalInsertPixels = horizontalInsert * theScreenFrame.size.width / [theScrollView scaleFactor];
		//[[self firstTextView] setTextContainerInset:NSMakeSize(100, 0)];
		[[self firstTextView] setTextContainerInset:NSMakeSize(horizontalInsertPixels, 0)];

		//BUGFIX 9 JAN 09 so visible text is only restored when pref control slider is used 
		if (sender != self)
			// 3 JAN 09 code addition
			[self restoreVisibleTextRangeAfterFullScreenPaddingChange];
	}
}

#pragma mark -
#pragma mark ---- Accessors  ----

// ******************* Accessors ********************

-(void)setFullScreen:(BOOL)flag
{
	fullScreen = flag;
}

-(BOOL)fullScreen;
{
	return fullScreen;
}

-(NSRect)oldFrameRect;
{
	return oldFrameRect;
}

-(void)setOldFrameRect:(NSRect)rect;
{
	oldFrameRect = rect;
}

-(BOOL)shouldRestoreRuler
{
	return shouldRestoreRuler;
}

-(void)setShouldRestoreRuler:(BOOL)flag
{
	shouldRestoreRuler = flag;
}

-(BOOL)shouldRestoreToolbar
{
	return shouldRestoreToolbar;
}

-(void)setShouldRestoreToolbar:(BOOL)flag
{
	shouldRestoreToolbar = flag;
}

-(BOOL)shouldRestoreAltTextColors
{
	return shouldRestoreAltTextColors;
}

-(void)setShouldRestoreAltTextColors:(BOOL)flag
{
	shouldRestoreAltTextColors = flag;
}

-(BOOL)shouldRestoreFullScreen
{
	return shouldRestoreFullScreen;
}

-(void)setShouldRestoreFullScreen:(BOOL)flag
{
	shouldRestoreFullScreen = flag;
}

-(BOOL)shouldRestoreLayoutView
{
	return shouldRestoreLayoutView;
}

-(void)setShouldRestoreLayoutView:(BOOL)flag
{
	shouldRestoreLayoutView = flag;
}

-(NSSize)contentSizeBeforeFullScreen
{
	return contentSizeBeforeFullScreen;
}

-(void)setContentSizeBeforeFullScreen:(NSSize)size
{
	contentSizeBeforeFullScreen = size;
}


@end