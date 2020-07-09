/*
 TextFinder.m
 Original version Copyright (c) 1995-2001 by Apple Computer, Inc., all rights reserved.
 Author: Ali Ozer

 Changes:
 - Changed by Matt Gemmell on July 2 2003:
   - Altered autosave name to "FindPanel", to distinguish from original TextFinder Find Panels.
   - Added validateMenuItem: method to sensibly enable/disable menuitems with actions targetting a TextFinder.
	 (By default, menuitems calling orderFrontFindPanel: are always enabled; this is easily changed however).
   - Changed replace: method to replace next occurrence of findString, instead of just current selection. Also affects replaceAndFind:.
	 (Will replace current selection if current selection is findString, respecting state of ignoreCaseButton).
   - Added replaceAndFindPrevious: action method.
   - Find panel will now remember the last-used Replace string per-application between launches.

 Description: Find and replace functionality with a minimal panel...
*/

/*
	Changes by James Hoover 18 Feb 09 for Bean 2.2.0
	------------------------------------------------
	- exposed hidden functionality of OS X Find Panel that confused some users (Replace All/Find All in Document/in Selection have their own buttons now)
	- added Regular Expressions via RegExKitLite and ICU library (see below), with popup menu containing common patterns so users aren't intimidated
	- field editor for findTextField displays spaces, tabs, returns as visible characters (via JHLayoutManager)
	
	- additional inspiration for adding RegEx to Find Panel (and particularly the FindAll: method) from IDEKit_FindPaletteController.m by Glenn Andreas, LGPL license
	- Regular Expressions: RegExKitLite by John Engelhart (BSD license) and ICU library (libicucore.dylib) by IBM
	- RegExKitLite provides easy access to the ICU library via a category on NSString. ICU library comes installed with OS X

	Changes by James Hoover 20 Mar 09 for Bean 2.3.0
	------------------------------------------------
	- ENHANCEMENT: 'findAll/replaceAll' now operate on the selectedRanges (that is, non-contiguous text selections), not just selectedRange as the original TextFinder code did
	- ENHANCEMENT: the symbol \0 in the Replace text field allows you to use the found match text as part of the replacement text when Regular Expressions is enabled. Example: find 'sample text', replace '<<\0>>', result '<<sample text>>'
	- BUGFIX: when the text selection doesn't match the Find field text, 'replace' now highlights next match (if there is one) instead of replacing next match without asking

	Changes by James Hoover 3 Feb 10 for Bean 2.4.3
	------------------------------------------------
	- ENHANCEMENT: range(s) of selected text remain selected after Replace or Replace All; previous behavior (resulting in *no* selection after Replace or Replace All) can be reinstated with a preference setting: prefNoSelectionAfterReplace = YES. 

	 Changes by James Hoover 10 MAY 11 for Bean 2.4.4
	 ------------------------------------------------
	 - BUGFIX: added missing brackets at lines 617, 620 that caused Replace to misbehave

	License
	------------------------------------------------
	-Because the license attached to the original TextFinder and its genetic offspring is very permissive, this implementation of TextFinder.[mh] and its accompanying files (RegEx.plist, FindPanel.strings, JHFindPanel.[mh]) are released under the BSD license: Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
	•	Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	•	Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	•	Neither the name of the Zang Industries nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	
	TODO:
	maybe add sound match, fuzzy match? (use RegEx to break backing string into array, then test each word individually)
*/

#import <Cocoa/Cocoa.h>
#import "TextFinder.h"
#import "RegexKitLite.h" //adds ICU library for Regular Expressions

@implementation TextFinder

static id sharedFindObject = nil;

#pragma mark -
#pragma mark ---- init, load UI ----

// ******************* init, load UI ********************

+ (id)sharedInstance {
	if (!sharedFindObject) {
		[[self allocWithZone:[[NSApplication sharedApplication] zone]] init];
	}
	return sharedFindObject;
}

- (id)init {
	if (sharedFindObject) {
		[super dealloc];
		return sharedFindObject;
	}

	if (!(self = [super init])) return nil;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidActivate:) name:NSApplicationDidBecomeActiveNotification object:[NSApplication sharedApplication]];

	[self setFindString:@"" writeToPasteboard:NO];
	[self loadFindStringFromPasteboard];

	// Register defaults
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
	[defaultValues setObject:@"" forKey:Last_Replace_String__Key];
	[defaults registerDefaults:defaultValues];
	_noSelectionAfterReplace = [defaults boolForKey:@"prefNoSelectionAfterReplace"];

	sharedFindObject = self;
	return self;
}

- (void)appDidActivate:(NSNotification *)notification {
	[self loadFindStringFromPasteboard];
}

- (void)loadFindStringFromPasteboard {
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSFindPboard];
	if ([[pasteboard types] containsObject:NSStringPboardType]) {
		NSString *string = [pasteboard stringForType:NSStringPboardType];
		if (string && [string length]) {
			[self setFindString:string writeToPasteboard:NO];
		}
	}
}

- (void)loadFindStringToPasteboard {
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSFindPboard];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pasteboard setString:[self findString] forType:NSStringPboardType];
}

