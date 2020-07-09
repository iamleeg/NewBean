/*
	GetInfoManager.m
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
 
#import "GetInfoManager.h"
#import "JHDocument.h" //shouldCreateDatedBackup, etc.
#import "JHDocument_LiveWordCount.h" //wordCountForString, thousandFormatedStringFromNumber
#import "JHDocument_SheetAndPanelManager.h" //showBeanSheet
#import "JHDocument_Backup.h" //toggleAutosave
#import "KBWordCountingTextStorage.h" //wordCount

@implementation GetInfoManager

#pragma mark -
#pragma mark ---- Init, Dealloc ----

- (void)dealloc
{
	if (document) [document release];
	[super dealloc];
}

#pragma mark -
#pragma mark ---- Statistics Sheet   ----

// ******************* Statistics Sheet ********************

//	do counts, then show Statistics sheet
- (IBAction)showSheet:(id)sender
{
	
	//pointers
	id doc = sender;
	NSArray		*textContainers = [[doc layoutManager] textContainers];
	NSTextView	*textView = [doc firstTextView];
	id docWindow = [doc docWindow];
	NSString	*theString = [[[doc layoutManager] textStorage] string];
	int	theStringLength = [[[doc textStorage] string] length];
	int	charCnt = 0;
	int	wordCnt = 0;
	
	//sender is document of interest
	[self setDocument:doc];
	
	//infoSheet behavior in nib = [x] release self when closed, so we don't need: [infoSheet release];
	if(infoSheet == nil) { [NSBundle loadNibNamed:@"GetInfo" owner:self]; }
	
	if(infoSheet == nil)
	{	
		NSLog(@"Could not load GetInfo.nib");
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}

	//load localized control labels
	[closeButton setTitle:NSLocalizedString(@"button: Close", @"")];
	[wordLabel setObjectValue:NSLocalizedString(@"label: Words:", @"")];
	[charLabel setObjectValue:NSLocalizedString(@"label: Characters:", @"")];
	[charNoSpaceLabel setObjectValue:NSLocalizedString(@"label: Characters (no spaces):", @"")];
	[lineLabel setObjectValue:NSLocalizedString(@"label: Lines:", @"")];
	[CRLabel setObjectValue:NSLocalizedString(@"label: Carriage Returns:", @"")];
	[paragraphLabel setObjectValue:NSLocalizedString(@"label: Paragraphs:", @"")];
	[pageLabel setObjectValue:NSLocalizedString(@"label: Pages:", @"")];
	[selWordLabel setObjectValue:NSLocalizedString(@"label: Selected Words:", @"")];
	[selCharLabel setObjectValue:NSLocalizedString(@"label: Selected Characters:", @"")];
	[statisticsLabel setObjectValue:NSLocalizedString(@"label: Statistics", @"")];
	[statisticsLabel sizeToFit];
	[fileInfoLabel setObjectValue:NSLocalizedString(@"label: File Info", @"")];
	[fileInfoLabel sizeToFit];
	[revealFileInFinderButton setTitle:NSLocalizedString(@"button: Show File in Finder", @"")];
	[lockedFileButton setTitle:NSLocalizedString(@"button: Locked file/template", @"")];
	[lockedFileButton sizeToFit];
	[readOnlyButton setTitle:NSLocalizedString(@"button: Read only file", @"")];
	[readOnlyButton sizeToFit];
	[backupAutomaticallyButton setTitle:NSLocalizedString(@"button: Backup at close", @"")];
	[backupAutomaticallyButton sizeToFit];
	[doAutosaveButton setTitle:NSLocalizedString(@"button: Backup every", @"")];
	[doAutosaveButton sizeToFit];
	[lockedFileLabel setObjectValue:NSLocalizedString(@"label: (Cannot be overwritten)", @"")];
	[readOnlyFileLabel setObjectValue:NSLocalizedString(@"label: (Cannot be edited)", @"")];
	[backupAutomaticallyLabel setObjectValue:NSLocalizedString(@"label: (Date-stamped)", @"")];
	[doAutosaveLabel setObjectValue:NSLocalizedString(@"label: minutes", @"")];
	[infoSheetEncodingBox setTitle:NSLocalizedString(@"box title: Plain Text Encoding", @"")];
	[infoSheetEncoding setObjectValue:NSLocalizedString(@"label: Not Applicable", @"")];
	[infoSheetEncodingButton setTitle:NSLocalizedString(@"button: Change Encoding…", @"")];

	//	=========== calculate statistics ===========

	// ----- Carriage Returns -----
	
	//	count Carriage Returns (=Hard Returns), ie, 'newLineMarker' character
	//	note: actual lineCount is one less than the count of the items separated by the newLineChar
	unichar newLineUnichar = 0x000a;
	NSString *newLineChar = [[NSString alloc] initWithCharacters:&newLineUnichar length:1]; // === init
	int lineCount = [[theString componentsSeparatedByString:newLineChar] count];
	
	// for testing - can potentially add count of characters minus newlines to get info panel
	//int numMatches = [theString numberOfMatchesForRegex:@"\n" options:0 sender:NULL];
	//NSLog(@"NUMBER MATCHES %i", numMatches);
	
	// ----- Paragraphs (= CRs minus empty paragraphs) -----
	
	//	count 'empty paragraphs' (two newLineChar's in a row)
	int charIndex = 0;
	int emptyParagraphCount = 0;
	int theFoundRangeLocation = 0;
	while (charIndex < theStringLength)
	{
		NSRange theFoundRange = [theString rangeOfString:[NSString stringWithFormat:@"%@%@", newLineChar, newLineChar] 
				options:NSLiteralSearch range:NSMakeRange(charIndex,(theStringLength - charIndex))];
		theFoundRangeLocation = theFoundRange.location;
		if (theFoundRangeLocation < theStringLength)
		{
			emptyParagraphCount = emptyParagraphCount + 1;
			charIndex = theFoundRangeLocation + 1;
			theFoundRangeLocation = 0;
		}
		else
		{
			charIndex = theStringLength;
		}
	}
	//	add possible CRs (with no text on the line) located at the very beginning and end of text
	if (theStringLength > 0 && [theString characterAtIndex:0]==newLineUnichar) 
			{ emptyParagraphCount = emptyParagraphCount + 1; }
	if (theStringLength > 0 && [theString characterAtIndex:theStringLength - 1]==newLineUnichar)
			{ emptyParagraphCount = emptyParagraphCount + 1; }
	
	//	cleanup
	[newLineChar release]; // ===== release
	charIndex = 0;
	newLineChar = nil;
	
	// ----- Lines -----

	//	count 'Soft' Returns, ie line fragments created by wrapped text (this code is from Apple)
	unsigned numberOfLineFrags, index, numberOfGlyphs; 
	numberOfGlyphs = [[doc layoutManager] numberOfGlyphs];
	NSRange lineRange;
	for (numberOfLineFrags = 0, index = 0; index < numberOfGlyphs; numberOfLineFrags++)
	{
		(void) [[doc layoutManager] lineFragmentRectForGlyphAtIndex:index effectiveRange:&lineRange];
		index = NSMaxRange(lineRange);
	}
	
	//	=========== set Get Info... sheet labels ===========
	
	//	new doc with no words = zero paragraphs and CRs
	if (theStringLength < 1)
	{ 	
		[lineCountField setIntValue:0];
		[paragraphCountField setIntValue:0];
	}
	else
	{
		//	----- Carriage Returns -----
		// = number of hard returns
		id theLineCount = [doc thousandFormatedStringFromNumber:[NSNumber numberWithInt:lineCount - 1]];
		[lineCountField setStringValue: theLineCount];
		
		//	----- Paragraphs -----
		// = number of CRs preceded by text
		id theParagraphCount = [doc thousandFormatedStringFromNumber:[NSNumber numberWithInt:lineCount - emptyParagraphCount]];
		[paragraphCountField setStringValue: theParagraphCount ];
	}
	
	//	----- Word Count -----
	
	//textStorage counts itself thanks to Keith Blount's KBWordCountingTextStorage
	wordCnt = [(KBWordCountingTextStorage *)[doc textStorage] wordCount]; 
	id theWordCount = [doc thousandFormatedStringFromNumber:[NSNumber numberWithInt:wordCnt]];
	[wordCountField setStringValue: theWordCount];

	//	----- Character Count -----
	
	id theCharCount = [doc thousandFormatedStringFromNumber:[NSNumber numberWithInt:theStringLength]];
	[charCountField setStringValue: theCharCount];
		
	//	----- Char Count Minus Spaces -----
	
	id theCharCountMinusSpaces = [doc thousandFormatedStringFromNumber:[NSNumber numberWithInt:theStringLength - [self whitespaceCountForString:theString]]];
	[charCountMinusSpacesField setStringValue: theCharCountMinusSpaces];
	
	//	----- Page Count -----
	
	if ([doc hasMultiplePages])
	{ 
		id thePageCount = [doc thousandFormatedStringFromNumber:[NSNumber numberWithInt:[textContainers count]]];
		[pageCountField setStringValue: thePageCount];
	}
	else
	{
		[pageCountField setStringValue:@"N/A"];
	}
	
	// ----- Line Count (soft returns) -----
	
	id theLineCount = [doc thousandFormatedStringFromNumber:[NSNumber numberWithInt:numberOfLineFrags]];
	[lineFragCountField setStringValue: theLineCount];
	
	// we reuse wordCnt and charCnt
	wordCnt = 0;
	charCnt = 0;	
	lineCount = 0;
	numberOfLineFrags = 0;
	emptyParagraphCount = 0;
	
	//	=========== Selected Text ===========
	
	//count selected text ranges and add them
	NSEnumerator *rangeEnumerator = [[textView selectedRanges] objectEnumerator];
	NSValue *rangeAsValue;
	while ((rangeAsValue = [rangeEnumerator nextObject]) != nil)
	{
		NSRange range = [rangeAsValue rangeValue];
		//	we have to send wordCountForString an attributed string because nextWordFromIndex only works on attributed strings
		NSAttributedString *tempStr = [[NSAttributedString alloc] initWithString:[theString substringWithRange:range]];
		wordCnt += [doc wordCountForString:tempStr];
		charCnt += [tempStr length];
		[tempStr release];
	}
	//	set labels for selected range(s) character and word count
	[selWordCountField setStringValue: [doc thousandFormatedStringFromNumber:[NSNumber numberWithInt:wordCnt]]];
	[selCharCountField setStringValue: [doc thousandFormatedStringFromNumber:[NSNumber numberWithInt:charCnt]]];
	//done
	wordCnt = 0;
	charCnt = 0;	
	theStringLength = 0;
	
	//	=========== prepare sheet controls ===========
	
	//templates (locked files) always open as Untitled documents (unlocked)
	if (![doc fileName])
	{
		[revealFileInFinderButton setEnabled:NO];
		[lockedFileButton setEnabled:NO];
		[lockedFileLabel setTextColor:[NSColor darkGrayColor]];
	}
	else
	{
		[revealFileInFinderButton setEnabled:YES];
		[lockedFileButton setEnabled:YES];
		[lockedFileLabel setTextColor:[NSColor blackColor]];
	}
	
	//	enable backupAutomaticallyButton if: 
	//	1) document not yet saved AND 2) fileType is not TXT, HTML, or WebArchive, which don't use (ie, save) keywords
	if ([doc fileName] && [doc usesKeywords])
	{
	
		//autosaveInterval is number of minutes between autosaves
		id val;
		//if value exists whether autosaving or not, set control
		if ([doc autosaveTime])
		{
			 if (val = [NSNumber numberWithInt:[doc autosaveTime]])
			{
				//NSLog(@"backup interval:%i", [val intValue]);
				[doAutosaveTextField setIntValue:[val intValue]];
				[doAutosaveStepper setIntValue:[val intValue]];
			}
		}
		[backupAutomaticallyButton setEnabled:YES];
		[backupAutomaticallyLabel setTextColor:[NSColor blackColor]];
		//shouldCreateDatedBackup > backup automatically
		[doc shouldCreateDatedBackup] ? 
					[backupAutomaticallyButton setState:NSOnState] : 
					[backupAutomaticallyButton setState:NSOffState];
		[doAutosaveButton setEnabled:YES];
		if ([doc doAutosave])
		{
			[doAutosaveButton setState:NSOnState];
			[doAutosaveLabel setTextColor:[NSColor blackColor]];
			[doAutosaveTextField setTextColor:[NSColor blackColor]];
		}
		else
		{
			[doAutosaveButton setState:NSOffState];
			[doAutosaveLabel setTextColor:[NSColor lightGrayColor]];
			[doAutosaveTextField setTextColor:[NSColor darkGrayColor]];
		}
	}
	else
	{
		//can't do backup or autosave for an unsaved document
		[backupAutomaticallyButton setState:NSOffState];
		[backupAutomaticallyButton setEnabled:NO];
		[backupAutomaticallyLabel setTextColor:[NSColor darkGrayColor]];
		[doAutosaveButton setState:NSOffState];
		[doAutosaveButton setEnabled:NO];
		[doAutosaveTextField setTextColor:[NSColor blackColor]];
		[doAutosaveLabel setTextColor:[NSColor blackColor]];
	}
	
	//	see if the file is LOCKED and adjust button
	NSDictionary *theFileAttrs = [[NSFileManager defaultManager] fileAttributesAtPath:[doc fileName] traverseLink:YES];
	[[theFileAttrs objectForKey:NSFileImmutable] boolValue] ?
					[lockedFileButton setState:NSOnState] :
					[lockedFileButton setState:NSOffState];
		
	//	see if the document is READ ONLY and adjust the button
	([doc readOnlyDoc]) ? [readOnlyButton setState:NSOnState] : [readOnlyButton setState:NSOffState];
	
	//	if text, show encoding and enable button to change encoding; else, unenable
	if (![textView isRichText])
	{
		[infoSheetEncodingBox setTitle:NSLocalizedString(@"Plain Text Encoding", @"get info label: Plain Text Encoding")];
		[infoSheetEncoding setObjectValue:[[self document] docEncodingString]];
		[infoSheetEncodingButton setHidden:NO];
	}
	else
	{
		[infoSheetEncodingBox setTitle:NSLocalizedString(@"Document File Format", @"get info label: Document File Format")];
		if ([doc fileName]) { [infoSheetEncoding setObjectValue:NSLocalizedString([doc fileType], @"this will translate automatically from file type name strings")]; }
		else { [infoSheetEncoding setObjectValue:NSLocalizedString(@"None (Unsaved Document)", @"get info label: None (Unsaved Document)")]; }
		[infoSheetEncodingButton setHidden:YES];
	}
	
	//	show the sheet
	[NSApp beginSheet:infoSheet modalForWindow:docWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];
	[infoSheet orderFront:sender];
}

- (IBAction)closeInfoSheet:(id)sender
{
	//	if autosaveInterval is not in acceptable range (1 min to 60 min), warn and don't close sheet
	if ([doAutosaveTextField intValue] < 1 || [doAutosaveTextField intValue] > 60)
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Please input an interval for automatic backup.", @"alert title: Please input an interval for automatic backup.")]];
		[alert setInformativeText:NSLocalizedString(@"At least 1 minute and no more than 60 minutes.", @"alert text: At least 1 minute and no more than 60 minutes. (alert title is: Please input an interval for automatic backup.)")];
		[alert runModal];
		[doAutosaveTextField setIntValue:5];
	}
	//	else close sheet
	else
	{
		[NSApp endSheet:infoSheet];
		[infoSheet orderOut:sender];
	}
	//fixed leak 15 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[infoSheet close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
}

#pragma mark -
#pragma mark ---- Actions ----

//this has been repurposed as a timed 'Backup'; the controls and code are in GetInfo nib and class
// ******************* Actions ********************
-(IBAction)startAndStopAutosaveAction:(id)sender
{
	//will be turned off, so enable controls
	if ([[self document] doAutosave])
	{
		[doAutosaveTextField setTextColor:[NSColor darkGrayColor]];
		[doAutosaveLabel setTextColor:[NSColor lightGrayColor]];
	}

	//will be turned on, so set interval accessor
	else
	{
		int theAutosaveInterval =[doAutosaveTextField intValue];
		//	if the interval passed by userDefaults was not valid (shouldn't happen, but you never know...)
		if (theAutosaveInterval <= 0 || theAutosaveInterval > 3600)
		{
			[[self document] setDoAutosave:NO];
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Please input an Autosave interval.", @"alert title: Please input an Autosave interval.")]];
			[alert setInformativeText:NSLocalizedString(@"At least 1 minute and no more than 60 minutes.", @"alert text: At least 1 minute and no more than 60 minutes. (alert title is: Please input an Autosave interval.)")];
			[alert runModal];
			[doAutosaveButton setState:NSOffState];
			[doAutosaveTextField setIntValue:5];
			return;
		}
		[[self document] setAutosaveTime:theAutosaveInterval];
		[doAutosaveLabel setTextColor:[NSColor blackColor]];
		[doAutosaveTextField setTextColor:[NSColor blackColor]];
	}
	
	[[self document] toggleAutosave];
}

-(IBAction)setAutosaveInterval:(id)sender
{
	[doAutosaveTextField setIntValue:[sender intValue]];
	[[self document] setAutosaveInterval:[sender intValue]];
}	
-(IBAction)changeEncodingAction:(id)sender
{
	//	get rid off the infoSheet before showing encoding sheet
	[NSApp endSheet:infoSheet];
	[infoSheet orderOut:sender];
	//encoding sheet releases self when closed
	NSControl *fakeSender = [NSControl new]; // <========== init
	[fakeSender setTag:2];
	[[self document] showBeanSheet:fakeSender];
	[fakeSender release];  // <========== release
	//fixed leak 15 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[infoSheet close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
}

- (IBAction)lockedFileButtonAction:(id)sender
{
	if ([[self document] fileName])
	{
		int lockedState = [sender state];
		//	set locked state based on checkbox
		NSDictionary *unlockFileDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:lockedState] forKey:NSFileImmutable];
		[[NSFileManager defaultManager] changeFileAttributes:unlockFileDict atPath:[[self document] fileName]];
		//	inform user that locked files cannot be saved to, but may be re-opened as templates
		NSDictionary *theFileAttrs = [[NSFileManager defaultManager] fileAttributesAtPath:[[self document] fileName] traverseLink:YES];
		if ([[theFileAttrs objectForKey:NSFileImmutable] boolValue] == YES) //confirm file is now locked
		{
			NSString *docName = [NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"firstLevelOpenQuote", nil), [[self document] displayName], NSLocalizedString(@"firstLevelCloseQuote", nil)]; 
			NSString *title = [NSString stringWithFormat:NSLocalizedString(@"The file %@ is now locked and may not be overwritten.", @"alert title: The file (name of file inserted at runtime) is now locked and may not be overwritten."), docName];
			NSString *infoText = NSLocalizedString(@"Close and reopen this document to create an \\U2018Untitled\\U2019 copy.", @"alert text: Close and reopen the document to create an 'Untitled' copy.");
			NSAlert *lockedFileAlert = [NSAlert alertWithMessageText:title defaultButton:NSLocalizedString(@"OK", @"OK") alternateButton:nil otherButton:nil
										   informativeTextWithFormat:infoText];
			[lockedFileAlert runModal];
		}
	}
}

- (IBAction)readOnlyButtonAction:(id)sender
{
	int readOnlyState = [sender state];
	//	set read only state based on checkbox
	[[self document] setReadOnlyDoc:readOnlyState];
	//	do this here rather than in setReadOnlyDoc accessor
	//	so read only docs are automatically dirty when opened
	[[self document] updateChangeCount:NSChangeDone];
}

//	called from button in getInfo panel
- (IBAction)backupAutomaticallyAction:(id)sender
{
	id doc = [self document];
	//toggle
	BOOL shouldBackup = !([doc shouldCreateDatedBackup]); 
	[doc setShouldCreateDatedBackup:shouldBackup];
	//not undoable thru undo manager
	[doc updateChangeCount:NSChangeDone];
}

-(IBAction)revealFileInFinder:(id)sender
{
	NSString *thePath = [[self document] fileName];
	if (thePath) { [[NSWorkspace sharedWorkspace] selectFile:thePath inFileViewerRootedAtPath:nil]; }
}


#pragma mark -
#pragma mark ---- helper methods ----

// ******************* helper methods ********************

//	counts and returns the number of space characters
- (int)whitespaceCountForString:(NSString *)textString
{
	int stringLength = [textString length];
	int i, theCharacterCount;
	for (i = theCharacterCount = 0; i < stringLength; i++)
	{
		if ( [textString characterAtIndex:i]  == ' ') { theCharacterCount++; }
	}
	return theCharacterCount;
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