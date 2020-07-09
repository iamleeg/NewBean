/* 
JHDocumentController.m
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

#import "JHDocumentController.h"
#import "JHDocument.h"
#import "JHDocument_Text.h" //for setSmartQuotesStyleAction
#import "JHDocument_FullScreen.h" //for fullScreen accessor
#import "TextFinder.h" //for regex enabled find panel
#import "JHDocument_View.h" //toggleLayoutView
#import "JHDocument_PageLayout.h" //doForegroundLayoutToCharacterAtIndex
#import "NSTextViewExtension.h" //setBeanCursorShape

//prevent header and footer from printing in printView
@interface JHPrintView : NSTextView
- (NSAttributedString *)pageHeader;
- (NSAttributedString *)pageFooter;
@end

@implementation JHPrintView
- (NSAttributedString *)pageHeader { return nil; }
- (NSAttributedString *)pageFooter { return nil; }
@end

//a subclass of NSDocumentController
@implementation JHDocumentController

static JHDocumentController *sharedInstance = nil;

//	note: init stuff is from TextForge; singleton; released on NSApp dealloc
+(JHDocumentController*)sharedInstance
{
	return sharedInstance ? sharedInstance : [[JHDocumentController alloc] init];
}

-(id)init
{
	if (sharedInstance)
	{
		[self dealloc];
	}
	else
	{
		sharedInstance = [super init];
	}
	
	//moved from Preferences, since that is loaded now on demand 10 AUG 08 JH
	//was moved to AppDelegate, but this is called first 18 AUG 08 JH

	//load user preferences
	//the path points to a plist file inside the app's resource folder that has factory defaults
	NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"];
	//create a dictionary containing the defaults
	NSDictionary *theDefaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];
	if (theDefaults) {
		//register them with NSUserDefaults
		[[NSUserDefaults standardUserDefaults] registerDefaults:theDefaults];
		//tell the controller they are the initial values (for first launch of app)
		[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:theDefaults];
		//apply preference settings immediately, without a 'save' button (won't apply to open docs, though)
		[[NSUserDefaultsController sharedUserDefaultsController] setAppliesImmediately:YES];
		//NSLog(@"user defaults did load");
	}
	else
	{
		NSLog(@"default settings could not be loaded from defaults.plist");
	}

	//activate cocoa autosave if pref says so 18 AUG 08 JH
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"prefDoCocoaAutosave"])
	{
		int interval = [[defaults valueForKey:@"prefCocoaAutosaveInterval"] intValue];
		if (interval > 0 && interval < 61)
		{
			int seconds = interval * 60;
			[self setAutosavingDelay:seconds];
		}
	}
	//	get version of OS X
	SInt32 systemVersion;
	Gestalt(gestaltSystemVersion, &systemVersion);

	if (systemVersion < 0x1050)
	{
		//if Leopard's Smart Quotes option is selected but OS is Tiger, switch to Bean's Smart Quotes
		if ([[defaults valueForKey:@"prefSmartQuotesSuppliedByTag"]intValue]==1)
		{
			NSNumber *num = [NSNumber numberWithInt:0];
			[defaults setValue:num forKey:@"prefSmartQuotesSuppliedByTag"];
		}
		//enabling the vertical ruler under Tiger causes gstack underflow error
		if ([defaults boolForKey:@"prefShowVerticalRuler"]==YES)
		{
			[defaults setBool:NO forKey:@"prefShowVerticalRuler"];
		}
		//hierarchy of save panel is different under Tiger
		if ([defaults boolForKey:@"prefSuggestFilename"]==YES)
		{
			[defaults setBool:NO forKey:@"prefSuggestFilename"];
		}
	}
	
	return sharedInstance;
}

-(void)dealloc
{
	[super dealloc];
}

//	change the initial save type based on user default in the Preferences pane
- (NSString *)defaultType
{
	//NSLog(@"called defaultType");
	//	subclassing NSDocumentController and adding this method means we do not have to use the undocumented NSDocument method changeSaveType, although that would have been easier 11 July 2007 BH
	//	we need non-localized file type name, which is used as the key to look up the extension for default file type in info.plist
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *type = nil;
	int formatIndex = 0;

	//	get index of default save format from popup in Preferences from user defaults
	formatIndex = [[defaults objectForKey:@"prefDefaultSaveFormatIndex"] intValue];
	//	get array of doc type dictionaries from info.plist in bundle
	NSArray *docTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleDocumentTypes"];
	//	get doc type with matching index (list is populated from array in order of array in info.plist, so should work)
	id defaultDocType = [docTypes objectAtIndex:formatIndex];

	//	get the string name for the doc type from the dictionary for the doc type
	type = [defaultDocType objectForKey: @"CFBundleTypeName"];
	//	return the string of the doc type, which NSDocument uses as a key for the default save doc type
	if (type) { return type; }
	//	if there's a problem, get the super's default save type, which is always the first type in the info.plist file
	else { return [super defaultType]; }
}	

//	changes smart quotes style for all documents
-(IBAction)setSmartQuotesStyleInAllDocuments:(id)sender
{
	NSEnumerator *enumerator = [[self documents] objectEnumerator];
	id document;
	while (document = [enumerator nextObject])
	{
		[document setSmartQuotesStyleAction:nil];
	}
}

//	changes smart quotes style for all documents
-(IBAction)setAllowsDocumentBackgroundColorChangeInAllDocuments:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL allowColorChange = [defaults boolForKey:@"prefAllowBackgroundColorChange"];
	NSEnumerator *enumerator = [[self documents] objectEnumerator];
	id document;
	while (document = [enumerator nextObject])
	{
		if (![document readOnlyDoc])
		{
			id tv = [document firstTextView];
			[tv setAllowsDocumentBackgroundColorChange:allowColorChange];
		}
	}
}

//called by prefs > general > text cursor > cursor color > color well action 
-(IBAction)changeInsertionPointColor:(id)sender
{
	NSEnumerator *enumerator = [[self documents] objectEnumerator];
	id document, color = [sender color];
		while (document = [enumerator nextObject])
	{
		if (![document shouldUseAltTextColors] && color)
			[[document firstTextView] setInsertionPointColor:color];
	}
}

//called by prefs > general > text cursor > shape matrix action 
-(IBAction)changeInsertionPointShape:(id)sender
{
	NSEnumerator *enumerator = [[self documents] objectEnumerator];
	id document;
	while (document = [enumerator nextObject])
	{
		int tag = [[sender selectedCell] tag];
		if (tag > -1 && tag < 3)
			[[document firstTextView] setBeanCursorShape:tag];
		else
			[[document firstTextView] setBeanCursorShape:0];
	}
}

//	update display of headers and footers in all documents based on changes made in Preferences
-(IBAction)updateDisplayOfHeadersAndFooters:(id)sender
{
	NSEnumerator *enumerator = [[self documents] objectEnumerator];
	id document;
	while (document = [enumerator nextObject])
	{
		//headerFooterSetting == 0 means use pref settings for header/footer (rather than doc-specific ones)
		if ([document headerFooterSetting] == 0 && [document hasMultiplePages])
		{
			id pageView = [[[document firstTextView] enclosingScrollView] documentView];
			[pageView setForceRedraw:YES];
			[pageView setNeedsDisplay:YES];
		}
	}
}

//	update for all documents based on button in Preferences
//	note: actual respect for system setting doesn't doesn't occur until app is restarted
//	BUG: under SL, setting lm setUsesScreenFonts:NO causes kern attribute to be treated as paragraph not span; filed bug report (7367161)
-(IBAction)toggleRespectAntialiasingThreshold:(id)sender
{
	NSEnumerator *enumerator = [[self documents] objectEnumerator];
	id document;
	while (document = [enumerator nextObject])
	{
		id lm = [[document firstTextView] layoutManager];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults boolForKey:@"prefRespectAntialiasingThreshold"])
		{
			//NSLog(@"fine kerning off");
			[lm setUsesScreenFonts:YES];
		}
		else
		{
			//NSLog(@"fine kerning on");
			[lm setUsesScreenFonts:NO];
		}
	}
}

-(IBAction)toggleCocoaAutosave:(id)sender
{
	[tfPrefAutosaveInterval validateEditing];
	
	//activate cocoa autosave if pref says so 18 AUG 08 JH
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"prefDoCocoaAutosave"])
	{
		int interval = [[defaults valueForKey:@"prefCocoaAutosaveInterval"] intValue];
		if (interval > 0 && interval < 61)
		{
			int seconds = interval * 60;
			[self setAutosavingDelay:seconds];
		}
	}
	//or turn it off
	else
	{
		[self setAutosavingDelay:0];
	}
}

//	menu validation
//	_openRecentDocument does not get called at all by any Open Recent Documents menu items when a document is in full screen mode (SetSystemUIMode called with kUIModeAllSuppressed). This looks like a bug. We disable the Open Recents menu items when in full screen mode, for lack of a better option.
- (BOOL)validateMenuItem:(NSMenuItem *)userInterfaceItem
{
	SEL action = [userInterfaceItem action];
	if ([self respondsToSelector:@selector(_openRecentDocument:)] && action == @selector(_openRecentDocument:))
	{
		if ([[self currentDocument] fullScreen])
		{
			return NO;
		}
		else
		{
			return [super validateUserInterfaceItem: userInterfaceItem];
		}
	}
	if (action == @selector(newDocumentFromPasteboard:))
	{
		return [[NSPasteboard pasteboardWithName:NSGeneralPboard] changeCount];
	}
	if (action == @selector(newDocumentFromSelection:) || action == @selector(printSelection:))
	{
		//at least one doc is open and at least one character is selected
		return ([[NSApp orderedDocuments] count] && [[[self currentDocument] firstTextView] selectedRange].length);
	}
	if (action == @selector(performFindPanelAction:))
	{
		return [[NSApp orderedDocuments] count];
	}
	return YES;
}

//24 JUNE 08 JH -- notifies inspector panel to gray-out
- (void)removeDocument:(NSDocument *)document
{
	[super removeDocument:document];
	if (![[self documents] count])
	{
		//notify inspector panel to gray-out because there are no documents to inspect
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHDocumentControllerHasNoDocumentsNotification" object:self userInfo:nil];
	}
}


/*
//debugging
-(IBAction) _openRecentDocument:(id)sender
{
	//NSLog(@"_openRecentDocument was called");
	[super _openRecentDocument:sender];
}
*/