-(void)loadRegExMenu
{
	//	1) populate 'Patterns...' popup button menu with symbol descriptions, tags and actions
	//	2) populate matching array of symbols the action method will insert into the find text field
	NSArray *regExItems = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"RegEx" ofType:@"plist"]];
	//will hold patterns for selector
	NSMutableArray *patterns = [NSMutableArray arrayWithCapacity:[regExItems count]];
	//iterate items, for each: load menu item title and add pattern to array for selector to use
	int i;
	NSDictionary *menuItem;
	//i = 1 to avoid dealing with popup button title, which is really menu item at index 0 even tho it doesn't appear in the popup menu!
	for (i = 1; i < [regExItems count] + 1; i++)
	{
		//create popup menu item
		menuItem = [regExItems objectAtIndex:i - 1];
		[patternPopupButton addItemWithTitle:[menuItem objectForKey:@"menuTitle"]];
		[[patternPopupButton itemAtIndex:i] setTag:i - 1];
		[[patternPopupButton itemAtIndex:i] setTarget:self];
		[[patternPopupButton itemAtIndex:i] setAction:@selector(insertRegExPatternIntoFindTextField:)];
		//add pattern to array
		[patterns insertObject:[menuItem objectForKey:@"pattern"] atIndex:i - 1];
	}
	//store patterns array in getter
	if (!regExPatterns) regExPatterns = [patterns copy];
}

- (void)loadUI {
	if (!findTextField) {
		if (![NSBundle loadNibNamed:@"FindPanel" owner:self])  {
			NSLog(@"Failed to load FindPanel.nib");
			NSBeep();
		}
	if (self == sharedFindObject) [[findTextField window] setFrameAutosaveName:@"FindPanel"];
	}
	[findTextField setStringValue:[self findString]];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[replaceTextField setStringValue:[defaults objectForKey:Last_Replace_String__Key]];
	
	//for RegEx in Bean
	[self regExButtonAction:nil];
	[self loadRegExMenu];
}

- (void)dealloc {

	if (self != sharedFindObject) {
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		if (findString) [findString release];
		if (regExPatterns) [regExPatterns release];
		if (_error) [_error release];
		[super dealloc];
	}
}

#pragma mark -
#pragma mark ---- getters, setters ----

// ******************* getters, setters ********************

- (NSString *)findString {
	return findString;
}

- (void)setFindString:(NSString *)string {
	[self setFindString:string writeToPasteboard:YES];
}

- (void)setFindString:(NSString *)string writeToPasteboard:(BOOL)flag {
	if ([string isEqualToString:findString]) return;
	[findString autorelease];
	findString = [string copyWithZone:[self zone]];
	if (findTextField) {
		[findTextField setStringValue:string];
		[findTextField selectText:nil];
	}
	if (flag) [self loadFindStringToPasteboard];
}

//error reported from regexkitlite (regex error)
-(NSError *)error
{
	return _error;
}

-(void)setError:(NSError *)anError
{
	[anError retain];
	[_error release];
	_error = anError;
}

- (NSTextView *)textObjectToSearchIn {
	id obj = [[NSApp mainWindow] firstResponder];
	return (obj && [obj isKindOfClass:[NSTextView class]]) ? obj : nil;
}

- (NSPanel *)findPanel {
	if (!findTextField) [self loadUI];
	return (NSPanel *)[findTextField window];
}

#pragma mark -
#pragma mark ---- find methods ----

// ******************* find methods ********************

/* The primitive for finding; this ends up setting the status field (and beeping if necessary)... */
//bug: invalid regex will not produce an error when no text to search in
//note: we always wrap when searching
- (BOOL)find:(BOOL)direction
{
	if (findTextField) [self setFindString:[findTextField stringValue]];
	NSTextView *text = [self textObjectToSearchIn];
	lastFindWasSuccessful = NO;
	if (text)
	{
		NSString *textContents = [text string];
		if (textContents && [textContents length])
		{
			NSRange range = {0,0};
			unsigned options = 0;
			// find regex
			if ([useRegExButton state])
			{
				//if no regex to search for, report 'Not found'; avoids regex error message
				if ([[self findString] length])
				{
					if ([ignoreCaseButton state]) options |= RKLCaseless;
					NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
					if ([defaults boolForKey:@"prefRegExMultiline"]) options |= RKLMultiline;
					if ([defaults boolForKey:@"prefRegExDotAll"]) options |= RKLDotAll;
					
					//necessary to call this regexkitlite method, or else replace can happen on an old copy of the backing string
					
					//I thought perhaps we were working on an old cache of the string once for a find operation -- test!
					//[NSString clearStringCache];
					
					range = [textContents rangeOfRegex:[self findString] selectedRange:[text selectedRange] options:options wrap:YES sender:self];
				}
			}
			// find string
			else
			{
				if (direction == Backward) options |= NSBackwardsSearch;
				if ([ignoreCaseButton state]) options |= NSCaseInsensitiveSearch;
				
				range = [textContents findString:[self findString] selectedRange:[text selectedRange] options:options wrap:YES];
			}
			// show found string
			if (range.length)
			{
				[text setSelectedRange:range];
				[text scrollRangeToVisible:range];
				//show find indicator (safron lozenge) Leopard only with safety check
				SInt32 systemVersion;
				if (Gestalt(gestaltSystemVersion, &systemVersion) == noErr && !(systemVersion < 0x1050));
				{
					//show find indicator (safron lozenge) Leopard only
					if ([text respondsToSelector:@selector(showFindIndicatorForRange:)] && range.length < 100)
					{
						[text showFindIndicatorForRange:range];
					}
				}
				lastFindWasSuccessful = YES;
			}
		}
	}
	if (!lastFindWasSuccessful)
	{
		NSBeep();
		[statusField setStringValue:NSLocalizedStringFromTable(@"Not found", @"FindPanel", @"Not found")];
	}
	else
	{
		[statusField setStringValue:@""];
	}
	// regexkitlite gave an error -- show explanatory alert
	if ([self error])
	{
		NSBeginAlertSheet(NSLocalizedStringFromTable(@"Regular Expression Error", @"FindPanel", @"Regular Expression Error"), NSLocalizedStringFromTable(@"OK", @"FindPanel", @"OK"), nil, nil, [NSApp keyWindow], self, nil, nil, NULL, [[self error] localizedFailureReason], NULL);
		[self setError:nil];
		[statusField setStringValue:@""];
	}

	return lastFindWasSuccessful;
}

