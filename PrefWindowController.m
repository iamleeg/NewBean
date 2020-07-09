/*
 Subclass: PrefWindowController.m
 Controls default font and text color changes in the preferences window

 Created 11 JUL 2006.
 Revised 21 NOV 2007 JH
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


#import "PrefWindowController.h"
#import "JHDocumentController.h" // for [sharedDocumentController documents], changeInsertionPointColor
#import "PrefWindowController_Toolbar.h" //toolbar
#import "TemplateNameValueTransformer.h" //transform filepath to filename for template name text field
#import "GLOperatingSystemVersion.h"

#define RICH_TEXT_IS_TARGET YES
#define PLAIN_TEXT_IS_TARGET NO

static id sharedInstance = nil;

@implementation PrefWindowController

#pragma mark -
#pragma mark ---- Init, Dealloc, etc. ----

// ******************* Init, Dealloc, etc. ********************

+(PrefWindowController*)sharedInstance
{
	//sharedInstance is dealloc'd when the app is quit
	return sharedInstance ? sharedInstance : [[PrefWindowController alloc] init];
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
	
	
	if(prefWindow== nil)
	{
		[NSBundle loadNibNamed:@"Preferences" owner:self];
	}
	if(prefWindow== nil)
	{ 
		[self release];
	}

	return sharedInstance;
}

- (void)awakeFromNib
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//show the alternate colors in the example text field, if we're using them
	if ([defaults boolForKey:@"prefUseAltColors"])
	{
		[richTextColorTextField setTextColor:[altTextColorWell color]];
		[richTextColorTextField setBackgroundColor:[altBackgroundColorWell color]];
		[plainTextColorTextField setTextColor:[altTextColorWell color]];
		[plainTextColorTextField setBackgroundColor:[altBackgroundColorWell color]];
	}
	//load rich text font's displayName and size into label from prefs
	[richTextFontNameField setStringValue:[NSString stringWithFormat:@"%@ %@ pt.", 
			[[NSFont fontWithName:[defaults objectForKey:@"prefRichTextFontName"]
			size:[defaults floatForKey:@"prefRichTextFontSize"]] displayName],
			[defaults stringForKey:@"prefRichTextFontSize"]]];
	//load plain text font's displayName and size into label from prefs
	[plainTextFontNameField setStringValue:[NSString stringWithFormat:@"%@ %@ pt.", 
			[[NSFont fontWithName:[defaults objectForKey:@"prefPlainTextFontName"]
			size:[defaults floatForKey:@"prefPlainTextFontSize"]] displayName],
			[defaults stringForKey:@"prefPlainTextFontSize"]]];
	
	//is system preference set to metric or U.S. units?
	NSString *measurementUnits = [defaults objectForKey:@"AppleMeasurementUnits"];

	//update the units label in the defaults pane of Preferences
	//this value can change in convertUnits method; it is not dependent on the system defaults and can be set independently 
	if ([defaults boolForKey:@"prefIsMetric"])
	{
		[defaultUnitsTextField setObjectValue:NSLocalizedString(@"(centimeters)", @"(centimeters)")];
	}
	else
	{
		[defaultUnitsTextField setObjectValue:NSLocalizedString(@"(inches)", @"(inches)")];
	}
	
	//set initial values for defaults from user defaults
	[defaultFirstLineIndentTextField setFloatValue:[defaults floatForKey:@"prefDefaultFirstLineIndent"]];
	[defaultFirstLineIndentStepper setFloatValue:[defaults floatForKey:@"prefDefaultFirstLineIndent"]];
	[defaultTopMarginTextField setFloatValue:[defaults floatForKey:@"prefDefaultTopMargin"]];
	[defaultLeftMarginTextField setFloatValue:[defaults floatForKey:@"prefDefaultLeftMargin"]];
	[defaultRightMarginTextField setFloatValue:[defaults floatForKey:@"prefDefaultRightMargin"]];
	[defaultBottomMarginTextField setFloatValue:[defaults floatForKey:@"prefDefaultBottomMargin"]];
	
	//accessor: do OS X system preferences indicate metric or US units as the current user preference?
	if ([@"Inches" isEqual:measurementUnits]) 
		{ [self setIsMetric:NO]; }
	else 
		{ [self setIsMetric:YES]; }

	//if system pref is metric but loaded values are not, convert them to metric
	if ([self isMetric] && ![defaults boolForKey:@"prefIsMetric"])
	{
		[defaultIsMetric setState:NSOnState];
		[self convertToMetric];
		[self applyChangesAction:nil];
	}
	//if system pref is U.S. units but loaded values are metric, convert them to U.S. units
	if (![self isMetric] && [defaults boolForKey:@"prefIsMetric"])
	{
		[defaultIsMetric setState:NSOffState];
		[self convertToUS];
		[self applyChangesAction:nil];
	}
	
	//	get names of possible file formats and load them into popup button in general pane
	NSArray *docTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleDocumentTypes"];
	NSMutableDictionary *docType = nil;
	NSEnumerator *enumerator = [docTypes objectEnumerator];
	[defaultSaveFormatPopupButton removeAllItems];
	// check localized version
	NSString *OpenDoc = NSLocalizedString(@"OpenDocument (.odt)", @"name of file format: OpenDocument (.odt)");
	NSString *DocXDoc = NSLocalizedString(@"Word 2007 (.docx)", @"name of file format: Word 2007 (.docx)");
	//	load popup
	while (docType = [enumerator nextObject])
	{
		NSString *theFormat = [docType valueForKey: @"CFBundleTypeName"];
		NSString *formatName = nil;
		if (theFormat)
		{
			formatName = NSLocalizedString(theFormat, @"localization for file type name from infoplist.strings");
		}
		//	Web Page (.html) is Viewer only (not Editor), so it's omitted from list by Cocoa; note: this item must be listed last in the info.plist, because omitting it from the middle of the menu list will cause problems (since selected item in list is saved in preferences based on position in popup button)
		//	for each docType, add to popup button
		if ([[docType valueForKey: @"CFBundleTypeRole"] isEqualToString:@"Editor"] && formatName)
		{
			// OpenDoc and DocXDox are not Tiger compatible, so don't add to list
			if ([GLOperatingSystemVersion isBeforeLeopard] && ([formatName isEqualToString:DocXDoc] || [formatName isEqualToString:OpenDoc]))
			{ 
				// nothing
			}		
			// types are compatible with Leopard, so add types to list
			else
			{
				[defaultSaveFormatPopupButton addItemWithTitle:formatName];
			}
		}
	}
	int formatIndex = 0;
	//this binding is done manually since we create the popup's items from scratch
	formatIndex = [[defaults objectForKey:@"prefDefaultSaveFormatIndex"] intValue];
	//select item based on saved user defaults
	if (formatIndex < [docTypes count])
	{
		[defaultSaveFormatPopupButton selectItemAtIndex:formatIndex];
	}
	//setup pref panel toolbar
	[self setupPreferencesToolbar];
	
	//shouldn't be able to hide toolbar in prefs window (code from Cocoa list)
	NSButton* toolbarButton;
	toolbarButton = [prefWindow standardWindowButton:NSWindowToolbarButton];
	if (toolbarButton != nil)
	{
		[toolbarButton setEnabled:NO];
	}

	[prefMainTabView selectTabViewItemWithIdentifier:@"0"];
	
	//un-enable controls that don't function in Tiger
	if ([GLOperatingSystemVersion isBeforeLeopard])
	{
		//these NSUserDefaults are checked when JHDocumentController loads and set NO if OS is Tiger
		
		//view hierarchy is different for Tiger; don't want to suss it out 9 DEC 08 JH
		[prefSuggestFilenameButton setEnabled:NO];
		//using vertical ruler under Tiger gives CGGRestoreStack gstack underflow error (os x bug?)
		[prefShowVerticalRulerButton setEnabled:NO];
		//un-enable Leopard's Smart Quotes option
		[[prefSmartQuotesSuppliedByMatrix cellWithTag:1] setEnabled:NO];
	}

	//load localization strings
	//	controls in preference window that are always visible

	[prefInstructionsLabel setObjectValue:NSLocalizedString(@"label: preferenceInstructions", @"")];
	//	controls in general pane -- general tab
	[[prefGeneralTabView tabViewItemAtIndex:0] setLabel:NSLocalizedString(@"pref general tab title: General", @"")];
	[spellcheckButton setTitle:NSLocalizedString(@"button: Continuously spellcheck", @"")];
	[spellcheckButton sizeToFit];
	[smartCopyPasteButton setTitle:NSLocalizedString(@"button: Smart copy/paste", @"")];
	[smartCopyPasteButton sizeToFit];
	[backgroundPaginationButton setTitle:NSLocalizedString(@"button: Background pagination*", @"")];
	[backgroundPaginationButton sizeToFit];
	[recommendedForIntelMacsOnlyLabel setObjectValue:NSLocalizedString(@"label: (recommended for Intel Macs only)", @"")];
	[useSmartQuotesButton setTitle:NSLocalizedString(@"button: Use (quotes)Smart Quotes(quotes)", @"")];
	[useSmartQuotesButton sizeToFit];
	[smartQuotesSuppliedByLabel setObjectValue:NSLocalizedString(@"label: Supplied by", @"")];
	[smartQuotesStyleLabel setObjectValue:NSLocalizedString(@"label: Style*", @"")];
	[prefGeneralAppliesImmediatelyLabel setObjectValue:NSLocalizedString(@"label: *Applies immediately", @"")];
	[[prefSmartQuotesSuppliedByMatrix cellWithTag:0] setTitle:NSLocalizedString(@"label: Bean", @"")];
	[[prefSmartQuotesSuppliedByMatrix cellWithTag:1] setTitle:NSLocalizedString(@"label: OS X (10.5+ only)", @"")];
	//	controls in general pane -- text cursor tab
	[[prefGeneralTabView tabViewItemAtIndex:1] setLabel:NSLocalizedString(@"pref general tab title: Text Cursor", @"")];
	[centerCursorButton setTitle:NSLocalizedString(@"button: Center cursor vertically", @"")];
	[centerCursorButton sizeToFit];
	[prefCursorShapeLabel setObjectValue:NSLocalizedString(@"pref label general cursor label: Cursor shape and behavior*", @"")];
	[[prefCursorShapeMatrix cellWithTag:0] setTitle:NSLocalizedString(@"pref general cursor button (cursor shape): Standard", @"")];
	[[prefCursorShapeMatrix cellWithTag:1] setTitle:NSLocalizedString(@"pref general cursor button (cursor shape): Wide, blinking", @"")];
	[[prefCursorShapeMatrix cellWithTag:2] setTitle:NSLocalizedString(@"pref general cursor button (cursor shape): Thin, non-blinking", @"")];
	[prefCursorColorLabel setObjectValue:NSLocalizedString(@"pref label general cursor label: Color*", @"")];
	[prefCursorColorDefaultButton setTitle:NSLocalizedString(@"button: Default", @"")];
	[prefCursorAppliesImmediatelyLabel setObjectValue:NSLocalizedString(@"label: *Applies immediately", @"")];
	//controls in documents pane
	[defaultSaveFormatLabel setObjectValue:NSLocalizedString(@"label: Default save format", @"")];
	[autosaveDocumentsButton setTitle:NSLocalizedString(@"button: Autosave documents every", @"")];
	[autosaveDocumentsButton sizeToFit];
	[autosaveDocumentsMinutesLabel setObjectValue:NSLocalizedString(@"label: minutes", @"")];
	[newDocumentTemplateLabel setObjectValue:NSLocalizedString(@"label: New document template", @"")];
	[[newDocumentSourceMatrix cellWithTag:0] setTitle:NSLocalizedString(@"matrix item: Generic", @"")];
	[[newDocumentSourceMatrix cellWithTag:1] setTitle:NSLocalizedString(@"matrix item: Custom", @"")];
	[newDocumentTemplateFileName setObjectValue:NSLocalizedString(@"label: None selected", @"")];
	[fileFormatOverridesDefaultSaveFormatLabel setObjectValue:NSLocalizedString(@"label: File format overrides default save format.", @"")];
	[chooseTemplateButton setTitle:NSLocalizedString(@"button: Choose Template", @"")];
	[showInFinderButton setTitle:NSLocalizedString(@"button: Show in Finder", @"")];
	//controls in view pane
	[showLabel setObjectValue:NSLocalizedString(@"label: Show", @"")];
	[layoutViewButton setTitle:NSLocalizedString(@"button: Layout view", @"")];
	[layoutViewButton sizeToFit];
	[alternateColorsViewButton setTitle:NSLocalizedString(@"button: Alternate display colors", @"")];
	[alternateColorsViewButton sizeToFit];
	[marginGuidesButton setTitle:NSLocalizedString(@"button: Margin guides", @"")];
	[marginGuidesButton sizeToFit];
	[pageShadowButton setTitle:NSLocalizedString(@"button: Page shadow", @"")];
	[pageShadowButton sizeToFit];
	[liveWordCountButton setTitle:NSLocalizedString(@"button: Live word count", @"")];
	[liveWordCountButton sizeToFit];
	[rulerButton setTitle:NSLocalizedString(@"button: Ruler", @"")];
	[rulerButton sizeToFit];
	[rulerAccessoriesButton setTitle:NSLocalizedString(@"button: Ruler accessories", @"")];
	[rulerAccessoriesButton sizeToFit];
	[showToolbarButton setTitle:NSLocalizedString(@"button: Toolbar", @"")];
	[showToolbarButton sizeToFit];
	[horizontalScrollbarButton setTitle:NSLocalizedString(@"button: Horizontal scroll bar", @"")];
	[horizontalScrollbarButton sizeToFit];
	[invisibleCharsButton setTitle:NSLocalizedString(@"button: Invisible characters", @"")];
	[invisibleCharsButton sizeToFit];
	[dontShowSpacesButton setTitle:NSLocalizedString(@"button: Don't show spaces", @"")];
	[dontShowSpacesButton sizeToFit];
	[invisCharsColorLabel setObjectValue:NSLocalizedString(@"label: Color:", @"")];
	//controls in font pane
	[richTextFontLabel setObjectValue:NSLocalizedString(@"label: Rich text font:", @"")];
	[plainTextFontLabel setObjectValue:NSLocalizedString(@"label: Plain text font:", @"")];
	[richTextFontChangeButton setTitle:NSLocalizedString(@"button: Change", @"")];
	[plainTextFontChangeButton setTitle:NSLocalizedString(@"button: Change", @"")];
	[alternateColorsFontPaneButton setTitle:NSLocalizedString(@"button: Use alternate display colors", @"")];
	[alternateColorsFontPaneButton sizeToFit];
	[textColorWellLabel setObjectValue:NSLocalizedString(@"label: Text", @"")];
	[backgroundColorWellLabel setObjectValue:NSLocalizedString(@"label: Background", @"")];
	[richTextColorTextField setObjectValue:NSLocalizedString(@"example text: Lorem Ipsum", @"")];
	[plainTextColorTextField setObjectValue:NSLocalizedString(@"example text: Lorem Ipsum", @"")];
	//controls in printing pane
	[printHeaderFooterButton setTitle:NSLocalizedString(@"button: Print header and footer*", @"")];
	[printHeaderFooterButton sizeToFit];
	[stylePrintingPaneLabel setObjectValue:NSLocalizedString(@"label (in pref printing pane): Style*", @"")];
	[beginOnPageLabel setObjectValue:NSLocalizedString(@"label: Begin on page*", @"")];
	[frontmostDocumentsHeaderIsLockedLabel setObjectValue:NSLocalizedString(@"label: Note: the frontmost document's header/footer is locked.", @"")];
	[appliesImmediatelyPrintingPaneLabel setObjectValue:NSLocalizedString(@"label (in pref printing pane): *Applies immediately", @"")];
	//forgot to include these in Bean 2.1
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:4]] setTitle:NSLocalizedString(@"pref header/footer item title: Footer: page#", @"")];
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:3]] setTitle:NSLocalizedString(@"pref header/footer item title: Footer: Page # of ##", @"")];
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:1]] setTitle:NSLocalizedString(@"pref header/footer item title: Header: Title (set in Get Properties...) page#", @"")];
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:9]] setTitle:NSLocalizedString(@"pref header/footer item title: Header: Title; Footer: Page # of ##", @"")];
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:2]] setTitle:NSLocalizedString(@"pref header/footer item title: Header: Author (set in Get Properties...) page#", @"")];
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:8]] setTitle:NSLocalizedString(@"pref header/footer item title: Header: Subject (set in Get Properties...)", @"")];
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:0]] setTitle:NSLocalizedString(@"pref header/footer item title: Header: Filename Page # of ##", @"")];
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:6]] setTitle:NSLocalizedString(@"pref header/footer item title: Header: Filename, Date; Footer: Page # of ##", @"")];
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:5]] setTitle:NSLocalizedString(@"pref header/footer item title: Header: File Location, Date; Footer: Page # of ##", @"")];
	[[prefHeaderFooterStylesPopUp itemAtIndex:[prefHeaderFooterStylesPopUp indexOfItemWithTag:10]] setTitle:NSLocalizedString(@"pref header/footer item title: Header: Title, Author, page#", @"")];

	//window pane -------------------------------------------------------
	[centerInitialWindowButton setTitle:NSLocalizedString(@"button: Center initial window", @"")];
	[centerInitialWindowButton sizeToFit];
	[windowSizeLabel setObjectValue:NSLocalizedString(@"label: Window size", @"")];
	[viewScaleLabel setObjectValue:NSLocalizedString(@"label: View scale", @"")];
	[[windowSizeMatrix cellWithTag:0] setTitle:NSLocalizedString(@"matrix item: Custom (window size)", @"")];
	[[windowSizeMatrix cellWithTag:1] setTitle:NSLocalizedString(@"matrix item: Factory setting", @"")];
	[[viewScaleMatrix cellWithTag:0] setTitle:NSLocalizedString(@"matrix item: Custom (view scale)", @"")];
	[[viewScaleMatrix cellWithTag:1] setTitle:NSLocalizedString(@"matrix item: Fit page width", @"")];
	[windowSizeMatrix sizeToFit];
	[viewScaleMatrix sizeToFit];
	[matchActiveDocumentButton setTitle:NSLocalizedString(@"button: Match to Active Document", @"")];
	[matchActiveDocumentButton sizeToFit];
	[exceptForPlainTextButton setTitle:NSLocalizedString(@"button: Except for plain text", @"")];
	[exceptForPlainTextButton sizeToFit];
	
	//style pane -------------------------------------------------------
	[marginsBox setTitle:NSLocalizedString(@"box title (pref style pane): Margins", @"")];
	[leftMarginLabel setObjectValue:NSLocalizedString(@"label (margin box in pref style pane): Left", @"")];
	[rightMarginLabel setObjectValue:NSLocalizedString(@"label (margin box in pref style pane): Right", @"")];
	[topMarginLabel setObjectValue:NSLocalizedString(@"label (margin box in pref style pane): Top", @"")];
	[bottomMarginLabel setObjectValue:NSLocalizedString(@"label (margin box in pref style pane): Bottom", @"")];
	//	set earlier, depending on user prefs
	//	[defaultUnitsTextField setObjectValue:NSLocalizedString(@"label (margin box in pref style pane): (inches)", @"")];
	[lineSpacingLabel setObjectValue:NSLocalizedString(@"label (pref style pane): Line spacing", @"")];
	[firstLineIndentLabel setObjectValue:NSLocalizedString(@"label (pref style pane): First line indent", @"")];
	//BUGFIX: was using index instead of tag...oops 19 JUN 09 JH
	[[defaultLineSpacingPopupButton itemAtIndex:[defaultLineSpacingPopupButton indexOfItemWithTag:0]] 
				setTitle:NSLocalizedString(@"button (pref style pane): Single spacing", @"")];
	[[defaultLineSpacingPopupButton itemAtIndex:[defaultLineSpacingPopupButton indexOfItemWithTag:1]]
				setTitle:NSLocalizedString(@"button (pref style pane): 1.5 spacing", @"")];
	[[defaultLineSpacingPopupButton itemAtIndex:[defaultLineSpacingPopupButton indexOfItemWithTag:2]]
				setTitle:NSLocalizedString(@"button (pref style pane): Double spacing", @"")];
	[[defaultLineSpacingPopupButton itemAtIndex:[defaultLineSpacingPopupButton indexOfItemWithTag:3]]
				setTitle:NSLocalizedString(@"button (pref style pane): 1.2 spacing", @"")];
	[applyStyleToTxtFilesButton setTitle:NSLocalizedString(@"button (pref style pane): Apply to .txt files", @"")];
	[applyStyleToTxtFilesButton sizeToFit];
	[defaultIsMetric setTitle:NSLocalizedString(@"button (pref style pane): Show in metric units", @"")];
	[defaultIsMetric sizeToFit];
	[applyChangesButton setTitle:NSLocalizedString(@"button (pref style pane): Apply changes", @"")];
	
	//full screen pane -------------------------------------------------------
	[fullScreenMarginLabel setObjectValue:NSLocalizedString(@"label (full screen pane): Left/right full screen margin*", @"")];
	[appliesImmediatelyFullScreenLabel setObjectValue:NSLocalizedString(@"label (fullscreen pane): *Applies immediately", @"")];
	[hideRulerFullScreenButton setTitle:NSLocalizedString(@"button (fullscreen pane): Hide ruler", @"")];
	[hideRulerFullScreenButton sizeToFit];
	[hideToolbarFullScreenButton setTitle:NSLocalizedString(@"button (fullscreen pane): Hide toolbar", @"")];
	[hideToolbarFullScreenButton sizeToFit];
	[alternateColorsFullScreenButton setTitle:NSLocalizedString(@"button (fullscreen pane): Use alternate text colors", @"")];
	[alternateColorsFullScreenButton sizeToFit];
	[layoutViewFullScreenButton setTitle:NSLocalizedString(@"button (fullscreen pane): Hide layout view", @"")];
	[layoutViewFullScreenButton sizeToFit];
	
	//advanced > document pane -------------------------------------------------------
	[[advancedTabView tabViewItemAtIndex:0] setLabel:NSLocalizedString(@"tab title: Document", @"")];
	[allowBackgroundColorChangeAdvancedDocButton setTitle:NSLocalizedString(@"button (advanced doc pane): Allow change of document background color*", @"")];
	[allowBackgroundColorChangeAdvancedDocButton sizeToFit];
	[respectAntialiasingAdvancedDocButton setTitle:NSLocalizedString(@"button (advanced doc pane): Respect antialiasing threshold** / turn off fine kerning*", @"")];
	[respectAntialiasingAdvancedDocButton sizeToFit];
	[serviceAddsSeparatorAdvancedDocButton setTitle:NSLocalizedString(@"button (advanced doc pane): Paste Selection... service adds separator*", @"")];
	[serviceAddsSeparatorAdvancedDocButton sizeToFit];
	[printSelectionSeparatesSelectionsAdvancedDocButton setTitle:NSLocalizedString(@"button (advanced doc pane): Print Selection... separates multiple selections*", @"")];
	[printSelectionSeparatesSelectionsAdvancedDocButton sizeToFit];
	[defaultGutterAdvancedDocLabel setObjectValue:NSLocalizedString(@"label (advanced doc pane): Default gutter between columns (in pts)", @"")];
	[appliesImmediatelyAdvancedDocLabel setObjectValue:NSLocalizedString(@"label (advanced doc pane): * Applies immediately", @"")];
	[appliesUponRestartAdvancedDocLabel setObjectValue:NSLocalizedString(@"label (advanced doc pane): ** Applies upon application restart", @"")];

	//advanced > interface -------------------------------------------------------
	[[advancedTabView tabViewItemAtIndex:1] setLabel:NSLocalizedString(@"tab title: Interface", @"")];
	[measurementUnitsAdvancedInterfaceLabel setObjectValue:NSLocalizedString(@"label (advanced interface pane): Measurement units:", @"")];
	[appliesImmediatelyAdvancedInterfaceLabel setObjectValue:NSLocalizedString(@"label (advanced interface pane): * Applies immediately", @"")];
	[leopardOnlyAdvancedInterfaceLabel setObjectValue:NSLocalizedString(@"label (advanced interface pane): OS X 10.5+ only", @"")];
	[[unitsAdvancedInterfaceMatrix cellWithTag:3] setTitle:NSLocalizedString(@"matrix item (advanced interface pane): Metric", @"")];
	[[unitsAdvancedInterfaceMatrix cellWithTag:2] setTitle:NSLocalizedString(@"matrix item (advanced interface pane): U.S.", @"")];
	[[unitsAdvancedInterfaceMatrix cellWithTag:1] setTitle:NSLocalizedString(@"matrix item (advanced interface pane): Automatic (from System Preferences)", @"")];
	[restoreCursorLocationAdvancedInterfaceButton setTitle:NSLocalizedString(@"button (advanced interface pane): Restore cursor location when opening documents", @"")];
	[restoreCursorLocationAdvancedInterfaceButton sizeToFit];
	[showPageNumbersInStatusBarAdvancedInterfaceButton setTitle:NSLocalizedString(@"button (advanced interface pane): Show page numbers in status bar (layout view only)*", @"")];
	[showPageNumbersInStatusBarAdvancedInterfaceButton sizeToFit];
	[showPageNumbersInLayoutViewAdvancedInterfaceButton setTitle:NSLocalizedString(@"button (advanced interface pane): Show page numbers in layout view*", @"")];
	[showPageNumbersInLayoutViewAdvancedInterfaceButton sizeToFit];
	[prefShowVerticalRulerButton setTitle:NSLocalizedString(@"button (advanced interface pane): Show vertical ruler**", @"")];
	[prefShowVerticalRulerButton sizeToFit];
	[prefSuggestFilenameButton setTitle:NSLocalizedString(@"button (advanced interface pane): Suggest filename at first save**", @"")];
	[prefSuggestFilenameButton sizeToFit];

	//advanced > find/replace -------------------------------------------------------
	[[advancedTabView tabViewItemAtIndex:2] setLabel:NSLocalizedString(@"tab title: Find/Replace", @"")];
	[prefUseSimpleFindPanel setTitle:NSLocalizedString(@"button (advanced find/replace pane): Use simple Find/Replace panel", @"")];
	[prefUseSimpleFindPanel sizeToFit];
	[matchPatternsLabel setObjectValue:NSLocalizedString(@"label (advanced find/replace pane): Match patterns (regex) options", @"")];
	[prefLineTerminatorsMatchNewline setTitle:NSLocalizedString(@"button (advanced find/replace pane): ^ and $ recognize newline*", @"")];
	[prefLineTerminatorsMatchNewline sizeToFit];
	[prefDotMatchesNewline setTitle:NSLocalizedString(@"button (advanced find/replace pane): . (dot) matches newline*", @"")];
	[prefDotMatchesNewline sizeToFit];
	[appliesImmediatelyAdvancedFindReplaceLabel setObjectValue:NSLocalizedString(@"label (advanced find/replace pane): * Applies immediately", @"")];
	
	//advanced > Alternate Font -------------------------------------------------------
	[[advancedTabView tabViewItemAtIndex:3] setLabel:NSLocalizedString(@"tab title: Notes Mode", @"")];
	[altFontExampleLabel setObjectValue:NSLocalizedString(@"label (advanced notes mode): Preview", @"")];
	[altFontInstructionsLabel setObjectValue:NSLocalizedString(@"label (advanced notes mode): Set font and colors to*", @"")];
	[altFontMatchSelectedText setTitle:NSLocalizedString(@"button (advanced notes mode): Match Selected Text", @"")];
	[altFontMatchSelectedText sizeToFit];
	[altFontUseLabel setObjectValue:NSLocalizedString(@"label (advanced notes mode): Use*", @"")];
	[altFontFontButton setTitle:NSLocalizedString(@"button (advanced notes mode): Font/size", @"")];
	[altFontFontButton sizeToFit];
	[altFontTextColorButton setTitle:NSLocalizedString(@"button (advanced notes mode): Text color", @"")];
	[altFontTextColorButton sizeToFit];
	[altFontHighlightColorButton setTitle:NSLocalizedString(@"button (advanced notes mode): Highlight color", @"")];
	[altFontHighlightColorButton sizeToFit];
	[altFontInsertNoteWithLabel setObjectValue:NSLocalizedString(@"label (advanced notes mode): Add*", @"")];
	[altFontUsesBracketsButton setTitle:NSLocalizedString(@"button (advanced notes mode): Brackets", @"")];
	[altFontUsesBracketsButton sizeToFit];
	[altFontUsesNewParagraphButton setTitle:NSLocalizedString(@"button (advanced notes mode): New paragraph", @"")];
	[altFontUsesNewParagraphButton sizeToFit];
	[appliesImmediatelyAdvancedNotesModeLabel setObjectValue:NSLocalizedString(@"label: *Applies immediately", @"")];
}

#pragma mark -
#pragma mark ---- Font Methods ----

// ******************* Font Methods ********************

//this action calls up the font panel
- (IBAction)changeFontAction:(id)sender {
	NSString *fontName;
	int fontSize = 0;
	//get font name and size from user defaults
	NSDictionary *values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	if ([sender tag]==0) { //==rich text
		fontName = [values valueForKey:@"prefRichTextFontName"];
		fontSize = [[values valueForKey:@"prefRichTextFontSize"] floatValue];
		//this determines what target is of fontManager font change
		[self setRichOrPlain:RICH_TEXT_IS_TARGET];
	} else { //tag==1==plain text
		fontName = [values valueForKey:@"prefPlainTextFontName"];
		fontSize = [[values valueForKey:@"prefPlainTextFontSize"] floatValue];
		[self setRichOrPlain:PLAIN_TEXT_IS_TARGET];
	}
	//create NSFont from name and size; initialize font panel with it
	NSFont *font = [NSFont fontWithName:fontName size:fontSize];
	//on error, set to default system font
	if (font == nil) font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	//set window as firstResponder so we get changeFont: messages
	[prefWindow makeFirstResponder:prefWindow];
	[[NSFontManager sharedFontManager] setSelectedFont:font isMultiple:NO];
	[[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}

//method called by font panel when a new font is selected
- (IBAction)changeFont:(id)sender
{
	NSString *ptString = NSLocalizedString(@"pt.", @"name of 'points' unit to indicate size unit of fonts in fonts Preferences pane");
	//get selected font
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *selectedFont = [fontManager selectedFont];
	if (selectedFont == nil)
		selectedFont = [NSFont systemFontOfSize:[NSFont systemFontSize]]; //default on error
	NSFont *panelFont = [fontManager convertFont:selectedFont];
	//get and store details of selected font
	NSNumber *fontSize = [NSNumber numberWithFloat:[panelFont pointSize]];	
	id defaults = [[NSUserDefaultsController sharedUserDefaultsController] values];
	//rich text if target of changeFont action
	if ([self richOrPlain]==RICH_TEXT_IS_TARGET)
	{
		//save font into user defaults
		[defaults setValue:[panelFont fontName] forKey:@"prefRichTextFontName"];
		[defaults setValue:fontSize forKey:@"prefRichTextFontSize"];
		//show a label for the rich text font
		[richTextFontNameField setStringValue:[NSString stringWithFormat:@"%@ %.0f %@", 
				[panelFont displayName], [panelFont pointSize], ptString]];
	}
	//plain text is target of changeFont action
	else
	{ 
		//save font into user defaults
		[defaults setValue:[panelFont fontName] forKey:@"prefPlainTextFontName"];
		[defaults setValue:fontSize forKey:@"prefPlainTextFontSize"];
		//show a label for the plain text font
		[plainTextFontNameField setStringValue:[NSString stringWithFormat:@"%@ %.0f %@",
				[panelFont displayName], [panelFont pointSize], ptString]];
	}
}

#pragma mark -
#pragma mark ---- Misc Action Methods ----

// ******************* Misc Action Methods ********************

- (IBAction) changeColor:(id)sender
{
	// if we don't at least pretend to implement this, the message gets sent from the color wells to the document's textView and the color of the selected range changes!
}

//called by change of color wells in default font pane
- (IBAction) changeColorExampleAction:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//show the alternate colors in the example text field, if we're using them
	if ([defaults boolForKey:@"prefUseAltColors"])
	{
		//foreground
		if ([sender tag]==0)
		{
			[richTextColorTextField setTextColor:[sender color]];
			[plainTextColorTextField setTextColor:[sender color]];
		}
		//background
		else if ([sender tag]==1)
		{
			[richTextColorTextField setBackgroundColor:[sender color]];
			[plainTextColorTextField setBackgroundColor:[sender color]];
		}
		else
		{
			//
		}
	}
	[prefWindow makeFirstResponder:sender];
}

//sets default new window size to match the active document in preferences
-(IBAction)matchWindowSizeToActiveDocumentWindowAction:(id)sender
{
	
	NSArray *docs = [[JHDocumentController sharedDocumentController] documents];
	if ([docs count])
	{
		[[NSApp mainWindow]	saveFrameUsingName:@"prefCustomWindowSize"];
	}
}

//called when user chooses alternate colors as default; sets the example field colors
- (IBAction) useAltColorsAction:(id)sender
{
	//not using alternate colors
	if ([sender state]==0)
	{
		[richTextColorTextField setTextColor:[NSColor blackColor]];
		[richTextColorTextField setBackgroundColor:[NSColor whiteColor]];
		[plainTextColorTextField setTextColor:[NSColor blackColor]];
		[plainTextColorTextField setBackgroundColor:[NSColor whiteColor]];
	} 
	//use alternate colors
	else
	{ 
		[richTextColorTextField setTextColor:[altTextColorWell color]];
		[richTextColorTextField setBackgroundColor:[altBackgroundColorWell color]];
		[plainTextColorTextField setTextColor:[altTextColorWell color]];
		[plainTextColorTextField setBackgroundColor:[altBackgroundColorWell color]];
	}
}

//attempts to validate changes, then updates user prefs dictionary
-(IBAction)applyChangesAction:(id)sender
{
	//this causes text fields with uncommited edits to try to validate them before focus leaves them 
	[[self window] makeFirstResponder:[self window]];
	//input in text fields was validated, because focus left them and was put on window, so save defaults
	if ([[self window] firstResponder] == [self window])
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSNumber *firstLineIndent = [NSNumber numberWithFloat:[defaultFirstLineIndentTextField floatValue]];
		[defaults setObject:firstLineIndent forKey:@"prefDefaultFirstLineIndent"];
		NSNumber *topMargin = [NSNumber numberWithFloat:[defaultTopMarginTextField floatValue]];
		[defaults setObject:topMargin forKey:@"prefDefaultTopMargin"];
		NSNumber *leftMargin = [NSNumber numberWithFloat:[defaultLeftMarginTextField floatValue]];
		[defaults setObject:leftMargin forKey:@"prefDefaultLeftMargin"];
		NSNumber *rightMargin = [NSNumber numberWithFloat:[defaultRightMarginTextField floatValue]];
		[defaults setObject:rightMargin forKey:@"prefDefaultRightMargin"];
		NSNumber *bottomMargin = [NSNumber numberWithFloat:[defaultBottomMarginTextField floatValue]];
		[defaults setObject:bottomMargin forKey:@"prefDefaultBottomMargin"];
		NSNumber *boolMetric = [NSNumber numberWithBool:[defaultIsMetric state]];
		//force save of this bool because otherwise it is not updated soon enough by bindings for when JHDocument
		//			needs it after conversion of units
		[defaults setObject:boolMetric forKey:@"prefIsMetric"];
		[applyChangesButton setEnabled:NO];
	}
	//otherwise, user will hear a beep and cursor will stay focused in field that needs better input 
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	//enable 'save changes' button when there has been a change to the textfields in 'defaults' pane
	[applyChangesButton setEnabled:YES];
}

- (IBAction)enableChangeButtonAction:(id)sender
{
	//20 June 2007 added because you could change firstLineIndent amount using stepper and never be prompted to save changes
	//defaultFirstLineIndentTextField is now tied to prefDefaultFirstLineIndent; also enables the 'save changes' button when there has been a change made to the textfields in the defaults preference panes
	[applyChangesButton setEnabled:YES];
}


-(void)convertToMetric
{
	float toMetric = 72.0 / 28.35;
	[defaultUnitsTextField setObjectValue:NSLocalizedString(@"(centimeters)", @"(centimeters)")];
	[defaultTopMarginTextField setFloatValue:[defaultTopMarginTextField floatValue] * toMetric];
	[defaultLeftMarginTextField setFloatValue:[defaultLeftMarginTextField floatValue] * toMetric];
	[defaultRightMarginTextField setFloatValue:[defaultRightMarginTextField floatValue] * toMetric];
	[defaultBottomMarginTextField setFloatValue:[defaultBottomMarginTextField floatValue] * toMetric];
	[defaultFirstLineIndentTextField setFloatValue:[defaultFirstLineIndentTextField floatValue] * toMetric];
	[defaultFirstLineIndentStepper setFloatValue:[defaultFirstLineIndentStepper floatValue] * toMetric];
}

-(void)convertToUS
{
	 float toUS = 28.35 / 72.0;
	 [defaultUnitsTextField setObjectValue:NSLocalizedString(@"(inches)", @"(inches)")];
	 [defaultTopMarginTextField setFloatValue:[defaultTopMarginTextField floatValue] * toUS];
	 [defaultLeftMarginTextField setFloatValue:[defaultLeftMarginTextField floatValue] * toUS];
	 [defaultRightMarginTextField setFloatValue:[defaultRightMarginTextField floatValue] * toUS];
	 [defaultBottomMarginTextField setFloatValue:[defaultBottomMarginTextField floatValue] * toUS];
	 [defaultFirstLineIndentTextField setFloatValue:[defaultFirstLineIndentTextField floatValue] * toUS];
	 [defaultFirstLineIndentStepper setFloatValue:[defaultFirstLineIndentStepper floatValue] * toUS];
}

-(IBAction)useMetricAction:(id)sender
{
	//state of button has already changed at this point, so change units to match state of button!`1q2
	if ([defaultIsMetric state]==NSOffState) [self convertToUS];
	else [self convertToMetric];
	[self applyChangesAction:nil];
}

-(IBAction)selectDefaultSaveFormatAction:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSNumber *theIndex = nil;
	theIndex = [NSNumber numberWithInt:[defaultSaveFormatPopupButton indexOfItem:[defaultSaveFormatPopupButton selectedItem]]];
	[defaults setValue:theIndex forKey:@"prefDefaultSaveFormatIndex"];
}

-(IBAction)showPrintTabView:(id)sender
{
	[prefMainTabView selectTabViewItemWithIdentifier:@"5"];
	//force toolbar to update along with tabview
	[[prefWindow toolbar] setSelectedItemIdentifier:@"Pref Print Item Identifier"];
}

-(IBAction)chooseDocumentTemplateAction:(id)sender
{
	//show openPanel after user presses 'Choose' button in Preferences
	//note: NSOpenPanel inherits from NSSavePanel!
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setResolvesAliases:YES];
	[openPanel setTitle:NSLocalizedString(@"Open Panel Title: Select Template", "Open Panel Title: Select Template")];
	[openPanel setPrompt:NSLocalizedString(@"Open Panel Button Title: Select", @"Open Panel Button Title: Select")];
	[openPanel setMessage:NSLocalizedString(@"Open Panel Message: Only locked files can be templates.", nil)];
	// see panel:shouldShowFilename: for delegate method that screens out all files except locked files and folders
	[openPanel setDelegate:self];
	
	//'Select' button was pressed
	if (NSOKButton == [openPanel runModalForTypes:[NSArray arrayWithObjects:@"txt", @"doc", @"rtfd", @"bean", @"webarchive", @"rtf", @"xml", @"odt", @"docx", NSFileTypeForHFSTypeCode('RTF '),  NSFileTypeForHFSTypeCode('.DOC'),  NSFileTypeForHFSTypeCode('TEXT'), nil]])
	{
		id theFilename = [openPanel filename];
		//NSLog(@"Selected file:%@", [openPanel filename]);
		
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL fileExists = NO;
		BOOL isLocked = NO;
		//	is fileName a valid file? 
		fileExists = [fm fileExistsAtPath:theFilename isDirectory:NULL];
		if (fileExists)
		{
			NSDictionary *theFileAttrs = [fm fileAttributesAtPath:theFilename traverseLink:YES];
			//is file locked (a template)?
			isLocked = [[theFileAttrs objectForKey:NSFileImmutable] boolValue];
			//shouldn't ever happen since we filter the browser view to show only locked files
			if (!isLocked) NSBeep();
		}
		//in tests, saving a filename as a string seems to work even with spaces and accents and japanese kanji
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		//save filename to prefs as string and save prefs
		[defaults setObject:theFilename forKey:@"prefCustomTemplateLocation"];
		[defaults synchronize];
	}
	//so it isn't retained
	if (openPanel) { [openPanel setDelegate:nil]; }
}

//delegate method: enable only locked files and folders in file browser of NSOpenPanel during pref's Select template action
- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDictionary *theFileAttrs = [fm fileAttributesAtPath:filename traverseLink:YES];
	BOOL isLocked = [[theFileAttrs objectForKey:NSFileImmutable] boolValue];
	BOOL isDirectory;
	[fm fileExistsAtPath:filename isDirectory:&isDirectory];
	BOOL isPkg = [[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename];
	//only enable directories that are not packages (ie, folders, not eg rtfd's) and templates in open panel
	return (isLocked | (isDirectory & !isPkg));
}


//reveals the custom template document for new documents in the Finder
-(IBAction)showTemplateInFinderAction:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *filePath = [defaults stringForKey:@"prefCustomTemplateLocation"];
	BOOL fileExists = NO;
	if (filePath)
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		fileExists = [fm fileExistsAtPath:filePath isDirectory:NULL];
		if (fileExists)
		{
			[[NSWorkspace sharedWorkspace] selectFile:filePath inFileViewerRootedAtPath:nil];
		}
	}
	if (!filePath || !fileExists)
	{
		NSBeep();
	}
}

//this changes the autosave interval for all open documents *if* Cocoa autosave is active
-(IBAction)changeCocoaAutosaveInterval:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"prefDoCocoaAutosave"])
	{
		int interval = [[defaults valueForKey:@"prefCocoaAutosaveInterval"] intValue];
		if (interval > 0 && interval < 61)
		{
			int seconds = interval * 60;
			//NSLog(@"autosave interval:%i", interval);
			[[JHDocumentController sharedDocumentController] setAutosavingDelay:seconds];
		}
	}
}

-(IBAction)setAllowsDocumentBackgroundColorChangeInAllDocuments:(id)sender
{
	[[JHDocumentController sharedDocumentController] setAllowsDocumentBackgroundColorChangeInAllDocuments:sender];
}

//gets typingAttributes from active document firstTextView and uses them as attributes for 'alternate default font' 
-(IBAction)setAlternateFontAction:(id)sender
{
	//if there's a currDoc, there should always be a textView which, even when textStorage = @"", will return a typingAttribtues dictionary
	id currDoc = [[NSDocumentController sharedDocumentController] currentDocument];
	if (nil == currDoc)
	{
		NSBeep();
		return;
	}
	//apply generic paragraphStyle so example doesn't look weird, but reapply writingDirection so it isn't lost 
	NSDictionary *origAttrs = [[currDoc firstTextView]typingAttributes];
	NSMutableDictionary *attrs = [[origAttrs mutableCopy]autorelease];
	NSParagraphStyle *pStyle = [attrs objectForKey:NSParagraphStyleAttributeName];
	NSWritingDirection writingDirection = [pStyle baseWritingDirection];
	NSMutableParagraphStyle *pAttrs = [[[NSParagraphStyle defaultParagraphStyle]mutableCopy]autorelease]; //<==copy/autorelease
	[pAttrs setBaseWritingDirection:writingDirection];
	[attrs setObject:pAttrs forKey:NSParagraphStyleAttributeName];
	//get font's display name
	NSFont *font = [attrs objectForKey:NSFontAttributeName];
	NSString *displayName = [font displayName];
	if (!displayName) displayName = NSLocalizedString(@"tab title: Notes Font", @""); 
	//font should always return a display name
	NSAttributedString *exampleString = [[[NSAttributedString alloc] initWithString:displayName attributes:attrs]autorelease];
	//if failed for some reason
	if (!exampleString)
	{
		NSBeep();
		return;
	}
	//load into UI
	[altFontTextView insertText:exampleString];
	//set attributed string in user defaults as archived data, and force write
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *data=[NSKeyedArchiver archivedDataWithRootObject:exampleString];
	[defaults setObject:data forKey:@"prefAltFontExampleData"];
	[defaults synchronize];
}

//sets insertion point to black
-(IBAction)defaultCursorColorAction:(id)sender
{
	id black = [NSColor blackColor];
	[prefCursorColorWell setColor:black];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:black];
	[defaults setObject:data forKey:@"prefCursorColor"];
	[defaults synchronize];
	[[JHDocumentController sharedDocumentController] changeInsertionPointColor:prefCursorColorWell];
}

#pragma mark -
#pragma mark ---- Accessors ----

// ******************* Accessors ********************

//indicates whether richText example or plainText example is the target of a changeFont action
- (BOOL)richOrPlain {
	return richOrPlain;
}

- (void)setRichOrPlain:(BOOL)flag {
	richOrPlain = flag;
}

//defaults use metric or U.S. units?
- (BOOL)isMetric {
	return isMetric;
}

- (void)setIsMetric:(BOOL)flag {
	isMetric = flag;
}

@end
