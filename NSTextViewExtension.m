/*
	NSTextViewExtension.m
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

#import "NSTextViewExtension.h"
#import "JHDocument.h" // for OS version
#import "JHDocument_FullScreen.h" // for fullScreen
#import "JHScrollView.h" // for isOptionKeyDown
#import "JHDocument_Text.h" //for alternateFontActive
#import "JHDocumentController.h" //for printTextViewSelection
#import "JHWindow.h" //for [JHWindow class] comparison
#import "JHFindPanel.h" //for class ID
#import "JHDocument_AltColors.h" //for altCursorColor

//#import <Carbon/Carbon.h> //for GetCurrentKeyModifiers()

BOOL _cursorCompositeLighter; // = NSCompositePlusLighter
BOOL dontChangeBackgroundColor; //global -- see changeColorSwizzle
int _beanCursorShape; //global -- see prefs > General > Text Cursor > Shape matrix control

@implementation NSTextView ( Extensions )

//	helper for constrainScroll; extends height of textView so scroller behavior matches what you see on screen
//	probably belongs in a subclass of NSTextView, but we use GNUStep code here instead of calling super

//note: this method is called regularly ... didChangeText > scrollRangeToVisible > sizeToFit > setConstrainedFrameSize

- (void) setConstrainedFrameSize: (NSSize)desiredSize
{
	NSSize newSize = NSZeroSize;
	id doc = [[[self window] windowController] document];
	id superview = [self superview];
	//text container's height == FLT_MAX means continuous text view
	if ([doc shouldConstrainScroll] 
				&& ![superview isKindOfClass:[PageView class]]
				&& [[self textContainer] containerSize].height == FLT_MAX
				// BUGFIX: 5 AUG 09 JH fix constant jitter of scroller button when half way through a long continuous document
				&& [self selectedRange].location > [[self textStorage] length] - 1000)
	{
		//make new size for textView (but don't change width)
		newSize.width = [self bounds].size.width;
		//	adjust textView's height (if constrainScroll is on); else use desired height
		//scrollView ought to be an instance of JHScrollView
		id scrollView = [superview superview];
		float amtToAdj = ( .50 * [superview frame].size.height ) / [scrollView scaleFactor];
		newSize.height = desiredSize.height + amtToAdj;
	
		//apply new size
		if (NSEqualSizes([self frame].size, newSize) == NO)
			[self setFrameSize: newSize];
	}
	else if ([superview isKindOfClass:[PageView class]])
	{
		//	multiple pages
		//	do nothing
	}
	//	for all other cases, we use [pre-2006] GNUStep code here (seems to work)
	//	TODO: we should call super instead if we ever actually subclass NSTextView
	else
	{
		//	lifted from post 2006 GNUstep NSTextView.m (various authors)
		//	cleaned up 6 AUG 09 JH
		newSize=[self frame].size;
		NSSize effectiveMinSize = [self minSize];
		//use size of containing clipview if larger than min size
		NSClipView *cv = (NSClipView *)[self superview];
		if (cv && [cv isKindOfClass: [NSClipView class]] && [cv documentView] == self)
		{
		  NSSize clipBounds = [cv bounds].size;
		  effectiveMinSize.width  = MAX(effectiveMinSize.width , clipBounds.width);
		  effectiveMinSize.height = MAX(effectiveMinSize.height, clipBounds.height);
		}
		//GNUstep coded
		newSize.width = [self isHorizontallyResizable]
				? MIN(MAX(desiredSize.width, effectiveMinSize.width), [self maxSize].width)
				: [self frame].size.width;
		newSize.height = [self isVerticallyResizable]
				? MIN(MAX(desiredSize.height, effectiveMinSize.height), [self maxSize].height)
				: [self frame].size.height;

		if(!NSEqualSizes([self frame].size, newSize))
		{
			// adjust to be between min and max size - may adjust the container depending on its tracking flags
			[self setFrameSize:newSize];
			[self setNeedsDisplay:YES];
		}
	}
}

-(void)setCursorCompositeLighter:(BOOL)flag
{
	_cursorCompositeLighter = flag;
}

//set global
-(void)setBeanCursorShape:(int)shape
{
	_beanCursorShape = shape;
}


/*
	//old cursor sizing/drawing/erasing code
	//	don't use anymore 3 AUG 09 JH
	//	make insertion point a little more visible -- why not, since we're here?
	//	note: behavior totally differently in leopard and tiger
	else if ([[[NSDocumentController sharedDocumentController] currentDocument] currentSystemVersion] >= 0x1050) 
	{
		//	Leopard +
		//	rect.origin.x = rect.origin.x - 0.2;
		//	rect.size.width = rect.size.width + 0.4;
		rect.size.width+=1.0;
	}
	else
	{
		//	Tiger
		// rect.origin.x = rect.origin.x - 0.6;
		// rect.size.width = rect.size.width + 1.2;
		rect.size.width+=1.0;
	}

	//	don't use anymore 3 AUG 09 JH
	//	Leopard
	if ([[[NSDocumentController sharedDocumentController] currentDocument] currentSystemVersion] >= 0x1050) 
	{
		//	make rect bigger when erasing insertion point because otherwise there's a ghostly shadow of the rect (antialiasing?) 
		//rect.origin.x = rect.origin.x - 0.3; // was 0.2 (17 JAN 08 JH)
		//rect.size.width = rect.size.width + 0.6; // was 0.4 (17 JAN 08 JH)
		rect.size.width+=1.0;
	}
	//	Tiger
	else
	{
		//rect.origin.x = rect.origin.x - 0.9; // was 0.2 (17 JAN 08 JH) // updated 15 APR 08 JH
		//rect.size.width = rect.size.width + 1.8; // was 0.4 (17 JAN 08 JH) // updated 15 APR 08 JH
		rect.size.width+=1.0;
	}
*/

