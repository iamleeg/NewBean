/*
	LinkManager.m
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

#import "LinkManager.h"
#import "JHDocument.h"

@implementation LinkManager

#pragma mark -
#pragma mark ---- Init, Dealloc ----

- (void)dealloc
{
	if (document) [document release];
	[super dealloc];
}

#pragma mark -
#pragma mark ---- Hyperlinks ----

// ******************* Hyperlinks ********************

- (void)showSheet:(id)sender
{

	//if so, then sheet is already shown
	//TODO: find a more gracefull way of handing this, perhaps involving menu item validation
	if ([sender isKindOfClass:[NSMenuItem class]]) return;

	//sender is control calling action, not doc
	id doc = sender;
	id docWindow = [doc docWindow];
	id tv = [doc firstTextView];
	id ts = [tv textStorage];

	[self setDocument:doc];

	//	load it if not already loaded
	//window behavior in nib = [x] release when closed
	if(linkSheet == nil) { [NSBundle loadNibNamed:@"LinkSheet" owner:self]; }
	//	call up the sheet if it exits
	if(linkSheet == nil)
	{
		NSLog(@"Could not load 'LinkSheet.nib'");
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}

	//load localized control labels
	[applyLink setTitle:NSLocalizedString(@"button: Apply", @"button: Apply")];
	[cancelLink setTitle:NSLocalizedString(@"button: Cancel", @"button: Cancel")];
	[linkInstructionsTextField setObjectValue:NSLocalizedString(@"label: Type, Paste, or Drag and Drop a Link Destination", @"")];
	[[linkSelectMatrix cellWithTag:0] setTitle:NSLocalizedString(@"link type: Web", @"")];
	[[linkSelectMatrix cellWithTag:1] setTitle:NSLocalizedString(@"link type: File", @"")];
	[[linkSelectMatrix cellWithTag:2] setTitle:NSLocalizedString(@"link type: Email", @"")];
	[[linkSelectMatrix cellWithTag:3] setTitle:NSLocalizedString(@"link type: No Prefix", @"")];
	[linkSelectMatrix sizeToFit];
	
	//	if text was selected, link attributes will be added to that text; otherwise link itself will be inserted
	if (![tv selectedRange].length==0)
	{
		NSDictionary *theAttributes;
		NSObject *theLink;
		theAttributes = [ts attributesAtIndex:[tv selectedRange].location  effectiveRange:NULL];
		theLink = [theAttributes objectForKey: @"NSLink"]; //NSLinkAttributedName
		//	if a link previously exists, insert it into sheet for editing, etc.
		if (theLink)
		{
			//	create a string from the object's value
			NSString *theLinkString = [NSString stringWithFormat:@"%@", theLink];
			//	get prefix, if there is one (http://  ...  file://   ...  mailto:); remainder of string is last part of URL
			NSString *theLinkPrefixString = nil;
			if ([theLinkString length] > 7)
			{
				[linkTextField setStringValue:[theLinkString substringFromIndex:7]];
				//	get URL prefix
				theLinkPrefixString = [[theLinkString substringToIndex:4] lowercaseString];
			}
			//	setup URL prefix in controls
			if ([theLinkPrefixString isEqualToString:@"http"])
			{
				[linkSelectMatrix selectCellWithTag:0];
				[linkPrefixTextField setStringValue:@"http://"];
			}
			else if ([theLinkPrefixString isEqualToString:@"file"])
			{
				[linkSelectMatrix selectCellWithTag:1];
				[linkPrefixTextField setStringValue:@"file://"];
			}
			else if ([theLinkPrefixString isEqualToString:@"mail"])
			{
				[linkSelectMatrix selectCellWithTag:2];
				[linkPrefixTextField setStringValue:@"mailto:"];
			}
			//	no prefix, so just use whatever we have in link attribute
			else
			{
				[linkSelectMatrix selectCellWithTag:3];
				[linkTextField setStringValue:theLinkString];
				[linkPrefixTextField setStringValue:@""];
			}
		}
		//	no link attribute exists in selected text
		else
		{
			//	select link style based on tag saved from previous sheet action (default = 0), since odds are that type will be the same
			switch ([doc linkPrefixTag])
			{
				case 0: //web
					[linkPrefixTextField setStringValue:@"http://"];
					[linkSelectMatrix selectCellWithTag:[doc linkPrefixTag]];
					break;
				case 1: //file
					[linkPrefixTextField setStringValue:@"file://"];
					[linkSelectMatrix selectCellWithTag:[doc linkPrefixTag]];
					break;
				case 2: //email
					[linkPrefixTextField setStringValue:@"mailto:"];
					[linkSelectMatrix selectCellWithTag:[doc linkPrefixTag]];
					break;
				case 3: //no prefix
					[linkPrefixTextField setStringValue:@""];
					[linkSelectMatrix selectCellWithTag:[doc linkPrefixTag]];
					break;
			}
		}	
	}
	//	now call the linkSheet
	[NSApp beginSheet:linkSheet 
	   modalForWindow:docWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

-(IBAction)cancelLink:(id)sender
{
	[linkTextField setStringValue:@""];
	[NSApp endSheet: [sender window]];
	[[sender window] orderOut:self];
	//fixed leak 14 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[[sender window] close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
}

-(IBAction)selectLinkType:(id)sender
{
	id doc = [self document];
	switch ([sender selectedRow]) {
		case 0: //web
			[linkPrefixTextField setStringValue:@"http://"];
			//[doc setLinkPrefixTag:i] saves link type for next type sheet is used
			[doc setLinkPrefixTag:0];
			break;
		case 1: //file
			[linkPrefixTextField setStringValue:@"file://"];
			[doc setLinkPrefixTag:1];
			break;
		case 2: //email
			[linkPrefixTextField setStringValue:@"mailto:"];
			[doc setLinkPrefixTag:2];
			break;
		case 3: //no prefix
			[linkPrefixTextField setStringValue:@""];
			[doc setLinkPrefixTag:3];
			break;
	}
}

-(IBAction)applyLink:(id)sender
{
	id doc = [self document];
	id tv = [doc firstTextView];
	id ts = [tv textStorage];
	NSRange	selRange = [tv selectedRange];
	
	NSObject *linkObject;
	NSMutableDictionary *linkAttributes;
	
	//	apply link attribute only if there was something entered in the 'link' text field
	if (![[linkTextField stringValue] isEqualToString:@""])
	{
		NSString *linkString = [NSString stringWithFormat:@"%@%@", [linkPrefixTextField stringValue], [linkTextField stringValue]];
		//	takes care of spaces in file URLs, so link opens immediately 20 APR 08 JH
		//	BUGFIX: NSASCIIStringEncoding was preventing URLs with accented characters - duh! 21 MAY 08 JH
		NSString *urlString = [linkString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]; //was NSASCIIStringEncoding
		NSString *theLinkDestination = [[NSURL URLWithString:urlString] absoluteString];
		
		linkObject = theLinkDestination;
		//	no link was input, so bail out
		if (linkObject == nil)
		{
			NSBeep();
			return;
		}
		//	for undo
		[tv shouldChangeTextInRange:selRange replacementString:nil];
		if (selRange.length == 0)
		{
			//	we add a space that preserves the previous attributes so the new link will not spill into user's subsequent text input
			[tv insertText:[NSString stringWithFormat:@"%@%@",[linkTextField stringValue], @" "]];
			selRange = NSMakeRange(selRange.location,[[linkTextField stringValue] length]);
		}
		//	NSLinkAttributeName => the object
		linkAttributes = [NSMutableDictionary dictionaryWithObject: linkObject forKey: NSLinkAttributeName];
		//	add attributes to the selected range (not 'set' which erases other attributes)
		[ts addAttributes: linkAttributes  range: selRange];
		//	end undo
		[tv didChangeText];
		//	name undo for menu
		[[doc undoManager] setActionName:NSLocalizedString(@"Link", @"Undo action name: Link ( = create URL link)")];
	}
	// text field was empty, so remove link attribute
	else
	{
		// can change text?
		if ([tv shouldChangeTextInRange:[tv selectedRange] replacementString:nil])
		{
			//	add attributes to the selected range (not 'set' which erases other attributes)
			[ts removeAttribute: NSLinkAttributeName range:selRange];
			//	end undo
			[tv didChangeText];
			//	name undo for menu
			[[doc undoManager] setActionName:NSLocalizedString(@"Link", @"Undo action name: Link ( = create URL link)")];
		}
	}
	//	we save the last link type used in an accessor, so don't reset to default
	[self selectLinkType:linkSelectMatrix];
	[linkTextField setStringValue:@""];
	//	dismiss sheet
	[NSApp endSheet: [sender window]];
	[[sender window] orderOut:nil];
	//fixed leak 14 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[[sender window] close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
}

#pragma mark -
#pragma mark ---- Accessors ----

// ******************* Accessors ********************

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