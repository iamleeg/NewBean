/*
	JHDocument_Text.m
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
 
#import "JHDocument_Text.h"
#import "InspectorController.h"
#import "JHScrollView.h" //for isOptionKeyDown

//	used in textView:shouldChangeTextInRange: for Smart Quotes
#define DOUBLE_QUOTE 0x0022 // 'first level' quotation marks
#define SINGLE_QUOTE 0x0027 // equivalent to 'nested' quotation marks

@implementation JHDocument ( JHDocument_Text )

#pragma mark -
#pragma mark ---- Smart Quotes ----

// ******************* Smart Quotes  *******************

//TODO: make Smart Quote options a dictionary in user defaults
//	plist file: array of dictionaries with id (=tag), 4 chars/hex? 201C <?> for quotes
//	need pref checkbox: [_] Use 'first level' smart quotes only (?)
//	note: make help popup for each item a VERY LARGE attributed string showing menu item label
//	add James Joyce option --Go, he said. "time" ??
-(IBAction)setSmartQuotesStyleAction:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	int smartQuotesType = [defaults integerForKey:@"prefSmartQuotesStyleTag"]; 

	switch (smartQuotesType)
	{
		case 0: //curly
			SINGLE_OPEN_QUOTE = 0x2018;
			SINGLE_CLOSE_QUOTE = 0x2019;
			DOUBLE_OPEN_QUOTE = 0x201C;
			DOUBLE_CLOSE_QUOTE = 0x201D;
			break;
		case 3: //French (modern) note: user let me know that this is not French :-(
			SINGLE_OPEN_QUOTE = 0x201C;		//double-6 high
			SINGLE_CLOSE_QUOTE = 0x201D;	//double-9 high
			DOUBLE_OPEN_QUOTE = 0x0AB;		//outward pointing brackets
			DOUBLE_CLOSE_QUOTE = 0x00BB;
			break;		
		case 4: //German (modern), Danish, and Croatian
			SINGLE_OPEN_QUOTE = 0x203A;		//inward pointing brackets
			SINGLE_CLOSE_QUOTE = 0x2039;
			DOUBLE_OPEN_QUOTE = 0x00BB;		//inward pointing double brackets
			DOUBLE_CLOSE_QUOTE = 0x00AB;
			break;
		case 5: //French, Greek, Spanish, Albanian, Turkish, and Swiss OK! note: *NOT* typical French usage
			SINGLE_OPEN_QUOTE = 0x2039;		//outward pointing single brackets
			SINGLE_CLOSE_QUOTE = 0x203A;
			DOUBLE_OPEN_QUOTE = 0x00AB;		//outward pointing double brackets
			DOUBLE_CLOSE_QUOTE = 0x00BB;
			break;
		case 6: //Bulgarian, Czech, German (old), Icelandic, Lithuanian, Slovak, Serbian, and Romanian
			SINGLE_OPEN_QUOTE = 0x201A;		//low 9
			SINGLE_CLOSE_QUOTE = 0x2018;	//high 6
			DOUBLE_OPEN_QUOTE = 0x201E;		//double low-9
			DOUBLE_CLOSE_QUOTE = 0x201C;	//double high-6
			break;
		case 7: //Afrikaans, Dutch, Polish
			SINGLE_OPEN_QUOTE = 0x201A;		//low 9
			SINGLE_CLOSE_QUOTE = 0x2019;	//high 9
			DOUBLE_OPEN_QUOTE = 0x201E;		//double low-9
			DOUBLE_CLOSE_QUOTE = 0x201D;	//double high-9
			break;
		case 8: //Finnish, Swedish
			SINGLE_OPEN_QUOTE = 0x2019;		//high 9
			SINGLE_CLOSE_QUOTE = 0x2019;	//high 9
			DOUBLE_OPEN_QUOTE = 0x201D;		//double high-9
			DOUBLE_CLOSE_QUOTE = 0x201D;	//double high-9
			break;
		case 9: //Norwegian NOTE: French compatible!
			SINGLE_OPEN_QUOTE = 0x2018;		//high 6
			SINGLE_CLOSE_QUOTE = 0x2019;	//high 9
			DOUBLE_OPEN_QUOTE = 0x00AB;		//brackets
			DOUBLE_CLOSE_QUOTE = 0x00BB;
			break;
		case 10: //Chinese, Japanese
			SINGLE_OPEN_QUOTE = 0x300E;		//square brakets
			SINGLE_CLOSE_QUOTE = 0x300F;
			DOUBLE_OPEN_QUOTE = 0x300C;
			DOUBLE_CLOSE_QUOTE = 0x300D;
			break;				
		case 11: //French - space for guillemets is added in shouldChangeTextInRange
			SINGLE_OPEN_QUOTE = 0x2018;		//high 6
			SINGLE_CLOSE_QUOTE = 0x2019;	//high 9
			DOUBLE_OPEN_QUOTE = 0x00AB;		//left outward double bracket
			DOUBLE_CLOSE_QUOTE = 0x00BB;	//right outward double bracket
			break;
		case 12: //Canadian French
			SINGLE_OPEN_QUOTE = 0x2018;		//high 6
			SINGLE_CLOSE_QUOTE = 0x2019;	//high 9
			DOUBLE_OPEN_QUOTE = 0x00AB;		//left outward double bracket
			DOUBLE_CLOSE_QUOTE = 0x00BB;	//right outward double bracket
			break;		
		default: //straight (dumb qutoes) style, which == tag 1
			SINGLE_OPEN_QUOTE = 0x0027;
			SINGLE_CLOSE_QUOTE = 0x0027;
			DOUBLE_OPEN_QUOTE = 0x0022;
			DOUBLE_CLOSE_QUOTE = 0x0022;
			break;
		}		
	//	update quotes style (can be changed by user on the fly)
	[self setSmartQuotesStyleTag:smartQuotesType];
}

// manually change straight quotes to smart quotes and vice versa
- (IBAction)convertQuotesAction:(id)sender
{
	id			tv = [self firstTextView];
	NSString	*text = [[tv textStorage] string];
	NSArray		*selRanges = nil;
	NSValue		*rangeAsValue, *aRange, *bRange;
	
	if ([tv selectedRange].length==0)
	{
		bRange = [NSValue valueWithRange:NSMakeRange(0, [textStorage length])];
		selRanges = [NSArray arrayWithObject:bRange];
	}
	else
	{
		selRanges = [tv selectedRanges];
	}
	
	//	count selected ranges and add them
	NSEnumerator *rangeEnumerator = [selRanges objectEnumerator];
	unsigned int i;
	unichar c = 0;
	
	//	this prepares undo by feeding it strings to be inserted so that it will remember the changed ranges
	//	we don't know what strings will be inserted at this point, but we do know the string lengths
	NSEnumerator *rangeEnumerator2 = [selRanges objectEnumerator];
	NSMutableArray *replacementStrings = [NSMutableArray arrayWithCapacity:0];
	while ((aRange = [rangeEnumerator2 nextObject]) != nil)
	{
		[replacementStrings addObject:[text substringWithRange:[aRange rangeValue]]];
	}
	//	for undo
	//	perhaps change undo so it works through invocation?
	[tv shouldChangeTextInRanges:selRanges replacementStrings:replacementStrings];
	replacementStrings=nil;
	[[self undoManager] beginUndoGrouping];
	//	bracket for efficiency
	[[tv textStorage] beginEditing]; 
	
	while ((rangeAsValue = [rangeEnumerator nextObject]) != nil)
	{
		NSRange range = [rangeAsValue rangeValue];
		//	we have to send wordCountForString an attributed string because nextWordFromIndex only works on attributed strings
		NSString *rangeString = [[NSString alloc] initWithString:[text substringWithRange:range]];
		NSCharacterSet *startSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		
		for (i = 0; i < range.length; i++)
		{
			unichar theChar = [rangeString characterAtIndex:i];
			unichar previousChar;
			// find out the character which preceeds this one - context is everything!
			if(i == 0)
			{
				if (range.location == 0 || [text length]==0) { previousChar = 0; } //if first char
				else { previousChar = [text characterAtIndex:range.location - 1]; }
			} 
			else
			{
				previousChar = [text characterAtIndex:(range.location + i)-1];
			}	
			//	convert to smart quotes menu item
			if ([sender tag]==0)
			{
				// When we encounter a straight quote, we decide whether it should be open or closed:
				if ((theChar == SINGLE_QUOTE) || (theChar == DOUBLE_QUOTE)) 
				{
					if (previousChar == 0x00A0) //non-breaking space (Bean places this before closing quote for French smart quotes)
					{
						c = (theChar == SINGLE_QUOTE ? SINGLE_CLOSE_QUOTE : DOUBLE_CLOSE_QUOTE);
					}
					else if (previousChar == 0 || [startSet characterIsMember:previousChar] 
							 || (previousChar == DOUBLE_OPEN_QUOTE && theChar == SINGLE_QUOTE) 
							 || (previousChar == SINGLE_OPEN_QUOTE && theChar == DOUBLE_QUOTE))
					{
						c = (theChar == SINGLE_QUOTE ? SINGLE_OPEN_QUOTE : DOUBLE_OPEN_QUOTE);
					}
					else
					{
						c = (theChar == SINGLE_QUOTE ? SINGLE_CLOSE_QUOTE : DOUBLE_CLOSE_QUOTE);
					}
					
					if (c) [[tv textStorage] replaceCharactersInRange:NSMakeRange(range.location + i,1) withString:[NSString stringWithFormat:@"%C", c]];
					c = 0;
				}
			}
			//	convert to straight quotes menu action
			else
			{
				// When we encounter an open or close quote, we convert it to straight:
				if ((theChar == SINGLE_OPEN_QUOTE) || (theChar == SINGLE_CLOSE_QUOTE))
				{
					c = SINGLE_QUOTE;
				}
				if ((theChar == DOUBLE_OPEN_QUOTE) || (theChar == DOUBLE_CLOSE_QUOTE))
				{
					c = DOUBLE_QUOTE;
				}
				if (c) 
				{
					[[tv textStorage] replaceCharactersInRange:NSMakeRange(range.location + i,1) withString:[NSString stringWithFormat:@"%C", c]];
				}
				c = 0;
			}
		}
		[rangeString release];
	}
	//	close bracket
	[[tv textStorage] endEditing];
	[[self undoManager] endUndoGrouping];
	//	end undo setup
	[tv didChangeText];
	//	name undo action, based on tag of control
	[[self undoManager] setActionName:NSLocalizedString(@"Convert Quotes", @"undo action: Convert Quotes.")];
}

-(IBAction)useSmartQuotesAction:(id)sender
{
	BOOL enabled;
	//toggle Leopard's Smart Quotes
	if ([self useSmartQuotesSuppliedByTextSystem])
	{
		if ([[self firstTextView] respondsToSelector:@selector(isAutomaticQuoteSubstitutionEnabled)])
		{
			enabled = [[self firstTextView] isAutomaticQuoteSubstitutionEnabled];
			[[self firstTextView] setAutomaticQuoteSubstitutionEnabled:!enabled];
		}
	}
	//toggle Bean's Smart Quotes
	else
	{
		enabled = [self shouldUseSmartQuotes];
		[self setShouldUseSmartQuotes:!enabled];
	}
}

 #pragma mark -
 #pragma mark ---- Inspector Shared Actions ----
  
 // ******************* Inspector Shared Actions  *******************

//called by some items in the mainMenu.nib
 - (IBAction)textControlAction:(id)sender
{
	//load sharedController for Inspector if not already loaded
	id ic = [InspectorController sharedInspectorController];
	//use some of its code 
	[ic textControlAction:sender];
}

#pragma mark -
#pragma mark ---- Edit > Insert Actions ----

// ******************* Edit > Insert Actions *******************

-(IBAction)insertDateTimeStamp:(id)sender
{
	NSDate *today = [NSDate date];
	id tv = [self firstTextView];
	int selLoc = [tv selectedRange].location;
	int selLen = [tv selectedRange].length;
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init]; // ===== init
	[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
	NSString *undoString = nil;
	switch ([sender tag])
	{
		//	if insert date - long format menu item choosen
		case 0:
			[dateFormatter setDateStyle:NSDateFormatterLongStyle];
			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			undoString = NSLocalizedString(@"undo action: Insert Date", @"undo action: Insert Date");
		break;
		//	if insert date - short format menu item choosen
		case 1:
			[dateFormatter setDateStyle:NSDateFormatterShortStyle];
			[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
			undoString = NSLocalizedString(@"undo action: Insert Date", @"undo action: Insert Date");
		break;
		//	if insert time format menu item choosen
		case 2:
			[dateFormatter setDateStyle:NSDateFormatterNoStyle];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
			undoString = NSLocalizedString(@"undo action:Insert Time", @"undo action: Insert Time");
		break;
		//	if insert date/time format menu item choosen
		case 3:
			[dateFormatter setDateStyle:NSDateFormatterShortStyle];
			[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
			undoString = NSLocalizedString(@"Insert Date/Time", @"undo action: Insert Date/Time");
		break;
	}
	//18 APR 09 JH: removed extra space ( "%@ " ); can't remember why it was there in the first place
	NSString *formattedDateString = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:today]];
	if ([tv shouldChangeTextInRange:NSMakeRange (selLoc, selLen)
											   replacementString:formattedDateString])
	{
		[tv replaceCharactersInRange:NSMakeRange (selLoc, selLen) withString:formattedDateString];
		[[self undoManager] setActionName:undoString];
	}
	[dateFormatter release]; // ===== release
}

//	since there are no tab leaders and tabs and regular spaces don't take underlining, there needs to be an easy way to create a signature line for forms (for people to write their signature on the hardcopy, etc.)
-(IBAction)insertSignatureLineAction:(id)sender
{
	NSTextView *tv = [self firstTextView];
	NSRange theRange = [tv selectedRange]; 
	int theLength = [textStorage length];
	
	id theUnderlineStyle = [NSNumber numberWithInt: NSUnderlinePatternSolid | NSUnderlineStyleSingle];
	//	the signature line string is a non-breaking space followed by a string of regular spaces. The signature line allows the spaces to be underlined (can't underline spaces without it, in fact!). A non-underlined space at the end prevents undeline from extending to following typed text.
	NSString *sigLine = [NSString stringWithFormat:@"%C%@", 0x00A0, NSLocalizedString(@"newSigLine", @"sigLine string: repeated non-breaking space chararcters that will be underlined to make a signature line, followed by a final non-underlined space")];
	
	if ([tv shouldChangeTextInRange:NSMakeRange(theRange.location, 0) replacementString:sigLine])
	{
		//	insert string
		[tv replaceCharactersInRange:NSMakeRange(theRange.location, 0) withString:sigLine];
		if ([textStorage length] > theLength)
		{
			//	add underline
			[textStorage addAttribute: NSUnderlineStyleAttributeName value:theUnderlineStyle 
							range:NSMakeRange(theRange.location, [sigLine length] - 1)];
		}
		[tv didChangeText];
		// name undo action
		[[self undoManager] setActionName:NSLocalizedString(@"undo action: Signature Line", @"undo action: Signature Line")];
	}
}

/*
- (void)insertLoremIpsum:(id)sender 
{
	NSTextView *tv = [self firstTextView];
	NSRange r = [tv selectedRange]; 

	//	NOTE: the actual Lorem Ipsum paragraph is found in Localization.strings
	NSString *loremIpsum = [NSString stringWithString:NSLocalizedString(@"Lorem ipsum", @"Lorem Ipsum is a paragraph of mock Latin text that is traditionally used as placeholder text when experimenting with page layout.")];
	
	if ([tv shouldChangeTextInRange:r replacementString:loremIpsum]) {
		//	insert string
		[tv replaceCharactersInRange:r withString:loremIpsum];
		[tv didChangeText];
		// name undo action
		[[self undoManager] setActionName:NSLocalizedString(@"Lorem Ipsum", @"undo action: Lorem Ipsum")];
	}
	
	// if option key is down before mouse down for menu selection begins, copy lorem ipsum to pasteboard
	// todo: perhaps change menu item label through validation
	if ([(JHScrollView *)[tv enclosingScrollView] isOptionKeyDown] && loremIpsum) {
		id pboard = nil;
		if (pboard = [NSPasteboard generalPasteboard]) {
			[pboard declareTypes:[NSArray arrayWithObject: NSStringPboardType] owner:nil];
			[pboard setString:loremIpsum forType:NSStringPboardType];
		}
	}
	
}
*/