//	an NSRulerView delegate method
//	since PageView ignores drawRect calls unless bounds of clipView change or forceRedraw is YES, we must set forceRedraw to YES when ruler markers are being redrawn so tracking lines get erased on next drawRect
- (float)rulerView:(NSRulerView *)aRulerView willMoveMarker:(NSRulerMarker *)aMarker toLocation:(float)location
{
	id theView = [[self enclosingScrollView] documentView];

	if ([theView isKindOfClass:[PageView class]])
	{
		//necessary to redraw ruler lines when widgets are moved
		[theView setForceRedraw:YES];
		//necessary to clean up ruler lines when widgets are removed from ruler 2 AUG 08 JH
		[theView performSelector:@selector(forceViewNeedsDisplay) withObject:theView afterDelay:0.0f];
	}
	
	//following lines copied from GnuSTEP (many authors) 16 MAY 08 JH
	NSSize size = [[self textContainer] containerSize];

	if (location < 0.0)
	{
		return 0.0;
	}
	if (location > size.width)
	{
		return size.width;
	}
	
	return location;
}

//	from a Cocoa List post by Keith Blount
//	Returns the range of characters that are contained within the given rect (can be called
//	for [self visibleRect], for instance).
//	(Thanks to Douglas Davidson for posting this code on the Cocoa dev lists).

- (NSRange)characterRangeForRect:(NSRect)aRect
{
	NSRange glyphRange, charRange;
	NSLayoutManager *layoutManager = [self layoutManager];
	NSTextContainer *textContainer = [self textContainer];
	NSPoint containerOrigin = [self textContainerOrigin];
	
	// Convert from view coordinates to container coordinates
	aRect = NSOffsetRect(aRect, -containerOrigin.x, -containerOrigin.y);
	
	glyphRange = [layoutManager glyphRangeForBoundingRect:aRect inTextContainer:textContainer];
	charRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
	
	if (![[self textStorage] length])
	{
		charRange = NSMakeRange(0, 0);
	}
	
	return charRange;
}

//	method swizzler is in ApplicationDelegate.m
//	why swizzle here? I'm trying to see how long I can go before having to subclass NSTextView which would have otherwise been needed here ;-) 30 AUG 08 JH
- (void) setBackgroundColorSwizzle: (NSColor *)color
{
	[self setBackgroundColorSwizzle:color];
	//do this, otherwise uncovered scrollView background is white while textView background has color
	id doc = [[[self window] windowController] document];
	//	currentDocument can return nil!
	//id doc = [[NSDocumentController sharedDocumentController] currentDocument];
	id scrollView = [self enclosingScrollView];
	if ([scrollView isKindOfClass:[JHScrollView class]] && ![doc hasMultiplePages])
	{
		[scrollView setBackgroundColor:color];
		[scrollView setNeedsDisplay:YES];
		//	using altColors also calls this method to set backgroundColor, so tell doc that background color it tracks has changed only if no altColors in use
		if (doc && ![doc shouldUseAltTextColors])
		{
			[doc setTheBackgroundColor:color];
		}
	}
}

