/*
	GetPropertiesManager.m
	Bean
	
	Class Created July 2008
		
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
 
#import "GetPropertiesManager.h"
#import "JHDocument.h"
#import "JHDocument_DocAttributes.h" // for createDocumentAttributesDictionary, setDocAttributes
#import "PageView.h" // for refresh headers/footers

@implementation GetPropertiesManager

#pragma mark -
#pragma mark ---- Init, Dealloc ----

- (void)dealloc
{
	if (document) [document release];
	[super dealloc];
}

#pragma mark -
#pragma mark ---- Properties Sheet ----

// ******************* Properties Sheet ********************

//show Get Properties... sheet (document properties, like Author, Keywords, etc.)
- (IBAction)showSheet:(id)sender
{	
	id doc = sender;
	id docWindow = [doc docWindow];

	[self setDocument:doc];

	//propertiesSheet's behavior set in nib = [x] release when closed
	if(propertiesSheet== nil) { [NSBundle loadNibNamed:@"GetProperties" owner:self]; }
	if(propertiesSheet == nil)
	{
		NSLog(@"Could not load GetProperties");
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}

	//load localized control labels
	[applyButton setTitle:NSLocalizedString(@"button: Apply", @"")];
	[cancelButton setTitle:NSLocalizedString(@"button: Cancel", @"")];
	//these labels are all right-aligned in the nib and given extra width to accommodate different languages
	[authorLabel setObjectValue:NSLocalizedString(@"label: Author:",@"")];
	[companyLabel setObjectValue:NSLocalizedString(@"label: Company:",@"")];
	[copyrightLabel setObjectValue:NSLocalizedString(@"label: Copyright:",@"")];
	[titleLabel setObjectValue:NSLocalizedString(@"label: Title:",@"")];
	[subjectLabel setObjectValue:NSLocalizedString(@"label: Subject:",@"")];
	[commentLabel setObjectValue:NSLocalizedString(@"label: Comment:",@"")];
	[keywordsLabel setObjectValue:NSLocalizedString(@"label: Keywords:",@"")];

	[self loadDocumentProperties:self];

	//	show the sheet
	[NSApp beginSheet:propertiesSheet modalForWindow:docWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];
	[propertiesSheet orderFront:sender];
}

-(IBAction)loadDocumentProperties:(id)sender
{
	id doc = [self document];
	id docAttrs = [doc docAttributes];
	id val;
	
	//	get document properties and load them into doc prop panel
	if (val = [docAttrs objectForKey:NSAuthorDocumentAttribute]) 
	{ [propsAuthor setStringValue:val]; }
	if (val = [docAttrs objectForKey:NSTitleDocumentAttribute]) 
	{ [propsTitle setStringValue:val]; }
	if (val = [docAttrs objectForKey:NSCompanyDocumentAttribute]) 
	{ [propsCompany setStringValue:val]; }
	if (val = [docAttrs objectForKey:NSCopyrightDocumentAttribute]) 
	{ [propsCopyright setStringValue:val]; }
	if (val = [docAttrs objectForKey:NSSubjectDocumentAttribute]) 
	{ [propsSubject setStringValue:val]; }
	if (val = [docAttrs objectForKey:NSCommentDocumentAttribute])
	{ [propsComment setStringValue:val]; }
	if (val = [docAttrs objectForKey:NSEditorDocumentAttribute]) 
	{ [propsEditor setStringValue:val]; }
	if (val = [docAttrs objectForKey:NSKeywordsDocumentAttribute])
	{ [propsKeywords setObjectValue:val]; }	
}

- (IBAction)closePropertiesSheet:(id)sender
{
	id doc = [self document];
	
	//apply button
	if ([sender tag]==1)
	{
		//docAttributes dictionary won't exist for not-yet-saved rich text docs, so we generate it
		if (![doc docAttributes])
		{
			[doc setDocAttributes:[doc createDocumentAttributesDictionary]];
		}

		//create potential new docAttribute dictionary
		NSMutableDictionary *newDict;
		newDict = [[doc docAttributes] mutableCopy]; //====copy
		if (newDict)
		{
			[newDict setValue:[propsAuthor stringValue] forKey:NSAuthorDocumentAttribute];
			[newDict setValue:[propsTitle stringValue] forKey:NSTitleDocumentAttribute];
			[newDict setValue:[propsCompany stringValue] forKey:NSCompanyDocumentAttribute];
			[newDict setValue:[propsCopyright stringValue] forKey:NSCopyrightDocumentAttribute];
			[newDict setValue:[propsSubject stringValue] forKey:NSSubjectDocumentAttribute];
			[newDict setValue:[propsComment stringValue] forKey:NSCommentDocumentAttribute];
			[newDict setValue:[propsEditor stringValue] forKey:NSEditorDocumentAttribute];
			[newDict setObject:[propsKeywords objectValue] forKey:NSKeywordsDocumentAttribute];
		}
		// if changes exist, set doc isDirty
		if (![newDict isEqualToDictionary:[doc docAttributes]])
		{
			//note: dirties document; there is no 'undo' action once sheet is dismissed
			//can make undoable, but uncertain whether user would understand without alert that they were undoing changes to text fields on the not-currently-visible Get Properties... sheet.
			[doc updateChangeCount:NSChangeDone];
			
			[doc setDocAttributes:newDict];
			
			// cause header/footer to refresh (changing doc attributes may have changed header/footer)
			id docView = [[doc theScrollView] documentView];
			if ([docView isKindOfClass:[PageView class]])
			{
				[docView setForceRedraw:YES];
				[docView setNeedsDisplay:YES];
			}
		}
		[newDict release]; //====release
	}
	//cancel button
	else
	{
		// don't save changes -- no warning dialog
	}
	
	//	order out the modal sheet
	[NSApp endSheet:propertiesSheet];
	[propertiesSheet orderOut:sender];
	//fixed leak 15 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[propertiesSheet close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];

}

#pragma mark -
#pragma mark ---- Accessors ----

// ******************* Accessors ********************

//pointer to document we are looking at
-(JHDocument *)document
{
	return document;
}

-(void)setDocument:(JHDocument *)newDoc
{
	[newDoc retain];
	[document release];
	document = newDoc;
}

@end