-(IBAction)insertBreakAction:(id)sender
{
	id tv = [self firstTextView];
	if ([sender tag]==0)
	{
		//	insert line break
		if ([tv shouldChangeTextInRange:[tv selectedRange] replacementString:nil])	
		{
			[tv insertLineBreak:sender];
			//	name undo action, based on tag of control
			[[self undoManager] setActionName:NSLocalizedString(@"Line Break", @"undo action: Line Break")];
		}
	}
	else if ([sender tag]==1)
	{
		//	insert new line (ie, paragraph break)
		if ([tv shouldChangeTextInRange:[tv selectedRange] replacementString:nil])	
		{
			[tv insertNewline:sender];
			//	name undo action, based on tag of control
			[[self undoManager] setActionName:NSLocalizedString(@"New Line", @"undo action: New Line")];		
		}
	}
	else if ([sender tag]==2)
	{
		//	insert page break
		if ([tv shouldChangeTextInRange:[tv selectedRange] replacementString:nil])	
		{
			[tv insertContainerBreak:sender];
			//	name undo action, based on tag of control
			[[self undoManager] setActionName:NSLocalizedString(@"Page Break", @"undo action: Page Break")];
		}
	}
	else if ([sender tag]==3) //insert non-breaking space (yes, I know, not a 'break', oh well).
	{
		//non-breaking space for avoiding inconvenient line breaks due to wrapping like 'I love MAC OS/n X'
		NSString *nonBreakingSpace = [NSString stringWithFormat:@"%C", 0x00A0];
		if ([tv shouldChangeTextInRange:[tv selectedRange] replacementString:nil])	
		{
			[tv insertText:nonBreakingSpace];
			//	name undo action, based on tag of control
			[[self undoManager] setActionName:NSLocalizedString(@"undo action: Non-breaking space", @"undo action: Non-breaking space")];
		}
	}
}