//based on GnuSTEP's openUntitledDocumentOfType:display: method
- (IBAction) newDocumentFromPasteboard: (id)sender
{
	BOOL success = NO;
	NSError *anError = nil;
	NSArray *types;
	NSString *preferredType, *typeName;
	NSPasteboard *pboard;
	id document;
	
	switch ([sender tag])
	{
		//new rich text document with contents of pasteboard
		case 0:
			//opens a new document (returned as id)
			document = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:&anError];
		
			if (!document) { return; }

			pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
			types = [pboard types];
			preferredType = [[document firstTextView] preferredPasteboardTypeFromArray:types restrictedToTypesFromArray:nil];

			if (preferredType)
			{
				//this retrieves text from pasteboard and inserts it into the newly opened Bean document
				success = [[document firstTextView] readSelectionFromPasteboard:pboard type:preferredType];
			}
			
			if (!success) { NSBeep(); }
			
			break;
		//new plain text document
		case 1:
			
			//should NOT use localized string here 10 APR 09 JH
			typeName = @"Text Document (.txt)";

			//open a new document of type TXTDoc rather than NSDocumentController's usual 'defaultType'
			document = [self makeUntitledDocumentOfType:typeName error:&anError];
			
			if (!document) { return; }
			
			// do here what is usually done in openUntitledDocumentOfType:display: (code based on GnuSTEP)
			[self addDocument:document];
			if ([self shouldCreateUI])
			{
				[document makeWindowControllers];
				[document showWindows];
			}
			
			pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
			types = [pboard types];
			//should choose plain text version from pasteboard
			preferredType = [[document firstTextView] preferredPasteboardTypeFromArray:types restrictedToTypesFromArray:nil];

			if (preferredType)
			{
				//this retrieves text from pasteboard and inserts it into the newly opened Bean document
				success = [[document firstTextView] readSelectionFromPasteboard:pboard type:preferredType];
			}
			
			if (!success) { NSBeep(); }

			break;
		case 2: //duplicate front-most document
			break;
	}	
}

