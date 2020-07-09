/*
  JHFindPanel.h
  Copyright (c) 2007-2011 James Hoover
 */


#import "JHFindPanel.h"
#import "JHLayoutManager.h" //for displaying 'invisible' characters

//kludges
BOOL onlyInSelectionButtonWasOn; //global (panel is shared instance)
BOOL _altKeyDown;
int _tmpRange;

@implementation JHFindPanel

- (void)awakeFromNib
{
	[self setDelegate:self];

	// load localization strings into UI
	[findLabel setObjectValue:NSLocalizedStringFromTable(@"Find:", @"FindPanel", @"Find:")];
	[replaceWithLabel setObjectValue:NSLocalizedStringFromTable(@"Replace:", @"FindPanel", @"Replace:")];
	//pressing cancel in replace cell can have bad consequences (if find matches, cancel sends replace action when replace not wanted) 
	[[replaceTextField cell] setCancelButtonCell:nil];
	//
	[ignoreCaseButton setTitle:NSLocalizedStringFromTable(@"Ignore case", @"FindPanel", @"Ignore case")];
	[ignoreCaseButton sizeToFit];
	[useRegExButton setTitle:NSLocalizedStringFromTable(@"Match patterns (Regex)", @"FindPanel", @"Match patterns (Regex)")];
	[useRegExButton sizeToFit];
	[patternPopupButton setTitle:NSLocalizedStringFromTable(@"Patterns…", @"FindPanel", @"Patterns…")];
	//
	[findNextButton setTitle:NSLocalizedStringFromTable(@"Next", @"FindPanel", @"Next")];
	[findPreviousButton setTitle:NSLocalizedStringFromTable(@"Previous", @"FindPanel", @"Previous")];
	[findAndReplaceButton setTitle:NSLocalizedStringFromTable(@"Replace & Find", @"FindPanel", @"Replace & Find")];
	[replaceButton setTitle:NSLocalizedStringFromTable(@"Replace", @"FindPanel", @"Replace")];
	//	
	[selectAllButton setTitle:NSLocalizedStringFromTable(@"Select All", @"FindPanel", @"Select All")];
	[replaceAllButton setTitle:NSLocalizedStringFromTable(@"Replace All", @"FindPanel", @"Replace All")];
	[[rangePopupButton itemAtIndex:0] setTitle:NSLocalizedStringFromTable(@"in entire document", @"FindPanel", @"in entire document")];
	[[rangePopupButton itemAtIndex:1] setTitle:NSLocalizedStringFromTable(@"in selection only", @"FindPanel", @"in selection only")];
	[optionKeyLabel setObjectValue:NSLocalizedStringFromTable(@"option key", @"FindPanel", @"option key")];
	// find search field history popup menu
	[[fieldHistory itemWithTag:1000] setTitle:NSLocalizedStringFromTable(@"Recent Searches", @"FindPanel", @"Recent Searches")];
	[[fieldHistory itemWithTag:1002] setTitle:NSLocalizedStringFromTable(@"Clear Recent Searches", @"FindPanel", @"Clear Recent Searches")];
	// window title
	[self setTitle:NSLocalizedStringFromTable(@"Find", @"FindPanel", @"Find")];
	
}

- (void)dealloc
{
	if (findFieldEditor) [findFieldEditor release]; // <==========release
	[super dealloc];
}

// return a field editor (=textView) for the Find and Replace fields that show invisible characters
- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject
{
	if (findFieldEditor == nil)
	{
		// field editor is NSTextView
		findFieldEditor = [[NSTextView alloc] initWithFrame:NSZeroRect];  // <==========init, released in dealloc
		// assign JHLayoutManager so invisible characters will show in search field
		JHLayoutManager *layoutManager = [[JHLayoutManager alloc] init];  // <==========init
		[layoutManager setDelegate:self];
		[layoutManager setShowInvisibleCharacters:YES];
		id textContainer = [findFieldEditor textContainer];
		[textContainer replaceLayoutManager:layoutManager];
		[layoutManager release];  // <==========release
		//make textView a field editor (tab, return etc. do not commit changes)
		[findFieldEditor setFieldEditor:YES];
		[findFieldEditor setDelegate:anObject];
	}
	if (!findFieldEditor) return nil; //shouldn't happen
	return findFieldEditor;
}

// when Option key is pressed, the Find/Replace All actions ONLY affect text selection
	//this duplicates OS X find panel behavior
	//toggles 'in document/in selection only' control in Find panel UI
	//based on implementation in OgreKitAdvancedFindPanelController.m by Isao Sonobe
	//TODO: would be nice to set 'in selection' in blue font color when alt key is pressed
- (void)flagsChanged:(NSEvent *)theEvent
{
	if ([theEvent modifierFlags] & NSAlternateKeyMask)
	{
		// alt key pressed
		if (!_altKeyDown)
		{
			_altKeyDown = YES;
			//BUGFIX 2.4.4 11 MAY 2011 so toggle works correctly 
			int tag = [[rangePopupButton selectedItem] tag] ? 0 : 1;
			[rangePopupButton selectItemWithTag:tag];
		}
	}
	else
	{
		// alt key released
		if (_altKeyDown)
		{
			_altKeyDown = NO;
			//BUGFIX 2.4.4 11 MAY 2011 so toggle works correctly 
			int tag = [[rangePopupButton selectedItem] tag] ? 0 : 1;
			[rangePopupButton selectItemWithTag:tag];
		}
	}
	[super flagsChanged:theEvent];
}

@end