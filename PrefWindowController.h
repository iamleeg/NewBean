/*
 Subclass: PrefWindowController.h
 Controls default font and text color changes in the preferences window

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


#import <Cocoa/Cocoa.h>

@interface PrefWindowController : NSWindowController
{
	BOOL richOrPlain;
	BOOL isMetric;

	IBOutlet id prefWindow;
	IBOutlet id altTextColorWell;
	IBOutlet id altBackgroundColorWell;
	IBOutlet id plainTextFontNameField;
	IBOutlet id richTextFontNameField;
	IBOutlet id defaultTopMarginTextField;
	IBOutlet id defaultLeftMarginTextField;
	IBOutlet id defaultRightMarginTextField;
	IBOutlet id defaultBottomMarginTextField;
	IBOutlet id defaultFirstLineIndentTextField;
	IBOutlet id defaultFirstLineIndentStepper;
	IBOutlet id defaultSaveFormatPopupButton;
	IBOutlet NSTabView *prefMainTabView; //
	
	//for loading localization strings
	
	//at bottom of prefs window, always visible
 	IBOutlet NSTextField *prefInstructionsLabel;
	//controls in general pane - general tab
	IBOutlet NSTabView *prefGeneralTabView; //new in 2.4
	IBOutlet NSButton *spellcheckButton;
	IBOutlet NSButton *wideCursorButton; //not used in 2.4!
	IBOutlet NSButton *smartCopyPasteButton;
	IBOutlet NSButton *backgroundPaginationButton;
	IBOutlet NSTextField *recommendedForIntelMacsOnlyLabel;
	IBOutlet NSButton *useSmartQuotesButton;
	IBOutlet NSTextField *smartQuotesSuppliedByLabel;
	IBOutlet NSTextField *smartQuotesStyleLabel;
	IBOutlet NSMatrix *prefSmartQuotesSuppliedByMatrix;
	IBOutlet NSTextField *prefGeneralAppliesImmediatelyLabel;
	//controls in general pane - text cursor tab
	IBOutlet NSButton *centerCursorButton;
	IBOutlet NSTextField *prefCursorShapeLabel;
	IBOutlet NSMatrix *prefCursorShapeMatrix;
	IBOutlet NSTextField *prefCursorColorLabel;
	IBOutlet NSColorWell *prefCursorColorWell;
	IBOutlet NSButton *prefCursorColorDefaultButton;
	IBOutlet NSTextField *prefCursorAppliesImmediatelyLabel;
	//documents pane
	IBOutlet NSTextField *defaultSaveFormatLabel;
	IBOutlet NSButton *autosaveDocumentsButton;
	IBOutlet NSTextField *autosaveDocumentsMinutesLabel;
	IBOutlet NSTextField *newDocumentTemplateLabel;
	IBOutlet NSMatrix *newDocumentSourceMatrix;
	IBOutlet NSTextField *newDocumentTemplateFileName;
	IBOutlet NSTextField *fileFormatOverridesDefaultSaveFormatLabel;
	IBOutlet NSButton *chooseTemplateButton;
	IBOutlet NSButton *showInFinderButton;
	//view pane
	IBOutlet NSTextField *showLabel;
	IBOutlet NSButton *layoutViewButton;
	IBOutlet NSButton *alternateColorsViewButton;
	IBOutlet NSButton *marginGuidesButton;
	IBOutlet NSButton *pageShadowButton;
	IBOutlet NSButton *liveWordCountButton;
	IBOutlet NSButton *rulerButton;
	IBOutlet NSButton *rulerAccessoriesButton;
	IBOutlet NSButton *showToolbarButton;
	IBOutlet NSButton *horizontalScrollbarButton;
	IBOutlet NSButton *invisibleCharsButton;
	IBOutlet NSButton *dontShowSpacesButton;
	IBOutlet NSTextField *invisCharsColorLabel;
	//font pane
	IBOutlet NSTextField *richTextFontLabel;
	IBOutlet NSTextField *plainTextFontLabel;
	IBOutlet NSButton *richTextFontChangeButton;
	IBOutlet NSButton *plainTextFontChangeButton;
	IBOutlet NSButton *alternateColorsFontPaneButton;
	IBOutlet NSTextField *textColorWellLabel;
	IBOutlet NSTextField *backgroundColorWellLabel;
	IBOutlet id richTextColorTextField;
	IBOutlet id plainTextColorTextField;
	//printing pane
	IBOutlet NSButton *printHeaderFooterButton;
	IBOutlet NSTextField *stylePrintingPaneLabel;
	IBOutlet NSPopUpButton *prefHeaderFooterStylesPopUp; //forgot to include in 2.1
	IBOutlet NSTextField *beginOnPageLabel;
	IBOutlet NSTextField *frontmostDocumentsHeaderIsLockedLabel;
	IBOutlet NSTextField *appliesImmediatelyPrintingPaneLabel;
	//window pane
	IBOutlet NSButton *centerInitialWindowButton;
	IBOutlet NSTextField *windowSizeLabel;
	IBOutlet NSTextField *viewScaleLabel;
	IBOutlet NSMatrix *windowSizeMatrix;
	IBOutlet NSMatrix *viewScaleMatrix;
	IBOutlet NSButton *matchActiveDocumentButton; 
	IBOutlet NSButton *exceptForPlainTextButton;
	//style pane
	IBOutlet NSBox *marginsBox;
	IBOutlet NSTextField *leftMarginLabel;
	IBOutlet NSTextField *rightMarginLabel;
	IBOutlet NSTextField *topMarginLabel;
	IBOutlet NSTextField *bottomMarginLabel;
	IBOutlet id defaultUnitsTextField;
	IBOutlet NSTextField *lineSpacingLabel;
	IBOutlet id defaultLineSpacingPopupButton;
	IBOutlet NSTextField *firstLineIndentLabel;
	IBOutlet NSButton *applyStyleToTxtFilesButton;
	IBOutlet id defaultIsMetric; //NSButton - style pane - 'Show in metric units'
	IBOutlet id applyChangesButton; //NSButton - style pane - 'Apply changes'
	//full screen pane
	IBOutlet NSTextField *fullScreenMarginLabel;
	IBOutlet NSTextField *appliesImmediatelyFullScreenLabel;
	IBOutlet NSButton *hideRulerFullScreenButton;
	IBOutlet NSButton *hideToolbarFullScreenButton;
	IBOutlet NSButton *alternateColorsFullScreenButton;
	IBOutlet NSButton *layoutViewFullScreenButton;
	//advanced > document
	IBOutlet NSTabView *advancedTabView;
	IBOutlet NSButton *allowBackgroundColorChangeAdvancedDocButton;
	IBOutlet NSButton *respectAntialiasingAdvancedDocButton;
	IBOutlet NSButton *serviceAddsSeparatorAdvancedDocButton;
	IBOutlet NSButton *printSelectionSeparatesSelectionsAdvancedDocButton;
	IBOutlet NSTextField *defaultGutterAdvancedDocLabel;
	IBOutlet NSTextField *appliesImmediatelyAdvancedDocLabel;
	IBOutlet NSTextField *appliesUponRestartAdvancedDocLabel;
	//advanced > interface
	IBOutlet NSTextField *measurementUnitsAdvancedInterfaceLabel;
	IBOutlet NSTextField *appliesImmediatelyAdvancedInterfaceLabel;
	IBOutlet NSTextField *leopardOnlyAdvancedInterfaceLabel;
	IBOutlet NSMatrix *unitsAdvancedInterfaceMatrix;
	IBOutlet NSButton *restoreCursorLocationAdvancedInterfaceButton;
	IBOutlet NSButton *showPageNumbersInStatusBarAdvancedInterfaceButton;
	IBOutlet NSButton *showPageNumbersInLayoutViewAdvancedInterfaceButton;
	IBOutlet NSButton *prefShowVerticalRulerButton;
	IBOutlet NSButton *prefSuggestFilenameButton;
	//advanced > Find/Replace
	IBOutlet NSButton *prefUseSimpleFindPanel;
	IBOutlet NSTextField *matchPatternsLabel;
	IBOutlet NSButton *prefLineTerminatorsMatchNewline;
	IBOutlet NSButton *prefDotMatchesNewline;
	IBOutlet NSTextField *appliesImmediatelyAdvancedFindReplaceLabel;
	//advanced > Alternate Font
	IBOutlet NSTextField *altFontExampleLabel;
	IBOutlet NSTextField *altFontInstructionsLabel;
	IBOutlet NSButton *altFontMatchSelectedText;
	IBOutlet NSTextView *altFontTextView;
	IBOutlet NSTextField *altFontUseLabel;
	IBOutlet NSButton *altFontFontButton;
	IBOutlet NSButton *altFontTextColorButton;
	IBOutlet NSButton *altFontHighlightColorButton;
	IBOutlet NSTextField *altFontInsertNoteWithLabel;
	IBOutlet NSButton *altFontUsesBracketsButton;
	IBOutlet NSButton *altFontUsesNewParagraphButton;
	IBOutlet NSTextField *appliesImmediatelyAdvancedNotesModeLabel;
}

+(PrefWindowController*)sharedInstance;

//	fonts pane
-(IBAction)changeFontAction:(id)sender;
-(IBAction)changeFont:(id)sender;
-(IBAction)useAltColorsAction:(id)sender;
-(IBAction)changeColorExampleAction:(id)sender;
-(void)setRichOrPlain:(BOOL)flag;
-(BOOL)richOrPlain;

//	style pane
-(void)setIsMetric:(BOOL)flag;
-(BOOL)isMetric;
-(IBAction)applyChangesAction:(id)sender;
-(void)convertToMetric;
-(void)convertToUS;
-(IBAction)useMetricAction:(id)sender;
-(IBAction)enableChangeButtonAction:(id)sender;

//	general pane
-(IBAction)selectDefaultSaveFormatAction:(id)sender;
-(IBAction)defaultCursorColorAction:(id)sender;

//	documents panel
-(IBAction)chooseDocumentTemplateAction:(id)sender;
-(IBAction)showTemplateInFinderAction:(id)sender;
-(IBAction)changeCocoaAutosaveInterval:(id)sender;

//	window pane
-(IBAction)matchWindowSizeToActiveDocumentWindowAction:(id)sender;

//	misc
//-(IBAction)closeAction:(id)sender;
-(IBAction)showPrintTabView:(id)sender; //called from PageView to show header and footer prefs tab

//advanced
-(IBAction)setAllowsDocumentBackgroundColorChangeInAllDocuments:(id)sender;
-(IBAction)setAlternateFontAction:(id)sender;

@end
