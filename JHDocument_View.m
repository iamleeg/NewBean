/*
	JHDocument_View.m
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
 
#import "JHDocument_View.h"
#import "JHDocument_FullScreen.h" //adjustFullScreenHorizontalPadding
#import "JHDocument_PageLayout.h" //addPage
#import "JHDocument_LiveWordCount.h" //liveWordCount
#import "NSTextViewExtension.h" //characterRangeForRect
#import "PageView.h"

@implementation JHDocument ( JHDocument_View )

#pragma mark -
#pragma mark ---- Interface Toggle Methods  ----

// ******************* Interface Toggle Methods ********************

// ******************* Toggle View Type ********************

-(void)setShowLayoutView:(BOOL)showLayout
{
	//	so we don't lose (reset) typingAttributes when containers are switched with no text to carry over attributes
	NSDictionary *storeTypingAttributes = nil; 
	if (![textStorage length])
	{
		storeTypingAttributes = [[self firstTextView] typingAttributes]; 
	}
	
	//	release old delegate so new delegate can be set for new firstTextView -- even with shared text state, delegate is not retained!
	if ([[self firstTextView] respondsToSelector:@selector(setDelegate:)])
		[[self firstTextView] setDelegate:nil];
	
	// ----- SHOW PAGE LAYOUT VIEW -----
	
	//	if continuous view, change to layout view
	if (showLayout)
	{

		//see note below
		//if ([layoutManager respondsToSelector: @selector(setAllowsNonContiguousLayout:)])
		//	[layoutManager setAllowsNonContiguousLayout:NO];

		//	Leopard is so slow at paginating that I feel the need to put up a Please Wait... sheet 18 Mar 08
		//	note: a 'James Bond' NSProgressIndicator spinner noticeably slowed pagination, so we just use text
		//	might not need this is keeping both layout and non-layout views around
		
		if ([textStorage length] > 200000)
		{
			//we don't use a progress indicator, just an alert message 'Please Wait...'
			//if doc window is visible, show sheet
			if ([docWindow isVisible] && [docWindow alphaValue] > 0)
			{
				[NSApp beginSheet:messageSheet modalForWindow:docWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];
				[messageSheet orderFront:self];
			}
			//if doc window is not visible, show alert window
			else
			{
				[messageSheet center];
				[[messageSheet windowController] showWindow:nil];
				[messageSheet orderFront:self];
			}
		}

		//alter behavior of typesetter based on view mode
		// show pagebreaks as linefeeds
		[layoutManager setShouldDoLineBreakForFormFeed:NO];
	
		PageView *pageView = [[PageView alloc] init]; // ===== new
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[self setHasMultiplePages:YES];
		//after this, continuous textView will release when its container is removed from index
		[theScrollView setDocumentView:pageView];
		if ([self showMarginsGuide]) { [pageView setShowMarginsGuide:YES]; }
		//	draw page shadow in pageView? (user can turn it off in prefs for slower machines)
		[defaults boolForKey:@"prefShowPageShadow"] ? [pageView setShowPageShadow:YES] : [pageView setShowPageShadow:NO];
		[pageView setPrintInfo:[self printInfo]]; // new pageView, so inform it of margins, etc.
 
		//	add the first new page before we remove the old container so we can avoid losing all the shared text view state.
		//	the setPreserving accessor allows addPage to ignore the old container
		[self setPreservingTextViewState:YES];
		[self addPage:self];
		[self setPreservingTextViewState:NO];
		
		//	remove the continuous text view text container
		//	removing the textContainer from the layoutManager causes it to be released, which releases its textView
		NSTextView *textView = [self firstTextView];
		if (textView) { [[self layoutManager] removeTextContainerAtIndex:0]; }
		
		//	layout and pagination on Tiger was lightning quick; on Leopard, not so much (bug filed!), up to 10 times as long
		//	also, Intel macs handle this much better than PPC macs, so we give a preference setting to turn background layout on
		if ([defaults boolForKey:@"prefBackgroundPagination"])
		{
			[self doForegroundLayoutToCharacterIndex:20000];
		}
		else
		{
			[self doForegroundLayoutToCharacterIndex:INT_MAX];
		}
		
		NSArray *textContainers = [[self layoutManager] textContainers];
		int containerIndex = [textContainers count] - 1;
		[pageView setNumberOfPages:[self pageNumberForContainerAtIndex:containerIndex]];
		
		//	setShouldUseAltTextColors sets an accessor in newly created pageView
		if ([self shouldUseAltTextColors]) { [self setShouldUseAltTextColors:YES]; }
						
		[self shouldShowHorizontalScroller] ? [theScrollView setHasHorizontalScroller:YES] : [theScrollView setHasHorizontalScroller:NO];
		[textView setBackgroundColor:[self theBackgroundColor]];
		[theScrollView setBackgroundColor:[NSColor lightGrayColor]];
		
		//	tweak ruler '0' for offset (only needs to be set once per pageView init)
		NSRulerView *xruler = [theScrollView horizontalRulerView];
		[xruler setOriginOffset:[pageView pageSeparatorLength]];
		
		//prevent wacky page number from showing due to background pagination
		[self setShowPageNumbers:NO];
		
		// so scroller's knob position is updated (bugfix) 
		[theScrollView reflectScrolledClipView:[theScrollView contentView]];
		[pageView release]; // ===== release
		
		//	dismiss alert sheet Please Wait...
		if ([messageSheet isVisible])
		{
			[NSApp endSheet:messageSheet];
			[messageSheet orderOut:self];
		}
		
	}
	
	// ----- SHOW 'CONTINUOUS' TEXT VIEW -----

	//if page layout view (shows multiple pages), change to continuous view
	else
	{	
		//alter behavior of typesetter based on view mode
		// show pagebreaks as linefeeds
		[layoutManager setShouldDoLineBreakForFormFeed:YES];

		[self setHasMultiplePages:NO];
		NSSize size = [theScrollView contentSize];
		//	===== new
		NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(size.width, FLT_MAX)];
		//	===== new
		NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0.0, 0.0, size.width, size.height) textContainer:textContainer];
		
		//note: removing the layoutManager makes this process go slower, for some reason 
	
		//	insert container at index 0 before removing existing containers to preserve shared text state.
		[[self layoutManager] insertTextContainer:textContainer atIndex:0];
		//	remove text containers representing 'pages'
		if ([[theScrollView documentView] isKindOfClass:[PageView class]])
		{
			NSArray *textContainers = [[self layoutManager] textContainers];
			unsigned cnt = [textContainers count];
			while (cnt-- > 1)
			{
				[[self layoutManager] removeTextContainerAtIndex:cnt];
			}
		}
		//	setup continuous text view
		[textContainer setWidthTracksTextView:YES];
		[textContainer setHeightTracksTextView:NO];
		
		// this would be a big performance boost, but glyphRangeForTextContainer gives exception ('container not in array') when non-contiguous layout is on (but only in hard-to-pin-down cases!)
		// noncontiguousLayout: only visible text is computed and drawn (typically, all text is computed and only visible text is drawn)
		// decreases document load time, display time
		//if ([layoutManager respondsToSelector: @selector(setAllowsNonContiguousLayout:)])
			//[layoutManager setAllowsNonContiguousLayout:YES];

		[textView setHorizontallyResizable:NO];			
		[textView setVerticallyResizable:YES];
		[textView setAutoresizingMask:NSViewWidthSizable];
		[textView setMinSize:size];	
		[textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
		if ([self shouldUseAltTextColors])
		{
			[theScrollView setBackgroundColor:[self textViewBackgroundColor]];
		}
		else
		{
			[theScrollView setBackgroundColor:[self theBackgroundColor]];
		}
		//	the next line should cause the multiple page view to go away - to quote Text Edit's code 
		[theScrollView setDocumentView:textView];
		[theScrollView setHasHorizontalScroller:NO];
		[textView release]; // ===== release
		[textContainer release]; // ===== release
		//	needed
		float zoomValue = [[zoomSlider cell] floatValue];
		[self adjustZoomOfTextViewWithFloat:zoomValue];
	}
	//	maintain ruler state
	([self areRulersVisible]) ? [theScrollView setRulersVisible:YES] : [theScrollView setRulersVisible:NO];
	//	set focus
	[[theScrollView window] makeFirstResponder:[self firstTextView]];
	[[theScrollView window] setInitialFirstResponder:[self firstTextView]];
	[self liveWordCount:nil];
	if (storeTypingAttributes) [[self firstTextView] setTypingAttributes:storeTypingAttributes];
	//	set the delegate again, since we created a new primary textView
	[[self firstTextView] setDelegate:self];
}

//	toggles Page Layout view (text containers act as 'pages') and Continuous Text view (one long text container) 
- (IBAction)toggleLayoutView:(id)sender
{
	//	if user attempts to switch to Layout View before layout is finished in Continuous View, then force layout to complete before doing the switch (takes just a second); if we switch when layout is not yet completed, we get an exception: NSMutableRLEArray objectAtIndex:effectiveRange:: Out of bounds'
	//	the [docWindow isVisible] condition prevents app toggling layout while initially loading doc;
	if (![self hasMultiplePages] && [docWindow isVisible] && [layoutManager firstUnlaidCharacterIndex] < [textStorage length])
	{
		[self doForegroundLayoutToCharacterIndex:INT_MAX]; // must be INT_MAX
	}

	//if showing layout view, turn it off, and vice versa
	BOOL showLayout = ![self hasMultiplePages];
	[self setShowLayoutView:showLayout];
}

//gave method a more sensible name
- (IBAction)setTheViewType:(id)sender
{
	[self rememberVisibleTextRange];
	[self toggleLayoutView:nil];
	[self restoreVisibleTextRange];
}

// ******************* Toggle Ruler Method ********************

-(IBAction)toggleBothRulers:(id)sender
{
	BOOL theBool = [theScrollView rulersVisible] ? NO : YES;
	[theScrollView setRulersVisible:theBool];
	[self setAreRulersVisible:theBool];
}

// ******************* Toggle Show Margin Guides ********************

-(IBAction)toggleMarginsAction:(id)sender
{
	PageView *pageView = [theScrollView documentView];
	BOOL theBool = [self showMarginsGuide] ? NO : YES;
	[pageView setShowMarginsGuide:theBool];
	//	accessor needed because pageView is destroyed when setTheViewType is cycled
	[self setShowMarginsGuide:theBool];
}

// ******************* Toggle Show Invisibles *******************

//	toggles edit mode in which returns, tabs, and spaces are visible in the text view
-(IBAction)toggleInvisiblesAction:(id)sender
{
	id lm = [self layoutManager];
	[lm showInvisibleCharacters] ? [lm setShowInvisibleCharacters:NO] : [lm setShowInvisibleCharacters:YES];
	[[theScrollView documentView] setNeedsDisplay:YES];
}

// ******************* Toggle Font Panel *******************

//	helper action for toolbar item
-(IBAction)showFontPanel:(id)sender
{
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFontPanel *fontPanel = [fontManager fontPanel:NO];
	
	if ([fontPanel isVisible]) 
	{
		[fontPanel orderOut:self];
		return;
	}
	
	[fontManager fontPanel:YES];
	[fontManager orderFrontFontPanel:nil];
}

#pragma mark -
#pragma mark ---- Zoom (View Scale) Methods ----

// ******************* Zoom (View Scale) Methods ********************

//	all 'zoom' code reworked 5 NOV 08 JH
//	TODO: reorganize code so method names, code structure, and variable names are clearer

-(void)adjustZoomOfTextViewWithFloat:(float)zoomValue
{
	//	adjust continuous text view scale according to value from zoomSlider (based on some Text Edit 1.4 code)
	NSTextView *textView = [self firstTextView];
	NSRect frame = NSInsetRect([textView bounds], 0.0, 0.0);
	NSSize curDocFrameSize, newDocBoundsSize;
	NSView *clipView = [[[textView enclosingScrollView] documentView] superview];
	// Get the frame.  The frame must stay the same.
	curDocFrameSize = [clipView frame].size;
	// The new bounds will be frame divided by scale factor
	newDocBoundsSize.width = curDocFrameSize.width / zoomValue;
	newDocBoundsSize.height = curDocFrameSize.height / zoomValue;
	//	resize the clipview (the size of the rect that allows us to see the textView)
	[clipView setBoundsSize:newDocBoundsSize]; //code duplicated in setScaleFactor?
	//	resize the textView to match the clipview (so text wraps to window)
	[textView setFrame:NSMakeRect(0.0, 0.0, newDocBoundsSize.width, frame.size.height)];
	//needed
	[theScrollView setScaleFactorWithoutDisplay: zoomValue];
	//set focus
	[[[textView enclosingScrollView] window] makeFirstResponder:textView];
	[[[textView enclosingScrollView] window] setInitialFirstResponder:textView];
	// for full screen only
	if ([self fullScreen])
	{
		//	inset text (for 'margins') according to amounts stored in user preferences
		[self adjustFullScreenHorizontalPadding:self];
		//	prevent blank areas in glyph layout 30 JUL 08 JH
		[[self firstTextView] performSelector:@selector(display) withObject:[self firstTextView] afterDelay:0.0f];
	}
}

-(void)adjustZoomWithFloat:(float)zoomValue
{

	//if option key is down, zoom in 25% increments
	BOOL shouldUpdateZoomSlider = NO;
	if ([theScrollView isOptionKeyDown])
	{
		zoomValue = ceil(zoomValue / .25) * .25;
		shouldUpdateZoomSlider = YES;
	}
	
	//	here we resize the clipView's bounds and the textView's frame to 'zoom' in on the text
	if (![self hasMultiplePages])
	{
		[self rememberVisibleTextRange];
		[self adjustZoomOfTextViewWithFloat:zoomValue];
		[self restoreVisibleTextRange];
	}
	//	hasMultiplePages, so setScaleFactor in scrollView, changing clipView's bounds around the (multiple) pageView
	else
	{
		[theScrollView setScaleFactor:zoomValue];
	}
	
	//	adjusts the label next to the slider; ceil allows label show even increments like 100%
	[zoomAmt setIntValue:ceil(100 * zoomValue)];
	//zoomValue received from slider was rounded to 25% increments, so change slider to reflect that 
	if (shouldUpdateZoomSlider)
		[self updateZoomSlider];
}

//	when the zoomSlider (view scale) control is changed, this adjusts the view(s) to match
//	this method is called by the actual zoom slider control at the botttom of JHDocument.nib window
-(IBAction)zoomSlider:(id)sender
{
	//	fit-to-width and fit-to-page are turned off when zoom slider control is used
	[theScrollView setIsFitWidth:NO];
	[theScrollView setIsFitPage:NO];
	
	float zoomValue = [[sender cell] floatValue];
	[self adjustZoomWithFloat:zoomValue];
}

//	adjusts the zoom amount for the frontmost window if it is full screen
//	called from Preferences > Full Screen > Zoom slider (accompanying checkbox label: [x] Different zoom amount for full screen)
-(IBAction)updateZoomAmount:(id)sender
{
	if ([self fullScreen])
	{
		//TODO save previous zoom amount for restore upon exit full screen
	
		//	fit-to-width and fit-to-page are turned off when zoom slider control is used
		[theScrollView setIsFitWidth:NO];
		[theScrollView setIsFitPage:NO];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		float zoom = [[defaults valueForKey:@"prefFullScreenZoomAmount"] floatValue] / 100;
		[self adjustZoomWithFloat:zoom];
	}
}

//	updates zoomSlider control and zoomAmt label when scrollView is resized programatically
-(void)updateZoomSlider
{
	[zoomSlider setFloatValue:[theScrollView scaleFactor]];
	float zoomValue = [zoomSlider floatValue];
	[zoomAmt setIntValue:(100 * zoomValue)];
}

//	menu item action to set Fit To Page or Fit To Width in Page Layout Mode
-(IBAction)zoomSelect:(id)sender
{
	//	fit width was selected
	if ([sender tag] == 1)
	{ 
		//	change to layout view
		if (![self hasMultiplePages]) [self setTheViewType:nil];
		[theScrollView setIsFitWidth:YES];
		[theScrollView setIsFitPage:NO];
		//	scaleFactor doesn't matter here cos will be Fit-To-Width
		//	but use a value that will never equal previous value to get past same-value checker
		[theScrollView setScaleFactor:.09];
		//	update the zoomSlider for fit to page / fit to screen resizings
		[self updateZoomSlider];
	}
	//	fit page
	if ([sender tag] == 2)
	{
		//	change to layout view
		if (![self hasMultiplePages]) [self setTheViewType:nil];
		[theScrollView setIsFitWidth:NO];
		[theScrollView setIsFitPage:YES];
		//	scaleFactor doesn't matter here cos will be Fit-To-Page
		//	but use a value that will never equal previous value to get past same-value checker
		[theScrollView setScaleFactor:.09];
		//	update the zoomSlider for fit to page / fit to screen resizings
		[self updateZoomSlider];
	}
	//	custom
	//	does this code ever get called?
	if ([sender tag] == 0)
	{ 
		[zoomSlider setFloatValue:[theScrollView scaleFactor]];
		[theScrollView setIsFitWidth:NO];
		[theScrollView setIsFitPage:NO];
		//	update the zoomSlider
		float zoomValue = [zoomSlider floatValue];
		[theScrollView setScaleFactor:zoomValue];
		[zoomAmt setIntValue:(100 * zoomValue)];
	}
}

//	user selected 'zoom in' from view menu
-(IBAction)zoomInAction:(id)sender
{
	// 4.0 means 400%, which is as high as we go
	[zoomSlider floatValue] < 3.8 ? [zoomSlider setFloatValue:([zoomSlider floatValue] + .2)] : [zoomSlider setFloatValue:4.0];
	[self zoomSlider:zoomSlider];
}

//	user selected 'zoom out' from view menu
-(IBAction)zoomOutAction:(id)sender
{
	// lowest value is .1 = 10% zoom (can encounter layout errors if smaller)
	[zoomSlider floatValue] > 0.2 ? [zoomSlider setFloatValue:([zoomSlider floatValue] - .2)] : [zoomSlider setFloatValue:0.1];
	[self zoomSlider:zoomSlider];
}

#pragma mark -
#pragma mark ---- Constrain Scroll ----

// ******************* Constrain Scroll ********************

//	tries to keep insertion point positioned about 2/3 legnth vertically below title bar in clipView;
//	this avoids problem of where you are always looking at very bottom of the window/screen when typing
//	note: only adjusts view when index is at END of file (otherwise too jittery)
-(void)constrainScrollWithForceFlag:(BOOL)forceFlag
{
	NSTextView *text = [self firstTextView];
	//only constrain scroll at end -- too jumpy otherwise
	if ([text selectedRange].location <= ([textStorage length] - 10) && !forceFlag)
		return;

	// don't constrain scroll if adding to a text list...causes scrollview to 'jump' 11 Oct 2007 JH
	NSParagraphStyle *paragraphStyle = [[text typingAttributes] objectForKey:NSParagraphStyleAttributeName];
	if ( paragraphStyle != nil )
	{
		if ([[paragraphStyle textLists] count])
			return;
	}
	
	//	forceFlag causes constrainScroll when it wouldn't otherwise do all the work (such as when there's no change in the y coord)
	if ([self hasMultiplePages] && [text selectedRange].location > 1)
	{
		//	determine position of lineFragment in documentView: we scrollToPoint to this point later
		NSEvent *theEvent = [NSApp currentEvent];
		NSRect lineFragRect;
		//	upon [return] (keyCode==36), figure location of lineFrag for empty line and scroll (added 10 June 2007 BH)
		if ([theEvent type]==NSKeyDown && [theEvent keyCode]==36)
		{
			lineFragRect = [[text layoutManager] lineFragmentRectForGlyphAtIndex:[text selectedRange].location + [text selectedRange].length - 2 effectiveRange:nil];
			lineFragRect.origin.y = lineFragRect.origin.y + lineFragRect.size.height;
		}
		//	otherwise, figure location of lineFrag for wrapped line and scroll
		else
		{
			lineFragRect = [[text layoutManager] lineFragmentRectForGlyphAtIndex:[text selectedRange].location + [text selectedRange].length - 1 effectiveRange:nil];
		}
		
		int	lineFragPosY = lineFragRect.origin.y;
		//	only constrains scroll if (lineFrag pos has change AND cursor is near end of text) OR doc has just been loaded but is not yet visible
		if (!(lineFragPosY==[self lineFragPosYSave]) || forceFlag) 
		{
			//	determine which text container contains insertion point (selectedRange)
			NSArray *containers = [[self layoutManager] textContainers];
			NSTextContainer *indexContainer = [[self layoutManager] textContainerForGlyphAtIndex:[text selectedRange].location - 1 effectiveRange:nil withoutAdditionalLayout:YES];
			int indexContainerNumber = [containers indexOfObjectIdenticalTo:indexContainer];
			//	out of bounds error (textContainer does not yet exist for unlaid out text)
			if (indexContainerNumber > [containers count]) return;
			//	get value of 1/2 of clipView height
			NSSize clipViewSize = [[[theScrollView documentView] superview] frame].size;
			int halfClipViewHeight = clipViewSize.height / 2; 
			//	figure new location for scrollToPoint...about 1/2 down from top of window
			int numPreviousPages = [self pageNumberForContainerAtIndex:indexContainerNumber] - 1;
			float theNewOriginY = lineFragPosY + (([printInfo paperSize].height + 15) * numPreviousPages) - halfClipViewHeight / [theScrollView scaleFactor] + 100;
			//	note that we use page count (above), not textContainer count (below)!
			//float theNewOriginY = lineFragPosY + (([printInfo paperSize].height + 15) * indexContainerNumber - 1) - halfClipViewHeight / [theScrollView scaleFactor] + 100;
			if (theNewOriginY < 0) theNewOriginY = 0;
			[[theScrollView contentView] scrollToPoint:NSMakePoint(0,theNewOriginY)];
			[theScrollView reflectScrolledClipView:[theScrollView contentView]];
			//	save for comparision above
			[self setLineFragPosYSave:lineFragPosY];
		}
	}
	if (![self hasMultiplePages])
	{
		//	determine position of lineFragment in documentView: we scrollToPoint to this point later
		NSEvent *theEvent = [NSApp currentEvent];
		NSRect lineFragRect;
		//	upon [return] (keyCode==36), figure location of lineFrag for empty line and scroll (added 10 June 2007 BH)
		if ([theEvent type]==NSKeyDown && [theEvent keyCode]==36)
		{
			lineFragRect = [[text layoutManager] lineFragmentRectForGlyphAtIndex:[text selectedRange].location + [text selectedRange].length - 2 effectiveRange:nil];
			lineFragRect.origin.y = lineFragRect.origin.y + lineFragRect.size.height;
		}
		//	otherwise, figure location of lineFrag for wrapped line and scroll
		else
		{
			lineFragRect = [[text layoutManager] lineFragmentRectForGlyphAtIndex:[text selectedRange].location + [text selectedRange].length - 1 effectiveRange:nil];
		}
		
		int	lineFragPosY = lineFragRect.origin.y;
		//	only constrains scroll if lineFrag pos has change OR doc has just been loaded but is not yet visible
		if (!(lineFragPosY==[self lineFragPosYSave]) || forceFlag) 
		{
			//crashed here one time on autosave recover -- race condition?
			if (!theScrollView) 
				return; 
			//	get value of 1/2 of clipView height
			NSSize clipViewSize = [[[theScrollView documentView] superview] frame].size;
			// ***** adjusting this number grows the textView's height *****
			int halfClipViewHeight = clipViewSize.height * .5; 
			//	figure new location for scrollToPoint...about 1/2 down from top of window
			float theNewOriginY = lineFragPosY - halfClipViewHeight / [theScrollView scaleFactor];
			if (theNewOriginY < 0) theNewOriginY = 0;
			
			[[theScrollView contentView] scrollToPoint:NSMakePoint(0,theNewOriginY)];
			[theScrollView reflectScrolledClipView:[theScrollView contentView]];
			//	save for comparision above
			[self setLineFragPosYSave:lineFragPosY];
		}
	}
}

//	remember visible range of glyphs for later restore
-(void)rememberVisibleTextRange;
{
	NSRange visRange = {0,0};

	//examine continuous text view
	if (![self hasMultiplePages])
	{
		NSTextView *textView = [self firstTextView];
		//	remember visible range of text
		visRange = [textView characterRangeForRect:[textView visibleRect]];
	}
	//multiple page view
	else
	{
		//	remember index of first visible character to restore after layout view toggle
		
		PageView *pageView = [theScrollView documentView];
		int containerArrayIndex = ([pageView firstPageVisible] - 1) * [self numberColumns];
		id container = [[layoutManager textContainers] objectAtIndex:containerArrayIndex];
		id tv = [container textView];
		visRange = [tv characterRangeForRect:[tv visibleRect]];

		// in case container is visible but not its characters
		if (containerArrayIndex > 0 && visRange.location == 0)
		{
			NSRange cRange = [layoutManager glyphRangeForTextContainer:container];
			visRange = cRange;
		}
	}
	
	if (NSNotFound == visRange.location) visRange = [[self firstTextView] selectedRange]; //fallback
	
	//if we constantly update the restore range while zooming, the range 'skates' due to more chars fitting in lineFragRect
	//we use old range instead if it looks like that is the case 8 NOV 08 JH
	if (visibleTextRange.length)
	{
		if (visRange.location > visibleTextRange.location + 200 || visRange.location < visibleTextRange.location - 200)
		{
			visibleTextRange = visRange;
		}
		else
		{
			//use old range as it's probably still valid; this prevents range from skating as zoom is changed
		}
	}
	else 
	{
		visibleTextRange = visRange;
	}
	
	BOOL cursorVisible;
	//only works if textStorage length > 0
	if ([textStorage length])
	{
		//remember if text cursor is visible; restore it later if it is not visible
		id tv = [self firstTextView];
		NSRange selRange = NSMakeRange([tv selectedRange].location, 1);
		if (selRange.location + 1 > [textStorage length] && selRange.location > 0)
		{
			selRange.location = selRange.location - 1; //prevent out of bounds
		}
		NSRange glyphSelRange = [layoutManager glyphRangeForCharacterRange:selRange actualCharacterRange:NULL];
		id container = [layoutManager textContainerForGlyphAtIndex:glyphSelRange.location effectiveRange:NULL];
		id selTextView = [container textView];
		NSRect selTextRect = [layoutManager boundingRectForGlyphRange:glyphSelRange inTextContainer:container];
		//rect of index char
		NSRect indexRect = [[theScrollView documentView] convertRect:selTextRect fromView:selTextView];
		//document view's visible rect
		NSRect docVisRect = [theScrollView documentVisibleRect];
		//intersection means cursor is visible
		cursorVisible = NSIntersectsRect(indexRect, docVisRect);
	}
	else
		cursorVisible = YES; //won't hurt if it isn't
	
	if (cursorVisible)
		[self setCursorWasVisible:YES];
	else
		[self setCursorWasVisible:NO];
}

-(void)restoreVisibleCursor
{
	if ([self cursorWasVisible])
	{
		id tv = [self firstTextView];
		//if the cursor was visible, then due to a change of layout (view mode, columns, page size, etc.) it becomes not visible, scroll the selected cursor range to become visible again; I think it does nothing if the range is already visible
		[tv scrollRangeToVisible:NSMakeRange([tv selectedRange].location, 0)];
	}
}

//this restores the visible character range after switching between continuous and layout views
-(void)restoreVisibleTextRange
{
	NSRange visRange = [self visibleTextRange];
	int visChar = visRange.location;
	id text = [self firstTextView];

	//error checking
	if (![textStorage length]) { return; }
	if (visChar == [textStorage length] && visChar > 1) { visChar = visChar - 1; }
	if (visibleTextRange.location == 0 && visibleTextRange.length == 0) return;

	//for continuous textView
	if (![self hasMultiplePages])
	{
		//	determine position of lineFragment of visRange.location in documentView so we can scrollToPoint
		NSRect lineFragRect;
		lineFragRect = [[text layoutManager] lineFragmentRectForGlyphAtIndex:visChar effectiveRange:nil];
						
		float theNewOriginY = lineFragRect.origin.y + (lineFragRect.size.height * 0.2); //fudge to avoid line scroll
		
		//	figure new location for scrollToPoint (so previous visible char range starts at top off window) 
		if (theNewOriginY < 0) theNewOriginY = 0;
		
		//	prevents scrolling of small content view (which can hide part of it)
		//	but allows restore of index near top of first page
		if ([text frame].size.height < [theScrollView visibleRect].size.height)
		{
			return;
		}
		//idea: test of margin of error here; don't do anything if deviation is not above a certain amount
		[[theScrollView contentView] scrollToPoint:NSMakePoint(0,theNewOriginY)];
		[theScrollView reflectScrolledClipView:[theScrollView contentView]];
	}
	//for layout view
	if ([self hasMultiplePages])
	{
		//	determine position of lineFragment of visRange.location in documentView so we can scrollToPoint later
		NSRect lineFragRect;
		id lm = [text layoutManager];
		lineFragRect = [lm lineFragmentRectForGlyphAtIndex:visChar effectiveRange:nil];
				
		int	lineFragPosY = lineFragRect.origin.y;
		//	determine which text container contains insertion point (selectedRange)
		NSArray *containers = [lm textContainers];
		NSTextContainer *indexContainer = [lm textContainerForGlyphAtIndex:visChar effectiveRange:nil withoutAdditionalLayout:YES];
		int indexContainerNumber = [containers indexOfObjectIdenticalTo:indexContainer];
		//	out of bounds error (textContainer does not yet exist for unlaid out text)
		if (indexContainerNumber > [containers count]) return;
		int pageIndex = [self pageNumberForContainerAtIndex:indexContainerNumber] - 1;
		// a little adjustment is necessary for some reason TODO: why is adjustment necessary?
		int posAdjustment = 0;
		if (visChar > 100) { posAdjustment = 70; }
		//	figure new location for scrollToPoint...lineFrag should be approx at top of contentView
		float theNewOriginY = lineFragPosY + ([printInfo paperSize].height + 15) * pageIndex + posAdjustment;
		if (theNewOriginY < 0) theNewOriginY = 0;
		[[theScrollView contentView] scrollToPoint:NSMakePoint(0,theNewOriginY)];
		[theScrollView reflectScrolledClipView:[theScrollView contentView]];
	}
	[self restoreVisibleCursor];
	//use Leopard flashing indicator to help user spot insertion point
	[text indicateCursorIndex];
}

//this restores the visible character range after full screen continuous view padding is changed
//TODO: should really be combined with above method with perhaps a flag
-(void)restoreVisibleTextRangeAfterFullScreenPaddingChange
{
	//for continuous textView only
	if ([self hasMultiplePages]) { return; }
	
	NSRange visRange = [self visibleTextRange];
	int visChar = visRange.location;
	id text = [self firstTextView];

	//error checking
	if (![textStorage length]) { return; }
	if (visChar == [textStorage length] && visChar > 1) { visChar = visChar - 1; }
	if (visibleTextRange.location == 0 && visibleTextRange.length == 0) return;

	//	determine position of lineFragment of visRange.location in documentView so we can scrollToPoint
	NSRect lineFragRect;
	lineFragRect = [[text layoutManager] lineFragmentRectForGlyphAtIndex:visChar effectiveRange:nil];
					
	float theNewOriginY = lineFragRect.origin.y + (lineFragRect.size.height * 0.2); //fudge to avoid line scroll
	
	//	figure new location for scrollToPoint (so previous visible char range starts at top off window) 
	if (theNewOriginY < 0) theNewOriginY = 0;
	
	//	prevents scrolling of small content view (which can hide part of it)
	//	but allows restore of index near top of first page
	if ([text frame].size.height < [theScrollView visibleRect].size.height)
	{
		return;
	}
	//idea: test of margin of error here; don't do anything if deviation is not above a certain amount
	[[theScrollView contentView] scrollToPoint:NSMakePoint(0,theNewOriginY)];
	[theScrollView reflectScrolledClipView:[theScrollView contentView]];
	[self restoreVisibleCursor];
}


-(NSRange)visibleTextRange;
{
	return visibleTextRange;
}

-(BOOL)cursorWasVisible
{
	return cursorWasVisible;
}

-(void)setCursorWasVisible:(BOOL)cursorVisible
{
	cursorWasVisible = cursorVisible;
}


@end