- (void)orderFrontFindPanel:(id)sender
{
	NSPanel *panel = [self findPanel];
	[findTextField selectText:nil];
	[panel makeKeyAndOrderFront:nil];
}

/**** Action methods for gadgets in the find panel; these should all end up setting or clearing the status field ****/

//connected to findTextField and replaceTextField (action sent on 'return')
- (void)findNextAndOrderFindPanelOut:(id)sender
{
	//deleting the last character in NSSearchField with delete key sends action causing beep and regexkitlite error
	//	we avoid that here
	NSEvent *theEvent = [NSApp currentEvent];
	if ([theEvent type]==NSKeyDown)
	{
		unichar c = 0;
		NSString *chars = [theEvent characters];
		if ([chars length]) c = [chars characterAtIndex:0];
		if (c==NSDeleteCharacter) { return; }
		//if (c != NSCarriageReturnCharacter && c != NSEnterCharacter) { return; }
	}

	//on find @"", do nothing; also, clicking cancel cell sends action; avoid unwanted action
	if ([[sender stringValue] isEqualToString:@""]) { return; }

	switch ([sender tag])
	{
		//replaceTextField > replace action
		case 1:
		{
			[self replace:nil];
			break;
		}
		//findTextField (tag = 0) > find next action
		default:
		{
			[findNextButton performClick:nil];
			if (lastFindWasSuccessful)
			{
				[[self findPanel] orderOut:sender];
			}
			else
			{
				[findTextField selectText:nil];
			}
			break;
		}
	}
}

- (void)findNext:(id)sender
{
	(void)[self find:Forward];
}

//	explanation of findPrevious using RegEx:
//	we iterate through matches until...
//	1) a match is found after the selectedRange AND one match exists before the selectedRange (=previous), or else
//	2) all matches are found (in this case last match is a 'wrapped' findPrevious)
//note: we always wrap when searching
- (void)findPrevious:(id)sender
{
	// find regex
	if ([useRegExButton state])
	{
		//findTextField should be set
		if (findTextField) [self setFindString:[findTextField stringValue]];
		NSTextView *text = [self textObjectToSearchIn];
		NSRange selRange = [text selectedRange];
		NSMutableArray *results = [NSMutableArray array];
		//if no regex to search for, ELSE below reports 'Not found'; avoids regex error message
		if (text && [[self findString] length])
		{
			NSString *textContents = [text string];
			unsigned textLength;
			if (textContents && (textLength = [textContents length]))
			{
				NSRange range, matchRange;
				NSRange fullRange = NSMakeRange(0,textLength);
				unsigned options = 0;
				while (fullRange.length)
				{
					if ([ignoreCaseButton state]) options |= RKLCaseless;
					NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
					if ([defaults boolForKey:@"prefRegExMultiline"]) options |= RKLMultiline;
					if ([defaults boolForKey:@"prefRegExDotAll"]) options |= RKLDotAll;

					range = [textContents rangeOfRegex:[self findString] selectedRange:NSMakeRange(fullRange.location,0) options:options wrap:NO sender:self];
					if (range.length)
					{
						fullRange.location = NSMaxRange(range);
						fullRange.length = textLength - fullRange.location;
						//we break searching if current match if after selected range with previous found count > 1 and...
						if (range.location >= selRange.location && [results count] > 0)
						{
							matchRange = [[results lastObject] rangeValue];
							//...previous match was before selected range
							if (matchRange.location < selRange.location)
								break;
						}
						//save matched range
						[results addObject: [NSValue valueWithRange:range]];
					}
					else
					{
						break;
					}
				}
			}
		}
		//found a match
		if ([results count])
		{
			//show found text
			NSRange foundRange = [[results lastObject]rangeValue];
			[text setSelectedRange:foundRange];
			[text scrollRangeToVisible:foundRange];
			//show find indicator (safron lozenge) Leopard only
			SInt32 systemVersion;
			if (Gestalt(gestaltSystemVersion, &systemVersion) == noErr && !(systemVersion < 0x1050));
			{
				//show find indicator (safron lozenge) Leopard only
				if ([text respondsToSelector:@selector(showFindIndicatorForRange:)] && foundRange.length < 100)
				{
					//instead, we do Leopard check here and call directly
					[text showFindIndicatorForRange:foundRange];
				}
			}
			[statusField setStringValue:@""];
		}
		//not found
		else
		{
			NSBeep();
			[statusField setStringValue:NSLocalizedStringFromTable(@"Not found", @"FindPanel", @"Not found")];
		}
		//regexkitlite gave an error -- show explanatory alert
		if ([self error])
		{
			NSBeginAlertSheet(NSLocalizedStringFromTable(@"Regular Expression Error", @"FindPanel", @"Regular Expression Error"), NSLocalizedStringFromTable(@"OK", @"FindPanel", @"OK"), nil, nil, [NSApp keyWindow], self, nil, nil, NULL, [[self error] localizedFailureReason], NULL);
			[self setError:nil];
			[statusField setStringValue:@""];
		}
	}
	// find string
	else
	{
		(void)[self find:Backward];
	}
}