#pragma mark -
#pragma mark ---- Edit > Remove Actions ----

// ******************* Edit > Remove Actions ********************

//	removes attachments from document or selection if selection length > 0
-(IBAction)removeAttachmentsAction:(id)sender;
{
	NSTextView *tv = [self firstTextView];
	//	if selection, change it; otherwise change all
	NSRange rangeToScan;
	int maxRange;
	int indexToRestore = [tv selectedRange].location;
	NSString *attachmentString = [NSString stringWithFormat:@"%C", NSAttachmentCharacter];
	if ([tv selectedRange].length)
	{
		maxRange = [tv selectedRange].location + [tv selectedRange].length;
		rangeToScan = [tv selectedRange];
	}
	else
	{
		maxRange = [textStorage length];
		rangeToScan = NSMakeRange(0, [textStorage length]);
	}
	//	record index of all relevant attachments in array
	NSMutableArray *indexesOfAttachments = [NSMutableArray arrayWithCapacity:1];
	NSString *stringToScan = [textStorage string];
	while (rangeToScan.location < maxRange)
	{
		NSRange rangeOfAttachment = [stringToScan rangeOfString:attachmentString options:0 range:rangeToScan]; 
		int indexOfAttachment = rangeOfAttachment.location;
		//if attachment found, note location
		if (indexOfAttachment != NSNotFound)
		{
			[indexesOfAttachments insertObject:[NSNumber numberWithInt:indexOfAttachment] atIndex:0];
			//	set range to search unexamined part only
			rangeToScan.location = indexOfAttachment + 1;
			rangeToScan.length = maxRange - indexOfAttachment - 1;
		}
		//	else, exit while
		else
		{
			rangeToScan.location = maxRange;
		}
	}
	//	go through and delete attachments
	if (indexesOfAttachments)
	{
		//	replace attachment with nil string
		NSAttributedString *nothingString = [[NSAttributedString alloc] initWithString:@""];
		NSEnumerator *enumerator = [indexesOfAttachments objectEnumerator];
		NSNumber *indexObj;
		
		//	we do this 'undo' couplet so that insertion point index will restore after undo
		[tv shouldChangeTextInRange:[tv selectedRange] replacementString:nil];
		//[tv setSelectedRange:NSMakeRange(indexToRestore, 0)];
		[tv didChangeText];
		
		//	NOTE: array was loaded with largest indexes first, so attachments are deleted from end to beginning so that the index of the attachments still to be deleted doesn't change 
		while (indexObj = [enumerator nextObject])
		{
			int indexInt = [indexObj intValue]; 
			// undo
			[tv shouldChangeTextInRange:NSMakeRange(indexInt, 1) replacementString:@""];
			//	replace attachment with a nothing string
			[textStorage replaceCharactersInRange:NSMakeRange(indexInt, 1) withAttributedString:nothingString];
			[tv didChangeText];
			//watch for out-of-bounds 5 MAR 08 JH
			if (indexInt <= indexToRestore && indexToRestore > 0)
			{
				indexToRestore = indexToRestore - 1;
			} 
		}
		[nothingString release];
	}
	//	restore insertion point index
	[tv setSelectedRange:NSMakeRange(indexToRestore, 0)];
}