//based on GnuSTEP's openUntitledDocumentOfType:display: method
- (IBAction) newPlainTextDocument: (id)sender
{
	//should NOT use localized string here 10 APR 09 JH
	NSString *typeName = @"Text Document (.txt)";
	NSError *outError;
	//open a new document of type TXTDoc rather than NSDocumentController's usual 'defaultType'
	id document = [self makeUntitledDocumentOfType:typeName error:&outError];
	
	if (document == nil) // || outError) 
	{
		return;
	}

	[self addDocument:document];

	if ([self shouldCreateUI])
	{
		[document makeWindowControllers];
		[document showWindows];
	}
}

//returns nil of no document or selection
-(NSAttributedString *)attributedStringFromSelectedRangesInCurrentDocument
{
	//no docs, so return
	if ([[self documents] count] == 0) { return nil; }
	//get frontmost document and textView
	id doc = [[NSApp orderedDocuments] objectAtIndex:0];
	id tv = [doc firstTextView];
	//no selection, so return
	if (0 == [tv selectedRange].length) { return nil; }
	//string for combined selected ranges
	NSMutableAttributedString *mas = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];
	NSEnumerator *e = [[tv selectedRanges] objectEnumerator];
	NSValue *r;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//enumerate selected ranges
	while (r = [e nextObject])
	{
		NSRange range = [r rangeValue];
		if (range.length > 0)
		{
			//add divider for selected ranges if user prefs say so
			if ([defaults boolForKey:@"prefPrintSelectionAddsOffset"] && [[mas string]length])
			{
				NSString *dividerString = [defaults stringForKey:@"prefPasteSelectionDividerString"];
				if (!dividerString)
					dividerString = @"-----";
				NSString *divider = [NSString stringWithFormat:@"%C%@%C", NSParagraphSeparatorCharacter, dividerString, NSParagraphSeparatorCharacter];
				NSAttributedString *attrDividerString = [[[NSAttributedString alloc] initWithString:divider attributes:nil] autorelease];
				[mas appendAttributedString:attrDividerString];
			}
			NSAttributedString *as = [[tv textStorage] attributedSubstringFromRange:range];
			[mas appendAttributedString:as];
		}
	}
	//return non-mutable attributed string
	return [[mas copy] autorelease];
}

