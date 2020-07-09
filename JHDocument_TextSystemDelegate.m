/*
	JHDocument_TextSystemDelegate.m
	was called JHDocumentAsDelegate.h
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
 
#import "JHDocument_TextSystemDelegate.h"
#import "JHDocument_LiveWordCount.h" //for wordCountForString, thousandFormatedStringFromNumber
#import "JHDocument_SheetAndPanelManager.h" //for showResizeImageSheetAction; showBeanSheet
#import "JHDocument_PageLayout.h" //for addPage, removePage
#import "JHDocument_TextLists.h" //listItemIndent
#import "JHDocument_Misc.h" //resizeImageToFitLayout
#import "JHDocument_View.h" //constrainScrollWithForceFlag
#import "JHDocument_Text.h" //alternate font methods
#import "RegexKitLite.h" //shouldRefreshListEnumeration

// 'first level' quotation marks for Smart Quotes
#define DOUBLE_QUOTE 0x0022
// equivalent to 'nested' quotation marks for Smart Quotes
#define SINGLE_QUOTE 0x0027 

//implements textView, textStorage, and layoutManager delegate methods
@implementation JHDocument ( JHDocument_TextSystemDelegate )

#pragma mark -
#pragma mark ---- accessors  ----

// ******************* accessors ********************

//	used in layoutManager:didCompleteLayoutForTextContainer
-(BOOL)pageWasAdded
{
	return pageWasAdded;
}

//	used in layoutManager:didCompleteLayoutForTextContainer
-(void)setPageWasAdded:(BOOL)wasPageAdded
{
	pageWasAdded = wasPageAdded;
}

#pragma mark -
#pragma mark ---- textView delegate methods ----

// ******************* textView:shouldChangeTextInRange ********************

BOOL shouldRefreshListEnumeration; // category BOOL
BOOL shouldUseCachedAttributes; // see below method

//this implements Bean's version of Smart Quotes
//	Leopard has smart quotes built in -- perhaps should eliminate this code when Bean becomes Leopard+ only
- (BOOL)textView:(NSTextView *)textView 
			shouldChangeTextInRange:(NSRange)affectedCharRange
			replacementString:(NSString *)replacementString;
{

	//Smart Quotes code based on sample code by Andrew C. Stone from the web article:
	//http:(removethis)//www.stone.com/The_Cocoa_Files/Smart_Quotes.html

	//	no replacementString means attributes change only, so skip the other stuff
	if (replacementString == nil)
		return YES;
	
	//	if typing smart quotes over smart quotes, can set up a loop that will crash Bean, so this code avoids the loop
	if (registerUndoThroughShouldChange)
	{
		[self setRegisterUndoThroughShouldChange:NO];
		return YES;
	}

	//------------------- WORKAROUND FOR TEXT LIST FONT ATTRIBUTE BUG -------------------
	//work around text system inconvenience where list item's text inherits attributes of hardcoded marker (causing spillover of Lucida Grand, often in Tiger) or inherits cached marker attributes from previous item which may not be called for by the context, since attributes are typically inherited from previous text, that is, attributes at tail end of previous list item (Leopard); we deny attribute change after marker in textView:shouldChangeTypingAttributes:
	if ([[[[textView typingAttributes] objectForKey:NSParagraphStyleAttributeName]textLists]count])
	{
		if ([replacementString length]==1
					&& [replacementString characterAtIndex:0] == NSNewlineCharacter
					&& ( affectedCharRange.location == [textStorage length]
							|| [[textStorage string] characterAtIndex:affectedCharRange.location] == NSNewlineCharacter) )
		{
			shouldUseCachedAttributes = YES;
		}
	}
	
	//------------------- PREPARE TO REFRESH LIST ENUMERATION -------------------
	//fix text system shortcoming where deleting a list item does not cause enumated lists to refresh list enumeration
	//	NOTE isEditingList (global BOOL) is set to YES in JHDoc_TextLists methods where a refresh would happen anyway
	//	TODO: fix problem where 1) list doesn't update items with indent level of less than list item deleted and 2) lists with bad hierarchies are not updated (bad hierarchies=sub items not preceded by higher level subitems)

	//	if bounds check, & textLists in affectedCharRange & !undoing & !editingList
	if (affectedCharRange.length 
				&& [[[textStorage attribute:NSParagraphStyleAttributeName atIndex:affectedCharRange.location effectiveRange:nil]textLists]count] 
				&& ![[self undoManager] isUndoing] 
				&& !isEditingList)
	{
		//and a return is included in affectedRange
		BOOL match = [[[textStorage string] substringWithRange:affectedCharRange] isMatchedByRegex:@"\n"];
		if (match)
		{
			//bounds check
			if (NSMaxRange(affectedCharRange) < [textStorage length]
						//check for where last item in list is cut and non-list text follows (refresh list enum will screws up text)
						&& [[[textStorage attribute:NSParagraphStyleAttributeName atIndex:NSMaxRange(affectedCharRange) effectiveRange:nil]textLists]count])
			{
				//list will refresh at textDidChange:
				shouldRefreshListEnumeration = YES;
			}
		}
	}

	//------------------- SMART QUOTES CODE -------------------
	//	TODO: post Leopard releases might want to delete all this Smart Quotes code and use native Smart Quotes to make things cleaner
	//	without resetting typingAttributes when isRichText==NO, you get no consistancy at all...why?
	//	19 July 2007 JH: this might be a symptom of a 'feature' of the text system--namely, that whenever you insert a character at the start of a paragraph, apparently even for plain text, insofar as the text object does plain text, the rest of the paragraphh adopts the paragraph attributes of the first character. If that object is, for instance, a drag'n'dropped image file, then there are NO attributes, which means you get nil for all the applied attribute values. Which is not good. Similarly, because NSText uses a mutable attributed string to hold its contents, random strings inserted at the head of a paragraph will overlay their nil paragraph attributes onto the rest of the text in the paragraph.
	//	Text Edit and other NSText based apps all seem to do this, which I would consider undesirable behavior. IMHO, the desireable behavior would be, if the inserted character at the start of a paragraph has nil for attributes, it adopts those of the following character, then fixAttributesInRange is run to even out any problems. But perhaps Apple wanted to maintain a consistent behavior across the board.
	
	//	note: now that we've moved to textView:insertText instead of textStorage:replaceCharactersInRange, is this needed? 10 Sept 07 JH
	//	apparently not needed, so commented out 27 JUNE 08 JH
	//	if (replacementString && ![textView isRichText]) { if (replacementString) [textView setTypingAttributes:[self oldAttributes]]; }
	
	// should we need to change the string to insert, use this mutable string to hold the new values:
	// if it's non-nil when we get done, we want to use *s instead of the replacementString!
	NSMutableString *s = nil;
	//	we need this info to deal with French (France) and French Canadian Smart Quotes
	int quoteTag = [self smartQuotesStyleTag];

	//we want to pass text for an 'undo' straight to textView so that it is not altered by code here 
	if (![[self undoManager] isUndoing])
	{
		// replacementString length == 1 could mean smartQuotes processing is needed
		if ([replacementString length]==1 && [self shouldUseSmartQuotes])
		{
			// this is what is in our text object before anything is added:
			NSString *text = [[textView textStorage] string];
			unichar affectedChar;

			//------------------- Smart Quotes Option 1: 3-WAY TOGGLE -------------------
			// 3 way toggle for quoation marks when one is typed over another:  plain -> open -> closed -> plain
			// this is where user needs, for instance, straight quotes instead of curvy to represent code, etc.
		
			unichar theReplacementChar = [replacementString characterAtIndex:0];
			if (affectedCharRange.length == 1) affectedChar = [text characterAtIndex:affectedCharRange.location];
			
			//	if a single quote is being typed over a single quote, or a double over a double, rotate the quote styles
			//	revised from previous method, which was causing a loop (insertText was calling shouldChange..., which was repeatedly using code below
			if (affectedCharRange.length == 1
						&& ((theReplacementChar == SINGLE_QUOTE
								&& (affectedChar == SINGLE_OPEN_QUOTE 
									|| affectedChar == SINGLE_CLOSE_QUOTE 
									|| affectedChar == SINGLE_QUOTE))

							|| (theReplacementChar == DOUBLE_QUOTE
								&& (affectedChar == DOUBLE_OPEN_QUOTE 
									|| affectedChar == DOUBLE_CLOSE_QUOTE 
									|| affectedChar == DOUBLE_QUOTE))))
			
			{
			
				// they had an open quote -> make it a closed one
				if (affectedChar == DOUBLE_OPEN_QUOTE || affectedChar == SINGLE_OPEN_QUOTE)
				{
					s = [NSString stringWithFormat:@"%C", theReplacementChar == DOUBLE_QUOTE ? DOUBLE_CLOSE_QUOTE : SINGLE_CLOSE_QUOTE];

				}
				// they had a closed quote -> make it straight
				else if (affectedChar == DOUBLE_CLOSE_QUOTE || affectedChar == SINGLE_CLOSE_QUOTE)
				{
					s = [NSString stringWithFormat:@"%C", theReplacementChar == DOUBLE_QUOTE ? DOUBLE_QUOTE : SINGLE_QUOTE];
				}
				// they had a straight quote -> make it open
				else if (affectedChar == SINGLE_QUOTE || affectedChar == DOUBLE_QUOTE)
				{
					s = [NSString stringWithFormat:@"%C", theReplacementChar == SINGLE_QUOTE ? SINGLE_OPEN_QUOTE : DOUBLE_OPEN_QUOTE];
				}
				//	we use this so that insertion of a smart quote below using insertText, which calls shouldChangeTextInRange to register the undo, does not call this very section of code again, which will cause a loop to occur, and cause Bean to crash 12 Sept 2007 JH
				[self setRegisterUndoThroughShouldChange:YES];
			}
			//------------------- Smart Quotes Option 2: INSERT SMART QUOTES -------------------
			// otherwise check first char of replacement string
			else
			{
				NSCharacterSet *startSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
				unichar theChar = [replacementString characterAtIndex:0];
				unichar previousChar, c;

				// use preceding character to determine open or closed quote
				unsigned int textLength = [text length];
				if (affectedCharRange.location == 0 || textLength==0) { previousChar = 0; } // first char
				else { previousChar = [text characterAtIndex:affectedCharRange.location - 1]; }

				// if STRAIGHT QUOTE , produce open or closed quote
				if ((theChar == SINGLE_QUOTE) || (theChar == DOUBLE_QUOTE))
				{

					if (previousChar == 0x00A0) //non-breaking space for French (special case) usually needs close quote 18 Aug 07
					{
						c = (theChar == SINGLE_QUOTE ? SINGLE_CLOSE_QUOTE : DOUBLE_CLOSE_QUOTE);
					}
					//added more left thingies 29 Sept 08 JH; referred to http: //www.pensee.com/dunham/smartQuotes.html
					else if (previousChar == 0 
								|| [startSet characterIsMember:previousChar] 
								|| (previousChar == DOUBLE_OPEN_QUOTE && theChar == SINGLE_QUOTE) 
								|| (previousChar == SINGLE_OPEN_QUOTE && theChar == DOUBLE_QUOTE)
								|| previousChar == '(' || previousChar == '{' || previousChar == '[')
					{
						c = (theChar == SINGLE_QUOTE ? SINGLE_OPEN_QUOTE : DOUBLE_OPEN_QUOTE);
					}
					else
					{
						c = (theChar == SINGLE_QUOTE ? SINGLE_CLOSE_QUOTE : DOUBLE_CLOSE_QUOTE);
					}
					//string is Smart Quote for insertion later in method...
					s = [NSMutableString stringWithString:[NSString stringWithFormat:@"%C", c]];
				}
				//if French (France) or French Canadian smart quotes (and punctuation) active, add the extra spacing French typography needs for ?!;: (yes, I know non-breaking spaces are not the same as the native partial cadratins)
				else if (quoteTag == 11)
				{
					switch (theChar) 
					{
						case 0x0021: //exclamation point
							{
								s = nil;
								s = [NSString stringWithFormat:@"%C%C", 0x00A0, theChar];
								break;
							}
						case 0x003F: //question mark
						{
							s = nil;
							s = [NSString stringWithFormat:@"%C%C", 0x00A0, theChar];
							break;
						}
						case 0x003A: //colon
						{
							s = nil;
							s = [NSString stringWithFormat:@"%C%C", 0x00A0, theChar];
							break;
						}
						case 0x003B: //semicolor
						{
							s = nil;
							s = [NSString stringWithFormat:@"%C%C", 0x00A0, theChar];
							break;
						}
						default:
							break;
					}
				}
				//	Canadian French just needs spacing for the :
				else if (quoteTag == 12)
				{
					if (theChar == 0x003A) //colon
					{
						s = nil;
						s = [NSString stringWithFormat:@"%C%C", 0x00A0, theChar];
					}
				}
				
			}
		}
		
		//	we insert s, the new Smart Quotes replacementString, here
		//	note: do nothing if 'straight' smart quotes (tag==1) since there is no need
		//	A. Stone says: Ideally, this method [shouldChangeText...] would return the desired attributedString, but since it doesn't, we insert the changes directly
		
		if ( s && !([self smartQuotesStyleTag]==1) )
		{
			//	if French style smart quotes, insert non-breaking spaces (yes, I know they are not partial em-spaces, but they prevent inconvenient line breaks)
			if (quoteTag == 11 || quoteTag == 12)
			{
				unichar frChar = [s characterAtIndex:0];
				if (frChar == 0x00AB) // <<
				{
					s = nil;
					s = [NSString stringWithFormat:@"%C%C", 0x00AB, 0x00A0];
				}
				else if (frChar == 0x00BB) // >>
				{
					s = nil;
					s = [NSString stringWithFormat:@"%C%C", 0x00A0, 0x00BB];
				}
			}
			
			// 25 Aug 2007 After studying the insertText method of NSTextView in GnuStep, which calls the sequence 1) shouldChangeTextInRange 2) replaceCharactersInRange 2) textDidChange which we do here, I decided to just use it; also, the problem of text being inserted into an empty textStorage and having no attributes is solved because NSTextView calls its own replaceCharactersInRange method which overlays its typing attributes, so the bugfix we added becomes unnecessary			
			[textView insertText:s];
			
			//zero out s
			s = nil;
			return NO;
		}
	}
	
	//this lets the text system insert the text as typed...
	return YES;
}

// ******************* Text Did Change Notification ********************

- (void)textDidChange:(NSNotification *)notification
{
	//NSLog(@"TEXT DID CHANGE");
		
	//only autosave if text did change since last autosave
	[self setNeedsAutosave:YES];
	
	//	BUGFIX: erasing all text leaves empty containers that don't go away until you type again; from Keith Blount's MyColumn example code
	if (0 == [textStorage length])
	{
		//remove all containers beyond 
		while ([[layoutManager textContainers] count] > [self numberColumns]) 
		{
			[self removePage:self];
		}
	}
	
	id tv = [self firstTextView];
	NSRange selRange = [tv selectedRange];
	//	save edit location for Find > Previous Edit menu action
	[self setSavedEditLocation:NSMaxRange(selRange)];
	
	//	if shouldChangeTextInRange determines list should renumerate, do it (will be part of original action's undo group)
	if (shouldRefreshListEnumeration)
	{
		shouldRefreshListEnumeration = NO;
		//calls private API, but should do nothing (ie, normal cocoa behavior) if API call is not available
		[self bean_reformListAtIndex:selRange.location];
	}
	
	//this could be an alternate location for calling the method [self constrainScrollWithForceFlag:NO];

}

//	this maintains the typingAttributes, which are ordinarilly reset to nil upon pasting an attachment (cos of a bug)
//	also fixes an inconvenience with NSTextList which resets font after marker
- (NSDictionary *)textView:(NSTextView *)aTextView
			shouldChangeTypingAttributes:(NSDictionary*)oldTypingAttributes
			toAttributes:(NSDictionary *)newTypingAttributes
{
	
	//	prevents an inserted text attachment from causing nil text attributes to follow; fix by Omni, refined by Keith Blount
	if ([newTypingAttributes objectForKey:NSAttachmentAttributeName])
		return oldTypingAttributes;

	//	here we save the typingAttributes so that when an attachment is pasted in replaceCharactersInRange in the textStorage, it is overlaid first with the typingAttributes instead of nil attributes, which makes the inspector controls go crazy among other things
	if (![[textStorage oldAttributes] isEqualTo:newTypingAttributes])
	{
		//set accessor for future use
		[textStorage setOldAttributes:newTypingAttributes];
	}
	
	//	we have some better code for this now; see shouldChangeTextInRange:replacementString: and code under if (shouldUseCachedAttributes)
	//	BUT, this code still necessary under Tiger because of annoying bug that causes marker attributes to spill over into text list items
	//	for example, make a text list with dashes as markers, return, indent, dedent, Lucida Grande is the new font for the text list item
	//	original note: this is a fix for a bug in NSTextList #5065130 that causes font to be reset to Lucida Grande after bullets, dashes, etc.
	//	code is by Philip Dow (www.cocoabuilder.com 15 March 2007)
	if ([self currentSystemVersion] < 0x1050)
	{
		NSParagraphStyle *paragraphStyle = [newTypingAttributes objectForKey:NSParagraphStyleAttributeName];
		if ( paragraphStyle != nil )
		{
			NSArray *textLists = [paragraphStyle textLists];
			if ( [textLists count] != 0 )
			{
				NSRange theSelectionRange = [aTextView selectedRange];
				if ( theSelectionRange.location >= 1 )
				{
					unichar aChar = [[aTextView string] characterAtIndex:theSelectionRange.location-1];
					if ( aChar == NSTabCharacter ) // -- and it seems to always be the case for the bug we're dealing with
					{
						NSFont *previousFont = [oldTypingAttributes objectForKey:NSFontAttributeName];
						NSString *prevFontFamily = [previousFont familyName];
						NSString *newFontFamily = [[newTypingAttributes objectForKey:NSFontAttributeName] familyName];
						//BUGFIX: if OS X 10.4, and font family has changed (potentially due to bug, but not conclusively)
						//	The problem here: typing attributes of list item are inherited from bullets, so font changes; you can restrict this change, as here, but then user can't change font family or font variation!
						//	10.5 introduced behavior where list item attributes are pulled from some previous item (can't pin down which, seems to change) to prevent unwanted change of font due to bullet creating mechanism, but this can be a regression, because sometimes you want the list item's font to continue the attributes from the END of the previous list item (this is, after all, how the text system works, eg with paragraph attributes)
						if (![prevFontFamily isEqualToString:newFontFamily])
						{
							NSMutableDictionary *betterAttributes = [[newTypingAttributes mutableCopyWithZone:[self zone]] autorelease];
							[betterAttributes setObject:previousFont forKey:NSFontAttributeName];
							return betterAttributes;
						}
					}
				}
			}
		}
	}
	
	if (shouldUseCachedAttributes)
	{
		shouldUseCachedAttributes = NO;
		return oldTypingAttributes; 
	}
	
	return newTypingAttributes;
}

- (void)textView:(NSTextView *)textView 
				doubleClickedOnCell:(id <NSTextAttachmentCell>)cell
				inRect:(NSRect)rect
				atIndex:(unsigned)charIndex
{
	//	if it's a picture, open the image slider resizing sheet
	if ([[[cell attachment] fileWrapper] isRegularFile])
	{
		//	is there an easier way to test for an image attachment here? 
		NSData *theData = [[[cell attachment] fileWrapper] regularFileContents];
		NSImage *anImage = nil;
		//	and make an NSImage from the attachment's data
		if (theData)
		{
			//made autoreleased 7 FEB 08 JH
			anImage = [[[NSImage alloc] initWithData:theData]autorelease];
		}	
		if (anImage)
		{
			//	position cursor just before clicked attachment
			[textView setSelectedRange:NSMakeRange(charIndex, 1)];
			NSControl *fakeControl = [NSControl new]; // <== init
			[fakeControl setTag:4];
			//show resize image sheet
			[self showBeanSheet:fakeControl];
			[fakeControl release]; // <== release
		}
		//	if not an image, open file in external editor
		//	note: any external changes made tot he file will be overwritten when the document is saved in Bean)
		else
		{
			BOOL success = NO;
			NSFileWrapper *fWrap = nil;
			fWrap = [[cell attachment] fileWrapper];
			//	get fileName of fileAttachment icon
			NSString *name = [fWrap filename];
			//	get path to file
			NSString *thePath = [[[self fileURL] path] stringByAppendingPathComponent:name];
			//	try to open it
			if (name && ![name isEqualToString:@""])
			{
				success = [[NSWorkspace sharedWorkspace] openFile:thePath];
			}
			if (!success)
			{
				//	from Text Edit (Leopard)
				if ([self isDocumentEdited]) {
					NSBeginAlertSheet(NSLocalizedString(@"The attached document could not be opened.", @"Title of alert indicating attached document in file could not be opened."),
									  NSLocalizedString(@"OK", @"OK"), nil, nil, [textView window], self, NULL, NULL, nil, 
									  NSLocalizedString(@"This is likely because the file has not yet been saved.  If possible, try again after saving.", @"Message indicating text attachment could not be opened, likely because document has not yet been saved."));
				}
				NSBeep();
			}
		}
	}
}

//	lifted straight from Text Edit (Leopard)
- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex
{
	NSURL *linkURL = nil;

	// Handle NSURL links
	if ([link isKindOfClass:[NSURL class]])
	{
		linkURL = link;
	}
	// Handle NSString links
	else if ([link isKindOfClass:[NSString class]])
	{
		linkURL = [NSURL URLWithString:link relativeToURL:[self fileURL]];
	}
	if (linkURL)
	{
		// Special case: We want to open text types in TextEdit, as presumably that is what was desired
		if ([linkURL isFileURL])
		{
			NSString *path = [linkURL path];
			if (path)
			{
				
				NSString *extension = [path pathExtension];
				if (extension && [[NSAttributedString textFileTypes] containsObject:extension])
				{
					if ([[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:linkURL display:YES error:nil] != nil) 
					{
						return YES;					
					}
				}
				if ([[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil]) return YES;
			}
		} 
		else
		{
			if ([[NSWorkspace sharedWorkspace] openURL:linkURL]) { return YES; }
		}
	}
	
	// We only get here on failure... Because we beep, we return YES to indicate "success", so the text system does no further processing.
	NSBeep();
	return YES;
}


//	types that can be written out to pboard
- (NSArray *)textView:(NSTextView *)view 
			writablePasteboardTypesForCell:(id <NSTextAttachmentCell>)cell
			  atIndex:(unsigned)charIndex
{
	//	this allows us to copy images, which can be opened, for instance, in Preview with File > New from Clipboard; also allows us to drag and drop file attachments (jpgs, rtfs, etc) into other docs or the Finder
	//	this is how Text Edit 5.1 (Leopard) does it
	NSString *name = [[[cell attachment] fileWrapper] filename];
	NSURL *docURL = [self fileURL];
   
	// return (docURL && [docURL isFileURL] && name) ? [NSArray arrayWithObjects: NSTIFFPboardType, NSFilenamesPboardType, nil] : nil;
	//	added some more types 2 JUL 08 JH
	//	extra types don't seem to do anything without code in tv:writeCell:atIndex:toPasteboard (except dragging file attachments to Finder)
	return (docURL && [docURL isFileURL] && name) ? [NSArray arrayWithObjects: NSTIFFPboardType, NSFilenamesPboardType, NSPDFPboardType, NSPICTPboardType, NSStringPboardType, NSFileContentsPboardType, nil] : nil;

	//	how we were doing it till 0.9.11
	// return [NSArray arrayWithObjects: NSFilenamesPboardType, NSTIFFPboardType, NSPDFPboardType, NSPICTPboardType, NSStringPboardType, NSFileContentsPboardType, nil];
}

//	types
- (BOOL)textView:(NSTextView *)view 
			//	made change from this to line below just to get rid of compiler warning...not sure how to really fix it
			//	was: writeCell:(id <NSTextAttachmentCell>)cell   
			writeCell:(NSTextAttachmentCell *)cell
			atIndex:(unsigned)charIndex
			toPasteboard:(NSPasteboard *)pboard
			type:(NSString *)type
{
	/*
	//	this is how Text Edit 5.1 (Leopard) does it
	NSString *theName = [[[cell attachment] fileWrapper] filename];
	NSURL *docURL = [self fileURL];
	if ([type isEqualToString:NSFilenamesPboardType] && theName && [docURL isFileURL]) {
		NSString *docPath = [docURL path];
		NSString *pathToAttachment = [docPath stringByAppendingPathComponent:theName];
		if (pathToAttachment) {
			[pboard setPropertyList:[NSArray arrayWithObject:pathToAttachment] forType:NSFilenamesPboardType];
			return YES;
		}
	}
	return NO;
	*/

	BOOL success = NO;
	id wrapper = [[cell attachment] fileWrapper];
	NSString *name = [wrapper filename];
	if ([type isEqualToString:NSFilenamesPboardType] && ![name isEqualToString:@""])
	{
		NSString *fullPath = [[[self fileURL] path] stringByAppendingPathComponent:name];
		[pboard setPropertyList:[NSArray arrayWithObject:fullPath] forType:NSFilenamesPboardType];
		success = YES;
	}
	//	write pictures to pasteboard as TIFF so that they can be, e.g. opened in Preview with 'New from Clipboard'
	if ([type isEqualToString:NSTIFFPboardType])
	{
		NSData *tiffData;
		//	'image not found in protocols' > recast cell as class not protocol
		if ([[cell image] isValid])
		{
			NSImage *theImage = [cell image];
			tiffData = [theImage TIFFRepresentation];
			[pboard declareTypes:[NSArray arrayWithObjects:NSTIFFPboardType, nil] owner:nil];
			[pboard setData:tiffData forType:NSTIFFPboardType];
			success = YES;
		}
		else
		{
			NSBeep();
		}
	}
	return success;
}