//based on method from IDEKit_FindPaletteController.m by Glenn Andreas, used under LGPL license
//note: UI button in Bean is 'Select All'
//- ENHANCEMENT: 'findAll/replaceAll' now operate on the selectedRanges (that is, non-contiguous text selections), not just selectedRange as the original TextFinder code did 20 MAR 09 JH
- (void) findAll: (id) sender
{
	NSMutableArray *results = [NSMutableArray array];
	NSTextView *text = [self textObjectToSearchIn];
	if (text)
	{
		if (findTextField) [self setFindString:[findTextField stringValue]];
		NSString *textContents = [text string];
		BOOL inSelection = [[rangePopupButton selectedItem] tag];
		
		//note: even with no selection, there is always a zero length range whose location is the insertion point index 
		NSEnumerator *e = [[text selectedRanges] objectEnumerator];
		NSValue *aRangeValue;
		while (aRangeValue = [e nextObject])
		{
			NSRange rng = [aRangeValue rangeValue];
			unsigned textLocation = inSelection ? rng.location : 0;
			unsigned textLength = inSelection ? rng.length : [textContents length];
			NSRange searchRange = inSelection ? rng : NSMakeRange(0, textLength);
			NSRange range = {0,0};
			if (textContents && textLength)
			{
				unsigned options = 0;
				while (searchRange.length)
				{
					// find regex
					if ([useRegExButton state])
					{
						//if no regex to search for, skip this so 'Not found' will result; avoids regex error message
						if ([[self findString] length])
						{
							//set up options
							if ([ignoreCaseButton state]) options |= RKLCaseless;
							NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
							if ([defaults boolForKey:@"prefRegExMultiline"]) options |= RKLMultiline;
							if ([defaults boolForKey:@"prefRegExDotAll"]) options |= RKLDotAll;

							range = [textContents rangeOfRegex:[self findString] selectedRange:NSMakeRange(searchRange.location,0) options:options wrap:NO sender:self];
						}
					}
					// find string
					else
					{
						if ([ignoreCaseButton state]) options |= NSCaseInsensitiveSearch;
						range = [textContents findString:[self findString] selectedRange:NSMakeRange(searchRange.location,0) options:options wrap:NO];
					}
					//found match
					if (range.length)
					{
						//match is beyond specified range OR match is partially inside range, so ignore it; no more matches to find
						if (range.location >= NSMaxRange(searchRange)
								|| (range.location < NSMaxRange(searchRange) && NSMaxRange(range) > NSMaxRange(searchRange)))
						{
							break;
						}
						searchRange.location = NSMaxRange(range);
						searchRange.length = textLocation + textLength - searchRange.location;
						//add match to results
						[results addObject: [NSValue valueWithRange:range]];
					}
					//no more matches
					else
					{
						break;
					}
				}
			}
		}
	}
	//show results
	if ([results count])
	{
		[text setSelectedRanges:results];
		[statusField setStringValue:[NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"%d found", @"FindPanel", @"%d found"), [results count]]];

	}
	//no results
	else
	{
		NSBeep();
		[statusField setStringValue:NSLocalizedStringFromTable(@"Not found", @"FindPanel", @"Not found")];
	}
	//regexkitlite gave an error -- show explanatory alert
	if ([self error])
	{
		NSBeginAlertSheet(NSLocalizedStringFromTable(@"Regular Expression Error", @"FindPanel", @"Regular Expression Error"), NSLocalizedStringFromTable(@"OK", @"FindPanel",  @"OK"), nil, nil, [NSApp keyWindow], self, nil, nil, NULL, [[self error] localizedFailureReason], NULL);
		[self setError:nil];
		[statusField setStringValue:@""];
	}
}