-(IBAction) newDocumentFromSelection: (id)sender
{
	//make attr string from selectedRanges in textViews of currentDocument 
	NSAttributedString *attrString = [self attributedStringFromSelectedRangesInCurrentDocument];
	//no doc or selection
	if (!attrString) { return; }
	//make new doc
	NSError *outError = nil;
	//open untitled doc of default type
	id doc = [self openUntitledDocumentAndDisplay:YES error:&outError];
	//error!
	if (outError || !doc) { return; }
	//replace textStorage of new doc with attr string from above
	id ts = [doc textStorage];
	[ts replaceCharactersInRange:NSMakeRange(0, [ts length]) withAttributedString:attrString];
	//bugfix 25 AUG 09 (new doc could be closed without save prompt)
	[doc updateChangeCount:NSChangeDone];
}

//	this is the usual way to open a new Untitled document, such as when the app starts without being passed a document to open
//	but if prefUseCustomTemplate, we open a locked document (at prefCustomTemplateLocation) as template for new documents
- (id)openUntitledDocumentAndDisplay:(BOOL)displayDocument error:(NSError **)outError
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	BOOL shouldUseCustomTemplate = [[defaults valueForKey:@"prefUseCustomTemplate"] intValue]; //cast as BOOL
	if (!shouldUseCustomTemplate)
	{
		//open untitled document, as usual
		// 5 FEB 09 JH corrected pass error by reference
		return [super openUntitledDocumentAndDisplay:displayDocument  error:outError]; 
	}
	else
	{
		//get path of template document (if one was chosen)
		NSString *theFilename = [defaults stringForKey:@"prefCustomTemplateLocation"];
		//make sure that file still exists there
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL fileExists = NO;
		BOOL isLocked = NO;
		fileExists = [fm fileExistsAtPath:theFilename isDirectory:NULL];
		if (fileExists)
		{
			NSDictionary *theFileAttrs = [fm fileAttributesAtPath:theFilename traverseLink:YES];
			isLocked = [[theFileAttrs objectForKey:NSFileImmutable] boolValue];
		}
		//if there is a problem with opening the template file, just open an Untitled document
		if (!theFilename || !fileExists || !isLocked)
		{
			//since user selected template is no longer valid, revert pref to just use generic template
			[defaults setValue:0 forKey:@"prefUseCustomTemplate"];
			[defaults removeObjectForKey:@"prefCustomTemplateLocation"];
			//alert user that template is no longer valid; shows once only (until template is invalid again)
			[[NSAlert alertWithMessageText:NSLocalizedString(@"The custom template for new documents is not valid.", @"Title of alert indicating that the customer new document template is not valid.")
					defaultButton:NSLocalizedString(@"OK", @"OK")
					alternateButton:nil
					otherButton:nil
					informativeTextWithFormat:NSLocalizedString(@"You can choose a new template under Preferences > Documents.", @"Text of alert indicating you can choose a new template under Preferences > Documents.")] runModal];
			//open untitled document since there was a problem opening the saved template
			return [super openUntitledDocumentAndDisplay:displayDocument  error:outError];
		}
		NSError *anError = nil;
		//open template document as Untitled document
		// 5 FEB 09 JH corrected pass error by reference
		id document = [super openDocumentWithContentsOfURL:[NSURL fileURLWithPath:theFilename] display:YES error:outError];
		if (document == nil) 
		{
			NSString *err = [anError localizedDescription];
			//log error and description of error
			NSLog(@"Could not open the template document. @%", err);
			//fall back to new untitled document since locked template produced nothing for some reaason
			return [super openUntitledDocumentAndDisplay:displayDocument  error:outError];
		}
		[document setWasCreatedUsingNewDocumentTemplate:YES];
		return document;
	}
}