// if the selected ranges change to include a text selection, show the selected word and character count in the status bar with blue text
- (NSArray *)textView:(NSTextView *)aTextView
		willChangeSelectionFromCharacterRanges:(NSArray *)oldSelectedCharRanges
		toCharacterRanges:(NSArray *)newSelectedCharRanges
{
	NSRange firstRange = [[newSelectedCharRanges objectAtIndex:0] rangeValue];
	//	if there is selected text
	if (firstRange.length)
	{
		NSEnumerator *rangeEnumerator = [newSelectedCharRanges objectEnumerator];
		NSValue *rangeAsValue;
		unsigned wordCnt = 0;
		unsigned charCnt = 0;
		//	count words and characters in each selected range, adding totals as we go
		while ((rangeAsValue = [rangeEnumerator nextObject]) != nil)
		{
			NSRange range = [rangeAsValue rangeValue];
			//	we have to send wordCountForString an attributed string because nextWordFromIndex only works on attributed strings
			NSAttributedString *tempStr = [[NSAttributedString alloc] initWithString:[[textStorage string] substringWithRange:range]];
			wordCnt += [self wordCountForString:tempStr];
			charCnt += [tempStr length];
			tempStr = nil;
			[tempStr release];
		}
		//	change status bar to reflect selected word and character totals
		NSString *liveWordCountString = [ [NSString alloc] initWithFormat:@"%@ %@ %@ %@", 
			NSLocalizedString(@" Selected Words:", @"status bar label for number of words of selected text: Selected Words:"),
			[self thousandFormatedStringFromNumber:[NSNumber numberWithInt:wordCnt]],
			NSLocalizedString(@" Selected Characters:", @"status bar label for number of characters of selected text: Selected Characters:"),
			[self thousandFormatedStringFromNumber:[NSNumber numberWithInt:charCnt]] ];
		[liveWordCountField setStringValue:liveWordCountString];
		[liveWordCountString release];
		[liveWordCountField setTextColor:[NSColor blueColor]];
	}
	//	if no selected text but status text is blue (=showing selected range), then reset to usual word count
	else if ([[liveWordCountField textColor] isEqualTo:[NSColor blueColor]] && !firstRange.length)
	{
		if ([self shouldDoLiveWordCount])
		{
			//	update live word count if selected range changed and length is zero and should do word count 24 NOV 07 JH  
			[self liveWordCount:nil]; //stop showing selected range
		}
		else
		{
			//	clear out selected word count if live word count is not on 24 NOV 07 JH
			[liveWordCountField setTextColor:[NSColor darkGrayColor]];
			[liveWordCountField setObjectValue:NSLocalizedString(@"B  E  A  N", @"status bar label: B  E  A  N")];	
		}
	}
		
	//	return the usual info
	return newSelectedCharRanges;
}

- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{
	//set notes mode typingAttributes at index if notes mode is active
	id tv = [self firstTextView];
	if ([self alternateFontActive])
	{
		//isRichText check necessary?
		if ([tv isEditable] && [tv isRichText] && [[self alternateFontDictionary]count])
		{
			//mutable copy of typingAttributes
			NSMutableDictionary *altTypingAttrs = [[[tv typingAttributes]mutableCopy]autorelease];
			//add alternate font attributes
			[altTypingAttrs addEntriesFromDictionary:[self alternateFontDictionary]];			
			//set new alternate font typing attribtues
			[tv setTypingAttributes:altTypingAttrs];
		}
	}
	
}


//	handle insertTab (tab key action) differently for lists  (to promote list item, rather than insert tab) 3 DEC 07 JH
//	this is NOT called by keyboard shortcut that calls listItemIndent, just tab key!
//	note that ctrl+opt+tab retains the old behavior (of inserting tab character into middle of textList item)
- (BOOL)textView:(NSTextView *)tv doCommandBySelector:(SEL)aSelector
{
	//tab indents list item (usually just inserts tab in Cocoa text system if insertion point is not contained by list item marker)
	if (aSelector == @selector(insertTab:))
	{
		//get paragraph style
		NSParagraphStyle *paragraphStyle = [[tv typingAttributes] objectForKey:NSParagraphStyleAttributeName];
		if (paragraphStyle != nil)
		{
			//	if text list is present at the index & will not cause out of bounds error
			if ([tv selectedRange].location != [textStorage length] && [[paragraphStyle textLists] count] != 0)
			{
				//	then promote (=indent) list item
				[self performSelector:@selector(listItemIndent:) withObject:self afterDelay:0.0f];
				return YES;
			}
			else
			{
				return NO;
			}
		}
	}

	//allows shortcut Shift + Enter for linebreak (new line without new paragraph), which is expected by users (and not allowed by text system)
	if (aSelector == @selector(insertNewline:))
	{
		if ([theScrollView isShiftKeyDown])
		{
			[tv performSelector:@selector(insertLineBreak:) withObject:self afterDelay:0.0f];
			return YES;
		}
		else
		{
			return NO;
		}
	}
	//	means we did nothing and the textView needs to handle this (opposite of what you might think)
	return NO;
}

