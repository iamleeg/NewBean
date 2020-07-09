/*
	EncodingManager.m
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

//object that 1) shows encoding sheet, 2) with document preview, and 3) allows user to change encoding (with preview of change) 
#import "EncodingManager.h"
#import "JHDocument.h"
#import "JHDocument_Initialize.h" //for applyPlainTextSettings
#import "JHDocument_Misc.h" //for undoChangeEncodingWithTag:andTitle:
#import "JHDocument_Backup.h" //for backupDocumentAction

@implementation EncodingManager

- (void)dealloc
{
	if (textDoc) [textDoc release];
	[super dealloc];
}

#pragma mark -
#pragma mark ---- Encoding Methods ----

// ******************* Encoding Methods ********************

//	this (heavily modified) code is from TextEdit's EncodingManager.m
//	return a sorted list of all available string encodings
- (NSArray *)allAvailableStringEncodings
{
	NSMutableArray *allEncodings = nil;
	// Build list of encodings, sorted, and including only those with human readable names
	if (!allEncodings) 
	{	
		const CFStringEncoding *cfEncodings = CFStringGetListOfAvailableEncodings();
		CFStringEncoding *tmp;
		int cnt, num = 0;
		while (cfEncodings[num] != kCFStringEncodingInvalidId) num++;	// Count
		tmp = malloc(sizeof(CFStringEncoding) * num);
		memcpy(tmp, cfEncodings, sizeof(CFStringEncoding) * num);	// Copy the list
		allEncodings = [[NSMutableArray alloc] init];			// Now put it in an NSArray
		for (cnt = 0; cnt < num; cnt++)
		{
			NSStringEncoding nsEncoding = CFStringConvertEncodingToNSStringEncoding(tmp[cnt]);
			if (nsEncoding && [NSString localizedNameOfStringEncoding:nsEncoding])
			{
				NSMutableArray*	row = [NSMutableArray arrayWithCapacity:2];
				//the human-readable name
				[row addObject:[NSString localizedNameOfStringEncoding:nsEncoding]];
				//the int indicating the encoding
				[row addObject:[NSNumber numberWithUnsignedInt:nsEncoding]];
				[allEncodings addObject:row];
			}
		}
		free(tmp);
	}
	return [allEncodings autorelease];
}

//	sort the encodings according to the human-readable name
int encSort(id array1, id array2, void *context)
{
	NSString *encName1 = [array1 objectAtIndex:0];
	NSString *encName2 = [array2 objectAtIndex:0];
	NSComparisonResult sortOrder = [encName1 caseInsensitiveCompare:encName2];
	return sortOrder;
}

-(IBAction)showSheet:(id)sender
{
	//instance of JHDocument is sender
	[self setTextDoc:sender];
	id doc = [self textDoc];
	//encodingSheet behavior in nib = [x] release self when closed, so we don't need: [encodingSheet release];
	if(encodingSheet== nil) { [NSBundle loadNibNamed:@"EncodingPanel" owner:self]; }
	if(encodingSheet == nil)
	{
		NSLog(@"Could not load EncodingPanel");
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}
	
	//load localized control labels
	[encodingOKButton setTitle:NSLocalizedString(@"button: OK", @"")];
	[encodingCancelButton setTitle:NSLocalizedString(@"button: Cancel", @"button: Cancel")];
	[encodingLabel setObjectValue:NSLocalizedString(@"label: Text encoding",@"")];
	[encodingLabel sizeToFit];
	[previewLabel setObjectValue:NSLocalizedString(@"label: Preview",@"")];
	[previewLabel sizeToFit];
	
	//	load popupButton menu with names of encodings (tag = NSStringEncoding)
	[encodingPopup removeAllItems];
	NSMenu *eMenu = [encodingPopup menu];
	//	get an array of objects, each of which is an array containing 1) encoding name string and 2) encoding name int
	NSArray *availableEncodings = [self allAvailableStringEncodings];
	//	sort the array
	NSArray *sortedEncodings; 
	//	these are references to the original array which increase the retain count
	//	fixed double release 4 Aug 07 JH
	sortedEncodings = [availableEncodings sortedArrayUsingFunction:encSort context:NULL];
	
	NSMenuItem *tempItem;
	int i;
	for (i = 0; i < [sortedEncodings count]; i++)
	{
		tempItem = [[NSMenuItem alloc] initWithTitle:[[sortedEncodings objectAtIndex:i] objectAtIndex:0]action:nil keyEquivalent:@""];
		[tempItem setTag:[[[sortedEncodings objectAtIndex:i] objectAtIndex:1] unsignedIntValue]];
		[tempItem setTarget:nil];
		unsigned enc = [[[sortedEncodings objectAtIndex:i] objectAtIndex:1] unsignedIntValue];
		if (!(enc==12 || enc==30 || enc==4 || enc==5)) { [eMenu addItem:tempItem]; } //special cases, see below
		[tempItem release];
		tempItem = nil;
	}
	
	//	place popular encodings at top
	
	//	MacRoman
	//	@"Western (Mac OS Roman)" = 30
	NSString *localizedMacRomanName = [NSString localizedNameOfStringEncoding:NSMacOSRomanStringEncoding];
	NSMenuItem *macRomanItem = [[NSMenuItem alloc] initWithTitle:localizedMacRomanName action:nil keyEquivalent:@""];
	[macRomanItem setTag:30];
	[macRomanItem setTarget:nil];
	[eMenu insertItem:macRomanItem atIndex:0];
	[macRomanItem release];
	
	//	UTF-8 (modern standard for human-readable text files...although OS X internally uses UTF-16)
	//	@"Unicode (UTF-8)" = 4
	NSString *localizedUTF8Name = [NSString localizedNameOfStringEncoding:NSUTF8StringEncoding];
	NSMenuItem *uTF8Item = [[NSMenuItem alloc] initWithTitle:localizedUTF8Name action:nil keyEquivalent:@""];
	[uTF8Item setTag:4];
	[uTF8Item setTarget:nil];
	[eMenu insertItem:uTF8Item atIndex:0];
	[uTF8Item release];
	
	//	WinLatin-1
	//	@"Western (Windows Latin 1)" = 12
	NSString *localizedWinLatinName = [NSString localizedNameOfStringEncoding:NSWindowsCP1252StringEncoding];
	NSMenuItem *winLatinItem = [[NSMenuItem alloc] initWithTitle:localizedWinLatinName action:nil keyEquivalent:@""];
	[winLatinItem setTag:12];
	[winLatinItem setTarget:nil];
	[eMenu insertItem:winLatinItem atIndex:0];
	[winLatinItem release];
	
	//	ISOLatin1 = 5
	NSString *localizedISOLatin1Name = [NSString localizedNameOfStringEncoding:NSISOLatin1StringEncoding];
	NSMenuItem *ISOLatin1Item = [[NSMenuItem alloc] initWithTitle:localizedISOLatin1Name action:nil keyEquivalent:@""];
	[ISOLatin1Item setTag:5];
	[ISOLatin1Item setTarget:nil];
	[eMenu insertItem:ISOLatin1Item atIndex:0];
	//	make this one the default! This is more common now than Mac Roman, I think; Gutenberg.org seems to be mostly ISOLatin1 now (used to be lots of Windows encoding)
	[encodingPopup selectItem:ISOLatin1Item];
	[ISOLatin1Item release];
	
	//	make cancellable after the first time shown (to allow cancel of change encoding...)
	if ([doc docEncoding])
	{
		[encodingCancelButton setHidden:NO];
		[encodingOKButton setTitle:NSLocalizedString(@"Convert", @"button: Convert (translator: this button causes change of encoding of a plain text file)")];
	}
	//	show sheet which forces the user to choose an encoding for the text file,
	//	since apparently it could not be determined (with certainty) automatically
	[NSApp beginSheet:encodingSheet modalForWindow:[[doc firstTextView] window] modalDelegate:self didEndSelector:@selector(encodingSheetDidEnd:returnCode:contextInfo:) contextInfo:doc];
	[encodingSheet orderFront:nil];
	[self encodingPreviewAction:doc];
}

- (IBAction)closeEncodingSheet:(id)sender
{
	//	pass return code to delegate
	if ([sender tag]==0)
		[NSApp endSheet:encodingSheet returnCode:0];
	else
		[NSApp endSheet:encodingSheet returnCode:1];
	[encodingSheet orderOut:sender];
	//fixed leak 15 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[encodingSheet close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];

}
/*
- (IBAction)closeEncodingSheetWithCancel:(id)sender
{
	//	pass return code to delegate
	[NSApp endSheet:encodingSheet returnCode:0];
	[encodingSheet orderOut:sender];
	[self release];
}
*/
-(void)changeEncoding:(id)sender
{
	id doc = [self textDoc];
	//moved undo to document class because this class has no undo manager to call
	[[[doc undoManager] prepareWithInvocationTarget:doc] undoChangeEncodingWithTag:[doc docEncoding] andTitle:[doc docEncodingString]];
	[[doc undoManager] setActionName:NSLocalizedString(@"Change Encoding", @"undo action: Change Encoding.")];
	[doc setDocEncoding:[sender tag]];
	[doc setDocEncodingString:[sender title]];
}