//color panel's changeColor msg is treated differently depending if option key is down 11 Oct 08 JH
-(void) changeColorSwizzle:(id)sender;
{
	//BOOL optionDown = ((GetCurrentKeyModifiers() & (optionKey | rightOptionKey)) != 0) ? YES : NO;
	//this is more complex, but is fully cocoa!
	BOOL optionDown = [(JHScrollView *)[self enclosingScrollView] isOptionKeyDown];
	BOOL shiftDown = [(JHScrollView *)[self enclosingScrollView] isShiftKeyDown];
	
	//BUGFIX 2 JAN 09 JH : using Option key to type special characters (ex: Opt+8=bullet) in colored text would cause foreground and background color to change (changing selection would update color picker, which would in turn send changeColor msg back to textView, changing background color because option key was down (which is meant to trigger text background color [highlight] in Bean!)
	if (optionDown && [[NSApp currentEvent] type]==NSKeyDown) 
	{
		dontChangeBackgroundColor = YES;
	}

	//intent is to change text background color ('highlighting')
	if (optionDown && shiftDown && ! dontChangeBackgroundColor)
	{
		id doc = [[[self window] windowController] document];
		id textStorage = [self textStorage];
		NSColor *color = (NSColor *)[sender color];
		NSEnumerator *e = [[self selectedRanges] objectEnumerator];
		NSValue *theRangeValue;
		//setup undo
		if ([self shouldChangeTextInRanges:[self selectedRanges] replacementStrings:nil])
		{
			[textStorage beginEditing];
			//	for selected ranges...
			while (theRangeValue = [e nextObject])
			{
				//	adjust text HIGHLIGHTING based on tag of menuItem
				[textStorage addAttribute:NSBackgroundColorAttributeName value:color range:[theRangeValue rangeValue]];
				//	also set the typing attributes, in case no text yet, or end of string text
				NSDictionary *theAttributes = [self typingAttributes];
				NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
				[theTypingAttributes setObject:color forKey:NSBackgroundColorAttributeName];
				[self setTypingAttributes:theTypingAttributes];
			}
			[textStorage endEditing];
			//	end undo
			[self didChangeText];
			//	name undo for menu
			[[doc undoManager] setActionName:NSLocalizedString(@"Highlighting", @"undo action: Highlighting")];
		}
	}
	//do usual thing
	else
	{
		[self changeColorSwizzle:sender];
	}
	
	dontChangeBackgroundColor = NO;
}

-(void)showFindIndicatorForRangeValue:(id)range
{
	[self showFindIndicatorForRange:[range rangeValue]]; 
}

-(void)indicateCursorIndex
{
	//BUGFIX 5 JAN 09 JH respondsToSelector returning YES for 10.5 only method in a category on Tiger...why?
	SInt32 systemVersion;
	//=Tiger
	if (Gestalt(gestaltSystemVersion, &systemVersion) == noErr && !(systemVersion < 0x1050));
	{
		NSRange range = [self selectedRange];
		if (range.length < 1) range.length = 1;
		//don't indicate if range.length is less than 10 chars -- looks weird otherwise 10 JAN 09 JH
		if ([self respondsToSelector:@selector(showFindIndicatorForRange:)] && range.length < 10)
		{
			//needs a slight delay or else gets lost
			[self performSelector:@selector(showFindIndicatorForRangeValue:) withObject:[NSValue valueWithRange:range] afterDelay:.25];
		}
	}
}

//allows us to alter text as it's coming in from the keyboard
//	this avoids ambiguity as to source of text (typed? pasted? find & replaced?)
//	it also allows us to alter text without messing up the undo mechanism
//	the only other place this was really possible was textStorageWillProcessEditing, but altering the textStorage there didn't feel clean
-(void)insertTextSwizzle:(id)aString
{
	id doc = [[[self window] windowController] document];
	//note: could make insertedTextNeedsExtraProcessing into a generic method to check for need for other types of processing
	//	e.g., would return 0 for no processing needed; integers for different types of processing needed
	if ([doc alternateFontActive] && [doc insertedTextNeedsExtraProcessing])
		[doc beginNoteWithString:aString];
	else
		[self insertTextSwizzle:aString];
}

//called from textView's context menu
-(void)printTextViewSelection
{
	[[NSDocumentController sharedDocumentController] printSelection:nil];
}