//BUGFIX: Edit > Remove > *All* Text Tables wasn't working until 2.4.0 (thanks Rudolf Gavlas)
-(IBAction)removeTextTablesAction:(id)sender;
{
	NSRange theRange;
	NSRange rangeToChange;
	NSParagraphStyle *theStyle = nil;
	NSTextView *tv = [self firstTextView];
	
	//restored at end
	NSArray *ranges = [tv selectedRanges]; 
	
	//	we do this 'undo' couplet so that insertion point index will restore after undo
	[tv shouldChangeTextInRanges:ranges replacementStrings:nil];
	[tv didChangeText];

	//if no selection, select all text
	if (![tv selectedRange].length) { [tv setSelectedRange:NSMakeRange(0, [textStorage length])]; }

	//	enumerate selected ranges of text
	NSEnumerator *e = [[tv selectedRanges] objectEnumerator];
	NSValue *aRange;
	//	for selected ranges...
	while (aRange = [e nextObject])
	{
		rangeToChange = [aRange rangeValue];
		//	APPLY new paragraph style to rangeToChange 
		int index = rangeToChange.location;
		while (index < rangeToChange.location + rangeToChange.length)
		{
			//	get range of paragraphStyle
			theStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:index effectiveRange:&theRange];
			//	if it contains textBlocks (parts of textTables)
			if ([theStyle textBlocks])
			{
				//	make a mutable copy of the style and nix the tables
				NSMutableParagraphStyle *mutableStyle = [theStyle mutableCopy]; //<==mcopy
				[mutableStyle setTextBlocks:nil];
				//	apply the new style to the original range
				if (mutableStyle)
				{
					//for undo
					[tv shouldChangeTextInRange:theRange replacementString:NULL];
					[textStorage addAttribute:NSParagraphStyleAttributeName value:mutableStyle range:theRange];
					[tv didChangeText];
				}
				[mutableStyle release]; //<==release
			}
			//	advance index
			index = theRange.location + theRange.length;
		}
	}
	if (ranges) [tv setSelectedRanges:ranges];
	[[self undoManager] setActionName:NSLocalizedString(@"undo action: Remove Text Tables", @"undo action: Remove Text Tables")];
}

