/*
 InspectorController.h
 revised 27 JUNE 08 JH
 Bean

 Created 11 JUL 2006 by JH
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

#import <AppKit/AppKit.h>

@class JHDocument;

@interface InspectorController : NSWindowController
{
	IBOutlet NSPanel *inspectorPanel;
	IBOutlet NSSlider *characterSpacingSlider;
	IBOutlet NSTextField *characterSpacingTextField;
	IBOutlet NSStepper *characterSpacingStepper;
	IBOutlet NSButton *characterSpacingDefaultButton;
	IBOutlet NSSlider *interlineSpacingSlider;
	IBOutlet NSTextField *interlineSpacingTextField;
	IBOutlet NSStepper *interlineSpacingStepper;
	IBOutlet NSSlider *multipleSpacingSlider;
	IBOutlet NSTextField *multipleSpacingTextField;
	IBOutlet NSStepper *multipleSpacingStepper;
	IBOutlet NSButton *multipleSpacingDefaultButton;
	IBOutlet NSSlider *afterParagraphSpacingSlider;
	IBOutlet NSTextField *afterParagraphSpacingTextField;
	IBOutlet NSStepper *afterParagraphSpacingStepper;
	IBOutlet NSSlider *beforeParagraphSpacingSlider;
	IBOutlet NSTextField *beforeParagraphSpacingTextField;
	IBOutlet NSStepper *beforeParagraphSpacingStepper;
	IBOutlet NSTextField *firstLineIndentTextField;
	IBOutlet NSStepper *firstLineIndentStepper;
	IBOutlet NSTextField *headIndentTextField;
	IBOutlet NSStepper *headIndentStepper;
	IBOutlet NSTextField *tailIndentTextField;
	IBOutlet NSStepper *tailIndentStepper;
	IBOutlet NSTextField *indentLabelTextField;
	IBOutlet NSButton *alignmentLeftButton;
	IBOutlet NSButton *alignmentRightButton;
	IBOutlet NSButton *alignmentCenterButton;
	IBOutlet NSButton *alignmentJustifyButton;
	//IBOutlet NSButton *traitsBoldButton;
	//IBOutlet NSButton *traitsItalicButton;
	IBOutlet NSTextField *minLineHeightTextField;
	IBOutlet NSTextField *maxLineHeightTextField;
	IBOutlet NSStepper *minLineHeightStepper;
	IBOutlet NSStepper *maxLineHeightStepper;
	IBOutlet NSPopUpButton *fontStylesMenu;
	IBOutlet NSButton *highlightYellowButton;
	IBOutlet NSButton *highlightOrangeButton;
	IBOutlet NSButton *highlightPinkButton;
	IBOutlet NSButton *highlightBlueButton;
	IBOutlet NSButton *highlightGreenButton;
	IBOutlet NSButton *highlightRemoveButton;
	IBOutlet NSButton *forceLineHeightDefaultButton;
	IBOutlet NSPopUpButton *fontNameMenu;
	IBOutlet NSTextField *fontSizeTextField;
	IBOutlet NSStepper *fontSizeStepper;
	IBOutlet NSSlider *fontSizeSlider;
	IBOutlet NSBox *topBox;
	IBOutlet NSBox *bottomBox;
	IBOutlet NSButton *showSpacingControlsButton;
	
	//for loading localization strings
	IBOutlet NSButton *previewFontsButton;
	IBOutlet NSTextField *fontLabel;
	IBOutlet NSTextField *styleLabel;
	IBOutlet NSTextField *sizeLabel;
	IBOutlet NSTextField *alignmentLabel;
	IBOutlet NSTextField *highlightLabel;
	IBOutlet NSTextField *spacingDisclosureLabel;
	IBOutlet NSTextField *charSpacingLabel;
	IBOutlet NSTextField *lineSpacingLabel;
	IBOutlet NSTextField *interLineSpacingLabel;
	IBOutlet NSTextField *beforeParaSpacingLabel;
	IBOutlet NSTextField *afterParaSpacingLabel;
	IBOutlet NSTextField *indentLabel;
	IBOutlet NSTextField *indentFirstLineLabel;
	IBOutlet NSTextField *indentLeftLabel;
	IBOutlet NSTextField *indentRightLabel;
	IBOutlet NSTextField *forceLineSpacingLabel;
	IBOutlet NSTextField *forceLineSpacingAtLeastLabel;
	IBOutlet NSTextField *forceLineSpacingAtMostLabel;
	IBOutlet NSButton *charSpacingDefaultButton;
	IBOutlet NSButton *lineSpacingDefaultButton;
	IBOutlet NSButton *forceLineSpacingDefaultButton;
	
	float pointsPerUnitAccessor;
	BOOL shouldForceInspectorUpdate;
	BOOL textFieldDidChange;
	BOOL returnFocusToDocWindow;
}

//public
+ (id)sharedInspectorController;
-(BOOL)acceptsFirstResponder;
-(void)prepareInspectorUpdate:(NSNotification *)notification;

//most controls (except the font attributes ones) are connected to this action, differentiated by tag
//this method is called from mainMenu.nib in places
-(IBAction)textControlAction:(id)sender;
//control actions
-(IBAction)refreshFontNameMenu:(id)sender;
-(IBAction)fontStyleAction:(id)sender;
-(IBAction)fontSizeAction:(id)sender;
-(IBAction)fontNameAction:(id)sender;
-(IBAction)showSpacingControls:(id)sender;

//forward declare
-(BOOL)textFieldDidChange;
-(void)setTextFieldDidChange:(BOOL)flag;
-(BOOL)returnFocusToDocWindow;
-(void)setReturnFocusToDocWindow:(BOOL)flag;

@end