//add items to text view's context menu to insert tab, paragraph break ,etc.; also Print (Text) Selection
- (NSMenu *)menu
{
	// we want to add items, not to default menu but to autoreleased copy
	// seems that menu originates from NSText.m or above, since we can call [super menu] and still get menu
	NSMenu *contextMenu = [[[super menu] copy] autorelease];
	
	//if textView is not in a JHDocument class window or JHFindPanel, return default menu
	//example: click add collection button in Font Panel uses field editor...but don't want insert menu there!
	if (![[self window] isKindOfClass:[JHWindow class]] && ![[self window] isKindOfClass:[JHFindPanel class]])
		return contextMenu;
	
	// add our own separator to keep our custom menu separate
	NSMenuItem *separator =  [NSMenuItem separatorItem];
	[contextMenu addItem:separator];

	//create a menu to become insert item's submenu, containing various insert character actions
	//okay for textView's and fieldEditors!
	NSMenu *insertMenu = [[[NSMenu alloc] init] autorelease];

	//move validation here, because substitutions > item state checkmark fails to show if validateMenuItem is used (bug?)
	//ie, enable for doc != readOnly
	//BOOL tvEditable = [self isEditable];

	NSMenuItem *tab=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"menu item (in context menu): Tab", @"") action:@selector(insertSpecial:) keyEquivalent:@""] autorelease];
	[tab setTag:0];
	[insertMenu addItem:tab];

	NSMenuItem *para=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"menu item (in context menu): Paragraph Break", @"") action:@selector(insertSpecial:) keyEquivalent:@""] autorelease];
	[para setTag:1];
	[insertMenu addItem:para];

	NSMenuItem *page=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"menu item (in context menu): Page/Column Break", @"") action:@selector(insertSpecial:) keyEquivalent:@""] autorelease];
	[page setTag:2];
	[insertMenu addItem:page];

	NSMenuItem *line=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"menu item (in context menu): Line Break", @"") action:@selector(insertSpecial:) keyEquivalent:@""] autorelease];
	[line setTag:3];
	[insertMenu addItem:line];

	NSMenuItem *nonbreakingSpace=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"menu item (in context menu): Non-breaking Space", @"") action:@selector(insertSpecial:) keyEquivalent:@""] autorelease];
	[nonbreakingSpace setTag:4];
	[insertMenu addItem:nonbreakingSpace];

	// attach insert character submenu to 'Insert' item
	NSMenuItem *insertItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"menu item (in context menu): Insert", @"") action:nil keyEquivalent:@""] autorelease];
	[contextMenu addItem:insertItem];
	[contextMenu setSubmenu:insertMenu forItem:insertItem];
		
	//if textView is not in a JHDocument class window, don't add Print Selection item, but just return what we've done so far
	if (![[self window] isKindOfClass:[JHWindow class]])
		return contextMenu;
		
	// add item to call print selection method above (which calls method in document controller)
	[contextMenu
			addItemWithTitle:NSLocalizedString(@"text view context menu item: Print Selection...", @"") 
			action:@selector(printTextViewSelection)
			keyEquivalent:@""];
	//return our modified menu
	return contextMenu;
}

- (BOOL)validateMenuItemSwizzle:(NSMenuItem *)userInterfaceItem
{
	SEL action = [userInterfaceItem action];
	if (action == @selector(insertSpecial:))
		//ie, enable for doc != readOnly
		return [self isEditable];
	if (action == @selector(printTextViewSelection))
		//at least one doc is open and at least one character is selected
		return ([self selectedRange].length);
	//call object's imp, or else substitution > menu items don't validate for state
	return [self validateMenuItemSwizzle:userInterfaceItem];
}

//character to insert is determined by menu item tag
-(IBAction)insertSpecial:(id)sender
{
	NSString *s = nil;
	switch ([sender tag])
	{
		//tab
		case 0:
		{
			s = [NSString stringWithFormat:@"%C", NSTabCharacter];
			break;
		}
		//paragraph break
		case 1:
		{
			s = [NSString stringWithFormat:@"%C", NSNewlineCharacter];
			break;
		}
		//page break
		case 2:
		{
			s = [NSString stringWithFormat:@"%C", NSFormFeedCharacter];
			break;
		}
		//line break
		case 3:
		{
			s = [NSString stringWithFormat:@"%C", NSLineSeparatorCharacter];
			break;
		}
		//non-breaking space
		case 4:
		{
			s = [NSString stringWithFormat:@"%C", 0x00A0];
			break;
		}
		default:
		{
			break;
		}
	}
	//get textStorage for textView or fieldEditor of textField
	id ts = [self textStorage];
	
	//get text insertion point
	NSRange insertionRange = {0,0};
	//is textField and is at end if findTextField just got focus (and so selectText got called)
	if ([self selectedRange].length == [ts length] && [self isFieldEditor])
		insertionRange = NSMakeRange([ts length], 0);
	else
		//else at insertion point if editing textView/textField
		insertionRange = [self selectedRange];
	
	//for undo
	if ([self shouldChangeTextInRange:insertionRange replacementString:s])
	{
		//insert the pattern
		[ts replaceCharactersInRange:insertionRange withString:s];
		
		[self didChangeText];
	}
}

//alternative to disabling List Marker... menu item when find panel has focus (cause List sheet will show on Find panel)
- (void)orderFrontListPanelSwizzle:(id)sender
{
	if ([self isFieldEditor]){
		if ([[NSDocumentController sharedDocumentController] currentDocument]){
			[[[[NSDocumentController sharedDocumentController] currentDocument] firstTextView] orderFrontListPanelSwizzle:sender];
		}
	}else{
		[self orderFrontListPanelSwizzle:nil];
	}
}

/* 
//debugging
-(void)_scrollRangeToVisible:(NSRange)aRange forceCenter:(BOOL)flag
{
	return;
}
*/

@end
