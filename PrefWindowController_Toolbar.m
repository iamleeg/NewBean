/*
	PrefWindowController_Toolbar.m
	Bean
		
	Copyright (c) 2007-2011 James Hoover

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

//	a category for toolbar method delegation for Preferences
 
#import "PrefWindowController_Toolbar.h"

//	internal identifiers for toolbar items -- DO NOT LOCALIZE!

//	toolbar itself
#define	PrefsToolbarIdentifier @"Preferences Toolbar Identifier" //toolbar instance
//	toolbar items
#define	PrefGeneralItemIdentifier @"Pref General Item Identifier"
#define	PrefPrintItemIdentifier @"Pref Print Item Identifier"
#define	PrefViewItemIdentifier @"Pref View Item Identifier"
#define	PrefFontItemIdentifier @"Pref Font Item Identifier"
#define	PrefStyleItemIdentifier @"Pref Style Item Identifier"
#define	PrefWindowItemIdentifier @"Pref Window Item Identifier"
#define	PrefFullScreenItemIdentifier @"Pref Full Screen Item Identifier"
#define	PrefAdvancedItemIdentifier @"Pref Advanced Item Identifier"
#define	PrefDocumentsItemIdentifier @"Pref Documents Item Identifier"

@implementation PrefWindowController (PrefWindowController_Toolbar)

#pragma mark-
#pragma mark ---- Toolbar Methods  ----

// ******************* NSToolbar Related Methods *******************

- (void) setupPreferencesToolbar
{
	// Create a new toolbar instance, and attach it to our document window 
	NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: PrefsToolbarIdentifier] autorelease];
	// Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
	[toolbar setAllowsUserCustomization: NO];
	[toolbar setAutosavesConfiguration: NO];
	[toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
	//[toolbar setDisplayMode: NSToolbarDisplayModeLabelOnly];
	[toolbar setShowsBaselineSeparator:YES];
	//[toolbar setSizeMode:NSToolbarSizeModeSmall];
	[toolbar setSizeMode:NSToolbarSizeModeRegular];
	// We are the delegate
	[toolbar setDelegate:self];
	// Attach the toolbar to the document window 
	[prefWindow setToolbar: toolbar];
	//select general pane
	[[prefWindow toolbar] setSelectedItemIdentifier:PrefGeneralItemIdentifier];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	// Required delegate method:  Given an item identifier, this method returns an item 
	// The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
	NSToolbarItem *toolbarItem = nil;
	if ([itemIdent isEqual: PrefGeneralItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"pref toolbar label: General", @"pref toolbar label: General")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBPrefGeneralItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showPrefPane:)];
	}
	else if ([itemIdent isEqual: PrefDocumentsItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"pref toolbar label: Documents", @"pref toolbar label: Documents")];
		[toolbarItem setImage: [NSImage imageNamed: @"multipleitems"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showPrefPane:)];
	}
	else if ([itemIdent isEqual: PrefPrintItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"pref toolbar label: Printing", @"pref toolbar label: Printing")];
		[toolbarItem setImage: [NSImage imageNamed: @"NSToolbarPrintItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showPrefPane:)];
	}
	else if ([itemIdent isEqual: PrefViewItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"pref toolbar label: View", @"pref toolbar label: View")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBLayoutItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showPrefPane:)];
	}
	else if ([itemIdent isEqual: PrefFontItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"pref toolbar label: Font", @"pref toolbar label: Font")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBShowFontPanelItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showPrefPane:)];
	}
	else if ([itemIdent isEqual: PrefStyleItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"pref toolbar label: Style", @"pref toolbar label: Style")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBStyleItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showPrefPane:)];
	}
	else if ([itemIdent isEqual: PrefWindowItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"pref toolbar label: Window", @"pref toolbar label: Window")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBWindowItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showPrefPane:)];
	}
	else if ([itemIdent isEqual: PrefFullScreenItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"pref toolbar label: Full Screen", @"pref toolbar label: Full Screen")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBFullScreenItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showPrefPane:)];
	}
	else if ([itemIdent isEqual: PrefAdvancedItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"pref toolbar label: Advanced", @"pref toolbar label: Advanced")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBPrefAdvancedItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showPrefPane:)];
	}
	else
	{
		// itemIdent refered to a toolbar item that is not provided or supported by us or cocoa 
		// Returning nil will inform the toolbar this kind of item is not supported 
		toolbarItem = nil;
	}
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
	// Required delegate method:  Returns the ordered list of items to be shown in the toolbar by default	
	// If during the toolbar's initialization, no overriding values are found in the user defaults, or if the
	// user chooses to revert to the default items this set will be used 
	return [NSArray arrayWithObjects:
			PrefGeneralItemIdentifier,
			PrefDocumentsItemIdentifier,
			PrefPrintItemIdentifier,
			PrefViewItemIdentifier,
			PrefFontItemIdentifier,
			PrefStyleItemIdentifier,
			PrefWindowItemIdentifier,
			PrefFullScreenItemIdentifier,
			PrefAdvancedItemIdentifier,
			nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
	// Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar 
	// does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed   
	// The set of allowed items is used to construct the customization palette 
	return [NSArray arrayWithObjects: 
			PrefGeneralItemIdentifier,
			PrefDocumentsItemIdentifier,
			PrefPrintItemIdentifier,
			PrefViewItemIdentifier,
			PrefFontItemIdentifier,
			PrefStyleItemIdentifier,
			PrefWindowItemIdentifier,
			PrefFullScreenItemIdentifier,
			PrefAdvancedItemIdentifier,
			nil];
}

//example how to make Preference style toolbars
- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar;
{
	// Optional delegate method: Returns the identifiers of the subset of
	// toolbar items that are selectable. In our case, all of them
	return [NSArray arrayWithObjects:
			PrefGeneralItemIdentifier,
			PrefDocumentsItemIdentifier,
			PrefPrintItemIdentifier,
			PrefViewItemIdentifier,
			PrefFontItemIdentifier,
			PrefStyleItemIdentifier,
			PrefWindowItemIdentifier,
			PrefFullScreenItemIdentifier,
			PrefAdvancedItemIdentifier,
			nil];
}


- (void) toolbarWillAddItem: (NSNotification *) notif
{
	// Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
	// This is the best place to notice a new item is going into the toolbar.  For instance, if you need to 
	// cache a reference to the toolbar item or need to set up some initial state, this is the best place 
	// to do it.  The notification object is the toolbar to which the item is being added.  The item being 
	// added is found by referencing the @"item" key in the userInfo 
}  

- (void) toolbarDidRemoveItem: (NSNotification *) notification
{
	// Optional delegate method:  After an item is removed from a toolbar, this notification is sent.   This allows 
	// the chance to tear down information related to the item that may have been cached.   The notification object
	// is the toolbar from which the item is being removed.  The item being added is found by referencing the @"item"
	// key in the userInfo 
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem
{
	return YES;
}

//called when user clicks on toolbar item in the preferences window
- (IBAction)showPrefPane:(id)sender
{
	id itemID = [sender itemIdentifier];
	if (itemID==PrefGeneralItemIdentifier)
	{
		[prefMainTabView selectTabViewItemWithIdentifier:@"0"];
	}
	if (itemID==PrefDocumentsItemIdentifier)
	{
		[prefMainTabView selectTabViewItemWithIdentifier:@"8"];
	}
	else if (itemID==PrefPrintItemIdentifier)
	{
		[prefMainTabView selectTabViewItemWithIdentifier:@"5"];
	}
	else if (itemID==PrefViewItemIdentifier)
	{
		[prefMainTabView selectTabViewItemWithIdentifier:@"1"];
	}
	else if (itemID==PrefFontItemIdentifier)
	{
		[prefMainTabView selectTabViewItemWithIdentifier:@"2"];
	}
	else if (itemID==PrefStyleItemIdentifier)
	{
		[prefMainTabView selectTabViewItemWithIdentifier:@"3"];
	}
	else if (itemID==PrefWindowItemIdentifier)
	{
		[prefMainTabView selectTabViewItemWithIdentifier:@"4"];
	}
	else if (itemID==PrefFullScreenItemIdentifier)
	{
		[prefMainTabView selectTabViewItemWithIdentifier:@"6"];
	}
	else if (itemID==PrefAdvancedItemIdentifier)
	{
		[prefMainTabView selectTabViewItemWithIdentifier:@"7"];
	}
	//else, General
}

@end