//if selection != findString, we do findNext: (per Gemmell's TextFinder.m)
//if findNext produces no match here, selection still gets replaced (this is standard find panel behavior)!
//note: perhaps if selection != findString, alert should warn "Replace selected text?" Cancel, Replace
//- BUGFIX: when the text selection doesn't match the Find field text, 'replace' now highlights next match (if there is one) instead of replacing next match without asking 20 MAR 09 JH
- (void)replace:(id)sender
{
	NSTextView *text = [self textObjectToSearchIn];
	NSString *textContents = [text string];
	NSError *error = nil;
	NSString *selection;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSRange foundMatchRange = NSMakeRange(NSNotFound,0);
	BOOL shouldReplace = YES, foundText = NO;
	unsigned options = 0;
	if (text)
	{
		//findTextField should be set
		if (findTextField) [self setFindString:[findTextField stringValue]];

		//find regex
		if ([useRegExButton state])
		{
			if ([[self findString] length])
			{
				//necessary to call this regexkitlite method, or else replace can happen on an old copy of the backing string
				[NSString clearStringCache];
				
				if ([ignoreCaseButton state]) options |= RKLCaseless;
				if ([defaults boolForKey:@"prefRegExMultiline"]) options |= RKLMultiline;
				if ([defaults boolForKey:@"prefRegExDotAll"]) options |= RKLDotAll;

				//range is compared with selected range below 
				foundMatchRange = [textContents rangeOfRegex:[self findString] options:options inRange:[text selectedRange] capture:0 error:&error];
				if (!error && !NSEqualRanges(foundMatchRange, [text selectedRange]))
				{
					shouldReplace = NO;
					foundText = [self find:Forward];
				}
			}
			else
			{
				shouldReplace = NO;
			}
		}
		//find string
		else
		{
			if ([[self findString] length])
			{
				selection = [textContents substringWithRange:[text selectedRange]];
				if ([ignoreCaseButton state] == NSOnState)
				{
					// Do case-insensitive comparison
					if ([selection caseInsensitiveCompare:[self findString]] != NSOrderedSame)
					{
						shouldReplace = NO;
						foundText = [self find:Forward];
					}
				}
				else
				{
					//BUGFIX 11 MAY 2011 missing brackets!
					if (![selection isEqualToString:[self findString]])
					{
						shouldReplace = NO;
						foundText = [self find:Forward];
					}
				}
			}
			else
			{
				shouldReplace = NO;
			}
		}
	}
	
	//default replacement string
	NSMutableString *replacementString = [[replaceTextField stringValue] mutableCopy]; // <======== mutableCopy

	// below code allows found match (= \0) to be used as part of replacement string *when regex is active*
	if ([useRegExButton state])
	{
		//if 1) using regex and 2) 'found match' symbol ( \0 ) is found in replacement string and 3) shouldReplace==YES...
		NSRange symbolRange = [replacementString rangeOfString:@"\\0"];
		if (symbolRange.location != NSNotFound && shouldReplace)
		{
			NSString *foundMatchString;
			foundMatchString = [textContents substringWithRange:foundMatchRange];
			//insert found match string into replacement string
			if (foundMatchString)
				[replacementString replaceCharactersInRange:symbolRange withString:foundMatchString];
		}
	}
	//3 FEB 10 JBH
	NSRange selRange = text ? [text selectedRange] : NSMakeRange(0,0); //else not necessary, but avoids static analysis error
	if (!error && text && [text isEditable]  && shouldReplace && selRange.length != 0
		&& [text shouldChangeTextInRange:selRange replacementString:replacementString])
	{
		[[text textStorage] replaceCharactersInRange:selRange withString:replacementString];
		[text didChangeText];
		//3 FEB 10 JBH retain selection after replace
		if (!_noSelectionAfterReplace) {
			[text setSelectedRange:NSMakeRange(selRange.location, [replacementString length])];
		}
	}
	else
	{
		//no match to replace and could not find Find field text
		if (!foundText) NSBeep();
	}
	
	[statusField setStringValue:@""];
	[replacementString release]; // <======== release
	
	//if regexkitlite error, selectedRange is not result of find, but can't findNext, so show error and bail early (inelegant!)
	if (error)
	{
		NSBeginAlertSheet(NSLocalizedStringFromTable(@"Regular Expression Error", @"FindPanel", @"Regular Expression Error"), NSLocalizedStringFromTable(@"OK", @"FindPanel", @"OK"), nil, nil, [NSApp keyWindow], self, nil, nil, NULL, [error localizedFailureReason], NULL);
	}
	else if (replaceTextField)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:[replaceTextField stringValue] forKey:Last_Replace_String__Key];
	}
}

- (void)replaceAndFind:(id)sender {
	[self replace:sender];
	[self findNext:sender];
}

- (void)replaceAndFindPrevious:(id)sender {
	[self replace:sender];
	[self findPrevious:sender];
}

/* The replaceAll: code is somewhat complex, and more complex than it used to be in DR1.  The main reason for this is to support undo. To play along with the undo mechanism in the text object, this method goes through the shouldChangeTextInRange:replacementString: mechanism. In order to do that, it precomputes the section of the string that is being updated. An alternative would be for this guy to handle the undo for the replaceAll: operation itself, and register the appropriate changes. However, this is simpler...

Turns out this approach of building the new string and inserting it at the appropriate place in the actual text storage also has an added benefit performance; it avoids copying the contents of the string around on every replace, which is significant in large files with many replacements. Of course there is the added cost of the temporary replacement string, but we try to compute that as tightly as possible beforehand to reduce the memory requirements.
*/

//in my tests, this method works about 1/3 faster than replaceAll in Text Edit (substituting '$$$' for 'the' in a 230K file on a G4) JH

