/*
  TabStopManager.h
  Bean

  Refactored 22 JUL 08 by JH
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

//forward declare JHDocument class; we import headers in .m file
@class JHDocument;

//inserts tabstops into documents
@interface TabStopManager : NSObject
{
	//tracks document for previews and encoding change
	JHDocument *document;
	//	----- Tab Stop Panel -----
	IBOutlet NSPanel *tabStopPanel;
	IBOutlet NSPopUpButton *tabStopAlignmentButton;
	IBOutlet NSButton *removeTabStopsButton;
	IBOutlet NSTextField *tabStopValueField;
	IBOutlet NSTextField *tabStopValueLabel;
	//for localization
	IBOutlet NSTextField *tabTypeLabel;
	IBOutlet NSTextField *tabLocationLabel;
	IBOutlet NSButton *shouldRemoveTabStopsButton;
	IBOutlet NSButton *okButton;
	IBOutlet NSButton *cancelButton;
}

//publicize
-(IBAction)showSheet:(id)sender;

//accessors
-(JHDocument *)document;
-(void)setDocument:(JHDocument *)aDocument;

@end