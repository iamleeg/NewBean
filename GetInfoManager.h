/*
  GetInfoManager.h
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

#import <Cocoa/Cocoa.h>

@class JHDocument;
@class KBWordCountingTextStorage;

//	category 
@interface GetInfoManager : NSObject
{
	//	pointer to instance of JHDocument
	JHDocument *document;
	
	//	----- Get Info sheet -----
	IBOutlet NSPanel *infoSheet;
	// ----- sheet labels -----
	IBOutlet NSTextField *wordCountField;
	IBOutlet NSTextField *charCountField;
	IBOutlet NSTextField *charCountMinusSpacesField;
	IBOutlet NSTextField *selWordCountField;
	IBOutlet NSTextField *selCharCountField;
	IBOutlet NSTextField *pageCountField;
	IBOutlet NSTextField *lineCountField;
	IBOutlet NSTextField *paragraphCountField;
	IBOutlet NSTextField *lineFragCountField;
	//	----- for localization -----
	IBOutlet NSButton *closeButton;
	IBOutlet NSTextField *wordLabel;
	IBOutlet NSTextField *charLabel;
	IBOutlet NSTextField *charNoSpaceLabel;
	IBOutlet NSTextField *lineLabel;
	IBOutlet NSTextField *CRLabel;
	IBOutlet NSTextField *paragraphLabel;
	IBOutlet NSTextField *pageLabel;
	IBOutlet NSTextField *selWordLabel;
	IBOutlet NSTextField *selCharLabel;
	IBOutlet NSTextField *statisticsLabel;
	IBOutlet NSTextField *fileInfoLabel;
	IBOutlet NSTextField *readOnlyFileLabel;
	//	----- sheet controls -----
	IBOutlet NSButton *lockedFileButton;
	IBOutlet NSTextField *lockedFileLabel;
	IBOutlet NSButton *readOnlyButton;
	IBOutlet NSButton *backupAutomaticallyButton; //=backup at close (of document)
	IBOutlet NSTextField *backupAutomaticallyLabel;
	IBOutlet NSButton *doAutosaveButton; //=timed backup (ie, backup every x minutes)
	IBOutlet NSTextField *doAutosaveTextField;
	IBOutlet NSStepper *doAutosaveStepper;
	IBOutlet NSTextField *doAutosaveLabel;
	IBOutlet NSButton *revealFileInFinderButton;
	IBOutlet NSTextField *infoSheetEncoding; //'Not Applicable' encoding type label
	IBOutlet NSButton *infoSheetEncodingButton; //'Change Encoding' button
	IBOutlet NSBox *infoSheetEncodingBox; // 'Plain Text Encoding'
}

//	show sheet
- (IBAction)showSheet:(id)sender;

//	control actions
-(IBAction)revealFileInFinder:(id)sender;
-(IBAction)readOnlyButtonAction:(id)sender;
-(IBAction)lockedFileButtonAction:(id)sender;
-(IBAction)backupAutomaticallyAction:(id)sender;
-(IBAction)changeEncodingAction:(id)sender;
-(IBAction)closeInfoSheet:(id)sender;
-(IBAction)startAndStopAutosaveAction:(id)sender;
-(IBAction)setAutosaveInterval:(id)sender;

//	helper method
-(int)whitespaceCountForString:(NSString *)textString;

//	forward declare
-(JHDocument *)document;
-(void)setDocument:(JHDocument *)newDoc;



@end