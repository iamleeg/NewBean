/*
	JHDocument_Toolbar.m
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

//	a category of JHDocument for toolbar delegate, validation and action methods
 
#import "JHDocument_Toolbar.h"
#import "JHDocument_Text.h" //textControlAction
#import "JHDocumentController.h" //for performTextFinderAction (show find panel toolbar action)
#import "KBPopUpToolbarItem.h" //highlighter icon
#import <Cocoa/Cocoa.h> //for NSSegmentedCell header

//	internal identifiers for toolbar items
//	DO NOT LOCALIZE
#define	MyDocToolbarIdentifier @"My Document Toolbar Identifier"  //toolbar instance
#define	SaveDocToolbarItemIdentifier @"Save Document Item Identifier" 
#define	LookUpInDictionaryItemIdentifier @"Define Word Item Identifier" 
#define	UndoItemIdentifier @"Undo Item Identifier" 
#define	RedoItemIdentifier @"Redo Item Identifier" 
#define	FindItemIdentifier @"Find Item Identifier" 
#define	AlternateTextColorItemIdentifier @"Alternate Text Color Identifier" 
#define	ShowInspectorItemIdentifier @"Show Inspector Item Identifier" 
#define	ShowStatisticsItemIdentifier @"Show Statistics Item Identifier"  //Get Info...
#define	BackupItemIdentifier @"Backup Item Identifier" 
#define	ToggleViewtypeItemIdentifier @"Toggle Viewtype Item Identifier" 
#define	AutocompleteItemIdentifier @"Autocomplete Item Indentifier" 
#define	FloatWindowItemIdentifier @"Float Window Item Identifier" 
#define	CopyItemIdentifier @"Copy Item Identifier" 
#define	PasteItemIdentifier @"Paste Item Identifier" 
#define	CutItemIdentifier @"Cut Item Identifier" 
#define	InsertPictureIdentifier @"Insert Picture Identifier" 
#define	ShowRulerItemIdentifier @"Show Ruler Item Identifier" 
#define	ShowFontPanelItemIdentifier @"Toggle Font Panel Item Identifier"  //now toggles font panel
#define	FullScreenItemIdentifier @"Full Screen Item Identifier"
#define	GetPropertiesItemIdentifier @"Get Properties Item Identifier"
#define	ShowInvisiblesItemIdentifier @"Show Invisibles Item Identifier"
#define	HighlightItemIdentifier @"Highlight Item Identifier"
#define	SegmentedStyleControlItemGroupIdentifier @"Segmented Style Control Item Group Identifier" 
#define	DateTimeItemIdentifier @"Date-Time Item Identifier"

@implementation JHDocument ( JHDocument_Toolbar )

#pragma mark-
#pragma mark ---- Toolbar Methods  ----

// ******************* NSToolbar Related Methods *******************

- (void) setupToolbar
{
	// Create a new toolbar instance, and attach it to our document window 
	NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: MyDocToolbarIdentifier] autorelease];
	// Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
	[toolbar setAllowsUserCustomization: YES];
	[toolbar setAutosavesConfiguration: YES];
	[toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
	[toolbar setShowsBaselineSeparator:YES];
	//create highlight popup menu before it is needed
	[self initializeHighlightPopupMenu];
	[self initializeDateTimePopupMenu];
	// We are the delegate
	[toolbar setDelegate:self];
	// Attach the toolbar to the document window 
	[docWindow setToolbar: toolbar];
}

- (id) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted
{
	// Required delegate method:  Given an item identifier, this method returns an item 
	// The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
	NSToolbarItem *toolbarItem = nil;
	if ([itemIdent isEqual: SaveDocToolbarItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Save", @"toolbar label: Save")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Save", @"palette label: Save")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Save Document", @"tooltip: Save Document")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBSaveItemImage"]]; //
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(saveTheDocument:)];
	}
	else if ([itemIdent isEqual: LookUpInDictionaryItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Define", @"toolbar label: Define")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Define", @"palette label: Define")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Define Word", @"tooltip: Define Word")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBDefineWord"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(defineWord:)];
	}
	else if ([itemIdent isEqual: UndoItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Undo", @"toolbar label: undo")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"pallete label: Undo", @"pallete label: Undo")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Undo", @"tooltip: Undo")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBUndoItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(undoChange:)];
	}
	else if ([itemIdent isEqual: RedoItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Redo", @"toolbar label: Redo")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Redo", @"palette label: Redo")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Redo", @"tooltip: Redo")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBRedoItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(redoChange:)];

	}
	else if ([itemIdent isEqual: FindItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Find", @"toolbar label: Find")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Find", @"palette label: Find")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Find", @"tooltip: Find")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBFindItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		//tells performFindPanelAction to show find panel
		[toolbarItem setTag: NSFindPanelActionShowFindPanel];
		[toolbarItem setAction: @selector(performFind:)];
	}
	else if ([itemIdent isEqual: AlternateTextColorItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Alt Colors", @"toolbar label: Alt Colors")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Alt Colors", @"palette label: Alt Colors")];
		
		// Set up a reasonable tooltip, and image
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Alternate Text Colors", @"tooltip: Alternate Text Colors")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBAltColorsItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(switchTextColors:)];
	}
	else if ([itemIdent isEqual: ShowInspectorItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Inspector", @"toolbar label: Inspector")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Inspector", @"pallete label: Inspector")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Inspector", @"tooltip: Inspector")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBInspectorItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showInspectorPanelAction:)];
	}
	else if ([itemIdent isEqual: ShowStatisticsItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Get Info", @"toolbar label: Get Info")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Get Info", @"palette label: Get Info")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Get Info", @"tooltip: Get Info")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBStatisticsItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setTag:0];
		[toolbarItem setAction: @selector(showBeanSheet:)];
	}
	else if ([itemIdent isEqual: BackupItemIdentifier])
	{
			toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
			
			// Set the text label to be displayed in the toolbar and customization palette 
			[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Backup", @"toolbar label: Backup")];
			[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Backup", @"palette label: Backup")];
			
			// Set up a reasonable tooltip, and image 
			[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Date-stamped Backup", @"tooltip: Date-stamped Backup")];
			[toolbarItem setImage: [NSImage imageNamed: @"TBBackupItemImage"]];
			
			// Tell the item what message to send when it is clicked 
			[toolbarItem setTarget: self];
			[toolbarItem setAction: @selector(backupDocumentAction:)];
	}
	else if ([itemIdent isEqual: ToggleViewtypeItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: View", @"toolbar label: View")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: View", @"palette label: View")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Toggle View Type", @"tooltip: Toggle View Type")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBLayoutItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(setTheViewType:)];
	}
	else if ([itemIdent isEqual: AutocompleteItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Complete", @"toolbar label: Complete")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Complete", @"palette label: Complete")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Autocomplete", @"tooltip: Autocomplete")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBCompleteItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(autocompleteAction:)];
	}
	else if ([itemIdent isEqual: FloatWindowItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Float", @"toolbar label: Float")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Float", @"palette label: Float")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Make Window Float", @"tooltip: Make Window Float")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBFloatItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(floatWindow:)];
		
	}
	else if ([itemIdent isEqual: CopyItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Copy", @"toolbar label: Copy")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Copy", @"palette label: Copy")];
		
		// Set up a reasonable tooltip, and image
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Copy", @"tooltip: Copy")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBCopyItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(copyAction:)];
		
	}
	else if ([itemIdent isEqual: PasteItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Paste", @"toolbar label: Paste")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Paste", @"palette label: Paste")];
		
		// Set up a reasonable tooltip, and image
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Paste", @"tooltip: Paste")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBPasteItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(pasteAction:)];
		
	}
	else if ([itemIdent isEqual: CutItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Cut", @"toolbar label: Cut")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Cut", @"palette label: Cut")];
		
		// Set up a reasonable tooltip, and image
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Cut", @"tooltip: Cut")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBCutItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(cutAction:)];
		
	}
	else if ([itemIdent isEqual: InsertPictureIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Picture", @"toolbar label: Picture")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Picture", @"palette label: Picture")];
		
		// Set up a reasonable tooltip, and image
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Insert Picture", @"tooltip: Insert Picture")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBInsertPicture"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(insertImageAction:)];
		
	}
	else if ([itemIdent isEqual: ShowRulerItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Ruler", @"toolbar label: Ruler")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Ruler", @"palette label: Ruler")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Ruler", @"tooltip: Ruler")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBRulerItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(toggleBothRulers:)];
		
	}
	else if ([itemIdent isEqual: ShowFontPanelItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Fonts", @"toolbar label: Fonts")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Fonts", @"palette label: Fonts")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Fonts", @"tooltip: Fonts")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBShowFontPanelItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showFontPanel:)];
	}

	else if ([itemIdent isEqual: FullScreenItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Full Screen", @"toolbar label: Full Screen")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Full Screen", @"palette label: Full Screen")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Full Screen", @"tooltip: Full Screen")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBFullScreenItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(bean_toggleFullScreen:)];
	}
	else if ([itemIdent isEqual: GetPropertiesItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Properties", @"toolbar label: Properties")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Properties", @"palette label: Properties")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Properties", @"tooltip: Properties")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBGetPropertiesItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTag:1];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showBeanSheet:)];
	}
	else if ([itemIdent isEqual: ShowInvisiblesItemIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Invisibles", @"toolbar label: Invisibles")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Invisibles", @"palette label: Invisibles")];
		
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Invisibles", @"tooltip: Invisibles")];
		[toolbarItem setImage: [NSImage imageNamed: @"TBInvisiblesItemImage"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(toggleInvisiblesAction:)];
	}
	else if ([itemIdent isEqual: HighlightItemIdentifier])
	{
		//KBPopupToolbarItem, which allows a toolbar item to display a popup menu, is by Keith Blount -- thank you Keith!
		id popupToolbarItem = [[[KBPopUpToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[popupToolbarItem setLabel:NSLocalizedString(@"toolbar label: Highlight", @"toolbar label: Highlight")];
		[popupToolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Highlight", @"palette label: Highlight")];
		
		// Set up a reasonable tooltip, and image 
		[popupToolbarItem setToolTip:NSLocalizedString(@"tooltip: Highlight", @"tooltip: Highlight")];
		[popupToolbarItem setImage: [NSImage imageNamed: @"TBHighlightYellowItemImage.tiff"]];
		
		// Tell the item what message to send when it is clicked 
		[popupToolbarItem setMenu:highlightPopupMenu];
		
		//	yellow is default
		[popupToolbarItem setTag:31];
		
		[popupToolbarItem setTarget: self];
		[popupToolbarItem setAction: @selector(textControlAction:)];
		return popupToolbarItem;
	}
	//	NSSegmentedControl is used to create three buttons in toolbarItem's view: Bold, Italic, Underline
	//	when toolbar is in text only mode, the 'style' label changes toolbar to icon view
	else if ([itemIdent isEqual: SegmentedStyleControlItemGroupIdentifier])
	{
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"toolbar label: Styles", @"toolbar label: Styles")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"palette label: Styles", @"palette label: Styles")];
		// Set up a reasonable tooltip, and image 
		[toolbarItem setToolTip:NSLocalizedString(@"tooltip: Styles", @"tooltip: Styles")];

		//if we don't set these, control fails to appear in Tiger (because the width is 0)
		NSRect frame = [segmentedStyleControlView frame];
		[toolbarItem setMinSize:NSMakeSize(100, frame.size.height)];
		[toolbarItem setMaxSize:NSMakeSize(100, frame.size.height)];
	
		//set view to customer segmented button view
		[toolbarItem setView:segmentedStyleControlView];
		return toolbarItem;
	}
	else if ([itemIdent isEqual: DateTimeItemIdentifier])
	{
		//KBPopupToolbarItem, which allows a toolbar item to display a popup menu, is by Keith Blount -- thank you Keith!
		id popupToolbarItem = [[[KBPopUpToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
		
		// Set the text label to be displayed in the toolbar and customization palette 
		[popupToolbarItem setLabel:NSLocalizedString(@"label: Date/Time", @"label: Date/Time")];
		[popupToolbarItem setPaletteLabel:NSLocalizedString(@"label: Date/Time", @"label: Date/Time")];
		
		// Set up a reasonable tooltip, and image 
		[popupToolbarItem setToolTip:NSLocalizedString(@"label: Date/Time", @"label: Date/Time")];
		[popupToolbarItem setImage: [NSImage imageNamed: @"TBInsertDate.tiff"]];
		
		// Tell the item what message to send when it is clicked 
		[popupToolbarItem setMenu:dateTimePopupMenu];
		[dateTimePopupMenu setDelegate:self];
		
		[popupToolbarItem setTag:0];
		[popupToolbarItem setTarget: self];
		
		//setting action to nil causes instant menu popup on click in *modified* KBPopUpToolbarItem (see my note there)
		[popupToolbarItem setAction:nil];
		//[popupToolbarItem setAction: @selector(insertDateTimeStamp:)];
		
		return popupToolbarItem;
	}
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
	// Required delegate method:  Returns the ordered list of items to be shown in the toolbar by default	
	// If during the toolbar's initialization, no overriding values are found in the user defaults, or if the
	// user chooses to revert to the default items this set will be used 
	return [NSArray arrayWithObjects:
			SaveDocToolbarItemIdentifier,
			NSToolbarPrintItemIdentifier,
			NSToolbarSeparatorItemIdentifier,
			UndoItemIdentifier,
			RedoItemIdentifier,
			NSToolbarSeparatorItemIdentifier,
			FindItemIdentifier,
			ToggleViewtypeItemIdentifier, 
			LookUpInDictionaryItemIdentifier, // = Define
			ShowStatisticsItemIdentifier, // = Get Info...
			ShowInspectorItemIdentifier,
			InsertPictureIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarCustomizeToolbarItemIdentifier,
			nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
	// Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar 
	// does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed   
	// The set of allowed items is used to construct the customization palette 
	return [NSArray arrayWithObjects: 
			SaveDocToolbarItemIdentifier,
			BackupItemIdentifier,
			NSToolbarPrintItemIdentifier,
			CopyItemIdentifier,
			PasteItemIdentifier,
			CutItemIdentifier,
			UndoItemIdentifier,
			RedoItemIdentifier,
			FindItemIdentifier, 
			NSToolbarShowColorsItemIdentifier,
			ShowFontPanelItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarSeparatorItemIdentifier,
			ShowStatisticsItemIdentifier,
			ToggleViewtypeItemIdentifier, 
			AlternateTextColorItemIdentifier,
			ShowInspectorItemIdentifier,
			LookUpInDictionaryItemIdentifier,
			AutocompleteItemIdentifier,
			FloatWindowItemIdentifier,
			InsertPictureIdentifier,
			ShowRulerItemIdentifier,
			FullScreenItemIdentifier,
			GetPropertiesItemIdentifier,
			ShowInvisiblesItemIdentifier,
			HighlightItemIdentifier,
			DateTimeItemIdentifier,
			SegmentedStyleControlItemGroupIdentifier,
			NSToolbarCustomizeToolbarItemIdentifier,
			nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif
{
	// Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
	// This is the best place to notice a new item is going into the toolbar.  For instance, if you need to 
	// cache a reference to the toolbar item or need to set up some initial state, this is the best place 
	// to do it.  The notification object is the toolbar to which the item is being added.  The item being 
	// added is found by referencing the @"item" key in the userInfo 
	NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];
	if ([[addedItem itemIdentifier] isEqual: NSToolbarPrintItemIdentifier]) {
		[addedItem setToolTip: NSLocalizedString(@"Print Your Document", @"tooltip: Print Your Document")];
		[addedItem setTarget: self];
	}
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

	BOOL enable = NO;
	if ([[toolbarItem itemIdentifier] isEqual: NSToolbarPrintItemIdentifier]) {
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: LookUpInDictionaryItemIdentifier]) {
	enable = [textStorage length] > 0; 
	} else if ([[toolbarItem itemIdentifier] isEqual: SaveDocToolbarItemIdentifier]) {
	enable = [self isDocumentEdited];
	} else if ([[toolbarItem itemIdentifier] isEqual: FindItemIdentifier]) {
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: UndoItemIdentifier]) {
	enable = [[self undoManager] canUndo];
	} else if ([[toolbarItem itemIdentifier] isEqual: RedoItemIdentifier]) {
	enable = [[self undoManager] canRedo];
	} else if ([[toolbarItem itemIdentifier] isEqual: AlternateTextColorItemIdentifier]) {
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: ShowInspectorItemIdentifier]) {
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: ToggleViewtypeItemIdentifier]) {
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: AutocompleteItemIdentifier]) {
	enable = [textStorage length] > 0;
	} else if ([[toolbarItem itemIdentifier] isEqual: FloatWindowItemIdentifier]) {
		enable = YES;
		if (![self isFloating])
		{
			[toolbarItem setImage: [NSImage imageNamed: @"TBFloatItemImage"]];
		}
		else
		{
			[toolbarItem setImage: [NSImage imageNamed: @"TBFloatItemImageActive"]];
		}
	} else if ([[toolbarItem itemIdentifier] isEqual: BackupItemIdentifier]) {
		if (![self isTransientDocument] && [self isDocumentSaved])
		{
			enable = YES;
		}
		else
		{
			enable = NO;
		}
	} else if ([[toolbarItem itemIdentifier] isEqual: ShowStatisticsItemIdentifier]) {
	enable = YES; 
	} else if ([[toolbarItem itemIdentifier] isEqual: PasteItemIdentifier]) { 
		enable = [[NSPasteboard pasteboardWithName:NSGeneralPboard] changeCount] > 0;
		//disable if read only doc 11 Oct 2007 JH
		if ([self readOnlyDoc]) enable = NO;
	} else if ([[toolbarItem itemIdentifier] isEqual: CopyItemIdentifier]) { 
	enable = [[self firstTextView] selectedRange].length > 0;
	} else if ([[toolbarItem itemIdentifier] isEqual: CutItemIdentifier]) { 
	enable = [[self firstTextView] selectedRange].length > 0;
	} else if ([[toolbarItem itemIdentifier] isEqual: InsertPictureIdentifier]) { 
		enable = [[self firstTextView] importsGraphics];
		//disable if read only doc 11 Oct 2007 JH
		if ([self readOnlyDoc]) enable = NO;
	} else if ([[toolbarItem itemIdentifier] isEqual: ShowRulerItemIdentifier]) { 
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: ShowFontPanelItemIdentifier]) { 
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: FullScreenItemIdentifier]) { 
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: GetPropertiesItemIdentifier]) { 
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: ShowInvisiblesItemIdentifier]) { 
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: HighlightItemIdentifier]) { 
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: SegmentedStyleControlItemGroupIdentifier]) { 
	enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: DateTimeItemIdentifier]) { 
	enable = YES;
	}	
	return enable;
}

- (IBAction)undoChange:(id)sender
{
	[[self undoManager] undo];	
}

- (IBAction)redoChange:(id)sender
{
	[[self undoManager] redo];	
}

- (IBAction)performFind:(id)sender
{
	//[[self firstTextView] performFindPanelAction:sender];	
	//show Find panel
	[[JHDocumentController sharedDocumentController] performTextFinderAction:sender];
}

-(IBAction)autocompleteAction:(id)sender
{
	[[self firstTextView] complete:nil];
}

-(IBAction)copyAction:(id)sender
{
	[[self firstTextView] copy:nil];
}

-(IBAction)pasteAction:(id)sender
{
	[[self firstTextView] paste:nil];
}

-(IBAction)cutAction:(id)sender
{
	[[self firstTextView] cut:nil];
}

-(IBAction)segmentedStyleControlAction:(id)sender
{
	//Keith Blount, I was lazy and cribbed this from some code you sent me; hope that's okay!
	int tag;
	//toolbar item label was clicked
	if ([sender isKindOfClass:[NSToolbarItem class]])
	{
		tag = [sender tag];
	}
	//toolbar item segment was clicked
	else
	{
		int selectedSegment = [sender selectedSegment];
		tag = [[sender cell] tagForSegment:selectedSegment];
	}
	NSTextView *tv = [self firstTextView];
	NSFontManager *fm = [NSFontManager sharedFontManager];
	NSDictionary *attrs = [tv typingAttributes];
	NSFont *font = [attrs objectForKey:NSFontAttributeName];

	//bold
	if (tag == 2)
	{
		NSFontTraitMask fontTraitMask = ([fm traitsOfFont:font] & NSBoldFontMask) ? NSUnboldFontMask : NSBoldFontMask;
		[fm setDelegate:tv];
		NSControl *fakeSender = [[NSControl alloc] init];
		[fakeSender setTag:fontTraitMask];
		[fm addFontTrait:fakeSender];
		[fakeSender release];
	}
	//italic
	else if (tag == 1)
	{
		NSFontTraitMask fontTraitMask = ([fm traitsOfFont:font] & NSItalicFontMask) ? NSUnitalicFontMask : NSItalicFontMask;
		[fm setDelegate:tv];
		NSControl *fakeSender = [[NSControl alloc] init];
		[fakeSender setTag:fontTraitMask];
		[fm addFontTrait:fakeSender];
		[fakeSender release];
	}
	//underline
	else if (tag == 0)
	{
		[tv underline:sender];
	}
}

//BUG: on Tiger, bold segment doesn't get selected when insertion point is at bold font; works on Leopard though!
-(IBAction) updateSegmentedStyleControl:(id)notification
{
	id tv = [self firstTextView];
	if ([notification object]==tv)
	{
		//Keith Blount, I was lazy and cribbed this from some code you sent me; hope that's okay!
		NSDictionary *attrs = [tv typingAttributes];
		NSFont *font = [attrs objectForKey:NSFontAttributeName];
		NSFontManager *fm = [NSFontManager sharedFontManager];
		
		BOOL isBold = [fm traitsOfFont:font] & NSBoldFontMask;
		BOOL isItalic = [fm traitsOfFont:font] & NSItalicFontMask;
		BOOL isUnderlined = ([[attrs objectForKey:NSUnderlineStyleAttributeName] intValue] != NSUnderlineStyleNone);
		
		[segmentedStyleControl setSelected:isBold forSegment:0];
		[segmentedStyleControl setSelected:isItalic forSegment:1];
		[segmentedStyleControl setSelected:isUnderlined forSegment:2];
	}
}

//when the highlight toolbar item is clicked-and-held, popup menu initialized here is shown
-(void)initializeHighlightPopupMenu
{
	SEL action = @selector(updateHighlightButtonAction:);
	NSString *title;
	//released in JHDocument's dealloc method
	highlightPopupMenu=[[NSMenu alloc] init];  // ===== init when class is init'd, released at dealloc
	[highlightPopupMenu setAutoenablesItems:NO];
	//yellow
	title = NSLocalizedString(@"menu label: Yellow", @"menu label: Yellow");
	id yellowHighlightItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[yellowHighlightItem setTag:31];
	[yellowHighlightItem setImage:[NSImage imageNamed:@"swatchYellow"]];
	[highlightPopupMenu addItem:yellowHighlightItem];
	//orange
	title = NSLocalizedString(@"menu label: Orange", @"menu label: Orange");
	id orangeHighlightItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[orangeHighlightItem setTag:32];
	[orangeHighlightItem setImage:[NSImage imageNamed:@"swatchOrange"]];
	[highlightPopupMenu addItem:orangeHighlightItem];
	//pink
	title = NSLocalizedString(@"menu label: Pink", @"menu label: Pink");
	id pinkHighlightItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[pinkHighlightItem setTag:33];
	[pinkHighlightItem setImage:[NSImage imageNamed:@"swatchPink"]];
	[highlightPopupMenu addItem:pinkHighlightItem];
	//blue
	title = NSLocalizedString(@"menu label: Blue", @"menu label: Blue");
	id blueHighlightItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[blueHighlightItem setTag:34];
	[blueHighlightItem setImage:[NSImage imageNamed:@"swatchBlue"]];
	[highlightPopupMenu addItem:blueHighlightItem];
	//green
	title = NSLocalizedString(@"menu label: Green", @"menu label: Green");
	id greenHighlightItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[greenHighlightItem setTag:35];
	[greenHighlightItem setImage:[NSImage imageNamed:@"swatchGreen"]];
	[highlightPopupMenu addItem:greenHighlightItem];
	//none
	title = NSLocalizedString(@"menu label: None", @"menu label: None");
	id noHighlightItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[noHighlightItem setTag:30];
	[noHighlightItem setImage:[NSImage imageNamed:@"swatchX"]];
	[highlightPopupMenu addItem:noHighlightItem];
}

//popup menu action changes highlight toolbar item color and tag (tag effects color of its action)
-(IBAction)updateHighlightButtonAction:(id)sender
{
	id toolbar = [docWindow toolbar];
	NSArray *itemsArray = [toolbar items];
	
	//find highlight item in toolbar (item changes when toolbar mode is changed, so we can't use a simple pointer)
	id toolbarItem = nil;
	NSEnumerator *enumerator = [itemsArray objectEnumerator];
	id item;
	while (item = [enumerator nextObject])
	{
		if ([[item itemIdentifier] isEqualToString:HighlightItemIdentifier])
			toolbarItem = item;
	}

	if (!toolbarItem) return;
	int itemTag = [sender tag];

	//tag == 30 mean remove highlight from text and don't change highlght icon color
	if (itemTag > 30)
	{
		//change tag and tiff to reflect new color
		[toolbarItem setTag:itemTag]; 

		switch (itemTag)
		{
			case 31:
				[toolbarItem setImage:[NSImage imageNamed: @"TBHighlightYellowItemImage.tiff"]];
				break;
			case 32:
				[toolbarItem setImage:[NSImage imageNamed: @"TBHighlightOrangeItemImage.tiff"]];
				break;
			case 33:
				[toolbarItem setImage:[NSImage imageNamed: @"TBHighlightPinkItemImage.tiff"]];
				break;
			case 34:
				[toolbarItem setImage:[NSImage imageNamed: @"TBHighlightBlueItemImage.tiff"]];
				break;
			case 35:
				[toolbarItem setImage:[NSImage imageNamed: @"TBHighlightGreenItemImage.tiff"]];
				break;
			default:
				[toolbarItem setImage:[NSImage imageNamed: @"TBHighlightYellowItemImage.tiff"]];
				break;		
		}
	}
	//highlight selected text too
	[self textControlAction:sender];
}

//when the highlight toolbar item is clicked-and-held, popup menu initialized here is shown
-(void)initializeDateTimePopupMenu
{
	SEL action = @selector(updateDateTimeButtonAction:);
	NSString *title;
	if (!dateTimePopupMenu)
	{
		//released in JHDocument's dealloc method
		dateTimePopupMenu=[[NSMenu alloc] init];  // ===== init when class is init'd, released at dealloc
		[dateTimePopupMenu setAutoenablesItems:NO];
	}
	NSDate *today = [NSDate date];
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init]; // ===== init
	[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
//long date
	[dateFormatter setDateStyle:NSDateFormatterLongStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	title = [NSString stringWithFormat:@"%@ ",[dateFormatter stringFromDate:today]];
	id longDateItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[longDateItem setTag:0];
	[dateTimePopupMenu addItem:longDateItem];
//short date
	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	title = [NSString stringWithFormat:@"%@ ",[dateFormatter stringFromDate:today]];
	id shortDateItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[shortDateItem setTag:1];
	[dateTimePopupMenu addItem:shortDateItem];
//time
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	title = [NSString stringWithFormat:@"%@ ",[dateFormatter stringFromDate:today]];
	id timeItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[timeItem setTag:2];
	[dateTimePopupMenu addItem:timeItem];
//date time
	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	title = [NSString stringWithFormat:@"%@ ",[dateFormatter stringFromDate:today]];
	id dateTimeItem=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
	[dateTimeItem setTag:3];
	[dateTimePopupMenu addItem:dateTimeItem];
	[dateFormatter release]; // ===== release
}

//popup menu action refreshes the titles of menu items based on user prefs for date and time format for current date/time
-(IBAction)updateDateTimeButtonAction:(id)sender
{
	id toolbar = [docWindow toolbar];
	NSArray *itemsArray = [toolbar items];
	
	//find date/time item in toolbar (the item changes when toolbar mode is changed, so we can't use a simple pointer)
	id toolbarItem = nil;
	NSEnumerator *enumerator = [itemsArray objectEnumerator];
	id item;
	while (item = [enumerator nextObject])
	{
		if ([[item itemIdentifier] isEqualToString:DateTimeItemIdentifier])
			toolbarItem = item;
	}

	if (!toolbarItem) return;
	int itemTag = [sender tag];
	//tag determines format of date/time string the action inserts into text
	[toolbarItem setTag:itemTag]; 

	[self insertDateTimeStamp:sender];
}

//refresh date time menu item titles
- (void)menuNeedsUpdate:(NSMenu *)menu
{
	while([menu numberOfItems])
	{
		[menu removeItemAtIndex:0];
	}
	[self initializeDateTimePopupMenu];
}


@end

//thanks for Todd Yandell for the fix to a bug on Tiger where part of the control is consistantly cut off
//from http:// www.cocoabuilder.com/archive/message/cocoa/2005/7/31/143275

@interface AOSegmentedControl : NSSegmentedControl
{
}
@end

@interface NSSegmentedCell ( PrivateMethod )

@end

@implementation AOSegmentedControl

- (void)awakeFromNib
{
	[self setFrameSize:NSMakeSize([self frame].size.width, 26)];
}

@end