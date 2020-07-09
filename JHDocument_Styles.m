/*
	JHDocument_Styles.m
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
 
#import "JHDocument_Styles.h"

@implementation JHDocument ( JHDocument_Styles )

#pragma mark -
#pragma mark ---- Styles: Copy, Paste, Select ----

// ******************* Styles: Copy, Paste, Select *******************

/*
 based on sender tag; copys or pastes or selects text based on attributes
 idea: selection panel with checkboxes for different types of matching selections
 */
-(IBAction) copyAndPasteFontOrRulerAction:(id)sender
{
	//COPY FONTNAME+FONTSIZE STYLE TO PASTEBOARD 
	if ([sender tag]==0) 
	{
		if ([[[[self layoutManager] textStorage] string] length] > 0)
			[[self firstTextView] copyFont:nil];
	}
	//COPY RULER STYLE TO PASTEBOARD 
	else if ([sender tag]==1)
	{
		if ([[[[self layoutManager] textStorage] string] length] > 0)
			[[self firstTextView] copyRuler:nil];
	}
	//GOES THROUGH THE SELECTEDRANGES OF TEXT AND PASTES THE PASTEBOARD FONT STYLE
	else if ([sender tag]==2)
	{
		NSArray *theRangeArray = [[self firstTextView] selectedRanges];
		NSEnumerator *rangeEnumerator = [theRangeArray objectEnumerator];
		id aRange;
		while (aRange = [rangeEnumerator nextObject])
		{
			[[self firstTextView] setSelectedRange:[aRange rangeValue]];
			[[self firstTextView] pasteFont:nil];
		}
	}
	//GOES THROUGH THE SELECTEDRANGES OF TEXT AND PASTES THE PASTEBOARD RULER STYLE
	else if ([sender tag]==3)
	{
		NSArray *theRangeArray = [[self firstTextView] selectedRanges];
		NSEnumerator *rangeEnumerator = [theRangeArray objectEnumerator];
		id aRange;
		while (aRange = [rangeEnumerator nextObject])
		{
			[[self firstTextView] setSelectedRange:[aRange rangeValue]];
			[[self firstTextView] pasteRuler:nil];
		}
	}
	//COPY FONT AND RULER STYLES TO RESPECTIVE PASTEBOARDS
	else if ([sender tag]==4)
	{ 		
		if ([[[[self layoutManager] textStorage] string] length] > 0) {
			[[self firstTextView] copyFont:nil];
			[[self firstTextView] copyRuler:nil];
		}
	}
	//GOES THROUGH THE SELECTEDRANGES OF TEXT AND PASTES THE FONT AND RULER STYLE
	//		IN THE FONT AND RULER PASTEBOARD TO EACH WHOLE PARAGRAPH CONTAINING PART OF EACH RANGE
	else if ([sender tag]==5)
	{
		NSArray *theRangeArray = [[self firstTextView] selectedRanges];
		NSEnumerator *rangeEnumerator = [theRangeArray objectEnumerator];
		id aRange;
		while (aRange = [rangeEnumerator nextObject])
		{
			[[self firstTextView] setSelectedRange:[aRange rangeValue]];
			[[self firstTextView] selectParagraph:nil];
			[[self firstTextView] pasteFont:nil];
			[[self firstTextView] pasteRuler:nil];
		}
		[[self firstTextView] setSelectedRanges:theRangeArray];
	}
	//SELECT RANGES OF TEXT WHICH MATCH FONT STYLE (NAME AND SIZE) AT THE INDEX (ie, NSFontAttributeNameAttributeName)
	else if ([sender tag]==6)
	{ 
		NSTextView *theTextView = [self firstTextView];
		NSString *theString = [[[self layoutManager] textStorage] string];
		//make sure there is a font to match (not last character, not empty)
		if ([theTextView selectedRange].location==[theString length] || [theString length] < 1) {
			NSBeep();
			return;
		} 
		//get NSFontAttributeName at index
		NSDictionary *theAttributes = [[[self layoutManager] textStorage] attributesAtIndex:[theTextView selectedRange].location effectiveRange:NULL];
		NSFont *theFont = [theAttributes objectForKey: NSFontAttributeName];
		int theStringLength = [theString length];
		int charIndex = 0;
		BOOL rangeIsOpen = NO;
		NSRange theMatchingFontRange = NSMakeRange(0,0);
		NSMutableArray *theSelectionRangesArray = [NSMutableArray arrayWithCapacity:0];
		
		//iterate through string, looking for ranges of text where NSFontAttributeName match the index
		while (charIndex < theStringLength)
		{
			NSDictionary *theIndexAttributes = [[[self layoutManager] textStorage] attributesAtIndex:charIndex effectiveRange:NULL];
			//matches...note index for creation of range and leave range 'open'
			if ([theFont isEqualTo:[theIndexAttributes objectForKey: NSFontAttributeName]] && rangeIsOpen==NO) {
				theMatchingFontRange = NSMakeRange(charIndex, 1);
				rangeIsOpen = YES;
				//matches and range is open so iterate to next char
			} else if ([theFont isEqualTo:[theIndexAttributes objectForKey: NSFontAttributeName]] && rangeIsOpen==YES) {
				theMatchingFontRange.length = theMatchingFontRange.length + 1;		
				//doesn't match and range is open, so close range and note length
			} else if (![theFont isEqualTo:[theIndexAttributes objectForKey: NSFontAttributeName]] && rangeIsOpen==YES) {
				unichar newLineUnichar = 0x000a;
				newLineChar = [[[NSString alloc] initWithCharacters:&newLineUnichar length:1] autorelease];
				NSString *initialChar = [[[self textStorage] string] substringWithRange:NSMakeRange(theMatchingFontRange.location, 1)];
				if ([initialChar isEqualToString:newLineChar]) {
					//scooch range.location forward one character to avoid newLineChar, which will drag previous line
					//	into any paragraph attribute change, which we don't want
					if (theMatchingFontRange.length > 1) {
						theMatchingFontRange.location = theMatchingFontRange.location + 1;
						theMatchingFontRange.length = theMatchingFontRange.length - 1;
					}
				}
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
				rangeIsOpen = NO;
			}
			charIndex = charIndex++;
			//end of text and a range is still open, so close it
			if (charIndex == theStringLength && rangeIsOpen==YES) {
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
			}
		}
		//use array of ranges to select areas of text in textView	
		[theTextView setSelectedRanges:theSelectionRangesArray];
		
	}
	//SELECT BY PARAGRAPH STYLE (NSParagraphStyle) = SELECT BY RULER
	else if ([sender tag]==7)
	{
		NSParagraphStyle *theCurrentParagraphStyle = [textStorage attribute:NSParagraphStyleAttributeName 
																	atIndex:[[self firstTextView] selectedRange].location
															 effectiveRange:NULL];
		NSTextView *theTextView = [self firstTextView];
		NSArray *theParagraphArray = [[[self layoutManager] textStorage] paragraphs];
		NSRange theSubParagraphRange;
		int theSubRangeIndex = 0;
		NSEnumerator *paragraphEnumerator = [theParagraphArray objectEnumerator];
		NSMutableArray *theSelectionRangesArray = [NSMutableArray arrayWithCapacity:0];
		id aParagraph;
		//examine each paragraph
		while (aParagraph = [paragraphEnumerator nextObject])
		{
			NSParagraphStyle *theSubParagraphStyle = [aParagraph attribute:NSParagraphStyleAttributeName 
																   atIndex:0
													 longestEffectiveRange:&theSubParagraphRange
																   inRange:NSMakeRange(0, [aParagraph length]) ];
			
			//if paragraphStyle matches index paragraphStyle, add paragraph to the array
			if ([theCurrentParagraphStyle isEqualTo:theSubParagraphStyle])
			{
				[theSelectionRangesArray addObject:[NSValue valueWithRange:NSMakeRange(theSubRangeIndex, theSubParagraphRange.length)]];
			}
			theSubRangeIndex = theSubRangeIndex + [aParagraph length];
		}
		//use array of ranges to select areas of text in textView	
		[theTextView setSelectedRanges:theSelectionRangesArray];
	}
	//SELECT RANGES OF TEXT WHICH MATCH THE FONTFAMILY AT THE INDEX, ie [aFont fontFamily]
	//SELECTION WILL INCLUDE INTALIC, BOLD, ETC FOR FONTFAMILYS WITH SEPARATE FONTS FOR THOSE STYLES
	else if ([sender tag]==8)
	{ 
		NSTextView *theTextView = [self firstTextView];
		NSString *theString = [[[self layoutManager] textStorage] string];
		//get NSFontAttributeName at index
		NSDictionary *theAttributes = [[[self layoutManager] textStorage] attributesAtIndex:[theTextView selectedRange].location effectiveRange:NULL];
		NSFont *theFont = [theAttributes objectForKey: NSFontAttributeName];
		NSString *theFontFamilyName = [theFont familyName];
		int theStringLength = [theString length];
		int charIndex = 0;
		BOOL rangeIsOpen = NO;
		NSRange theMatchingFontRange = NSMakeRange(0,0);
		NSMutableArray *theSelectionRangesArray = [NSMutableArray arrayWithCapacity:0];
		
		//iterate through string, looking for ranges of text where NSFontAttributeName match the index
		while (charIndex < theStringLength)
		{
			NSDictionary *theIndexAttributes = [[[self layoutManager] textStorage] attributesAtIndex:charIndex effectiveRange:NULL];
			NSString *theCurrentFontFamilyName = [[theIndexAttributes objectForKey: NSFontAttributeName] familyName]; 
			
			//matches...note index for creation of range and leave range 'open'
			if ([theFontFamilyName isEqualTo:theCurrentFontFamilyName] && rangeIsOpen==NO)
			{
				theMatchingFontRange = NSMakeRange(charIndex, 1);
				rangeIsOpen = YES;
			}
			//matches and range is open so iterate to next char
			else if ([theFontFamilyName isEqualTo:theCurrentFontFamilyName] && rangeIsOpen==YES)
			{
				theMatchingFontRange.length = theMatchingFontRange.length + 1;		
			}
			//doesn't match and range is open, so close range and note length
			else if (![theFontFamilyName isEqualTo:theCurrentFontFamilyName] && rangeIsOpen==YES)
			{
				unichar newLineUnichar = 0x000a;
				newLineChar = [[[NSString alloc] initWithCharacters:&newLineUnichar length:1] autorelease];
				NSString *initialChar = [[[self textStorage] string] substringWithRange:NSMakeRange(theMatchingFontRange.location, 1)];
				if ([initialChar isEqualToString:newLineChar])
				{
					//	scooch range.location forward one character to avoid newLineChar, which will drag previous line
					//	into any paragraph attribute change, which we don't want
					if (theMatchingFontRange.length > 1)
					{
						theMatchingFontRange.location = theMatchingFontRange.location + 1;
						theMatchingFontRange.length = theMatchingFontRange.length - 1;
					}
				}
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
				rangeIsOpen = NO;
			}
			charIndex = charIndex++;
			//end of text and a range is still open, so close it
			if (charIndex == theStringLength && rangeIsOpen==YES)
			{
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
			}
		}
		//use array of ranges to select areas of text in textView	
		[theTextView setSelectedRanges:theSelectionRangesArray];
	}
	//SELECT RANGES OF TEXT WHICH MATCH THE FONTSIZE AT THE INDEX, ie [aFont fontSize]
	else if ([sender tag]==9)
	{ 
		NSTextView *theTextView = [self firstTextView];
		NSString *theString = [[[self layoutManager] textStorage] string];
		//	get NSFontAttributeName at index
		NSDictionary *theAttributes = [[[self layoutManager] textStorage] attributesAtIndex:[theTextView selectedRange].location effectiveRange:NULL];
		NSFont *theFont = [theAttributes objectForKey: NSFontAttributeName];
		float indexPointSize = [theFont pointSize];
		int theStringLength = [theString length];
		int charIndex = 0;
		BOOL rangeIsOpen = NO;
		NSRange theMatchingFontRange = NSMakeRange(0,0);
		NSMutableArray *theSelectionRangesArray = [NSMutableArray arrayWithCapacity:0];
		
		//	iterate through string, looking for ranges of text where NSFontAttributeName match the index
		while (charIndex < theStringLength)
		{
			NSDictionary *theIndexAttributes = [textStorage attributesAtIndex:charIndex effectiveRange:NULL];
			float currentPointSize = 0;
			currentPointSize = [[theIndexAttributes objectForKey: NSFontAttributeName] pointSize]; 
			//matches...note index for creation of range and leave range 'open'
			if (indexPointSize==currentPointSize && rangeIsOpen==NO)
			{
				theMatchingFontRange = NSMakeRange(charIndex, 1);
				rangeIsOpen = YES;
			}
			//matches and range is open so iterate to next char
			else if (indexPointSize==currentPointSize && rangeIsOpen==YES)
			{
				theMatchingFontRange.length = theMatchingFontRange.length + 1;		
			}
			//doesn't match and range is open, so close range and note length
			else if (!(indexPointSize==currentPointSize) && rangeIsOpen==YES)
			{
				unichar newLineUnichar = 0x000a;
				newLineChar = [[[NSString alloc] initWithCharacters:&newLineUnichar length:1] autorelease];
				NSString *initialChar = [[[self textStorage] string] substringWithRange:NSMakeRange(theMatchingFontRange.location, 1)];
				if ([initialChar isEqualToString:newLineChar])
				{
					//scooch range.location forward one character to avoid newLineChar, which will drag previous line
					//	into any paragraph attribute change, which we don't want
					if (theMatchingFontRange.length > 1)\
					{
						theMatchingFontRange.location = theMatchingFontRange.location + 1;
						theMatchingFontRange.length = theMatchingFontRange.length - 1;
					}
				}
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
				rangeIsOpen = NO;
			}
			charIndex = charIndex++;
			//	end of text and a range is still open, so close it
			if (charIndex == theStringLength && rangeIsOpen==YES)
			{
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
			}
		}
		//	use array of ranges to select areas of text in textView	
		[theTextView setSelectedRanges:theSelectionRangesArray];
	}
	//SELECT RANGES OF TEXT WHICH MATCH FONT FOREGROUND COLOR AT THE INDEX (ie, NSForegroundColorAttributeName)
	else if ([sender tag]==10)
	{
		NSTextView *theTextView = [self firstTextView];
		NSString *theString = [[[self layoutManager] textStorage] string];
		//get NSFontAttributeName at index
		NSDictionary *theAttributes = [[[self layoutManager] textStorage] attributesAtIndex:[theTextView selectedRange].location effectiveRange:NULL];
		NSColor *theColor = [theAttributes objectForKey: NSForegroundColorAttributeName];
		int theStringLength = [theString length];
		int charIndex = 0;
		BOOL rangeIsOpen = NO;
		NSRange theMatchingFontRange = NSMakeRange(0,0);
		NSMutableArray *theSelectionRangesArray = [NSMutableArray arrayWithCapacity:0];
		
		//iterate through string, looking for ranges of text where NSFontAttributeName match the index
		while (charIndex < theStringLength)
		{
			NSDictionary *theIndexAttributes = [[[self layoutManager] textStorage] attributesAtIndex:charIndex effectiveRange:NULL];
			//matches...note index for creation of range and leave range 'open'
			//NOTE that theColor doesn't work for blackColor; it becomes !theColor, so we check for that to account for the 'color black
			if (([theColor isEqualTo:[theIndexAttributes objectForKey: NSForegroundColorAttributeName]]  
				 || !theColor && ![theIndexAttributes objectForKey: NSForegroundColorAttributeName])
				&& rangeIsOpen==NO)
			{
				theMatchingFontRange = NSMakeRange(charIndex, 1);
				rangeIsOpen = YES;
			}
			//matches and range is open so iterate to next char
			else if (([theColor isEqualTo:[theIndexAttributes objectForKey: NSForegroundColorAttributeName]] 
					  || !theColor && ![theIndexAttributes objectForKey: NSForegroundColorAttributeName]) 
					 && rangeIsOpen==YES)
			{
				theMatchingFontRange.length = theMatchingFontRange.length + 1;		
			}
			//doesn't match and range is open, so close range and note length
			else if ((![theColor isEqualTo:[theIndexAttributes objectForKey: NSForegroundColorAttributeName]] 
					  || !theColor && ![theIndexAttributes objectForKey: NSForegroundColorAttributeName])
					 && rangeIsOpen==YES)
			{
				unichar newLineUnichar = 0x000a;
				newLineChar = [[[NSString alloc] initWithCharacters:&newLineUnichar length:1] autorelease];
				NSString *initialChar = [[[self textStorage] string] substringWithRange:NSMakeRange(theMatchingFontRange.location, 1)];
				if ([initialChar isEqualToString:newLineChar])
				{
					//scooch range.location forward one character to avoid newLineChar, which will drag previous line into any paragraph attribute change, which we don't want
					if (theMatchingFontRange.length > 1)
					{
						theMatchingFontRange.location = theMatchingFontRange.location + 1;
						theMatchingFontRange.length = theMatchingFontRange.length - 1;
					}
				}
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
				rangeIsOpen = NO;
			}
			charIndex = charIndex++;
			//	end of text and a range is still open, so close it
			if (charIndex == theStringLength && rangeIsOpen==YES)
			{
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
			}
		}
		if ([theSelectionRangesArray count]==0)
		{
			// NSColor blackColor doesn't work with above routine, so we 
			[theTextView setSelectedRange:NSMakeRange(0, theStringLength)];
		}
		else
		{
			//use array of ranges to select areas of text in textView	
			[theTextView setSelectedRanges:theSelectionRangesArray];
		}
	}
	//SELECT RANGES OF TEXT WHICH MATCH HIGHLIGHT COLOR AT THE INDEX (ie, NSBackgroundColorAttributeName)
	else if ([sender tag]==11)
	{ 
		NSTextView *theTextView = [self firstTextView];
		NSString *theString = [[[self layoutManager] textStorage] string];
		//get NSFontAttributeName at index
		NSDictionary *theAttributes = [[[self layoutManager] textStorage] attributesAtIndex:[theTextView selectedRange].location effectiveRange:NULL];
		NSColor *theColor = [theAttributes objectForKey: NSBackgroundColorAttributeName];
		//NOTE: we can also match by lack of highlight
		int theStringLength = [theString length];
		int charIndex = 0;
		BOOL rangeIsOpen = NO;
		NSRange theMatchingFontRange = NSMakeRange(0,0);
		NSMutableArray *theSelectionRangesArray = [NSMutableArray arrayWithCapacity:0];
		
		//iterate through string, looking for ranges of text where NSFontAttributeName match the index
		while (charIndex < theStringLength)
		{
			NSDictionary *theIndexAttributes = [[[self layoutManager] textStorage] attributesAtIndex:charIndex effectiveRange:NULL];
			//matches...note index for creation of range and leave range 'open'
			if (([theColor isEqualTo:[theIndexAttributes objectForKey: NSBackgroundColorAttributeName]]  
				 || !theColor && ![theIndexAttributes objectForKey: NSBackgroundColorAttributeName])
				&& rangeIsOpen==NO)
			{
				theMatchingFontRange = NSMakeRange(charIndex, 1);
				rangeIsOpen = YES;
			}
			//matches and range is open so iterate to next char
			else if (([theColor isEqualTo:[theIndexAttributes objectForKey: NSBackgroundColorAttributeName]] 
					  || !theColor && ![theIndexAttributes objectForKey: NSBackgroundColorAttributeName]) 
					 && rangeIsOpen==YES)
			{
				theMatchingFontRange.length = theMatchingFontRange.length + 1;		
			}
			//doesn't match and range is open, so close range and note length
			else if ((![theColor isEqualTo:[theIndexAttributes objectForKey: NSBackgroundColorAttributeName]] 
					  || !theColor && ![theIndexAttributes objectForKey: NSBackgroundColorAttributeName])
					 && rangeIsOpen==YES)
			{
				unichar newLineUnichar = 0x000a;
				newLineChar = [[[NSString alloc] initWithCharacters:&newLineUnichar length:1] autorelease];
				NSString *initialChar = [[[self textStorage] string] substringWithRange:NSMakeRange(theMatchingFontRange.location, 1)];
				if ([initialChar isEqualToString:newLineChar])
				{
					//scooch range.location forward one character to avoid newLineChar, which will drag previous line into any paragraph attribute change, which we don't want
					if (theMatchingFontRange.length > 1)
					{
						theMatchingFontRange.location = theMatchingFontRange.location + 1;
						theMatchingFontRange.length = theMatchingFontRange.length - 1;
					}
				}
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
				rangeIsOpen = NO;
			}
			charIndex = charIndex++;
			//	end of text and a range is still open, so close it
			if (charIndex == theStringLength && rangeIsOpen==YES)
			{
				[theSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
			}
		}
		//	use array of ranges to select areas of text in textView	
		[theTextView setSelectedRanges:theSelectionRangesArray];
	}
	//SELECT BY PARAGRAPH STYLE (NSParagraphStyle) AND FONT STYLE at INDEX = SELECT BY FONT/RULER
	//	TO DO : BY FONT FAMILY AND SIZE, NOT JUST FONT (OMITS ITALS AND BOLD)
	else if ([sender tag]==12 || [sender tag]==13)
	{
		NSTextView *theTextView = [self firstTextView];
		NSString *theString = [[[self layoutManager] textStorage] string];
		//make sure there is a font to match (not last character, not empty)
		if ([theTextView selectedRange].location==[theString length] || [theString length] < 1) {
			NSBeep();
			return;
		}		
		NSParagraphStyle *theCurrentParagraphStyle = [textStorage attribute:NSParagraphStyleAttributeName 
																	atIndex:[[self firstTextView] selectedRange].location
															 effectiveRange:NULL];
		NSArray *theParagraphArray = [[[self layoutManager] textStorage] paragraphs];
		NSRange theSubParagraphRange;
		int theSubRangeIndex = 0;
		NSEnumerator *paragraphEnumerator = [theParagraphArray objectEnumerator];
		NSMutableArray *theSelectionRangesArray = [NSMutableArray arrayWithCapacity:0];
		id aParagraph;
		//examine each paragraph
		while (aParagraph = [paragraphEnumerator nextObject])
		{
			NSParagraphStyle *theSubParagraphStyle = [aParagraph attribute:NSParagraphStyleAttributeName 
																   atIndex:0
													 longestEffectiveRange:&theSubParagraphRange
																   inRange:NSMakeRange(0, [aParagraph length]) ];
			
			//if paragraphStyle matches index paragraphStyle, add paragraph to the array
			if ([theCurrentParagraphStyle isEqualTo:theSubParagraphStyle])
			{
				[theSelectionRangesArray addObject:[NSValue valueWithRange:NSMakeRange(theSubRangeIndex, theSubParagraphRange.length)]];
			}
			theSubRangeIndex = theSubRangeIndex + [aParagraph length];
		}		
		
		//get NSFontAttributeName at index
		NSDictionary *theAttributes = [[[self layoutManager] textStorage] attributesAtIndex:[theTextView selectedRange].location effectiveRange:NULL];
		NSFont *theFont = [theAttributes objectForKey: NSFontAttributeName];
		float indexPointSize = [theFont pointSize];
		NSString *theFontFamilyName = [theFont familyName];
		BOOL rangeIsOpen = NO;
		NSRange theMatchingFontRange = NSMakeRange(0,0);
		NSMutableArray *newSelectionRangesArray = [NSMutableArray arrayWithCapacity:0];
		
		//	we don't need to release anything later
		if ([theSelectionRangesArray count]==0) { return; }
		
		//iterate through string, looking for ranges of text where NSFontAttributeName match the index
		NSEnumerator *enumerator = [theSelectionRangesArray objectEnumerator];
		id theRangeValue;
		while (theRangeValue = [enumerator nextObject])
		{
			int charIndex = [theRangeValue rangeValue].location;
			int theStringLength = [theRangeValue rangeValue].location + [theRangeValue rangeValue].length;
			while (charIndex < theStringLength)
			{
				//	narrow selection by font attr (font style + size)
				if ([sender tag]==12)
				{
					NSDictionary *theIndexAttributes = [[[self layoutManager] textStorage] attributesAtIndex:charIndex effectiveRange:NULL];
					//matches...note index for creation of range and leave range 'open'
					if ([theFont isEqualTo:[theIndexAttributes objectForKey: NSFontAttributeName]] && rangeIsOpen==NO)
					{
						//font matches (always should here!) and range is open so examine next char
						theMatchingFontRange = NSMakeRange(charIndex, 1);
						rangeIsOpen = YES;
					}
					else if ([theFont isEqualTo:[theIndexAttributes objectForKey: NSFontAttributeName]] && rangeIsOpen==YES)
					{
						//font matches and range if open, so examine next char
						theMatchingFontRange.length = theMatchingFontRange.length + 1;		
					}
					else if (![theFont isEqualTo:[theIndexAttributes objectForKey: NSFontAttributeName]] && rangeIsOpen==YES)
					{
						//doesn't match and range is open, so close range and note length
						[newSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
						rangeIsOpen = NO;
					}
					charIndex = charIndex++;
					//end of text and a range is still open, so close it
					if (charIndex == theStringLength && rangeIsOpen==YES)
					{
						[newSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
						rangeIsOpen = NO;
					}
				}
				//	narrow selection by font family + size
				else if ([sender tag]==13)
				{
					NSDictionary *theIndexAttributes = [[[self layoutManager] textStorage] attributesAtIndex:charIndex effectiveRange:NULL];
					float currentPointSize = 0;
					currentPointSize = [[theIndexAttributes objectForKey: NSFontAttributeName] pointSize]; 
					NSString *theCurrentFontFamilyName = [[theIndexAttributes objectForKey: NSFontAttributeName] familyName]; 
					
					//matches...note index for creation of range and leave range 'open'
					if ([theFontFamilyName isEqualTo:theCurrentFontFamilyName] 
						&& indexPointSize==currentPointSize
						&& rangeIsOpen==NO)
					{
						//font matches (always should here!) and range is open so examine next char
						theMatchingFontRange = NSMakeRange(charIndex, 1);
						rangeIsOpen = YES;
					}
					else if ([theFontFamilyName isEqualTo:theCurrentFontFamilyName]
							 && indexPointSize==currentPointSize
							 && rangeIsOpen==YES)
					{
						//font matches and range if open, so examine next char
						theMatchingFontRange.length = theMatchingFontRange.length + 1;		
					}
					else if (!([theFontFamilyName isEqualTo:theCurrentFontFamilyName]
							   && indexPointSize==currentPointSize)
							 && rangeIsOpen==YES)
					{
						//doesn't match and range is open, so close range and note length
						[newSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
						rangeIsOpen = NO;
					}
					charIndex = charIndex++;
					//end of text and a range is still open, so close it
					if (charIndex == theStringLength && rangeIsOpen==YES)
					{
						[newSelectionRangesArray addObject:[NSValue valueWithRange:theMatchingFontRange]];
						rangeIsOpen = NO;
					}
				}
			}
		}
		//use array of ranges to select areas of text in textView
		if ([newSelectionRangesArray count] != 0)
		{
			[theTextView setSelectedRanges:newSelectionRangesArray];
		}
	}
}

#pragma mark -
#pragma mark ---- Styles Menu Methods ----

// ******************* Styles Menu Methods *******************

//	extract string from textStorage, remove attachments, reset testView with new revised string, then apply vanilla attributes
//	NOTE: this is functionally equivalent to a 'feature' users have been requesting to be copied from Text Edit, namely: Format > Make Plain Text then back again to rich as a way of striping all attributes (so, we do not work with ranges, but rather the whole text) 
-(IBAction)removeAllStylesAction:(id)sender
{
	//	menu item validated only for text length > 0
	NSTextView *tv = [self firstTextView];
	NSMutableString *theString = [NSMutableString stringWithCapacity:[textStorage length]];
	//	make mutable string based on textStorage
	[theString setString:[textStorage string]];
	//	remember selectedRange -- we use .location to restore the insertion point later, adjusting for lost attachments!
	//	NOTE: we should probably leave the whole document selected since whole document is change, but then insertion point index would be lost to the user, and it will be obvios that the whole document was changed
	NSRange oldRange = [tv selectedRange];
	//	remove attachments characters, tracking how many so we can adjust selectedRange.location for resetting insertion point later
	int attachmentsRemoved =[theString replaceOccurrencesOfString:[NSString stringWithFormat:@"%C", NSAttachmentCharacter] withString:@"" options:0 range:NSMakeRange(0, oldRange.location)];
	//	remaining range to check for attachments AND new selectedRange.location
	NSRange newRange = NSMakeRange(oldRange.location - attachmentsRemoved, [textStorage length] - oldRange.location - attachmentsRemoved);
	//	finish replacing attachment characters with @""
	[theString replaceOccurrencesOfString:[NSString stringWithFormat:@"%C", NSAttachmentCharacter] withString:@"" options:0 range: newRange];
	//	for undo
	[tv shouldChangeTextInRange:NSMakeRange(0, [textStorage length]) replacementString:theString];
	//	use it as the text view text
	[tv setString:theString];
	//	close undo bracket
	[tv didChangeText];
	
	//	default paragraphStyle
	NSParagraphStyle *theParagraphStyle = [NSParagraphStyle defaultParagraphStyle];
	//	a default font
	NSFont *theFont = [NSFont fontWithName:@"Helvetica" size:0.0];
	//on error, set to default system font
	if (theFont == nil) theFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	//	now, scrub attributes
	NSMutableDictionary *theAttributes = [[NSMutableDictionary alloc] initWithCapacity:2];
	//	add changed paragraphStyle to Attrs
	if (theParagraphStyle) [theAttributes setObject:theParagraphStyle forKey:NSParagraphStyleAttributeName];
	//	add font to Attrs
	if (theFont) [theAttributes setObject:theFont forKey:NSFontAttributeName];
	
	//	for undo
	[tv shouldChangeTextInRange:NSMakeRange(0, [textStorage length]) replacementString:NULL];
	//	apply modified Attrs to total text
	[textStorage setAttributes:theAttributes range:NSMakeRange(0, [textStorage length])];
	//	close undo bracket
	[tv didChangeText];
	//	undo label
	[[self undoManager] setActionName:NSLocalizedString(@"undo action: Remove All Styles", @"undo action: Remove All Styles")];
	//	restore previous (recalculated) selectedRange.location
	[tv setSelectedRange:NSMakeRange(newRange.location, 0)];
	[tv scrollRangeToVisible:[tv selectedRange]];
	//	set typing attributes
	[[self firstTextView] setTypingAttributes:theAttributes];
	//	cleanup
	[theAttributes release];
}

//	match all text / selection in doc to style at index, minus any tables
-(IBAction)matchToSelectionAction:(id)sender;
{
	NSTextView *tv = [self firstTextView];
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSRange rangeToChange;
	// we need to note insertion point, because that is where we get paragraphStyle and font to apply to selection / all text
	NSRange origRange = [tv selectedRange];
	
	//	if selection, change it; otherwise change all
	if ([tv selectedRange].length) { rangeToChange = [tv selectedRange]; }
	else { rangeToChange = NSMakeRange(0, [textStorage length]); }	
	
	//	paragraphStyle
	NSParagraphStyle *theStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:origRange.location effectiveRange:NULL];
	NSMutableParagraphStyle *mutableStyle = [theStyle mutableCopy];
	//	get rid of tables - they tend to be copied over from HTML and can easily screw up multicontainer views
	[mutableStyle setTextBlocks:nil];
	//	apply new paragraph style to rangeToChange (bracket with 'undo' pair)
	[tv shouldChangeTextInRange:rangeToChange replacementString:NULL];
	[textStorage addAttribute:NSParagraphStyleAttributeName value:mutableStyle range:rangeToChange];
	[tv didChangeText];
	//	cleanup
	[mutableStyle release];
	
	//	font
	NSFont *theFont = [textStorage attribute:NSFontAttributeName atIndex:origRange.location effectiveRange:NULL];
	//	apply a converted version of the saved font if a range has a different font 
	NSRange theRange;
	int index = rangeToChange.location;
	//	for undo
	[tv shouldChangeTextInRange:rangeToChange replacementString:NULL];
	while (index < rangeToChange.location + rangeToChange.length)
	{
		// get font from range
		NSFont *someFont = [textStorage attribute:NSFontAttributeName atIndex:index effectiveRange:&theRange];
		//	make font == default but save traits (bold, ital) if possible
		NSFont *newFont = [fontManager convertFont:someFont toFamily:[theFont familyName]];
		index = theRange.location + theRange.length;
		//	intersecton of range to change and found attribute range so change doesn't overstep selection
		theRange = NSIntersectionRange(theRange, rangeToChange);
		//	apply the font (attachments won't return a font, so make sure there is one)
		if (newFont) [textStorage addAttribute:NSFontAttributeName value:newFont range:theRange];
	}
	[tv didChangeText];
	[[self undoManager] setActionName:NSLocalizedString(@"undo action: Match Style at Text Cursor", @"undo action: Match Style at Text Cursor")];
}

//	apply font and ruler prefs to text in doc or selection
-(IBAction)applyDefaultStyleAction:(id)sender;
{
	//	menu item validated only for text length > 0
	NSTextView *tv = [self firstTextView];
	//	get user prefs
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	//	create DEFAULT PARAGRAPH STYLE
	//	make mutable paragraphStyle and set default attributes
	NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	//	settings for rich text...
	if ([tv isRichText] || (![tv isRichText] && [defaults boolForKey:@"prefApplyToText"]))
	{
		//	get line spacing attribute from defaults in preferences
		switch ([defaults integerForKey:@"prefDefaultLineSpacing"]) //binding is selectedTag
		{
			case 0: //single space
				[theParagraphStyle setLineHeightMultiple:1.0];
				break;
			case 2: //double space
				[theParagraphStyle setLineHeightMultiple:2.0];
				break;
			case 3: //1.2 space
				[theParagraphStyle setLineHeightMultiple:1.2];
				break;
			default: //1.5 space
				[theParagraphStyle setLineHeightMultiple:1.5];
				break;
		}
		//	get first line indent from defaults in preferences
		float firstLineIndent = 0;
		firstLineIndent = [defaults boolForKey:@"prefIsMetric"]
		? [[defaults valueForKey:@"prefDefaultFirstLineIndent"] floatValue] * 28.35 
		: [[defaults valueForKey:@"prefDefaultFirstLineIndent"] floatValue] * 72.0;
		if (firstLineIndent) { [theParagraphStyle setFirstLineHeadIndent:firstLineIndent]; }
	}
	//	and for plain text (if plain text is treated like code, not rich text according to Prefs) 
	else
	{
		[theParagraphStyle setLineHeightMultiple:1.0];
	}
	//	get rid of troublesome tables! (copied from web pages, usually)
	[theParagraphStyle setTextBlocks:nil];
	
	//	create DEFAULT FONT STYLE
	NSString *textFontName = nil;
	NSFont *aFont = nil;
	float textFontSize = 0;
	//	for plain text...
	if (![tv isRichText])
	{
		//	retrieve the preferred font and size from user prefs
		textFontName = [defaults valueForKey:@"prefPlainTextFontName"];
		textFontSize = [[defaults valueForKey:@"prefPlainTextFontSize"] floatValue];
		//	create that NSFont
		aFont = [NSFont fontWithName:textFontName size:textFontSize];
	}
	//	for rich text...
	else
	{
		//	retrieve the default font name and size from user prefs; add to dictionary
		textFontName = [defaults valueForKey:@"prefRichTextFontName"];
		textFontSize = [[defaults valueForKey:@"prefRichTextFontSize"] floatValue];
		//	create NSFont from name and size
		aFont = [NSFont fontWithName:textFontName size:textFontSize];
	}
	//	use system font on error (Lucida Grande, it's nice)
	if (aFont == nil) aFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	
	int index;
	NSRange theRange;
	NSRange rangeToChange;
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	//	if selection, change it; otherwise change all
	if ([tv selectedRange].length)
	{ 
		rangeToChange = [tv selectedRange];
	}
	else
	{
		[tv setSelectedRange:NSMakeRange(0, [textStorage length])];
		rangeToChange = NSMakeRange(0, [textStorage length]);
	}	
	
	//	we do this 'undo' couplet so that insertion point index will restore after undo
	[tv shouldChangeTextInRanges:[tv selectedRanges] replacementStrings:nil];
	[tv didChangeText];
	
	//	look at each paragraph's paragraphStyle
	//	NOTE: effectiveRange doesn't alwasy start at beginning of paragraph for NSParagraphStyleAttributeName (!) so we set index to actual beginning of paragraph
	//	change selected ranges to use the new NSFontAttributeName
	NSEnumerator *e = [[tv selectedRanges] objectEnumerator];
	NSValue *aRange;
	//	for selected ranges...
	while (aRange = [e nextObject])
	{
		rangeToChange = [aRange rangeValue];
		index = rangeToChange.location;
		//	apply the saved font if a range has a different font 
		while (index < rangeToChange.location + rangeToChange.length)
		{
			// get font from range
			NSFont *someFont = [textStorage attribute:NSFontAttributeName atIndex:index effectiveRange:&theRange];
			//	make font == default but save traits (bold, ital) if possible
			NSFont *newFont = [fontManager convertFont:someFont toFamily:[aFont familyName]];
			//	intersecton of range to change and found attribute range so change doesn't overstep selection
			theRange = NSIntersectionRange(theRange, rangeToChange);
			//	attachments return nil for font, so only change the font is there is one
			if (newFont)
			{
				//for undo
				[tv shouldChangeTextInRange:theRange replacementString:NULL];
				[textStorage addAttribute:NSFontAttributeName value:newFont range:theRange];
				[tv didChangeText];
			}
			index = theRange.location + theRange.length;
		}
		//apply default paragraphStyle to all text
		[tv shouldChangeTextInRange:rangeToChange replacementString:NULL];
		[textStorage addAttribute:NSParagraphStyleAttributeName value:theParagraphStyle range:rangeToChange];
		[tv didChangeText];
	}
	//	cleanup	
	[theParagraphStyle release];
	//	undo label
	[[self undoManager] setActionName:NSLocalizedString(@"undo action: Apply Default Style", @"undo action: Apply Default Style")];
}

//	find longest runs of attributes and extend them, retaining fonts within main font family
-(IBAction)simplifyStylesAction:(id)sender;
{
	int index;
	int savedLocation = 0;
	int savedLength = 0;
	NSRange theRange;
	NSRange rangeToChange = {0,0};
	NSFont *theFont = nil;
	NSParagraphStyle *theStyle = nil;
	NSMutableParagraphStyle *mutableStyle = nil;
	NSTextView *tv = [self firstTextView];
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	
	//	if selection, change it; otherwise change all
	if ([tv selectedRange].length) { rangeToChange = [tv selectedRange]; }
	else { rangeToChange = NSMakeRange(0, [textStorage length]); }	
	
	//	REMEMBER PARAGRAPH STYLE from longest stretch of similar text
	index = rangeToChange.location;
	while (index < rangeToChange.location + rangeToChange.length)
	{
		[textStorage attribute:NSParagraphStyleAttributeName atIndex:index effectiveRange:&theRange];
		// remember the location of the longest stretch of any paragraphStyle
		theRange = NSIntersectionRange(theRange, rangeToChange);
		if (theRange.length > savedLength)
		{
			savedLocation = theRange.location;
			savedLength = theRange.length;
		}
		index = theRange.location + theRange.length;
	}
	theStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:savedLocation effectiveRange:NULL];
	mutableStyle = [theStyle mutableCopy];
	//	get rid of tables - they tend to be copied over from HTML and can easily screw up multicontainer views
	[mutableStyle setTextBlocks:nil];
	
	//	REMEMBER FONT STYLE from longest stretch of similar text
	savedLocation = 0;
	savedLength = 0;
	index = rangeToChange.location;
	while (index < rangeToChange.location + rangeToChange.length)
	{
		[textStorage attribute:NSFontAttributeName atIndex:index effectiveRange:&theRange];
		//	only look within the selected range - an effectiveRange might stretch beyond selected range
		theRange = NSIntersectionRange(theRange, rangeToChange);
		if (theRange.length > savedLength)
		{
			savedLocation = theRange.location;
			savedLength = theRange.length;
			//NSLog(@"savedLocation:%i savedLength:%i", savedLocation, savedLength);
		}
		index = theRange.location + theRange.length;
	}
	theFont = [textStorage attribute:NSFontAttributeName atIndex:savedLocation effectiveRange:NULL];
	
	//	APPLY a converted version of the FONT STYLE to rangeToChange 
	
	//	if selection, change it; otherwise change all
	if ([tv selectedRange].length)
	{ 
		rangeToChange = [tv selectedRange];
	}
	else
	{
		[tv setSelectedRange:NSMakeRange(0, [textStorage length])];
		rangeToChange = NSMakeRange(0, [textStorage length]);
	}	
	
	//	we do this 'undo' couplet so that insertion point index will restore after undo
	[tv shouldChangeTextInRanges:[tv selectedRanges] replacementStrings:nil];
	[tv didChangeText];
	
	//	look at each paragraph's paragraphStyle
	//	NOTE: effectiveRange doesn't alwasy start at beginning of paragraph for NSParagraphStyleAttributeName (!) so we set index to actual beginning of paragraph
	//	change selected ranges to use the new NSFontAttributeName
	NSEnumerator *e = [[tv selectedRanges] objectEnumerator];
	NSValue *aRange;
	//	for selected ranges...
	while (aRange = [e nextObject])
	{
		rangeToChange = [aRange rangeValue];
		index = rangeToChange.location;
		//	apply the saved font if a range has a different font 
		while (index < rangeToChange.location + rangeToChange.length)
		{
			// get font from range
			NSFont *someFont = [textStorage attribute:NSFontAttributeName atIndex:index effectiveRange:&theRange];
			//	make font == default but save traits (bold, ital) if possible
			NSFont *newFont = [fontManager convertFont:someFont toFamily:[theFont familyName]];
			//	intersecton of range to change and found attribute range so change doesn't overstep selection
			theRange = NSIntersectionRange(theRange, rangeToChange);
			//	attachments return nil for font, so only change the font is there is one
			if (newFont)
			{
				//for undo
				[tv shouldChangeTextInRange:theRange replacementString:NULL];
				[textStorage addAttribute:NSFontAttributeName value:newFont range:theRange];
				[tv didChangeText];
			}
			index = theRange.location + theRange.length;
		}
		//	APPLY PARAGRAPH STYLE to rangeToChange
		
		[tv shouldChangeTextInRange:rangeToChange replacementString:NULL];
		[textStorage addAttribute:NSParagraphStyleAttributeName value:mutableStyle range:rangeToChange];
		[tv didChangeText];
	}
	//	cleanup	
	[mutableStyle release];
	//	undo label
	[[self undoManager] setActionName:NSLocalizedString(@"undo action: Match to Most Common Style", @"undo action: Match to Most Common  Style")];
}

@end