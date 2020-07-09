/*
	JHDocument_Misc.m
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
 
#import "JHDocument_Misc.h"
#import "JHDocument_View.h" //constrainScrollWithForceFlag
#import "JHDocument_FullScreen.h" //fullScreen, toggleFullScreen
#import "JHDocument_Print.h" //applyUpdatedPrintInfo
#import "JHDocument_PageLayout.h" //doForegroundLayout
#import "GLOperatingSystemVersion.h"

//	various helper and action methods
@implementation JHDocument ( JHDocument_Misc )

#pragma mark -
#pragma mark ---- Misc Helper & Action Methods ----

// ******************* Misc Helper & Action Methods ********************

//	Look up word or words in selection using Dictionary.app; multiple word URLs - Done! 23 APR 08 JH
//	NOTE: no capitalized words (like 'French') a limitation of the 'dict' NSURL (case insensitive)
- (IBAction)defineWord:(id)sender
{
	//	---------determine range for word to be defined---------

	NSRange wordRange;
	NSRange selRange = [[self firstTextView] selectedRange];
	//	if selRange is exactly at start of word, nextWordFromIndex will look backward to the previous word, which we don't want, so we add '1' to the index (as long as not out of bounds)
	int adjustAmount = 0;
	// bounds check
	if (selRange.location != [textStorage length])
	{
		adjustAmount = 1;
	}
	// find start of range of word(s) to define
	wordRange.location = [textStorage nextWordFromIndex:(selRange.location + adjustAmount) forward:NO];
	
	//	old one-word method for length, note used
	//	wordRange.length = [textStorage nextWordFromIndex:selRange.location forward:YES] - wordRange.location;

	//	if selRange is exactly at end of word, nextWordFromIndex will look forward to the next word, which we don't want, so we subtract '1' from the length of the word(s) to define
	adjustAmount = 0;
	// bounds check
	if (selRange.location != [textStorage length])
	{
		//	nuther bounds check
		if (selRange.location + selRange.length < [textStorage length])
		{
			unichar c = [[textStorage string] characterAtIndex:(selRange.location + selRange.length)];
			//	if next char is space
			if (c == NSNewlineCharacter || [[NSCharacterSet whitespaceCharacterSet] characterIsMember:c])
			{
				adjustAmount = 1;
			}
		}
	}
	//	find end of range of word(s) to define (avoid NSException with nextWordFromIndex)
	if (selRange.location + selRange.length == [textStorage length])
	{
		adjustAmount = adjustAmount + 1;
	}
	int endIndex = selRange.location + selRange.length - adjustAmount;
	wordRange.length = [textStorage  nextWordFromIndex:endIndex forward:YES] - wordRange.location;

	//	---------make URL to feed to dictionary.app---------

	//	determine string for word to define
	NSString *defineWordString = nil;
	defineWordString = [[textStorage string] substringWithRange:NSMakeRange(wordRange.location, wordRange.length)];
	//	remove punctuation, if necessary	
	
	// newlineCharacterSet is not Tiger compatible, so we make its equivalent for Tiger!
	NSString *newlineString = [NSString stringWithFormat:@"%C%C%C", 0x000A, 0x000D, 0x0085];
	NSCharacterSet *theNewlineCharacterSet = [NSCharacterSet characterSetWithCharactersInString:newlineString];
	NSMutableCharacterSet *nonLetterCharacterSet = [[theNewlineCharacterSet mutableCopy] autorelease];
	[nonLetterCharacterSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
	int nonLetterLocation;
	nonLetterLocation = [defineWordString rangeOfCharacterFromSet:nonLetterCharacterSet].location;
	//	if punctuation etc. is found, trim it
	if (nonLetterLocation !=NSNotFound)
	{
		defineWordString = [defineWordString substringWithRange:NSMakeRange(0,nonLetterLocation)];
	}
	//	check spelling of word to define with sharedSpellChecker (loaded at didLoadNib) 
	NSRange misspelledWordRange = [spellChecker checkSpellingOfString:defineWordString startingAt:0 language:nil wrap:NO inSpellDocumentWithTag:0 wordCount:nil];
	//	if misspelled (so no definition through URL scheme is possible), alert user
	if (misspelledWordRange.length)
	{
		int choice = NSAlertDefaultReturn;
		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"The word \\U2018%@\\U2019 may be misspelled.", @"alert tite: The word (word inserted at runtime) may be misspelled."), defineWordString];
		NSString *theInformativeString = [NSString stringWithFormat:NSLocalizedString(@"Do you want to check the spelling?", @"alert text: Do you want to check the spelling?")];
		choice = NSRunAlertPanel(title, 
								 theInformativeString,
								 NSLocalizedString(@"button title: Check Spelling", @"button: Check Spelling"),
								 NSLocalizedString(@"button title: Open Dictionary", @"button: Open Dictionary"), 
								 NSLocalizedString(@"button title: Cancel", @"button: Cancel"));
		//	1 = call up the spell check panel, if user chooses
		if (choice==NSAlertDefaultReturn)
		{
			[[self firstTextView] setSelectedRange:NSMakeRange(wordRange.location,wordRange.length)];
			[[self firstTextView] showGuessPanel:nil];
			[spellChecker spellingPanel];
			[spellChecker updateSpellingPanelWithMisspelledWord:defineWordString];
			return;
		}
		//	-1 = otherwise exit method and let user get back to work without trying the dictionary
		else if (choice==NSAlertOtherReturn)
		{
			return;
		}
		else if (choice==NSAlertAlternateReturn)
		{
			//just continue with dictionary
		}
	}
	//	make a 'dict' type URL to pass to the Dictionary.app 
	NSString *newURLString = [NSString stringWithFormat:@"dict:///%@", defineWordString];
	//	clean up spaces in URL, etc
	NSString *urlString = [newURLString stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
	NSString *defineWordURLString = [[NSURL URLWithString:urlString] absoluteString];
		
	NSArray *theURLArray = [NSArray arrayWithObject:[NSURL URLWithString:defineWordURLString]];
	if (defineWordURLString)
	{
		[[NSWorkspace sharedWorkspace] launchApplication:@"Dictionary"];	
			//	under Tiger, we have to kick Dictionary.app then feed it an empty URL to make it responsive; this was fixed in Leopard 7 DEC 07 JH
		if ([GLOperatingSystemVersion isBeforeLeopard])
		{
			[[NSWorkspace sharedWorkspace] launchApplication:@"Dictionary"];	
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"dict:/// "]];
		}
		[[NSWorkspace sharedWorkspace] openURLs:theURLArray withAppBundleIdentifier:@"com.apple.Dictionary" options:NSWorkspaceLaunchAsync additionalEventParamDescriptor:nil launchIdentifiers:nil];
	}
}

-(IBAction)sendToMail:(id)notification
{
	//	opens Mail.app with a new message, and inserts the documents saved file into body with brief description the description is so the person sending it knows what exactly it is!
	if ([self fileName])
	{
		NSDictionary* errorDict;
		//NSAppleEventDescriptor* returnDescriptor = NULL;
		NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:
			
			[NSString stringWithFormat:
				@"\
	tell application \"Mail\"\n\
	activate\n\
			set bodyvar to \"Attached file name: %@\"\n\
	set the new_message to (make new outgoing message with properties {visible:true, content:\" \"})\n\
	tell the new_message\n\
	set the content to bodyvar\n\
	tell content\n\
	make new attachment with properties {file name:\"%@\"} at before the first character\n\
	end tell\n\
	end tell\n\
	end tell", [[self fileName] lastPathComponent], [self fileName]]
			];
		
		//returnDescriptor = 
		[scriptObject executeAndReturnError: &errorDict];
		[scriptObject release];
	}
}

//	action for menu item: Find > Location of Last Edit
-(IBAction)restoreCursorLocationAction:(id)sender
{
	if ([self savedEditLocation] && [self savedEditLocation] < [textStorage length] + 1)
	{
		[[self firstTextView] setSelectedRange:NSMakeRange([self savedEditLocation], 0)];
		if ([self hasMultiplePages])
		{
			[self constrainScrollWithForceFlag:YES];
			[theScrollView reflectScrolledClipView:[theScrollView contentView]];
		}
		else
		{
			[[self firstTextView] centerSelectionInVisibleArea:self];
		}
	}
}

//hide control to change document background color in font panel (JHDocument is textView's delegate)
- (unsigned int)validModesForFontPanel:(NSFontPanel *)fontPanel
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL allowColorChange = [defaults boolForKey:@"prefAllowBackgroundColorChange"];
	if (!allowColorChange || [self shouldUseAltTextColors])
		return (NSFontPanelStandardModesMask ^ NSFontPanelDocumentColorEffectModeMask);
	else
		return (NSFontPanelStandardModesMask);
}

//	kind of worthless method that moves first page up to very tippy top when up arrow is pressed
-(IBAction) scrollUpWhenAtBeginning:(id)notification
{
	id tv = [self firstTextView];
	// 23 SEPT 08 JH bugfix: so only current window responds
	if ([notification object]==tv)
	{
		NSRange selRange = [tv selectedRange];
		if (selRange.location == 0 && selRange.length == 0 && [self hasMultiplePages])
		{
			[tv scrollPageUp:nil];
		}
	}
}

//	undo method for changeEncoding in EncodingManager class (moved here because EncodingManager doesn't have undoManager)
-(void)undoChangeEncodingWithTag:(int)tag andTitle:(NSString *)title
{
	[[[self undoManager] prepareWithInvocationTarget:self] undoChangeEncodingWithTag:[self docEncoding] andTitle:[self docEncodingString]];
	[[self undoManager] setActionName:NSLocalizedString(@"Change Encoding", @"undo action: Change Encoding.")];
	[self setDocEncoding:tag];
	[self setDocEncodingString:title];
}

// ******************* Invert Selection Method & Undo *******************

//the undo method for invertSelection; should precede invertSelection in .m file
-(void)undoInvertSelection:(NSArray *)theOldRangesArray
{
	//	record undo info
	[[[self undoManager] prepareWithInvocationTarget:self] undoInvertSelection:[[self firstTextView] selectedRanges]];
	[[self undoManager] setActionName:NSLocalizedString(@"Invert Selection", @"undo action: Invert Selection")];
	//	then change selected ranges to old ranges
	[[self firstTextView] setSelectedRanges:theOldRangesArray];
}

//	selects all unselected text
-(IBAction)invertSelection:(id)sender
{
	NSMutableArray *theNewRanges = [NSMutableArray arrayWithCapacity:0];
	NSArray *theSelectedRanges = [[self firstTextView] selectedRanges];
	int objectNumber = 0;
	int theStringLength = [[[[self layoutManager] textStorage] string] length];
	NSRange aNewRange;
	NSRange theCurrentRange = [[theSelectedRanges objectAtIndex:objectNumber] rangeValue];
	NSRange theNextRange;
	//	if all text is selected, un-select all
	if (theCurrentRange.location + theCurrentRange.length == theStringLength && theCurrentRange.length > 0 && theCurrentRange.location == 0)
	{
		aNewRange = NSMakeRange(0, 0);
		[theNewRanges addObject:[NSValue valueWithRange:aNewRange]];
	}
	//	if no test is selected, select all
	else if (theCurrentRange.length==0 || theCurrentRange.location==theStringLength + 1)
	{
		aNewRange = NSMakeRange(0, theStringLength);
		[theNewRanges addObject:[NSValue valueWithRange:aNewRange]];
	}
	//	misc ranges of text
	else {
		//	if the location of the first range is > 0, create range for first section 
		if (theCurrentRange.location > 0 && theCurrentRange.length > 0)
		{
			aNewRange = NSMakeRange(0, theCurrentRange.location);
			[theNewRanges addObject:[NSValue valueWithRange:aNewRange]];
		}
		//account for ranges in-between
		while (objectNumber <= [theSelectedRanges count] - 2 && [theSelectedRanges count] > 1 )
		{
			theCurrentRange = [[theSelectedRanges objectAtIndex:objectNumber] rangeValue];
			if (objectNumber < [theSelectedRanges count]) {
				theNextRange = [[theSelectedRanges objectAtIndex:objectNumber + 1] rangeValue];
			}
			else
			{
				theNextRange.location = (theCurrentRange.location + theCurrentRange.length);
			}
			aNewRange = NSMakeRange(theCurrentRange.location + theCurrentRange.length, theNextRange.location - theCurrentRange.location - theCurrentRange.length);
			[theNewRanges addObject:[NSValue valueWithRange:aNewRange]];
			objectNumber = objectNumber + 1;
		}
		//	if the last selected range does not extend to end of the string, create a range for last section
		if (theCurrentRange.location + theCurrentRange.length < theStringLength)
		{
			theCurrentRange = [[theSelectedRanges objectAtIndex:objectNumber] rangeValue];
			int newLocation = theCurrentRange.location + theCurrentRange.length;
			aNewRange = NSMakeRange(newLocation, theStringLength - newLocation);
			[theNewRanges addObject:[NSValue valueWithRange:aNewRange]];
		}
	}
	//	first record undo
	[[[self undoManager] prepareWithInvocationTarget:self] undoInvertSelection:theSelectedRanges];
	[[self undoManager] setActionName:NSLocalizedString(@"Invert Selection", @"undo action: Invert Selection")];
	//	then change selected ranges to new ranges
	[[self firstTextView] setSelectedRanges:theNewRanges];
}

//	undoes a Change Margins action
- (void)undoChangeLeftMargin:(int)theLeftMargin 
				 rightMargin:(int)theRightMargin 
				   topMargin:(int)theTopMargin
				bottomMargin:(int)theBottomMargin
{
	PageView *pageView = [theScrollView documentView];	
	//	record old margin settings in case undo of undo is called
	[[[self undoManager] prepareWithInvocationTarget:self] 
	 undoChangeLeftMargin:[printInfo leftMargin] 
	 rightMargin:[printInfo rightMargin]
	 topMargin:[printInfo topMargin]
	 bottomMargin:[printInfo bottomMargin]];
	[[self undoManager] setActionName:NSLocalizedString(@"Change Margins", @"undo action: Change Margins")];
	
	//	set printInfo properities
	[printInfo setLeftMargin:theLeftMargin];
	[printInfo setRightMargin:theRightMargin];
	[printInfo setTopMargin:theTopMargin];
	[printInfo setBottomMargin:theBottomMargin];
	//	update things
	[self applyUpdatedPrintInfo];
	//	23 DEC 07 JH; BUGFIX 11 APR 09 JH (was sending setForceRedraw to textView, which doesn't know that method)
	if ([pageView isKindOfClass:[PageView class]])
		[pageView setForceRedraw:YES];
	[pageView setNeedsDisplay:YES];
	[self doForegroundLayoutToCharacterIndex:INT_MAX];
}  

-(void)undoChangeColumns:(int)numColumns gutter:(int)gutter
{
	id doc = self;
	if ([doc numberColumns] != numColumns || [doc columnsGutter] != gutter)
	{
		//	record old margin settings in case undo margin change is called
		[ [[doc undoManager] prepareWithInvocationTarget:doc] 
				undoChangeColumns:[doc numberColumns]
				gutter:[doc columnsGutter] ];
		[[doc undoManager] setActionName:NSLocalizedString(@"Change Columns", @"undo action: Change Margins")];

		[doc rememberVisibleTextRange];
		//	set number columns
		[doc setNumberColumns:numColumns];
		//	set gutter width in pts
		[doc setColumnsGutter:gutter];

		PageView *pageView = [[doc theScrollView] documentView];
		//	means Layout View
		if ([pageView isKindOfClass:[PageView class]])
		{
			//	must refresh view
			[pageView setForceRedraw:YES];
			[pageView setNeedsDisplay:YES];
		}
		[doc applyUpdatedPrintInfo];
		[doc restoreVisibleTextRange];
	}
}

//do this to allow UI translation of boilerplate OS X menu item (which is only translated for system langauges)
-(IBAction)toggleToolbarShownAction:(id)sender
{
	[docWindow doCommandBySelector:@selector(toggleToolbarShown:)];
}

-(IBAction)makeTemplateAction:(id)sender
{
	NSString *filePath = [self fileName];
	if (!filePath) return; //shouldn't happen
	//	is filePath a valid file? 
	id fm = [NSFileManager defaultManager];
	BOOL fileExists = NO;
	fileExists = [fm fileExistsAtPath:filePath isDirectory:NULL];
	if (!fileExists) return;
	//	make file locked (ie, a template for Bean)
	NSDictionary *lockFileDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:NSFileImmutable];
	[fm changeFileAttributes:lockFileDict atPath:filePath];
	NSDictionary *theFileAttrs = [fm fileAttributesAtPath:filePath traverseLink:YES];
	//	ask user if he/she wants to reopen locked file as untitle doc
	if ([[theFileAttrs objectForKey:NSFileImmutable] boolValue] == YES) //confirm file is now locked
	{
		//	ask if user wants to reopen template (locked) doc as Untitled document
		int choice = NSAlertDefaultReturn; //reopen
		NSString *title = NSLocalizedString(@"alert title: Do you want to reopen the template as an untitled document?", @"alert title: Do you want to reopen the template as an untitled document?");
		//NSString *infoString = NSLocalizedString(@"This action is undoable.", @"alert text: You will lose unsaved changes.");
		choice = NSRunAlertPanel(title, @"", NSLocalizedString(@"button: Reopen", @"button: Reopen (translator: it means, close the new template document and reopen it as an untitled document)"), @"", NSLocalizedString(@"button: Don\\U2019t Reopen", @"button: Don't Reopen (don't reopen new template as untitled document)"));
		// 'reopen' button selected
		if (choice==NSAlertDefaultReturn)
		{
			//close self and tell documentController to reopen locked file (as untitled doc)
			NSURL *fileURL = [NSURL fileURLWithPath:filePath];
			fileExists = [fm fileExistsAtPath:filePath isDirectory:NULL];

			if (fileExists) [self close];

			id document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:YES error:NULL];
			//alert user if template could not be reopened
			if (document == nil) 
			{
				NSLog(@"Could not open the template document. @%");
				NSBeep();
				//	alert user that the template (locked doc) could not be opened for some reason
				int choice = NSAlertDefaultReturn; //reopen
				NSString *title2 = NSLocalizedString(@"alert title: Bean could not open the file.", @"alert title: Bean could not open the file.");
				choice = NSRunAlertPanel(title2, @"", NSLocalizedString(@"OK", @"OK"), @"", NSLocalizedString(@"button: Reveal File in Finder", @"button: Reveal File in Finder"));
				// OK
				if (choice==NSAlertDefaultReturn)
				{
					return;
				}
				// reveal file in Finder
				else if (choice==NSAlertOtherReturn)
				{
					//open a finder window with the file highlighted
					NSFileManager *fm = [NSFileManager defaultManager];
					fileExists = [fm fileExistsAtPath:filePath isDirectory:NULL];
					if (fileExists)
					{
						[[NSWorkspace sharedWorkspace] selectFile:filePath inFileViewerRootedAtPath:nil];
					}
					else
					{
						NSBeep;
					}
					return;
				}
			}
			//document exists, so we set accessor that prevents shows prev. filename as msg in save panel (as occurs with Save As...)
			else
			{
				if ([document respondsToSelector:@selector(setWasCreatedUsingNewDocumentTemplate:)])
				{
					[document setWasCreatedUsingNewDocumentTemplate:YES];
				}
			}
		}
		// don't reopen template as untitled doc
		else if (choice==NSAlertOtherReturn)
		{
			return;
		}
	}
	//the file could not be locked for some reason
	else
	{
		NSBeep();
		NSLog(@"Could not lock the file: %@", filePath);
		return;
	}
}

#pragma mark -
#pragma mark ---- NSEvent Catcher/Handler ----

// ******************* NSEvent Catcher/Handler ********************

//triggers constrainScroll (center text input cursor on screen) and quint-click (select all)
- (void) applicationDidUpdateDocument:(NSNotification *)notification
{
	NSTextView *textView = [self firstTextView];

	//	used by following two blocks of code
	NSEvent *theEvent = [NSApp currentEvent];
	
	//	BUGFIX 18 JUNE 2007 so only this window responds! // ===== revised 10 JUL 08 JH
	if ([NSApp keyWindow]==[textView window] && [theEvent window]==[textView window])
	{
		//	watches for mouse quintuple-click, and if so selects all text (=select all)
		if ([theEvent type]==NSLeftMouseUp && [theEvent clickCount]==5)
		{
			//	make sure it does not loop, that is, notification changes selection, which calls notification, etc.
			//	this: ([theEvent window]==[textView window]) makes sure input is from textView, not inspector, etc.  
			if ([textView selectedRange].length < [textStorage length] && ![textView selectedRange].length==0) \
			{
				[textView setSelectedRange:NSMakeRange(0,[textStorage length])];
			}
		}
		//	if not using the modifier keys (to scroll, etc.), we try to center the caret vertically in the window or page;
		//	method is not Tiger compatible (causes scroller to jump wildly) so disallow starting in 2.3.0 8 MAY 09 JH 
		//	if ([self shouldConstrainScroll] && [self currentSystemVersion] >= 0x1050)
		//this bug was fixed in NSTextView setConstrainedFrameSize by not using special code until end of document 21 AUG 09 JH
		if ([self shouldConstrainScroll])
		{
			if ([theEvent type]==NSKeyDown
				&& !([theEvent modifierFlags] & NSFunctionKeyMask) 
				&& !([theEvent modifierFlags] & NSControlKeyMask) 
				&& !([theEvent modifierFlags] & NSAlternateKeyMask) 
				&& !([theEvent modifierFlags] & NSCommandKeyMask))
			{
				//NSLog(@"CONSTRAIN SCROLL WITH FORCE FLAG");
				[self constrainScrollWithForceFlag:NO];
			}
		}
		//this allows Cmd= and Cmd+ to call grow font on both Tiger and Leopard systems 18 Oct 08 JH
		//note: Leopard will do this automatically when growFont = Cmd+
		if ([theEvent type]==NSKeyDown)
		{
			NSString *chars = [theEvent charactersIgnoringModifiers];
			//version 2.0.3 bugfix -- accented characters via dead key were causing a crash (because charAtIndex:0 was nil)
			unichar ch = [chars length] > 0 ? [chars characterAtIndex:0] : 0;
			// 0x002B = '+'
			if (ch == 0x002B)
			{
				if ([theEvent modifierFlags] & NSCommandKeyMask)
				{
					NSFontManager *fm = [NSFontManager sharedFontManager];
					[fm setDelegate:textView];
					NSControl *fakeSender = [[NSControl alloc] init];
					//tag = 3 causes 'grow font' command
					[fakeSender setTag:3];
					[fm modifyFont:fakeSender];
					[fakeSender release];
				}
			}
		}
	}
	//	log autosave
	//	if ([self hasUnautosavedChanges]) { NSLog(@"hasUnautosavedChanges"); }
	//	NSLog(@"autosaveDelay: %1.2f", [[NSDocumentController sharedDocumentController] autosavingDelay]);
	
	//test code - determine the unicode character(s) supplied by the keyDown event event
	/*
	 if ([theEvent type]==NSKeyDown)
	 {
		 NSString *chars = [theEvent characters];
		 int i, l = [chars length];
		 for(i=0; i<l; i++)
		 {
			 unichar c = [chars characterAtIndex:i];
			 //NSLog([NSString stringWithFormat:@"unichar: %i", c]);
		 }
	 }
	 */
}

/*
//for logging
-(NSString *)stringFromColor:(NSColor *)inColor
{
	float red, green, blue, alpha;
	if (inColor)
	[inColor getRed:&red green:&green blue:&blue alpha:&alpha];
	NSString *colorDesc = [NSString stringWithFormat:@"red:%1.2f blue:%1.2f green:%1.2f alpha:%1.2f", red, green, blue, alpha];
	return colorDesc;
}
*/
@end