-(IBAction)performTextFinderAction:(id)sender
{
	//action type is specified by tag of sender
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//use OS X find panel
	if ([defaults boolForKey:@"prefUseSimpleFindPanel"])
	{
		//BUGFIX 2.4.4 11 MAY 2011 fixed screwed up sanity check 
		if ([[NSApp orderedDocuments] count] > 0)
		{
			id frontDoc = [[NSApp orderedDocuments] objectAtIndex:0];
			if (frontDoc)
			{
				[[frontDoc firstTextView] performFindPanelAction:sender];
			}
		}
	}
	//use RegEx find panel -- more powerful and intuitive (even if he sez so himself), but not faster
	else
	{
		id finder = [TextFinder sharedInstance];
		
		switch ([sender tag])
		{
			//show find panel
			case 1:
			{
				[finder findPanel];
				[finder orderFrontFindPanel:sender];
				break;
			}
			//next
			case 2:
			{
				[finder findNext:sender];
				break;
			}
			//previous
			case 3:
			{
				[finder findPrevious:sender];
				break;
			}
			//replace all
			case 4:
			{
				[finder replaceAll:sender];
				break;
			}
			//replace
			case 5:
			{
				[finder replace:sender];
				break;
			}
			//replace and find
			case 6:
			{
				[finder replaceAndFind:sender];
				break;
			}
			//set find string
			case 7:
			{
				[finder takeFindStringFromSelection:sender];			
				break;
			}
			//replace all in selection
			case 8:
			{
				//we don't have a method for this specifically, but we could have easily
				//NIMP;
			}
		}
	}
}

-(IBAction)printSelection:(id)sender
{
	//if no docs, return
	if ([[self documents] count] == 0) { return; }

	//make attr string from selectedRanges in textViews of currentDocument 
	NSAttributedString *attrString = [self attributedStringFromSelectedRangesInCurrentDocument];
	//no doc or selection
	if (!attrString) { return; }

	//necessary: need NSFitPagination!
	NSPrintInfo *printInfo = [[[NSPrintInfo alloc] initWithDictionary:[[NSPrintInfo sharedPrintInfo] dictionary]] autorelease];
	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSAutoPagination];
	[printInfo setHorizontallyCentered:NO];
	[printInfo setVerticallyCentered:NO];

	//create a textView for printing
	//NOTE: JHPrintView subclass overrides pageHeader / pageFooter to return @""
	JHPrintView *printView = [[[JHPrintView alloc] initWithFrame:[printInfo imageablePageBounds]] autorelease];
	//insert the attr string of text from selected ranges
	[printView insertText:attrString];
	
	//get frontmost document and textView
	id doc = [[NSApp orderedDocuments] objectAtIndex:0];
	id tv = [doc firstTextView];
	id win = [tv window];

	//print view
	NSPrintOperation *op = [NSPrintOperation
				printOperationWithView:printView
				printInfo:printInfo];				
	//print panel attached to doc window; no callback
	[op	runOperationModalForWindow:win
				delegate:nil
				didRunSelector:NULL 
				contextInfo:NULL];
}

@end
