/*
	TabStopManager.m
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

#import "TabStopManager.h"
#import "JHDocument.h"

@implementation TabStopManager

#pragma mark -
#pragma mark ---- Init, Dealloc ----

- (void)dealloc
{
	if (document) [document release];
	[super dealloc];
}

#pragma mark -
#pragma mark ---- Add Aligned Tabstop Methods ----

// ******************* Add Aligned Tabstop Methods *******************

//	insert aligned tab stop at specified position in ruler
-(IBAction)showSheet:(id)sender
{
	//sender is control calling action, not doc
	id doc = sender;
	id docWindow = [doc docWindow];
	
	[self setDocument:doc];
	
	
	//tabStopPanel behavior in nib = [x] release self when closed, so we don't need: [tabStopPanel release];
	if(tabStopPanel== nil) { [NSBundle loadNibNamed:@"TabStopSheet" owner:self]; }
	if(tabStopPanel== nil)
	{ 
		NSLog(@"Could not load TabStopSheet.nib.");
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}
	
	//load localization strings
	[okButton setTitle:NSLocalizedString(@"button: OK", @"")];
	[cancelButton setTitle:NSLocalizedString(@"button: Cancel", @"")];
	[shouldRemoveTabStopsButton setTitle:NSLocalizedString(@"button: Remove other tab stops in selection", @"")];
	[tabTypeLabel setObjectValue:NSLocalizedString(@"label: Tab alignment type:",@"")];
	[tabLocationLabel setObjectValue:NSLocalizedString(@"label: Input tab location:",@"")];
	[[tabStopAlignmentButton itemAtIndex:0] setTitle:NSLocalizedString(@"button: Left Tab Stop", @"")];
	[[tabStopAlignmentButton itemAtIndex:1] setTitle:NSLocalizedString(@"button: Center Tab Stop", @"")];
	[[tabStopAlignmentButton itemAtIndex:2] setTitle:NSLocalizedString(@"button: Right Tab Stop", @"")];
	[[tabStopAlignmentButton itemAtIndex:3] setTitle:NSLocalizedString(@"button: Decimal Tab Stop", @"")];
	
	//setup a label
	if ([doc pointsPerUnitAccessor] > 30.0) 
	{
		[tabStopValueLabel setObjectValue:NSLocalizedString(@"(Inches from left margin)", @"(Inches from left margin)")];
	}
	else
	{
		[tabStopValueLabel setObjectValue:NSLocalizedString(@"(Centimeters from left margin)", @"(Centimeters from left margin)")];	
	}
	
	[removeTabStopsButton setState:NSOffState];
	[NSApp beginSheet:tabStopPanel modalForWindow:docWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];
	[tabStopPanel orderFront:sender];
}


-(IBAction)addTabStopAction:(id)sender
{
	id doc = [self document];
	id pInfo = [doc printInfo];
	id ts = [doc textStorage];
	id tv = [doc firstTextView];
	
	//	if user supplied values out of bounds, reset the value and let them try again
	if (([tabStopValueField floatValue] <.1 && [removeTabStopsButton state]==NSOffState)
		|| [tabStopValueField floatValue] > ([pInfo paperSize].width - [pInfo leftMargin] - [pInfo rightMargin]))
	{
		[tabStopValueField setObjectValue:@"0.00"];
		[tabStopValueField selectText:nil];
		return;
	}
	//	values were OK, so dismiss the sheet
	[NSApp endSheet:tabStopPanel];
	[tabStopPanel orderOut:sender];
	
	//	set up a NSTextTab based on user supplied information 
	float pointsPerUnit = [doc pointsPerUnitAccessor];
	float theTabValue = [tabStopValueField floatValue] * pointsPerUnit;  // Every cm or half inch
	NSTextTab *tabStop = nil;
	int theAlignmentType = [[tabStopAlignmentButton cell] tag];
	
	if (theAlignmentType==1) {
		tabStop = [[[NSTextTab alloc] initWithType:NSLeftTabStopType location:theTabValue] autorelease]; 
	} else if (theAlignmentType==2) {
		tabStop = [[[NSTextTab alloc] initWithType:NSCenterTabStopType location:theTabValue] autorelease]; 
	} else if (theAlignmentType==3) {
		tabStop = [[[NSTextTab alloc] initWithType:NSRightTabStopType location:theTabValue] autorelease]; 
	} else if (theAlignmentType==4) {
		tabStop = [[[NSTextTab alloc] initWithType:NSDecimalTabStopType location:theTabValue] autorelease]; 
	}
	unsigned paragraphNumber;
	//	an array of NSRanges containing applicable (possibly grouped) whole paragraph boundaries
	NSArray *theRangesForChange = [tv rangesForUserParagraphAttributeChange];
	//	a range containing one or more paragraphs
	NSRange theCurrentRange;
	//	a range containing the paragraph of interest 
	NSRange theCurrentParagraphRange;
	//	figure effected range for undo
	int undoRangeIndex = [tv rangeForUserParagraphAttributeChange].location;
	int undoRangeLength = [[theRangesForChange objectAtIndex:([theRangesForChange count] - 1)] rangeValue].location
	+ [[theRangesForChange objectAtIndex:([theRangesForChange count] - 1)] rangeValue].length - undoRangeIndex;
	//	start undo setup
	if ([tv shouldChangeTextInRange:NSMakeRange(undoRangeIndex,undoRangeLength) replacementString:nil])
	{
		// changed backeting 6 SEPT 08 JH 
		[ts beginEditing]; //bracket for efficiency
		//	iterate through ranges of paragraph groupings
		for (paragraphNumber = 0; paragraphNumber < [theRangesForChange count]; paragraphNumber++) 
		{
			//	set range for first (or only) paragraph; index is needed to locate paragraph; length is not important
			//	note: function rangesForUserPargraphAttributeChange returns NSValues (objects), so we use rangeValue to get NSRange value
			theCurrentParagraphRange = [[theRangesForChange objectAtIndex:paragraphNumber] rangeValue];
			theCurrentRange = [[theRangesForChange objectAtIndex:paragraphNumber] rangeValue];
			//now, step thru theCurrentRange paragraph by paragraph
			while (theCurrentParagraphRange.location < (theCurrentRange.location + theCurrentRange.length))
			{
				//get the actual paragraph range including length
				theCurrentParagraphRange = [[ts string] paragraphRangeForRange:NSMakeRange(theCurrentParagraphRange.location, 1)];
				//get the paragraphStyle
				NSMutableParagraphStyle *theParagraphStyle = [ts attribute:NSParagraphStyleAttributeName atIndex:theCurrentParagraphRange.location effectiveRange:NULL];
				if (theParagraphStyle==nil)
				{
					theParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
				}
				else
				{
					theParagraphStyle = [[theParagraphStyle mutableCopyWithZone:[tv zone]]autorelease];
				}
				
				//	add tabStop to the current paragraphStyle
				
				//	remove all tabStops for paragraph if user requests
				//	NOTE: this can screw up textLists, which need at least two tabs for each line item
				if ([removeTabStopsButton state]) [theParagraphStyle setTabStops:[NSArray arrayWithObjects:nil]];
				//	add new tabStop to paragraph
				if ([tabStopValueField floatValue] > 0) [theParagraphStyle addTabStop:tabStop];
				
				//	add the paragraphStyle attribute to the current paragraph in textStorage
				[ts addAttribute:NSParagraphStyleAttributeName value:theParagraphStyle range:theCurrentParagraphRange];
				
				//	make index (=location) the first letter of the next paragraph
				theCurrentParagraphRange = NSMakeRange((theCurrentParagraphRange.location + theCurrentParagraphRange.length),1);

				//	add style to the current typingAttributes
				NSDictionary *theAttributes = [tv typingAttributes];
				NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
				[theTypingAttributes setObject:theParagraphStyle forKey:NSParagraphStyleAttributeName];
				[tv setTypingAttributes:theTypingAttributes];
				
				NSArray *theMarkers = [[tv layoutManager]
									   rulerMarkersForTextView:tv 
									   paragraphStyle:theParagraphStyle ruler:[[doc theScrollView] horizontalRulerView]];
				[[[doc theScrollView] horizontalRulerView] setMarkers:theMarkers];
				[[doc theScrollView] setRulersVisible:YES];
			}
		}
		[ts endEditing]; //	close bracket
	}
	//	end undo setup
	[tv didChangeText];
	//	name undo action, based on tag of control
	[[doc undoManager] setActionName:NSLocalizedString(@"Tab Stop", @"undo action: Tab Stop")];
	[removeTabStopsButton setState:NSOffState];
	//fixed leak 15 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[tabStopPanel close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
}

-(IBAction)cancelAddTabStopAction:(id)sender
{
	[NSApp endSheet:tabStopPanel];
	[tabStopPanel orderOut:sender];
	//fixed leak 15 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[tabStopPanel close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
}

#pragma mark -
#pragma mark ---- Accessors ----

// ******************* Accessors ********************

-(JHDocument *)document
{
	return document;
}

-(void)setDocument:(JHDocument *)newDoc
{
	[newDoc retain];
	[document release];
	document = newDoc;
}

@end