-(IBAction)removeTextListsAction:(id)sender;
{
	NSRange rangeToChange;
	NSParagraphStyle *theStyle = nil;
	NSTextView *tv = [self firstTextView];
	
	//	if no selection, change all
	if ([tv selectedRange].length==0)
	{
		[tv setSelectedRange:NSMakeRange(0, [textStorage length])];
	}	
		
	//	we do this 'undo' couplet so that insertion point index will restore after undo
	[tv shouldChangeTextInRanges:[tv selectedRanges] replacementStrings:nil];
	[tv didChangeText];
	
	//	change selected ranges to use the new NSFontAttributeName
	NSEnumerator *e = [[tv selectedRanges] objectEnumerator];
	NSValue *aRange;
	//	for selected ranges...
	while (aRange = [e nextObject])
	{
		
		rangeToChange = [aRange rangeValue];
		//	APPLY a converted version of the FONT STYLE to rangeToChange 
		int index = rangeToChange.location + rangeToChange.length - 1;
		while (index >= rangeToChange.location && index > 0)
		{
			 NSString *aString = [textStorage string];
			 NSRange pRange = [aString paragraphRangeForRange:NSMakeRange(index, 0)];

			 //	get paragraphStyle
			 theStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:index effectiveRange:NULL];
			 //	if it contains textLists
			 if ([theStyle textLists])
			 {
				 [tv setSelectedRange:NSMakeRange(pRange.location, 0)];
				 int i;
				 int numLists = [[theStyle textLists] count];
				 for (i = 0; i < numLists; i++)
				 {
					 //	textView includes automatic undo
					 [tv insertBacktab:nil];
				 }
			 }
			 //	move index back to potential previous list item
			 index = pRange.location - 1;
		 }
	}
	[[self undoManager] setActionName:NSLocalizedString(@"undo action: Remove List Markers", @"undo action: Remove List Markers")];
}

#pragma mark -
#pragma mark ---- Paragraph Attribute Actions ----

// ******************* Paragraph Attribute Actions ********************

//	if we assign the textView's message directly as the toolbar action, item does not get validated so we call indirectly here
-(IBAction)toggleWritingDirection:(id)sender;
{
	//	switches orientation of paragraph to be friendly to right to left languages (Arabic, Hebrew, Farsi, others?)
	[[self firstTextView] toggleBaseWritingDirection:self];
}

-(IBAction)allowHyphenationAction:(id)sender;
{
	int index;
	NSRange rangeToChange;
	NSParagraphStyle *theStyle = nil;
	NSTextView *tv = [self firstTextView];
	float theHyphenationFactor;
	NSString *undoString;

	//	if allow hyphenation is checked (meaning hyphenation exists at least at index as checked by validateMenu method), then turn off by setting hyphenationFactor to 0.0; otherwise, turn on by setting hyphenation = 0.9 
	if ([sender state])
	{ 
		theHyphenationFactor = 0.0;
		undoString = @"undo action: Do not Allow Hyphenation";
	}
	else
	{
		theHyphenationFactor = 0.9;
		undoString = @"undo action: Allow Hyphenation";
	}
	
	//	we do this 'undo' couplet so that insertion point index will restore after undo
	[tv shouldChangeTextInRanges:[tv selectedRanges] replacementStrings:nil];
	[tv didChangeText];
	
	//	look at each paragraph's paragraphStyle
	//	NOTE: effectiveRange doesn't alwasy start at beginning of paragraph for NSParagraphStyleAttributeName (!) so we set index to actual beginning of paragraph
	//	change selected ranges to use the new NSFontAttributeName
	NSEnumerator *e = [[tv selectedRanges] objectEnumerator];
	NSValue *theRange;
	//	for selected ranges...
	while (theRange = [e nextObject])
	{
		rangeToChange = [theRange rangeValue];
		NSRange runRange;
		index = [[textStorage string] paragraphRangeForRange:NSMakeRange(rangeToChange.location, 0)].location;
		while (index < rangeToChange.location + rangeToChange.length)
		{
			//	get range of paragraphStyle
			theStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:index effectiveRange:&runRange];
			//NSLog(NSStringFromRange(runRange));
			//	make a mutable copy of the style and add hyphenation support
			NSMutableParagraphStyle *mutableStyle = [theStyle mutableCopy];
			[mutableStyle setHyphenationFactor:theHyphenationFactor];
			//	apply the new style to the original range
			if (mutableStyle)
			{
				//for undo
				[tv shouldChangeTextInRange:runRange replacementString:NULL];
				[textStorage addAttribute:NSParagraphStyleAttributeName value:mutableStyle range:runRange];
				[tv didChangeText];
			}
			[mutableStyle release];
			//	advance index
			index = runRange.location + runRange.length;
		}
	}
	[[self undoManager] setActionName:NSLocalizedString(undoString, @"undo action: Allow Hyphenation / Do not Allow Hyphenation")];
}

#pragma mark -
#pragma mark ---- Font Attribute Actions ----

// ******************* Font Attribute Actions ********************

// fixed broken imp 8 APR 09 JH
-(IBAction)strikethroughAction:(id)sender;
{
	NSTextView *tv = [self firstTextView];
	NSRange theRange = {0,0}; 
	
	//is text already struckthrough at index?
	NSDictionary *attributes = nil;
	if ([tv selectedRange].length > 0)
		attributes = [textStorage attributesAtIndex:[tv selectedRange].location effectiveRange:NULL];
	else
		attributes = [tv typingAttributes];
	BOOL isStruckthrough = [attributes objectForKey:NSStrikethroughStyleAttributeName] ? YES : NO;
	
	id strikethrough = [NSNumber numberWithInt: NSUnderlinePatternSolid | NSUnderlineStyleSingle];
	
	//	we do this 'undo' couplet so that insertion point index will restore after undo
	[tv shouldChangeTextInRanges:[tv selectedRanges] replacementStrings:nil];
	[tv didChangeText];
			
	[tv shouldChangeTextInRanges:[tv selectedRanges] replacementStrings:nil];
	
	//	add strikethrough typingAttributes
	if (!isStruckthrough)
	{
		NSDictionary *theAttributes = [tv typingAttributes];
		NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease]; // < ==== autorelease
		[theTypingAttributes setObject:strikethrough forKey:NSStrikethroughStyleAttributeName];
		[tv setTypingAttributes:theTypingAttributes];
	}
	//	or remove strikethrough if struckthrough
	else
	{
		//	add strikethrough style to the current typingAttributes
		NSDictionary *theAttributes = [tv typingAttributes];
		NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease]; // < ==== autorelease
		[theTypingAttributes setObject:[NSNumber numberWithInt:0] forKey:NSStrikethroughStyleAttributeName];
		[tv setTypingAttributes:theTypingAttributes];
	}

	//	add strikethrough to selectedRanges, or remove strikethrough if need be

	NSEnumerator *e = [[tv selectedRanges] reverseObjectEnumerator];
	NSValue *aRange;

	while (aRange = [e nextObject])
	{
		
		theRange = [aRange rangeValue];
		[tv shouldChangeTextInRange:theRange replacementString:nil];
		//	add strikethrough if not struckthrough at index
		if (!isStruckthrough)
		{
			[textStorage addAttribute: NSStrikethroughStyleAttributeName value:strikethrough range:theRange];
		}
		//	or remove strikethrough
		else
		{
			[textStorage removeAttribute: NSStrikethroughStyleAttributeName range:theRange];
		}
		[tv didChangeText];
	}
	
	[[self undoManager] setActionName:NSLocalizedString(@"undo action: Strikethrough", @"undo action: Strikethrough")];

	[tv didChangeText];

}

