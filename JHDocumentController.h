/* 
JHDocumentController.h
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

//forward declare JHDocument, which has some methods we call
@class JHDocument;

@interface JHDocumentController : NSDocumentController
{
	IBOutlet NSTextField *tfPrefAutosaveInterval;
}

+(JHDocumentController*)sharedInstance;

//override to return preferred file type
-(NSString *)defaultType;

//called from Preferences as firstResponder actions
-(IBAction)setSmartQuotesStyleInAllDocuments:(id)sender;
-(IBAction)updateDisplayOfHeadersAndFooters:(id)sender;
-(IBAction)changeInsertionPointColor:(id)sender;
-(IBAction)changeInsertionPointShape:(id)sender;

-(IBAction) newPlainTextDocument: (id)sender;
-(IBAction) newDocumentFromPasteboard: (id)sender;
-(IBAction) newDocumentFromSelection: (id)sender;

//sends performFindPanelAction to NSTextView's panel or TextFinder panel (depending on user prefs)
-(IBAction)performTextFinderAction:(id)sender;
-(IBAction)printSelection:(id)sender;

@end