#pragma mark -
#pragma mark ---- textStorage delegate methods  ----

// ******************* textStorage delegate methods ********************

//	delegate method of NSTextStorage sent after change is made but before any processing is done to the mutable attributed string; if a smart quote (') is sandwiched between two letters, substitute an apostrophe if it isn't one already (as in English); this is because we can't determine if the user meant apostrophe or smart quote (e.g. guillemet) until the next character is entered.
//	another explanation: user might have typed an apostrophe that Bean made into a smart quote, but it really should have been an apostrophe; example >>Wie geht>ts?<< should become >>Wie geht's?<< (note: doesn't catch case of final apostrophe)
//	TODO: would be nice to accomodate final apostrophe in Italian when using << " " >> quotes, as here: Giuliano Cangiano, fumettista e illustratore "un po' di sinistra" catanese, ci ha inviato questo fumetto..., but don't see how without doing linguistic heuristics 5 JUL 08

- (void)textStorageWillProcessEditing:(NSNotification *)aNotification
{
	id tv = [self firstTextView];
	int quoteTag = [self smartQuotesStyleTag];
	// types of smart quotes where this can happen (ignore others which already use 'apostrophe' for smart quote)
	if ([self shouldUseSmartQuotes] && quoteTag > 2 && quoteTag < 7)
	{
		int rLoc = [tv selectedRange].location;
		int rLen = [tv selectedRange].length;
		int tLen = [textStorage length];
		if (rLoc - 1 < tLen && rLoc > 0 && tLen > 2) // prevent out of bounds; rLoc > 0 added 10 Sept 2007 JH 
		{
			unichar q = [[textStorage string] characterAtIndex:rLoc - 1];
			//smart quote characters that might actually need to be apostrophes
			if ((q == 0x201D && quoteTag==3) //double high 9 
				|| (q == 0x2039 && quoteTag==4) //left pointing single guillemet
				|| (q == 0x203A && quoteTag==5) //right pointing single guillemet
				|| (q == 0x2018 && quoteTag==6)) //single high 6
			{
				//string version of this mutable attributed class
				NSString *s = nil;
				s = [textStorage string];
				unichar p = [s characterAtIndex:rLoc - 2];
				//if previous character was alphanumeric
				if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:p])
				{
					if (rLoc + rLen < tLen) //prevent out of bounds
					{
						unichar f = [s characterAtIndex:rLoc ];
						{
							//if following character is alphanumeric
							if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:f])
							{
								//substitute an apostrophe for the smart quote
								// fixed a leak here 20 JAN 08 JH
								NSAttributedString *apostropheString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C", 0x2019] attributes:oldAttributes];
								[textStorage replaceCharactersInRange:NSMakeRange(rLoc - 1, 1) withAttributedString:apostropheString];
								[apostropheString release];
							}
						}
					}
				}
				s = nil;
			}
		}	
	}
}