//	shrink superscripted text so line spacing remains constant (so only one line spacing doesn't grow to fit superscripted text)
- (void)superscriptAction:(id)sender;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//	only use if pref says so; else, just use Cocoa behavior
	if ([defaults boolForKey:@"prefShrinkSuperAndSubscript"])
	{
		[self shrinkSuperAndSubscriptText];
	}
	[[self firstTextView] superscript:sender];
}

//	shrink subscripted text
//	note: this doesn't prevent line spacing from becoming irregular, but it would be silly to shrink superscript & not subscript text
- (void)subscriptAction:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//	only use if pref says so; else, just use Cocoa behavior
	if ([defaults boolForKey:@"prefShrinkSuperAndSubscript"])
	{
		[self shrinkSuperAndSubscriptText];
	}
	[[self firstTextView] subscript:sender];
}

//	removes super/subscript and tries to restore text to previous size
- (void)unscriptAction:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//	only use if pref says so; else, just use Cocoa behavior
	if ([defaults boolForKey:@"prefShrinkSuperAndSubscript"])
	{
		[self restoreSizeToUnscriptText];
	}
	[[self firstTextView] unscript:sender];
}

- (void)shrinkSuperAndSubscriptText
{
	id tv = [self firstTextView];
	//superscript will effect entire doc if plain text, so check for this
	if ([tv isRichText] && [tv selectedRange].location != [textStorage length])
	{
		NSFontManager *fm = [NSFontManager sharedFontManager];
		//	interate thru ranges of selected text
		NSEnumerator *rangeEnumerator = [[tv selectedRanges] objectEnumerator];
		NSValue *rangeAsValue;
		while ((rangeAsValue = [rangeEnumerator nextObject]) != nil)
		{
			NSRange range = [rangeAsValue rangeValue];
			if (range.location >= 0)
			{	
				int index, superscriptAttr = 0;
				if (range.location > 0)
				{
					index = range.location - 1;
					superscriptAttr = [[textStorage attribute:NSSuperscriptAttributeName atIndex:index effectiveRange:NULL] intValue];
				}
				// don't shrink text unless previous char is not superscripted (to avoid double shrinking) or there is no prev. char (for index = 0)
				if (superscriptAttr == 0 || range.location == 0)
				{
					//	get font
					NSFont *aFont = [textStorage attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL];
					float fontSize = ceil([aFont pointSize]);
					//	modify font size so superscript won't cause line spacing to change
					//	doen't help with preserving line spacing for subscript
					float newSize = ceil(fontSize * 0.6);
					if (newSize < 5) newSize = 5; 
					NSFont *newFont = [fm convertFont:aFont toSize:newSize];
					//	apply font with new size to text to superscript
					BOOL canChange = [tv shouldChangeTextInRange:range replacementString:nil];
					if (canChange)
						[textStorage addAttribute:NSFontAttributeName value:newFont range:range];
					[tv didChangeText];
				}
			}
		}
	}
}

- (void)restoreSizeToUnscriptText
{
	id tv = [self firstTextView];
	//superscript will effect entire doc if plain text, so check for this
	if ([tv isRichText] && [tv selectedRange].location != [textStorage length])
	{
		NSFontManager *fm = [NSFontManager sharedFontManager];
		//	interate thru ranges of selected text
		NSEnumerator *rangeEnumerator = [[tv selectedRanges] objectEnumerator];
		NSValue *rangeAsValue;
		while ((rangeAsValue = [rangeEnumerator nextObject]) != nil)
		{
			NSFont *aFont;
			NSRange range = [rangeAsValue rangeValue];
			float fontSize;
			//	if we can restore to the size of the char prev. to selection, we do
			if (range.location > 0)
			{	
				int index = range.location - 1;
				aFont = [textStorage attribute:NSFontAttributeName atIndex:index effectiveRange:NULL];
				fontSize = ceil([aFont pointSize]);
			}
			//	otherwise we look forward to the first change in font attributes to 'guess' size to restore
			else
			{
				NSRange fontRange;
				[textStorage attribute:NSFontAttributeName atIndex:range.location effectiveRange:&fontRange];
				if (fontRange.location + fontRange.length < [textStorage length])
				{
					int nextIndex = fontRange.location + fontRange.length;
					NSFont *anotherFont = [textStorage attribute:NSFontAttributeName atIndex:nextIndex effectiveRange:NULL];
					fontSize = ceil([anotherFont pointSize]);	
				}
				else
				{
					//in case there was no text before or after the superscript!
					fontSize = 13.0;
				}
			}
			NSFont *sFont = [textStorage attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL];
			//	create font with new fize
			NSFont *newFont = [fm convertFont:sFont toSize:fontSize];
			//	apply font with new size to text to superscript
			BOOL canChange = [tv shouldChangeTextInRange:range replacementString:nil];
			if (canChange)
				[textStorage addAttribute:NSFontAttributeName value:newFont range:range];
			[tv didChangeText];
		}
	}	
}