//- ENHANCEMENT: 'findAll/replaceAll' now operate on the selectedRanges (that is, non-contiguous text selections), not just selectedRange as the original TextFinder code did 20 MAR 09 JH
- (void)replaceAll:(id)sender
{
	
	NSTextView *text = [self textObjectToSearchIn];
	if (!text)
	{
		NSBeep();
	}
	else
	{
		if (findTextField) [self setFindString:[findTextField stringValue]];
		NSTextStorage *textStorage = [text textStorage];
		NSString *textContents = [text string];
		BOOL inSelection = [[rangePopupButton selectedItem] tag];
		int totalReplaced = 0, lengthChange = 0;
		
		//note: even with no selection, there is always one range with location = insertion point and zero length 
		NSEnumerator *e = [[text selectedRanges] objectEnumerator];
		NSValue *aRangeValue;
		NSMutableArray *rangesToSelect = [NSMutableArray arrayWithCapacity:10]; //?
		while (aRangeValue = [e nextObject])
		{
			NSRange rng = [aRangeValue rangeValue];
			//account for possible change in range index due to replacements in previous selected range
			rng.location = rng.location + lengthChange;
			NSRange replaceRange = inSelection ? rng : NSMakeRange(0, [textStorage length]);
			NSRange firstOccurence = {0,0};
			//options is used throughout the method, so set it up early
			unsigned options = 0, replaced = 0;
			if ([useRegExButton state])
			{
				options = [ignoreCaseButton state] ? options |= RKLCaseless : 0;
				NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
				if ([defaults boolForKey:@"prefRegExMultiline"]) options |= RKLMultiline;
				if ([defaults boolForKey:@"prefRegExDotAll"]) options |= RKLDotAll;
			}
			else
			{
				options = [ignoreCaseButton state] ? options |= NSCaseInsensitiveSearch : 0;
			}
			// Find the first occurence of the string being replaced; if not found, we're done!
			if ([useRegExButton state])
			{
				//avoid illegal regex and error
				if ([[self findString] length])
				{
					//necessary to call this regexkitlite method, or else replace can happen on an old copy of the backing string
					[NSString clearStringCache];
					//do regex search
					firstOccurence = [textContents rangeOfRegex:[self findString] selectedRange:NSMakeRange(replaceRange.location, 0) options:options wrap:NO sender:self];
				}
			}
			else
			{
				firstOccurence = [textContents rangeOfString:[self findString] options:options range:replaceRange];
			}
			
			// We found a match; find last occurence and union ranges to get total range to change
			
			if (firstOccurence.length > 0)
			{
				NSAutoreleasePool *pool;
				NSString *targetString = [self findString];
				NSString *replaceString = [replaceTextField stringValue];

				NSMutableAttributedString *temp;	/* This is the temporary work string in which we will do the replacements... */
				NSRange rangeInOriginalString;	/* Range in the original string where we do the searches */

				// Find the last occurence of the string and union it with the first occurence to compute the tightest range...
				NSRange lastOccurence = firstOccurence;
				// find regex
				if ([useRegExButton state])
				{
					NSRange range, searchRange = replaceRange;
					while (searchRange.length)
					{
						range = [textContents rangeOfRegex:targetString selectedRange:NSMakeRange(searchRange.location, 0) options:options wrap:NO sender:self];
						//match was found
						if (range.length)
						{
							//match is beyond specified range OR match is partially inside range, so ignore it; no more matches to find
							//=OS X text finder behavior
							if (range.location >= NSMaxRange(searchRange)
									|| (range.location < NSMaxRange(searchRange) && NSMaxRange(range) > NSMaxRange(searchRange)))
							{
								break;
							}
							//save match result as lastOccurence (until or unless a next one is found)
							if (range.location > lastOccurence.location)
							{
								lastOccurence = range;
							} 
							searchRange.location = NSMaxRange(range);
							searchRange.length = NSMaxRange(replaceRange) - searchRange.location;
						}
						//no more matches
						else
						{
							break;
						}
					}
				}
				//find string
				else
				{
					lastOccurence = [textContents rangeOfString:targetString options:NSBackwardsSearch|options range:replaceRange];

				}
				rangeInOriginalString = replaceRange = NSUnionRange(firstOccurence, lastOccurence);

				temp = [[NSMutableAttributedString alloc] init];

				[temp beginEditing];

				// The following loop can execute an unlimited number of times, and it could have autorelease activity.
				// To keep things under control, we use a pool, but to be a bit efficient, instead of emptying everytime through
				// the loop, we do it every so often. We can only do this as long as autoreleased items are not supposed to
				// survive between the invocations of the pool!

				pool = [[NSAutoreleasePool alloc] init];

				NSRange foundRange, rangeToCopy;
				NSInteger diffMultiple = 0; //3 FEB 10 JBH
				while (rangeInOriginalString.length > 0)
				{
					if ([useRegExButton state])
					{
						foundRange = [textContents rangeOfRegex:targetString selectedRange:NSMakeRange(rangeInOriginalString.location, 0) options:options wrap:NO sender:self];
					}
					else
					{
						foundRange = [textContents rangeOfString:targetString options:options range:rangeInOriginalString];
					}
					
					//	allows text of 'found match' to be used as part of replacement string when \0 symbol is used in Replace field text 
					NSString *replacementString = nil;
					//if regexp in use and \0 symbol found in replace field text...
					if ([useRegExButton state])
					{
						NSRange symbolRange = [replaceString rangeOfString:@"\\0"];
						if (symbolRange.location != NSNotFound)
						{
							//...replace \0 with found match string in replacement string...
							NSMutableString *startString = [[[replaceTextField stringValue] mutableCopy] autorelease];
							[startString replaceCharactersInRange:symbolRange withString:[textContents substringWithRange:foundRange]];
							replacementString = [[startString copy] autorelease];
						}
					}
					//...otherwise use replace field text
					if (replacementString ==nil)
						replacementString = [replaceTextField stringValue];
					
					// Because we computed the tightest range above, foundRange should always be valid.
					rangeToCopy = NSMakeRange(rangeInOriginalString.location, foundRange.location - rangeInOriginalString.location + 1);
					// Copy upto the start of the found range plus one char (to maintain attributes with the overlap)...
					[temp appendAttributedString:[textStorage attributedSubstringFromRange:rangeToCopy]];
					[temp replaceCharactersInRange:NSMakeRange([temp length] - 1, 1) withString:replacementString];
					rangeInOriginalString.length -= NSMaxRange(foundRange) - rangeInOriginalString.location;
					rangeInOriginalString.location = NSMaxRange(foundRange);
					replaced++;
					// Refresh the pool... See warning above!
					if (replaced % 100 == 0)
					{
						[pool release];
						pool = [[NSAutoreleasePool alloc] init];
					}
					//3 FEB 10 JBH retain selection after replace
					if (!_noSelectionAfterReplace) {
						NSInteger replacementStringLength = [replacementString length];
						NSInteger diff = replacementStringLength - foundRange.length;
						NSRange rangeToSelect = NSMakeRange(foundRange.location + (diff * diffMultiple), replacementStringLength);
						[rangesToSelect addObject:[NSValue valueWithRange:rangeToSelect]];
						diffMultiple++;
					}
				}

				[pool release];

				[temp endEditing];
				
				// Now modify the original string (and create undo action!)
				if ([text shouldChangeTextInRange:replaceRange replacementString:[temp string]])
				{
					[textStorage replaceCharactersInRange:replaceRange withAttributedString:temp];
					totalReplaced = totalReplaced + replaced;
					//keep total of text length changes because they affect each following range location
					lengthChange = lengthChange + [temp length] - replaceRange.length;
					[text didChangeText];
				}
				[temp release];
			}
		}
		//no replacements done
		if (totalReplaced == 0)
		{
			NSBeep();
			[statusField setStringValue:NSLocalizedStringFromTable(@"Not found", @"FindPanel", @"Not found")];
		}
		//did replacements
		else
		{
			[statusField setStringValue:[NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"%d replaced", @"FindPanel", @"%d replaced"), totalReplaced]];
			//3 FEB 10 JBH retain selection after replace
			if (!_noSelectionAfterReplace) {
				[text setSelectedRanges:rangesToSelect];
				[text centerSelectionInVisibleArea:self]; //24 FEB 2010 JBH gives user a clear indication that there was a replacement
			}
		}
	}
	//regexkitlite gave an error -- show explanatory alert
	if ([self error])
	{
		NSBeginAlertSheet(NSLocalizedStringFromTable(@"Regular Expression Error", @"FindPanel", @"Regular Expression Error"), NSLocalizedStringFromTable(@"OK", @"FindPanel",  @"OK"), nil, nil, [NSApp keyWindow], self, nil, nil, NULL, [[self error] localizedFailureReason], NULL);
		[self setError:nil];
		[statusField setStringValue:@""];
	}
	else if (replaceTextField)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:[replaceTextField stringValue] forKey:Last_Replace_String__Key];
	}
}