#pragma mark -
#pragma mark ---- layoutManager delegate methods  ----

// ******************* layoutManager delegate methods ********************

//	taken from TextEdit by Ali Ozer, basically
//	this method adds and removes pages as needed when multiple page view is used
- (void)layoutManager:(NSLayoutManager *)lm	
			didCompleteLayoutForTextContainer:(NSTextContainer *)textContainer
			atEnd:(BOOL)layoutFinishedFlag
{
	//	prevent pagination while document is closing
	if ([self isTerminatingGracefully]) { return; }

	if ([self hasMultiplePages])
	{
		NSArray *containers = [layoutManager textContainers];
		
		// layout not finished or no final container, so add page
		if (!layoutFinishedFlag || (textContainer == nil))
		{
			NSTextContainer *lastContainer = [containers lastObject];
			//add a new page if the newly full container is the last container or non-existant.
			//	but first, check if container is not found in lm's textContainers array, which layout in containers did not finish!
			if ((textContainer == lastContainer) || (textContainer == nil))
			{				
				//only if glyphs are laid in the last container (temporary solution for 3729692, until AppKit makes something better available.)
				if ([layoutManager glyphRangeForTextContainer:lastContainer].length > 0)
				{
					[self addPage:self];
					//this accessor keeps track of whether a page was added from one call of this delegate method to the next (used below)
					[self setPageWasAdded:YES];
					
					//more experimentation with progressIndicator during pagination: shown in a sheet, the progressIndicator does not slow things down, but shown in separate panel; repagination takes 3x as long...not sure why 3 Oct 08 JH
					/*
					if ([messageSheet isVisible])
					{
						//	NOTE: paginationIndicator no loner exists!!!!
						//	showing a progress bar during pagination noticeably increased the time to layout; performance hit wasn't worth it
						float charIndex = [layoutManager firstUnlaidCharacterIndex];
						float docLength = [textStorage length];
						float paginationProgress = charIndex / docLength * 100;
						if (paginationProgress > [progressIndicator doubleValue] + 9)
						{
							[progressIndicator setDoubleValue:paginationProgress];
							[progressIndicator display];
						}
					}
					*/
				}
			}
		}
		// layout is done and it all fit.  See if we can axe some pages.
		else
		{
			//for debugging
			//	int i = [lm firstUnlaidCharacterIndex];
			//	NSLog(@"FIRST UNLAID CHAR: %i", i);
		
			unsigned lastUsedContainerIndex = [containers indexOfObjectIdenticalTo:textContainer];
			unsigned containerIndex = [containers count];
			while (--containerIndex > lastUsedContainerIndex)
			{
				//NOTE: in certain instances, removing a page will give you an out of bounds error; for example: deleting text at the bottom of a page causing text on next page to be drawn to previous container and next page destroyed. This causes NSCFArray out of bounds error. Never could figure out why, but Text Edit sends the same message to the console, so I'm going to let it go.
				//BUGFIX: automatically removing pages because of resizing an image causes an objectAtIndex: out of bounds message (a page is created when an image at the bottom of one page is sized too big, then that created page is removed when the image is resized small again)
				//doc window = key window (no sheets are up)
				if ([[NSApp keyWindow] isEqualTo:[theScrollView window]])
				{
					unsigned pageWithEmptyContainer = [self pageNumberForContainerAtIndex:containerIndex];
					unsigned pageWithUsedContainer = [self pageNumberForContainerAtIndex:lastUsedContainerIndex];
					if (pageWithEmptyContainer > pageWithUsedContainer)
					{	
						[self removePage:self];
						//refresh page count
						[self performSelector:@selector(liveWordCount:) withObject:nil afterDelay:0.0f];
					}
				}
			}
			//	since layout is done, start showing total page numbers in status bar
			if ([self hasMultiplePages] && ![self showPageNumbers])
			{
				//	laying out text in containers is finished, so allow drawRect in PageView
				[self setShowPageNumbers:YES];
			}
		}
		
		//	constrainToScroll causes portion of textView to go blank where glyphs should be laid out after the pageView frame is recalculated
		//	here we force a redraw ONLY IF a page was just added and layout is finished 13 DEC 07 JH
		if (layoutFinishedFlag && [self pageWasAdded])
		{
			PageView *pageView = [theScrollView documentView];
			[pageView performSelector:@selector(display) withObject:pageView afterDelay:0.0f];
			[self performSelector:@selector(liveWordCount:) withObject:nil afterDelay:0.0f];
			[self setPageWasAdded:NO];
		}
	}
	//NOTE: formerly, we were setting temporary attributes here, but under Leopard, this has to be done under textStorage:processEditing to avoid massive slowdowns; apparently the underlying framework code was changed 
				
	//	this tells Bean the document is no longer empty and should not be closed upon opening another doc
	if (isTransientDocument)
	{
		if ([[layoutManager textStorage] length]) { [self setIsTransientDocument:NO]; }
	}
}

@end