// ----- Alternate Font (= Note Mode) methods -----

#pragma mark -
#pragma mark ---- Alternate Font methods ----

//NOTE: 'alternate font' was early name for notes mode / insert note actions

//textViewDidChangeSelection will set typingAttribtues for notes font if YES is returned
-(void)setAlternateFontActive:(BOOL)flag { _alternateFontActive = flag; }
-(BOOL)alternateFontActive { return _alternateFontActive; }

//caches font and color, to be added to typingAttributes at insertion point for notes 
-(void)setAlternateFontDictionary:(NSDictionary *)newDict;
{
	[_alternateFontDictionary autorelease];
	_alternateFontDictionary = [newDict copy];
}
-(NSDictionary *)alternateFontDictionary;
{
	return _alternateFontDictionary;
}

//caches old attributes so can be restored when notes font is turned off
-(void)setOldTypingAttributes:(NSDictionary *)oldAttrs;
{
	[_oldTypingAttributes autorelease];
	_oldTypingAttributes = [oldAttrs copy];
}
-(NSDictionary *)oldTypingAttributes;
{
	return _oldTypingAttributes;
}

//updates notes font attributes based on prefs; called by toggleAlternateFont AND by option buttons in prefs
-(IBAction)reviseAlternateFontDictionary:(id)sender
{
	//get attributedString from user preferences
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *data = [defaults objectForKey:@"prefAltFontExampleData"];
	NSAttributedString *attrStr = nil;
	if (data) attrStr = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	//make cached dictionary of notes font attributes
	NSMutableDictionary *mDict =[NSMutableDictionary dictionaryWithCapacity:3];
	if ([defaults boolForKey:@"prefAltFontUsesFont"])
	{
		//user pref font present on system?
		NSFont *testFont = nil;
		//returns nil if no font by that name or attrStr is nil!
		testFont = [NSFont fontWithName:[attrStr string] size:13];
		//the font is *not* available now
		if (!testFont)
		{
			//use system font with red text color as a substitute
			attrStr = nil;
			NSFont *sysFont = [NSFont systemFontOfSize:13];
			NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:sysFont, NSFontAttributeName, [NSColor redColor], NSForegroundColorAttributeName, nil];
			attrStr = [[[NSAttributedString alloc] initWithString:[sysFont displayName] attributes:dict] autorelease];
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			NSData *data=[NSKeyedArchiver archivedDataWithRootObject:attrStr];
			[defaults setObject:data forKey:@"prefAltFontExampleData"];
			[defaults synchronize];
		}
		NSFont *font = [attrStr attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
		if (font)
			[mDict setObject:font forKey:NSFontAttributeName];
	}
	if ([defaults boolForKey:@"prefAltFontUsesTextColor"])
	{
		NSColor *fColor = [attrStr attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL];
		if (fColor)
			[mDict setObject:fColor forKey:NSForegroundColorAttributeName];
	}
	if ([defaults boolForKey:@"prefAltFontUsesHighlightColor"])
	{
		NSColor *bgColor = [attrStr attribute:NSBackgroundColorAttributeName atIndex:0 effectiveRange:NULL];
		if (bgColor)
			[mDict setObject:bgColor forKey:NSBackgroundColorAttributeName];
	}				
	if ([mDict count])
	{
		[self setAlternateFontDictionary:mDict];
	}
}

-(IBAction)toggleAlternateFont:(id)sender;
{
	id tv = [self firstTextView];
	//turn off alternate font
	if ([self alternateFontActive])
	{
		NSInteger loc = [tv selectedRange].location;
		NSDictionary *attrAtIndex = nil; // = nil required!
		//bounds check
		if (loc < [textStorage length])
			attrAtIndex = [textStorage attributesAtIndex:loc effectiveRange:NULL];
		//if not index == length and following text attrs are different from typingAttributes reflecting alternate font
		if (attrAtIndex && ![[tv typingAttributes] isEqualToDictionary:attrAtIndex])
			//use following attributes for typingAttributes (so alternate font doesn't propagate)
			[tv setTypingAttributes:attrAtIndex];
		else
			//else use attributes cached from when alternate font was first activated; may produce desired typingAttribtues but not necessarily; another way would be to find first attr run before current notes attr run, but this might also be incorrect!  
			[tv setTypingAttributes:[self oldTypingAttributes]];
		//set reporter
		[self setAlternateFontActive:NO];
	}
	//need to turn ON alternate font
	else
	{
		//cache previous typingAttributes for later restoration
		[self setOldTypingAttributes:[tv typingAttributes]];
		//update notes attributes from prefAltFontExampleData (user pref)
		[self reviseAlternateFontDictionary:self];
		//set reporter
		[self setAlternateFontActive:YES];
		//call the textView delegate method that sets notes font typingAttributes
		[self textViewDidChangeSelection:nil];
	}
}

-(IBAction)beginNote:(id)sender;
{
	[self beginNoteWithString:nil];
}