- (void)takeFindStringFromSelection:(id)sender {
	NSTextView *textView = [self textObjectToSearchIn];
	if (textView) {
		NSString *selection = [[textView string] substringWithRange:[textView selectedRange]];
		[self setFindString:selection];
	}
}

- (void) jumpToSelection:sender {
	NSTextView *textView = [self textObjectToSearchIn];
	if (textView) {
		[textView scrollRangeToVisible:[textView selectedRange]];
	}
}

#pragma mark -
#pragma mark ---- regex stuff ----

// ******************* regex stuff ********************

-(NSArray *)regExPatterns
{
	return regExPatterns;
}

//note: there appears to be no way to shift insertion point from end to middle programmatically
-(IBAction)insertRegExPatternIntoFindTextField:(id)sender
{
	//tag of menu item signifies regex pattern to insert
	int i = [sender tag];
	NSString *pattern = [[self regExPatterns] objectAtIndex:i];

	//get field editor for findTextField
	id fieldEditor = [findTextField currentEditor];
	if (!fieldEditor)
	{
		[[findTextField window] makeFirstResponder:findTextField];
		fieldEditor = [findTextField currentEditor];
	}
	id ts = [fieldEditor textStorage];
	
	//suss insertion point for pattern
	NSRange insertionRange = {0,0};
	if ([fieldEditor selectedRange].length == [ts length])
		//at end if findTextField just got focus (and so selectText got called)
		insertionRange = NSMakeRange([ts length], 0);
	else
		//else at insertion point if editing field text
		insertionRange = [fieldEditor selectedRange];
	
	//for undo
	if ([fieldEditor shouldChangeTextInRange:insertionRange replacementString:pattern])
	{
		//insert the pattern
		[ts replaceCharactersInRange:insertionRange withString:pattern];
	}
	[fieldEditor didChangeText];
	
	// not necessary?
	//[findTextField validateEditing];
}