-(IBAction)encodingSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{

	id doc = [self textDoc];
	//NSLog(@"encodingSheetDidEnd; doc:%@", [[self textDoc] displayName]);

	//	the user selected an encoding and pressed 'choose' (not 'cancel')
	if (returnCode==1)
	{
		//	if no encoding yet, use the one the user selected
		if (![[doc firstTextView] isRichText] && ![doc docEncoding])
		{
			//	set doc encoding to equal item tag, which was NSStringEncoding id number
			[doc setDocEncoding:[[encodingPopup selectedItem] tag]];
			[doc setDocEncodingString:[[encodingPopup selectedItem] title]];
			NSError *encError = nil;
			NSString *aString = [[NSString alloc] initWithContentsOfFile:[doc fileName] encoding:[doc docEncoding] error:&encError];
			if (aString != nil)
			{
				[[doc textStorage] replaceCharactersInRange:NSMakeRange(0,[[doc textStorage] length]) withString:aString];
			}	
			[aString release];
			aString = nil;
			[doc applyPlainTextSettings];
			//	alert user upon what is most likely an encoding error at this point
			if (encError)
			{
				NSString *docName = [NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"firstLevelOpenQuote", nil), [doc displayName], NSLocalizedString(@"firstLevelCloseQuote", nil)]; 
				(void)NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"The encoding chosen for the document %@ may not be appropriate.", @"alert title: The encoding chosen for the document (document name inserted at runtime--note: no space after variable)may not be appropriate."), docName], NSLocalizedString(@"Close the document and reopen it with another encoding.", @"alert text: Close the document and reopen it with another encoding."), NSLocalizedString(@"OK", @"OK"), nil, nil);
			}
		}
		//	if there is already an encoding, convert to the encoding the user selected
		//	NOTE: nothing happens to the attributed string, just [doc docEncoding] is set for when document is saved to file
		else
		{
			//	since change encoding is now undoable, we don't need to offer user option to backup file
			/*
			//	ask if user wants to backup the original document
			int choice = NSAlertDefaultReturn;
			NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Do you want to create a backup of the original document before changing the encoding?", @"alert title: Do you want to create a backup of the original document before changing the encoding?")];
			NSString *theInformativeString = NSLocalizedString(@"You might want to preserve the original in case of problems.", @"alert text: You might want to preserve the original in case of problems.");
			choice = NSRunAlertPanel(title, 
									 theInformativeString,
									 NSLocalizedString(@"Backup", @"button: Backup"),
									 nil, 
									 NSLocalizedString(@"Don\\U2019t Backup", @"button: Don't Backup"));
			if (choice==NSAlertDefaultReturn) { // 1
				//backup file, then change encoding
				[doc backupDocumentAction:nil];
			} else if (choice==NSAlertOtherReturn) {
				//change encoding w/o doing backup first
			}
			*/
			[self changeEncoding:[encodingPopup selectedItem]];
			/*
			[[doc undoManager] beginUndoGrouping];
			[[[doc undoManager] prepareWithInvocationTarget:doc] setDocEncoding:[doc docEncoding]];
			[[[doc undoManager] prepareWithInvocationTarget:doc] setDocEncodingString:[doc docEncodingString]];
			[[doc undoManager] endUndoGrouping];
			[[doc undoManager] setActionName:NSLocalizedString(@"Change Encoding", @"undo action: Change Encoding.")];
			[doc setDocEncoding:[[encodingPopup selectedItem] tag]];
			[doc setDocEncodingString:[[encodingPopup selectedItem] title]];
			*/
		}
	}
}

