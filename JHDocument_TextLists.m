/*
	JHDocument_TextLists.m
	Bean
		
	revised March 2009
	
	goal: add some sorely missing action methods to text lists
	note: almost no API for NSTextLists, so we end up using Cocoa almost as a scripting language to trigger enumeration refresh, etc.
	
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
 
#import "JHDocument_TextLists.h"
#import "RegExKitLite.h" //for regexp
#import "GLOperatingSystemVersion.h"

@interface NSTextView(Private)
//get rid of compiler error (for NSTexteView private API)
-(void)_reformListAtIndex:(int)idx;
@end

//	category for methods affecting groups of NSTextList objects
@implementation JHDocument ( JHDocument_TextLists )

#pragma mark -
#pragma mark ---- TextList Methods ----

// ******************* Text List Methods *******************

//	indents selected textlist item(s) (ie, paragraphs) when tab is pressed and insertion point is anywhere within first item
//	note: we override std Cocoa behavior, which is to insert a tab when tab pressed, instead indenting list item
//	see textView:doCommandBySelector in JHDocument_TextSystemDelegate.m for override of insertTab: which calls this method
- (IBAction)listItemIndent:(id)sender
{
	//usual cocoa behavior is this:
	//	1. insert simple text tab (*not* list indention) if insertion point is in list item *after* \t*\t marker
	//	2. if cursor is inside list marker, list item(s) are indented and re-enumerated
	//	3. [Leopard only!] if selection(s) exist, list item(s) are indented and re-enumerated
	//
	//here, we use action 2. for Tiger and action 3. for Leopard, restoring selected range after tab/indent
	//	so, pressing tab always indents list item(s)
	//	note: ctrl+opt+tab retains the old behavior (that is, inserts text tab into middle of textList item)

	NSTextView *tv = [self firstTextView];
	NSRange selRng = [tv selectedRange];
	
	SInt32 systemVersion;
	//=Tiger?
	if ([GLOperatingSystemVersion isBeforeLeopard])
	{
		//Tiger behavior: tab on selection does not promote list item, but rather inserts tab
		//	remember paragraph range
		NSRange paragraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(selRng.location, 0)];
		//	causes indent of textList item only
		[tv moveToBeginningOfParagraph:sender];
		[tv insertTab:sender];
		//	since previous insertion point might have changed, we recalculate it
		//	for instance: "9." could become "10.", so selRng would be off
		NSRange newParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange([tv selectedRange].location, 0)];
		int indexChange = newParagraphRange.length - paragraphRange.length; 
		//	restore selected range
		[tv setSelectedRange:NSMakeRange(selRng.location + indexChange, selRng.length)];
	}
	//Leopard +
	else
	{
		BOOL rangeWasChanged = NO;
		//Leopard behavior: tab on selection promotes list item
		//increase selection length so indention of text list item occurs (otherwise a text tab would be inserted)
		//bounds check in case this method is called programmatically
		NSDictionary *theAttributes = nil;
		if (selRng.length==0 && NSMaxRange(selRng) < [textStorage length])
		{
			//		if ([[textStorage string] characterAtIndex:selRng.location] != NSTabCharacter
			//					&& [[textStorage string] characterAtIndex:NSMaxRange(selRng)] != NSNewlineCharacter)
			if ([[textStorage string] characterAtIndex:selRng.location] != NSTabCharacter)
			{
				//BUGFIX: change in selection causes change in typingAttributes; we cache them and restore them 22 MAY 09 BH
				//	ex: apply bold to typing attributes, indent list item, bold typing attribute is gone)
				theAttributes = [tv typingAttributes];
				[tv setSelectedRange: NSMakeRange(selRng.location, selRng.length + 1)];
				rangeWasChanged = YES;
			}
		}
		//action indention
		[tv insertTab:sender];
		//restore range *only* if needed (might not be needed; insertion point is sometimes moved just after list marker)
		//note: cocoa usually restores insertion point even if marker changes length
		if (rangeWasChanged && [tv selectedRange].length > 0)
		{
			[tv setSelectedRange:NSMakeRange([tv selectedRange].location,[tv selectedRange].length - 1)];
			if (theAttributes) [tv setTypingAttributes:theAttributes];
		}	
	}
}

- (IBAction)listItemUnindent:(id)sender
{
	[[self firstTextView] insertBacktab:nil];
}

//	move list item toward top of list by one item
//	NOTE: works only on [[tv selectedRanges] itemAtIndex:0]
//	TODO: to move multiple selected list items with different indent levels north and south in list at the same time, you would have to copy each list item's (ie, paragraph's) marker style and paragraphStyle and reapply them after moving them; might be helpful to reestablish selectedRanges as well
//	NOTE: lists which skip a hierarchy of indents seem to be orphaned and won't update, even when they should
- (IBAction)moveListItemNorth:(id)sender
{
	isEditingList=YES;

	//GET INFO NEEDED TO MOVE LIST ITEMS
	
	NSTextView *tv = [self firstTextView];
	NSRange originalSelectedRange = [tv selectedRange];
	//	note range of paragraph(s) in selection (or containing selectedRange.location) to move and its marker
	NSRange originalParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(originalSelectedRange.location, 0)];
	//	we use this later to see if marker length changes
	NSRange originalMarkerRange = [[textStorage string] rangeOfRegex:@"\t.*\t" options:RKLCaseless inRange:originalParagraphRange capture:0 error:NULL];
	//	does list item end with newline? (might not if at end of file; if no newline, will have to add one later)
	BOOL hasNewline = ([[textStorage string] characterAtIndex:NSMaxRange(originalParagraphRange) - 1] == NSNewlineCharacter);
	//	note current paragraphStyle (for indent level, that is, textLists)
	NSParagraphStyle *pStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:originalParagraphRange.location effectiveRange:NULL];
	//	note range of preceding paragraph
	NSRange prevParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(originalParagraphRange.location - 1, 0)];	
		
	//MOVE LIST ITEMS NORTH using responder macros
	
	//	select current paragraph(s)
	[tv setSelectedRange:NSMakeRange(originalParagraphRange.location, 1)];
	[tv selectParagraph:nil];
	[tv cut:nil];
	//	paste the cut list item(s) before previous item
	[tv setSelectedRange:NSMakeRange(prevParagraphRange.location, 0)];
	[tv paste:nil];
		
	//	no newline at pasted text (probably was very last text in file), so add a newline
	if (!hasNewline)
		[tv insertNewline:nil];

	//REAPPLY TEST LIST, INSERTION POINT, RE-ENUMERATE

	//	re-apply paragraphStyle (because list item forgets indent level -- ie, textLists -- after being pasted)
	NSRange newParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(prevParagraphRange.location, 0)];
	if (pStyle)
		[textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:NSMakeRange(newParagraphRange.location, 1)];
	
	//	restore insertion point location (accounting for possible changed length of marker)
	NSRange newMarkerRange = [[textStorage string]rangeOfRegex:@"\t.*\t" options:RKLCaseless inRange:newParagraphRange capture:0 error:NULL];
	if (newMarkerRange.location != NSNotFound)
	{
		int loc = originalSelectedRange.location - originalParagraphRange.location - originalMarkerRange.length + newMarkerRange.length + newParagraphRange.location;
		NSRange oldSelectionRange = NSMakeRange(loc, 0);
		if (loc < [textStorage length])
			[tv setSelectedRange:oldSelectionRange];
		//shouldn't happen
		else
			[tv setSelectedRange:NSMakeRange(NSMaxRange(newMarkerRange),0)];
	}
	//	hack to force list re-enumeration
	[self listItemIndent:nil];
	[self listItemUnindent:nil];
	
	isEditingList=NO;
}

//	move list item toward bottom of list by one item
- (IBAction)moveListItemSouth:(id)sender
{
	isEditingList=YES;

	//NOTE INFO NEEDED TO MOVE LIST ITEMS

	NSTextView *tv = [self firstTextView];
	NSRange originalSelectedRange = [tv selectedRange];
	//	note range of paragraph(s) in selection (or containing selectedRange.location) to move and its marker
	NSRange originalParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(originalSelectedRange.location, 0)];
	//	we use this later to see if marker length changes
	NSRange originalMarkerRange = [[textStorage string] rangeOfRegex:@"\t.*\t" options:RKLCaseless inRange:originalParagraphRange capture:0 error:NULL];
	//	note current paragraphStyle (for indent level, that is, textLists)
	NSParagraphStyle *pStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:originalParagraphRange.location effectiveRange:NULL];
	//	remember next paragraphRange
	NSRange followingParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(originalParagraphRange.location + originalParagraphRange.length, 0)];
	//	does following paragraph range end with newline? (might not if at end of file; will have to add one later)
	BOOL hasNewline = ([[textStorage string] characterAtIndex:NSMaxRange(followingParagraphRange) - 1] == NSNewlineCharacter);
	
	//MOVE LIST ITEMS SOUTH using responder macros

	//	select current paragraph(s)
	[tv setSelectedRange:NSMakeRange(originalParagraphRange.location, 1)];
	[tv selectParagraph:nil];
	[tv cut:nil];
	//	paste the cut list item(s)
	[tv setSelectedRange:NSMakeRange(originalParagraphRange.location + followingParagraphRange.length, 0)];
	[tv paste:nil];
	
	//	if pasting item after another item which is not followed by the newline char, insert new line char
	if (!hasNewline)
	{
		[tv setSelectedRange:NSMakeRange(originalParagraphRange.location + followingParagraphRange.length, 0)];
		[tv insertNewline:nil];
	}
	//	note range of moved items
	NSRange northParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(originalParagraphRange.location, 0)];
	NSRange newParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(NSMaxRange(northParagraphRange), 0)];

	//REAPPLY TEST LIST, INSERTION POINT, RE-ENUMERATE

	//	re-apply paragraphStyle (because list item forgets indent level -- ie, textLists -- after being pasted)
	if (pStyle)
		[textStorage addAttribute:NSParagraphStyleAttributeName value:pStyle range:NSMakeRange(newParagraphRange.location, 1)];

	//	restore insertion point location (accounting for possible changed length of marker)
	NSRange newMarkerRange = [[textStorage string]rangeOfRegex:@"\t.*\t" options:RKLCaseless inRange:newParagraphRange capture:0 error:NULL];
	if (newMarkerRange.location != NSNotFound)
	{
		int loc = originalSelectedRange.location - originalParagraphRange.location - originalMarkerRange.length + newMarkerRange.length + newParagraphRange.location;
		NSRange oldSelectionRange = NSMakeRange(loc, 0);
		if (loc < [textStorage length])
			[tv setSelectedRange:oldSelectionRange];
		//shouldn't happen
		else
			[tv setSelectedRange:NSMakeRange(NSMaxRange(newMarkerRange),0)];	
	}
	//	hack to force list re-enumeration
	[self listItemIndent:nil];
	[self listItemUnindent:nil];
	
	isEditingList=NO;
}


//	turn text paragraph(s) into text list items with specified markers without user going through 'List Marker' panel
//	TODO: file enhancement request with Apple for API like this...native sheet is confusing and there is no easy way to avoid it
//	NOTE: works only on [[tv selectedRanges] itemAtIndex:0]; native list sheet works on selectedRanges, but I can't duplicate that
- (IBAction)specialTextListAction:(id)sender
{
	//note: there is now some better code at cocoadev.com / NSTextList for creating a text list ex nihilo; we know this hack below works tho

	isEditingList=YES;
	id tv = [self firstTextView];

	//create the text list item
	NSTextList *theList = nil;
	//	sender determines what kind of marker
	if ([sender tag]==0) //bullet
		theList = [[[NSTextList alloc] initWithMarkerFormat:@"{disc}" options:0] autorelease];
	else if ([sender tag]==1) //arabic number and dot
		theList = [[[NSTextList alloc] initWithMarkerFormat:@"{decimal}." options:0] autorelease];
	NSArray *theListArray = [NSArray arrayWithObjects:theList, nil];
	
	//note to self: MLA style outline; you have to initially create a heavily indented list item to even begin a list like this
	//WISHLIST: it'd be great to have an rtf list style encapsulating this info to create lists from automatically
	/*
	 NSTextList *urList = [[[NSTextList alloc] initWithMarkerFormat:@"{upper-roman}." options:nil] autorelease];
	 NSTextList *uaList = [[[NSTextList alloc] initWithMarkerFormat:@"{upper-alpha}." options:nil] autorelease];
	 NSTextList *decList = [[[NSTextList alloc] initWithMarkerFormat:@"{decimal}." options:nil] autorelease];
	 NSTextList *laList = [[[NSTextList alloc] initWithMarkerFormat:@"{lower-alpha}." options:nil] autorelease];
	 NSTextList *dec2List = [[[NSTextList alloc] initWithMarkerFormat:@"({decimal})" options:nil] autorelease];
	 NSTextList *la2List = [[[NSTextList alloc] initWithMarkerFormat:@"({lower-alpha})" options:nil] autorelease];
	//an array of marker types, forming an MLA-style outline
	 NSArray *theListArray = [NSArray arrayWithObjects:urList, uaList, decList, laList, dec2List, la2List, urList, nil];
	 */
	
	//	set up two standard tabStops for the list items
	float pointsPerUnit = [self pointsPerUnitAccessor];
	//if inches, use Snow Leopard's .39 tab interval (where did they get that?), else use cm's
	float tabInterval = (pointsPerUnit > 30) ? pointsPerUnit * .39 : pointsPerUnit; //every cm or .5 inch
	//copied from snow leopard's text list items
	float tabValue1 = .39 * tabInterval;
	float tabValue2 = 1.27 * tabInterval;
	NSTextTab *tabStop1;
	NSTextTab *tabStop2;
	tabStop1 = [[[NSTextTab alloc] initWithType:NSLeftTabStopType location:tabValue1] autorelease]; 
	tabStop2 = [[[NSTextTab alloc] initWithType:NSLeftTabStopType location:tabValue2] autorelease]; 
	
	//used later
	NSRange origSelRng = [tv selectedRange], theCurrentRange, theCurrentParagraphRange;

	//	if no text, supply some (otherwise, failure); use attributedString to avoid Cocoa defaults (Helvetica 12)
	if (origSelRng.length < 1)
	{
		NSDictionary *attrs = [tv typingAttributes];
		NSAttributedString *dummyString = [[[NSAttributedString alloc] initWithString:@"itm" attributes:attrs] autorelease];
		if ([tv shouldChangeTextInRange:NSMakeRange(origSelRng.location, 0) replacementString:@"itm"])
		{
			[textStorage insertAttributedString:dummyString atIndex:origSelRng.location];
			[tv didChangeText];
		}
		[tv setSelectedRange:NSMakeRange(origSelRng.location, 2)];
	}
	
	//	apply text list properties to create a list
	unsigned paragraphNumber;
	//	an array of NSRanges containing applicable (possibly grouped) whole paragraph boundaries
	//	ie, every paragraph the text selection touches
	NSArray *theRangesForChange = [tv rangesForUserParagraphAttributeChange];
	//	figure effected range for undo
	int undoRangeIndex = [tv rangeForUserParagraphAttributeChange].location;
	int undoRangeLength = [[theRangesForChange objectAtIndex:([theRangesForChange count] - 1)] rangeValue].location
		+ [[theRangesForChange objectAtIndex:([theRangesForChange count] - 1)] rangeValue].length - undoRangeIndex;
	//	setup undo
	if ([tv shouldChangeTextInRange:NSMakeRange(undoRangeIndex,undoRangeLength) replacementString:nil])
	{
		[textStorage beginEditing]; //bracket for efficiency
		//	iterate through ranges of groups of paragraph
		for (paragraphNumber = 0; paragraphNumber < [theRangesForChange count]; paragraphNumber++)
		{
			theCurrentRange = [[theRangesForChange objectAtIndex:paragraphNumber] rangeValue];
			theCurrentParagraphRange = theCurrentRange;
			//	now, iterate paragraphs in each range, applying list attributes 
			while (theCurrentParagraphRange.location < NSMaxRange(theCurrentRange))
			{
				//	get actual paragraph range
				theCurrentParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(theCurrentParagraphRange.location, 1)];
				//	get the paragraphStyle
				NSMutableParagraphStyle *theParagraphStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:theCurrentParagraphRange.location effectiveRange:NULL];
				if (theParagraphStyle==nil)
					//theParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
					//26 MAY 09 JH use typingAttributes to avoid Helvetica 12 (cocoa default)
					theParagraphStyle = [[[[tv typingAttributes] objectForKey:NSParagraphStyleAttributeName] mutableCopy] autorelease];
				else
					theParagraphStyle = [[theParagraphStyle mutableCopyWithZone:[tv zone]]autorelease];
				//	remove all tabStops from textList items, then add std list tab stops
				[theParagraphStyle setTabStops:[NSArray arrayWithObjects:nil]];
				[theParagraphStyle setFirstLineHeadIndent:0.0];
				//so text of list item indents properly after wrap
				[theParagraphStyle setHeadIndent:tabValue2];
				[theParagraphStyle addTabStop:tabStop1];
				[theParagraphStyle addTabStop:tabStop2];
				//so text moves on to next tab when marker spills over, instead of dropping a line 
				int cnt;
				for (cnt = 1; cnt < 12; cnt++) {	// Add 12 tab stops, at desired intervals...
					NSTextTab *tabStop = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:tabInterval * (cnt + 1)];
					[theParagraphStyle addTabStop:tabStop];
					[tabStop release];
				}
				//	add text list attribute to the current paragraphStyle
				[theParagraphStyle setTextLists:theListArray];
				//	add the paragraphStyle attribute to the current paragraph in textStorage
				[textStorage addAttribute:NSParagraphStyleAttributeName value:theParagraphStyle range:theCurrentParagraphRange];
				//	make index the first letter of the next paragraph
				theCurrentParagraphRange = NSMakeRange(NSMaxRange(theCurrentParagraphRange),1);
			}
		}
		[textStorage endEditing]; //close bracket
		//end undo
		[tv didChangeText];
	}
	//name undo action, based on tag of control
	[[self undoManager] setActionName:@"List"];
		
	//	this monkey business (cut and paste) appers to be necessary to actually get the textList to display!
	if (origSelRng.length < 2) [tv setSelectedRange:NSMakeRange(origSelRng.location, 2)]; // need to paste at least 2 chars
	else [tv setSelectedRange:NSMakeRange(origSelRng.location, origSelRng.length - 1)];
	
	//	hack: cut and paste causes list markers to show up
	[tv cut:nil];
	//	typing attributes are incidentally set here
	[tv paste:nil];
	
	//	restore insertion point
	if (origSelRng.length < 1)
	{
		NSRange itemRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(origSelRng.location, 1)];
		NSRange dummyItemRange = [[textStorage string] rangeOfRegex:@"itm" options:RKLCaseless inRange:itemRange capture:0 error:NULL];
		//	delete dummy text
		if ([tv shouldChangeTextInRange:dummyItemRange replacementString:@""])
		{
			[textStorage deleteCharactersInRange:dummyItemRange];
			[tv didChangeText];
		}
		[tv setSelectedRange:NSMakeRange(dummyItemRange.location, 0)];
	}
	else
	{
		//	restore insertion point to just after marker text
		id str = [textStorage string];
		// 19 MAY 09 JH original code here made no sense
		NSRange itemRange = [str paragraphRangeForRange:NSMakeRange(origSelRng.location, 1)];
		NSRange markerRange = [str rangeOfRegex:@"\t.*\t" options:RKLCaseless inRange:itemRange capture:0 error:NULL];
		if (markerRange.location != NSNotFound)
			[tv setSelectedRange:NSMakeRange(NSMaxRange(markerRange), 0)];
	}
	isEditingList=NO;
}

//calls private API function, which is a no-no; triggers re-enumeration of lists
-(void)bean_reformListAtIndex:(int)idx
{
	id tv = [self firstTextView];
	if ([tv respondsToSelector:@selector(_reformListAtIndex:)]) 
		[tv _reformListAtIndex:idx];
}

//hack to cause lists to redo their markers
//BUG: creates undo item
-(void)refreshListEnumeration
{
	//NSLog(@"REFRESH LIST ENUMERATION");
	[self listItemIndent:nil];
	[self listItemUnindent:nil];
}

@end
