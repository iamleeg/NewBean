/*
  JHDocument_Text.h
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
#import "JHDocument.h"

//	actions which directly modify the text by inserting or removing text or by changing attributes 
@interface JHDocument (JHDocument_Text)

//	smart quotes
-(IBAction)setSmartQuotesStyleAction:(id)sender;
-(IBAction)convertQuotesAction:(id)sender;
-(IBAction)useSmartQuotesAction:(id)sender;

// target of menu actions that call some shared code in InspectorController
-(IBAction)textControlAction:(id)sender;

// ----- Edit > Insert Actions -----
-(IBAction)insertDateTimeStamp:(id)sender;
-(IBAction)insertBreakAction:(id)sender;
-(IBAction)insertSignatureLineAction:(id)sender;
//- (void)insertLoremIpsum:(id)sender;

// ----- Edit > Remove Actions -----
-(IBAction)removeAttachmentsAction:(id)sender;
-(IBAction)removeTextTablesAction:(id)sender;
-(IBAction)removeTextListsAction:(id)sender;

// ----- Paragraph Attribute Actions -----
-(IBAction)allowHyphenationAction:(id)sender;
-(IBAction)toggleWritingDirection:(id)sender;

// ----- Font Attribute Actions -----
-(IBAction)strikethroughAction:(id)sender;
-(void)superscriptAction:(id)sender;
-(void)subscriptAction:(id)sender;
-(void)unscriptAction:(id)sender;
-(void)shrinkSuperAndSubscriptText;
-(void)restoreSizeToUnscriptText;

// ----- Alternate Font methods -----
-(IBAction)toggleAlternateFont:(id)sender;
-(IBAction)reviseAlternateFontDictionary:(id)sender;
-(IBAction)beginNote:(id)sender;
-(IBAction)beginNoteWithString:(id)string;
-(BOOL)insertedTextNeedsExtraProcessing;

-(void)setAlternateFontActive:(BOOL)flag;
-(BOOL)alternateFontActive;
-(void)setAlternateFontDictionary:(NSDictionary *)dict;
-(NSDictionary *)alternateFontDictionary;

@end