-(IBAction)encodingPreviewAction:(id)contextInfo
{
	// get the document
	id doc = [self textDoc];
	//NSLog(@"encodingPreviewAction; doc:%@", [doc displayName]);
	
	//	Whenever the user selects an encoding from the popup button menu, the text file is reloaded with the encoding and displayed in a small text view 'preview' window on the sheet so the user can see whether the encoding is really appropriate.
	NSError *encError = nil;
	//	no encoding means encoding not yet determined; show preview with potential encoding
	if (![doc docEncoding])
	{
		NSString *aString = [[NSString alloc] initWithContentsOfFile:[doc fileName] encoding:[[encodingPopup selectedItem] tag] error:&encError];
		// string for preview
		if (aString != nil)
		{
			NSString *previewString = nil;
			//	if the string is long, just load about 5 pages worth
			if ([aString length] > 5000)
				{ previewString = [NSString stringWithString:[aString substringWithRange:NSMakeRange(0, 5000)]]; } 
			else
				{ previewString = [NSString stringWithString:aString]; }
			[[encodingPreviewTextView textStorage] replaceCharactersInRange:NSMakeRange(0,[[encodingPreviewTextView textStorage] length]) withString:previewString];
		}
		//	couldn't get a string for preview; suggest user try another encoding
		else
		{
			NSString *infoText = [NSString stringWithFormat:NSLocalizedString(@"The encoding \\U2018%@\\U2019 is not valid for this text. Please try another encoding.", @"The encoding '(localized encoding name automatically inserted at runtime)' is not valid for this text. Please try another encoding."), [[encodingPopup selectedItem] title]];
			[[encodingPreviewTextView textStorage] replaceCharactersInRange:NSMakeRange(0,[[encodingPreviewTextView textStorage] length]) withString:infoText];
		}
		[aString release];
		aString = nil;
	}
	//	encoding already exists, but we want to change it
	else
	{
		NSString *aString = [NSString stringWithString:[[doc textStorage] string]];
		//show preview with encoding
		if ([aString canBeConvertedToEncoding:[[encodingPopup selectedItem] tag]])
		{
			NSString *previewString = nil;
			
			//if the string is long, just load about 5 pages worth
			if ([aString length] > 5000) { previewString = [NSString stringWithString:[aString substringWithRange:NSMakeRange(0, 5000)]]; }
			else { previewString = [NSString stringWithString:aString]; }
			
			[[encodingPreviewTextView textStorage] replaceCharactersInRange:NSMakeRange(0,[[encodingPreviewTextView textStorage] length]) withString:previewString];
			[encodingOKButton setEnabled:YES];
		}
		//can't show preview (invalid encoding?), so suggest user try another encoding
		else
		{
			NSString *infoText = [NSString stringWithFormat:NSLocalizedString(@"The encoding \\U2018%@\\U2019 is not valid for this text. Please try another encoding.", @"The encoding '(localized encoding name automatically inserted at runtime)' is not valid for this text. Please try another encoding."), [[encodingPopup selectedItem] title]];
			[[encodingPreviewTextView textStorage] replaceCharactersInRange:NSMakeRange(0,[[encodingPreviewTextView textStorage] length]) withString:infoText];
			[encodingOKButton setEnabled:NO];
		}
	}
}

-(JHDocument *)textDoc
{
	return textDoc;
}

-(void)setTextDoc:(JHDocument *)aDoc
{
	[aDoc retain];
	[textDoc release];
	textDoc = aDoc;
}

@end