-(IBAction)regExButtonAction:(id)sender
{
	//change background color of findTextField to remind user that RegEx is active
	//also: bold text in findTextField is binded to prefUseRegEx in nib
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"prefUseRegEx"])
	{
		NSColor	*purdyBlue = [NSColor colorWithCalibratedRed:0.78 green:0.94 blue:1.0 alpha:1.0];
		[findTextField setBackgroundColor:purdyBlue];
	}
	else
	{
		[findTextField setBackgroundColor:[NSColor whiteColor]];
	}
}


#pragma mark -
#pragma mark ---- menu validation ----

// ******************* menu validation ********************

// note: replace buttons are validated for [text isEditable] in bindings in nib
// todo: disable all replace buttons when no find text string(?) can use findTextField.stringValue with transformer
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	NSTextView *textView = [self textObjectToSearchIn];
	
	if (([menuItem action] == @selector(takeFindStringFromSelection:)) || ([menuItem action] == @selector(jumpToSelection:))) {
		if (textView) {
			return !([textView selectedRange].length == 0);
		}
		return NO;
	} else if (([menuItem action] == @selector(findNext:)) || ([menuItem action] == @selector(findPrevious:)) ||
			   ([menuItem action] == @selector(findNextAndOrderFindPanelOut:))) {
		if (textView) {
			return ([self findString] && ![[self findString] isEqualToString:@""]);
		}
		return NO;
	} else if (([menuItem action] == @selector(replace:)) || ([menuItem action] == @selector(replaceAll:)) ||
			   ([menuItem action] == @selector(replaceAndFind:)) || ([menuItem action] == @selector(replaceAndFindPrevious:))) {
		if (textView) {
			if ([textView isEditable]) {
				return ([self findString] && ![[self findString] isEqualToString:@""]);
			}
		}
		return NO;
	} else if ([menuItem action] == @selector(orderFrontFindPanel:)) {
		return YES;
	} else if ([menuItem action] == @selector(insertRegExPatternIntoFindTextField:)) {
		return ![[[self regExPatterns] objectAtIndex:[menuItem tag]] isEqualToString:@""];
	}
	
	return YES;
}

@end

@implementation NSString (NSStringTextFinding)

#pragma mark -
#pragma mark ---- workhorse find methods ----

// ******************* workhorse find methods ********************

- (NSRange)findString:(NSString *)string selectedRange:(NSRange)selectedRange options:(unsigned)options wrap:(BOOL)wrap {
	BOOL forwards = (options & NSBackwardsSearch) == 0;
	unsigned length = [self length];
	NSRange searchRange, range;

	if (forwards) {
	searchRange.location = NSMaxRange(selectedRange);
	searchRange.length = length - searchRange.location;
	range = [self rangeOfString:string options:options range:searchRange];
		if ((range.length == 0) && wrap) {	/* If not found look at the first part of the string */
		searchRange.location = 0;
			searchRange.length = selectedRange.location;
			range = [self rangeOfString:string options:options range:searchRange];
		}
	} else {
	searchRange.location = 0;
	searchRange.length = selectedRange.location;
		range = [self rangeOfString:string options:options range:searchRange];
		if ((range.length == 0) && wrap) {
			searchRange.location = NSMaxRange(selectedRange);
			searchRange.length = length - searchRange.location;
			range = [self rangeOfString:string options:options range:searchRange];
		}
	}
	return range;
}		

- (NSRange)rangeOfRegex:(NSString *)string selectedRange:(NSRange)selectedRange options:(unsigned)options wrap:(BOOL)wrap sender:(id)sender
{
	unsigned length = [self length];
	NSRange searchRange, range;
	NSError *anError;
	//NOTE: selectedRange here is range currently selected, not range to search in; we start search at NSMaxRange(selectedRange)
	searchRange.location = NSMaxRange(selectedRange);
	searchRange.length = length - searchRange.location;
	range = [self rangeOfRegex:string options:options inRange:searchRange capture:0 error: &anError]; 
	//if not found look at the first part of the string
	if ((range.length == 0) && wrap)
	{
		searchRange.location = 0;
		searchRange.length = selectedRange.location;
		range = [self rangeOfRegex:string options:options inRange:searchRange capture:0 error: &anError];
	}
	//communicate error to textFinder for alert panel
	if (anError)
	{
		[sender setError:anError];
	}
	return range;
}


//utility method for Bean
/*
- (int)numberOfMatchesForRegex:(NSString *)regex options:(unsigned)options sender:(id)sender
{
	int numberOfMatches = 0;
	if (!regex || [regex isEqualToString:@""])
	{
		return numberOfMatches;
	}
	NSError *error;
	int stringLength = [self length];
	NSRange searchRange = NSMakeRange(0, stringLength), foundRange;
	while (searchRange.length > 0)
	{
		foundRange = [self rangeOfRegex:regex options:options inRange:searchRange capture:0 error:&error];
		//found match
		if (foundRange.length)
		{
			searchRange = NSMakeRange(NSMaxRange(foundRange), stringLength - NSMaxRange(foundRange));
			//add match to results
			numberOfMatches++;
		}
		//paranoid insurance that while loop breaks
		if (foundRange.location == NSNotFound)
		{
			break;
		}
	}
	//log error
	if (error)
	{
		NSLog(@"Regex Error: %@", [error localizedFailureReason]);
	}
	return numberOfMatches;
}
*/

@end
