/*
  GetPropertiesManager.h
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

//	show document properties panel & write changes back to instance of JHDocument via setDocAttributes
@interface GetPropertiesManager : NSObject
{
	// pointer for document of interest
	JHDocument *document;
	// ----- sheet -----
	IBOutlet NSPanel *propertiesSheet;
	// ----- controls -----
	IBOutlet NSTextField *propsAuthor;
	IBOutlet NSTextField *propsCompany;
	IBOutlet NSTextField *propsCopyright;
	IBOutlet NSTextField *propsTitle;
	IBOutlet NSTextField *propsSubject;
	IBOutlet NSTextField *propsComment;
	IBOutlet NSTextField *propsEditor; //chec
	//for localization
	IBOutlet NSButton *applyButton;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSTextField *authorLabel;
	IBOutlet NSTextField *companyLabel;
	IBOutlet NSTextField *copyrightLabel;
	IBOutlet NSTextField *titleLabel;
	IBOutlet NSTextField *subjectLabel;
	IBOutlet NSTextField *commentLabel;
	IBOutlet NSTextField *keywordsLabel;
	// ----- token field -----
	IBOutlet id propsKeywords;
}

-(IBAction)showSheet:(id)sender;
-(IBAction)loadDocumentProperties:(id)sender;
-(IBAction)closePropertiesSheet:(id)sender;

//forward declare
-(JHDocument *)document;
-(void)setDocument:(JHDocument *)newDoc;

@end