-(void)beginNoteWithString:(id)aString;
{
	//update notes attributes from prefAltFontExampleData (user pref)
	[self reviseAlternateFontDictionary:self];

	id tv = [self firstTextView];
	int loc = [tv selectedRange].location;
	//extra check, since this method can be called at insertText
	if (![tv isEditable] || ![tv isRichText] || 0==[[self alternateFontDictionary]count]) return;

	//modify note string if necessary (based on user prefs)
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *leftNewline = nil, *rightNewline = nil, *leftBracket = nil, *rightBracket = nil;
	//sandwich in square brackets if user prefs say so
	if ([defaults boolForKey:@"prefAltFontUsesBrackets"])
	{
		leftBracket = [defaults stringForKey:@"prefAltFontLeftBracketString"];
		rightBracket = [defaults stringForKey:@"prefAltFontRightBracketString"];
	}
	else
	{
		leftBracket = @"";
		rightBracket = @"";
	}
	int rightBracketLength = [rightBracket length];
	int attributesIndex = 0;
	//sandwich in newlines if user prefs say so
	if ([defaults boolForKey:@"prefAltFontUsesNewParagraph"])
	{
		if (loc > 0 && [[textStorage string] characterAtIndex:loc - 1] != NSNewlineCharacter)
		{
			leftNewline = [NSString stringWithFormat:@"%C", NSNewlineCharacter];
			attributesIndex = attributesIndex + 1;
		}
		else
			leftNewline = @"";
		if (loc < [textStorage length] && [[textStorage string] characterAtIndex:loc] != NSNewlineCharacter)
		{
			rightNewline = [NSString stringWithFormat:@"%C", NSNewlineCharacter];
			rightBracketLength = rightBracketLength + 1;
		}
		else
			rightNewline = @"";
	}
	else
	{
		leftNewline = @"";
		rightNewline = @"";
	}

	NSString *string = @"";
	//aString is cast to id; can be attributedString or string or nil, so examine it
	//is NSAttributedString - extract string
	if (![aString isKindOfClass:[NSString class]] && [aString respondsToSelector:@selector(string)])
		string = [aString string];
	//is nil
	else if (!aString)
		string = @"";
	//is NSString
	else
		string = aString;
		
	//a note created with a return, and sandwiched between returns, creates a two-line note
	//	user intended one line, so correct
	if (1==[string length] && NSNewlineCharacter == [string characterAtIndex:0])
		string = @"";
		
	//mutable copy of typingAttributes
	NSMutableDictionary *altTypingAttrs = [[[tv typingAttributes]mutableCopy]autorelease];
	//add alternate font attributes
	[altTypingAttrs addEntriesFromDictionary:[self alternateFontDictionary]];			
	//make attributed string
	NSString *s = [NSString stringWithFormat:@"%@%@%@%@%@", leftNewline, leftBracket, string, rightBracket, rightNewline];

	if ([s length] && [tv shouldChangeTextInRange:[tv selectedRange] replacementString:s])
	{
		[textStorage replaceCharactersInRange:[tv selectedRange] withString:s];
		[textStorage addAttributes:altTypingAttrs range:NSMakeRange([tv selectedRange].location - [s length] + attributesIndex, [s length] - attributesIndex)];
		[tv didChangeText];
		[tv setSelectedRange:NSMakeRange([tv selectedRange].location - rightBracketLength, 0)];
	}
	//set typing attributes, in case no string was inserted
	[tv setTypingAttributes:altTypingAttrs];
}

-(BOOL)insertedTextNeedsExtraProcessing
{
	id tv = [self firstTextView];
	NSInteger loc = [tv selectedRange].location;
	NSDictionary *attrs = nil; // = nil required for later comparison!
	if (0 == [textStorage length])
		return YES;
	//if not index == length
	else if (loc < [textStorage length])
	{
		if (loc > 0)
		{
			NSDictionary *prevAttrs = nil; // = nil required for comparison
			prevAttrs = [textStorage attributesAtIndex:loc - 1 effectiveRange:NULL];
			if ([[tv typingAttributes] isEqualToDictionary:prevAttrs])
				return NO;
		}
		attrs = [textStorage attributesAtIndex:loc effectiveRange:NULL];
		//if following text attrs are different from alt font typingAttributes
		if (![[tv typingAttributes] isEqualToDictionary:attrs])
			return YES;
	}
	//index == length
	else
	{
		//	notes font typingAttributes not always being set at textViewDidChangeSelection when index == length ... why?
		//	seems to be working now? 23 AUG 09
		attrs = [textStorage attributesAtIndex:loc - 1 effectiveRange:NULL];
		//if previous text attrs are different from alt font typingAttributes
		if (![[tv typingAttributes] isEqualToDictionary:attrs])
			return YES;
	}
	return NO;
}

//	the following was a bad idea -- since most users only mix in a few words of some other language at a time.
//	kept for future reference
//	need to implement a reverse ruler (numbers going right to left, as e.g. in Mellel) if that is the case.
/*
 -(void)checkForRightToLeftInputSource
 {
 return; // <----------------------------------------------short circut
 
 KeyboardLayoutRef keyLayout = nil;
 NSString *keyboardLayoutName = nil;
 
 //	0 == left to right input specifically
 if ([[self firstTextView] baseWritingDirection] != 1)
 {
 
 KLGetCurrentKeyboardLayout(&keyLayout);
 if (keyLayout)
 {
 KLGetKeyboardLayoutProperty(keyLayout, kKLName, (const void **) &keyboardLayoutName);
 }
 if (keyboardLayoutName && ([keyboardLayoutName isEqualToString:@"Hebrew"] ||
 [keyboardLayoutName isEqualToString:@"Hebrew-QWERTY"] ||
 [keyboardLayoutName isEqualToString:@"Arabic"] ||
 [keyboardLayoutName isEqualToString:@"Arabic-PC"] ||
 [keyboardLayoutName isEqualToString:@"Arabic-QWERTY"]))
 {
 [[self firstTextView] setBaseWritingDirection:NSWritingDirectionRightToLeft];
 //NSLog(@"wD:%@ %i", keyboardLayoutName, [[self firstTextView] baseWritingDirection]);
 
 }
 
 }
 
 //	0 == right to left input specifically
 if ([[self firstTextView] baseWritingDirection] == 1)
 {
 KLGetCurrentKeyboardLayout(&keyLayout);
 if (keyLayout)
 {
 KLGetKeyboardLayoutProperty(keyLayout, kKLName, (const void **) &keyboardLayoutName);
 }
 if (keyboardLayoutName && !([keyboardLayoutName isEqualToString:@"Hebrew"] ||
 [keyboardLayoutName isEqualToString:@"Hebrew-QWERTY"] ||
 [keyboardLayoutName isEqualToString:@"Arabic"] ||
 [keyboardLayoutName isEqualToString:@"Arabic-PC"] ||
 [keyboardLayoutName isEqualToString:@"Arabic-QWERTY"]))
 {
 [[self firstTextView] setBaseWritingDirection:NSWritingDirectionLeftToRight];
 //NSLog(@"wD:%@ %i", keyboardLayoutName, [[self firstTextView] baseWritingDirection]);
 }
 }
 
 //NSLog(@"kl:%@", keyboardLayoutName);
 return;
 }
 */

@end