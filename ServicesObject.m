/*
 ServicesObject.m
 Bean
 
 Copyright (c) 2007-2011	James Hoover
 
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

#import "ServicesObject.h"
#import "JHDocument.h"
#import "JHDocumentController.h" //12 JAN 08 JH

#import "JHDocument_ReadWrite.h" //CopyPaste
#import "JHDocument_Window.h" // CopyPaste

@implementation ServicesObject

static id sharedInstance = nil;

//singleton
+ (ServicesObject *)sharedInstance
{ 
	if (sharedInstance == nil) { 
		sharedInstance = [[self alloc] init];
	} 
	return sharedInstance; 
} 

- (id)init 
{
	if (sharedInstance) {
		[self dealloc];
	} else {
		sharedInstance = [super init];
	}
	return sharedInstance;
}

//	this is based on Text Edit and Smultron! 25 May 2007 BH
- (void)openSelectionInBean:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
	BOOL success = NO;
	NSError *anError = nil;
	NSArray *types = nil;
	NSString *preferredType = nil;
	//[NSApp activateIgnoringOtherApps:YES];
	//opens a new document (whose id is returned as document)
	JHDocument *document = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:&anError];
	if (!document) {
		(void)NSRunAlertPanel(NSLocalizedString(@"Bean Service Failed.", @"alert title (indicating error during Open Selection service): Bean Service Failed"),
							  NSLocalizedString(@"\\U2018New Document Containing Selection\\U2019 failed because a new document could not be created.", @"alert text: 'New Document Containing Selection' failed because a new document could not be created."),
							  NSLocalizedString(@"OK", @"OK"), nil, nil);
	}
	if (anError) {
		NSLog(@"Bean Services failed to open a new Bean document.");
	} else {
		types = [pboard types];
		preferredType = [[document firstTextView] preferredPasteboardTypeFromArray:types restrictedToTypesFromArray:nil];
		if (preferredType) {
			//this retrieves text from pasteboard and inserts it into the newly opened Bean document
			success = [[document firstTextView] readSelectionFromPasteboard:pboard type:preferredType];
		}
		if (!success) {
			(void)NSRunAlertPanel(NSLocalizedString(@"'Open Selection' failed", @"alert title (when Bean Service supposed to open selected text in a new Bean document fails): 'Open Selection' failed."),
								  NSLocalizedString(@"The Bean Service \\U2018New Document Containing Selection\\U2019 failed.", @"alert text: The Bean Service 'New Document Selection' failed."),
								  NSLocalizedString(@"OK", @"OK"), nil, nil);
		}
		else // set values for CopyPaste begin
		{
			NSString* pbname = [pboard name];
			if([pbname hasPrefix:@"CopyPasteClip"])
			{
				[document setWasPasteboard:YES];
				[document setPbname:pbname];
				[[document windowForSheet]  setTitle:@"CopyPaste Clip"];
				//[document floatWindow:nil];
			}
		} // CopyPaste end
	}
	document = nil;
	anError = nil;
	types = nil;
	preferredType = nil;
	return;	
}

//	This Service attempts to recover plain text from proprietary format document files. For instance, you can use it to recover text from a corrupted MS-Word '97 format file that Word cannot open, or from a legacy format file, such as WriteNow documents. When successful, the service recovers plain text (but not text formatting, images, etc.). Recovered text is inserted into a new document, and the original file is not changed.
//	rewritten 7 DEC 07 JH
//TODO: could benefit from regex

//BUGFIX: 30 OCT 09 change info.plist sendType to NSFilenamesPboardType instead of NSStringPboardType
- (void)recoverTextFromSelectedFile:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error 
{
	BOOL needsAlert = NO;
	// no selected file
	if (![[pboard types] containsObject:NSFilenamesPboardType])
	{
		needsAlert = YES;
	}
	else
	{
		//	file to examine
		NSString *filename = [[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0];
		//	new line; carriage return
		NSString *newLine = [NSString stringWithFormat:@"%C", 0x000D];
		NSString *CR = [NSString stringWithFormat:@"%C", 0x000A];
		NSMutableString *newString = nil;
		NSMutableString *revisedString = nil;
		NSMutableString *finalString = nil;
		NSMutableString *rejectedString = nil;
		NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
		NSArray *origTextArray = nil;
		NSMutableArray *newTextArray = nil;
		int i = 0;
		int totalChars = 0;
		int newArrayCount = 0;
		
		BOOL isDir = NO;
		// if file seems valid...
		if (filename && [filename isAbsolutePath] && [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir] && !isDir)
		{
			//	...get data from file, then string from data
			NSData *textData = [[[NSData alloc] initWithContentsOfFile:filename] autorelease];
			NSString *aString = nil; 
			if (textData) aString = [[[NSString alloc] initWithData:textData encoding:[NSString defaultCStringEncoding]] autorelease];

			// first, REMOVE CONTROL CHARACTERS
			if (aString && [aString length] > 1)
			{
				newString = [[NSMutableString alloc] initWithCapacity:[aString length]];
				rejectedString = [[[NSMutableString alloc] initWithCapacity:1] autorelease]; 
				int stringLength = [aString length];
				i = 0;
				while (i < stringLength)
				{
					//	examine current character (c) in context
					unichar c = [aString characterAtIndex:i];
					//	(if form feed/new page, substitute new line for cleaner output)
					if (c == 0x000C)
					{
						//	0x000A is new line character
						[newString appendString:[NSString stringWithFormat:@"%C", 0x000A]];
					}
					//	weed out all control characters (except tab, etc.)
					else if ((c > 0x0008 && c < 0x000E) || c > 0x001F)
					{
						[newString appendString: [aString substringWithRange:NSMakeRange(i, 1)] ];
					}
					i++;
				}
			}
			
			//	make an array of newLine terminated strings, and REMOVE LINES WITHOUT WHITE SPACES
			//	this doesn't work for, for example, single word lines
			if (newString)
			{
				origTextArray = [newString componentsSeparatedByString:newLine];
				newTextArray = [NSMutableArray arrayWithCapacity:[origTextArray count]];
				[newTextArray addObjectsFromArray:origTextArray];
				i = [newTextArray count];
				//	now test for remaining lines greater than 5 chars which are less than 10% spaces
				totalChars = 0;
				//	iterate through lines
				while (i > 0)
				{
					NSString *theLine = [newTextArray objectAtIndex:(i - 1)];
					totalChars = [theLine length];
					int spaces = 0;
					int j;
					for (j = 0; j < totalChars; j++)
					{
						//	count spaces
						if ([ws characterIsMember:[theLine characterAtIndex:j]])
						{
							spaces = spaces + 1;
						}
					}
					//	find percentage spaces
					float percentSpaces = (float) spaces / (float) totalChars;
					if (percentSpaces < 0.1 || totalChars < 4)
					{
						//	if the line looks bad, remove it
						[rejectedString appendString: [newTextArray objectAtIndex: i - 1]];
						[newTextArray removeObjectAtIndex:i - 1];
					}
					i--;
				}
				//	create a new string from the array of kept lines
				newArrayCount = [newTextArray count];
				revisedString = [[NSMutableString alloc] initWithCapacity:[newString length]];
				i = 0;
				while (i < newArrayCount)
				{
					[revisedString appendString:[newTextArray objectAtIndex:i]];
					[revisedString appendString:newLine];
					i++;
				} 
			}
			//	make an array of carriage-return terminated strings, and REMOVE LINES WITHOUT WHITE SPACES
			//	note: some formats use carriage-return, some use newLine
			
			if (revisedString)
			{
				origTextArray = nil;
				newTextArray = nil;
				origTextArray = [revisedString componentsSeparatedByString:CR];
				newTextArray = [NSMutableArray arrayWithCapacity:[origTextArray count]];
				[newTextArray addObjectsFromArray:origTextArray];
				i = [newTextArray count];
				//	now test for remaining lines greater than 5 chars which are less than 10% spaces
				totalChars = 0;
				//	iterate through lines
				while (i > 0)
				{
					NSString *theLine = [newTextArray objectAtIndex:(i - 1)];
					totalChars = [theLine length];
					int spaces = 0;
					int j;
					for (j = 0; j < totalChars; j++)
					{
						//	count spaces
						if ([ws characterIsMember:[theLine characterAtIndex:j]])
						{
							spaces = spaces + 1;
						}
					}
					//	find percentage spaces
					float percentSpaces = (float) spaces / (float) totalChars;
					if (percentSpaces < 0.1 || totalChars < 4)
					{
						//	if the line looks bad, remove it
						[rejectedString appendString: [newTextArray objectAtIndex: i - 1]];
						[newTextArray removeObjectAtIndex:i - 1];
					}
					i--;
				}
				//	create a new string from the array of kept lines
				newArrayCount = [newTextArray count];
				finalString = [[NSMutableString alloc] initWithCapacity:[revisedString length]];
				i = 0;
				while (i < newArrayCount)
				{
					[finalString appendString:[newTextArray objectAtIndex:i]];
					[finalString appendString:newLine];
					i++;
				} 
			}
			
			if (finalString)
			{
				//	declare types on pasteboard
				NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
				[pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
				[pboard setString:finalString forType:NSStringPboardType];
				
				//	open a new document and paste recovered string
				NSError *anError = nil;
				JHDocument *document = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:&anError];
				if (!anError)
				{
					//	header for recovered text
					[[document firstTextView] insertText:[NSString stringWithFormat:@"<Recovered Text from Document: %@>%@", [filename lastPathComponent], newLine]];
					//	recovered text
					[[document firstTextView] insertText:finalString];
					
					//	insert header and removed garbage at end of text (in case something important was removed)
					[[document firstTextView] insertText:newLine];
					[[document firstTextView] insertText:[NSString stringWithFormat:@"<Rejected Text from Document: %@>%@%@", [filename lastPathComponent], newLine, rejectedString]];
				}
			}
			else
			{
				NSBeep();
			}
			//	cleanup
			[newString release];
			[revisedString release];
			[finalString release];
		}
		else if (isDir)
		{
			needsAlert = YES;
		}
	}
	if (needsAlert)
	{
		NSBeep();
		[self recoverTextAlert];
	}	
}

-(void)recoverTextAlert
{
	NSBeep();
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:NSLocalizedString(@"Select a file in the Finder before choosing Recover Text service.", @"alert title: Select a file in the Finder before running this service")];
	[alert setInformativeText:NSLocalizedString(@"The Recover Text service attempts to recover plain text from proprietary format document files. For instance, you can use it to recover text from a corrupted MS-Word '97 format file that Word cannot open, or from a legacy format file, such as WriteNow documents. When successful, the service recovers plain text (but not text formatting, images, etc.). Recovered text is pasted into a new document, and the original file is not changed.", @"explanation of Recover Text from Selected File OS X service")];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
	[alert runModal];
	
}

//	Lorem Ipsum is a paragraph of mock Latin text that is traditionally used as placeholder text when experimenting with page layout
//	BUG: doesn't work in Snow Leopard; doesn't insert Lorem Ipsum into any Bean document -- race condition? frameworks bug?
//	simple test app does same thing on Snow Leopard; bug report 7355325 filed with Apple
//	method moved to Edit > Insert menu; not as useful, but at least doesn't cause app to freeze for a minute! 1 NOV 09 JH
/*
- (void)insertLoremIpsum:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error 
{
	//	NOTE: the actual Lorem Ipsum paragraph is found in Localization.strings
	NSString *loremIpsum = [NSString stringWithString:NSLocalizedString(@"Lorem ipsum", @"Lorem Ipsum is a paragraph of mock Latin text that is traditionally used as placeholder text when experimenting with page layout.")];
	if (loremIpsum)
	{
		// FIXME: can't get UTIs to work at all!
		[pboard declareTypes:[NSArray arrayWithObject: NSStringPboardType] owner:nil];
		[pboard setString:loremIpsum forType:NSStringPboardType];
	}
}
*/

-(void)pasteSelectionIntoCurrentBeanDocument:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
{
	BOOL success = NO;
	NSArray *types = nil;
	NSString *preferredType = nil;
	JHDocument *document;
	
	//	if a frontmost document exists...
	if ([[[NSDocumentController sharedDocumentController] documents] count] > 0)
	{
		//get frontmost document, and...
		document = [[NSApp orderedDocuments] objectAtIndex:0];
		types = [pboard types];
		if (document)
		{	
			//	get preferred paste type...
			preferredType = [[document firstTextView] preferredPasteboardTypeFromArray:types restrictedToTypesFromArray:nil];
		}
		if (preferredType)
		{
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			BOOL addOffset = [defaults boolForKey:@"prefPasteSelectionAddsOffset"];
			NSString *dividerString = [defaults stringForKey:@"prefPasteSelectionDividerString"];
			if (addOffset)
			{
				NSAttributedString *dividerWithAttributes = nil;
				//	retrieve default typing attributes for cocoa
				NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
				//	make a dictionary of the attributes
				NSMutableDictionary *theAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:theParagraphStyle, NSParagraphStyleAttributeName, nil];
				[theAttributes autorelease];
				[theParagraphStyle release];
				NSString *divider = [NSString stringWithFormat:@"%C%@%C", NSParagraphSeparatorCharacter, dividerString, NSParagraphSeparatorCharacter];
				dividerWithAttributes = [[NSAttributedString alloc] initWithString:divider attributes:theAttributes];
				[dividerWithAttributes autorelease];
				[[[document firstTextView] textStorage] appendAttributedString:dividerWithAttributes];
			}
			//then paste from pasteboard into frontmost document
			success = [[document firstTextView] readSelectionFromPasteboard:pboard type:preferredType];
		}
		//	paste failed for some reason (like doc being read only)
		if (!success) {
			NSBeep();
			(void)NSRunAlertPanel(NSLocalizedString(@"Bean Service Failed.", @"alert title (indicating error during Open Selection service): Bean Service Failed"), NSLocalizedString(@"\\U2018Paste Selection\\U2019 failed.", @"alert text: 'Paste Selection' failed."), NSLocalizedString(@"OK", @"OK"), nil, nil);
		}
	}
	//	but if no frontmost document, just beep
	else
	{
		NSBeep();
	}
	
	types = nil;
	preferredType = nil;
	document = nil;
	return;		
}

-(BOOL)htmlSnippitFromPasteboard:(NSPasteboard *)pboard WithStyles:(BOOL)withStyles
{

	//convert pasteboard data into attributed string -------------------------

	NSString *pbType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFDPboardType, NSRTFPboardType, nil]];
	NSData *pbData = nil;
	NSMutableAttributedString *pbString = nil; // 2.4.4 11 MAY 2011 value was uninitialized -- thanks MS
	if (pbType)
	{
		if ([pbType isEqualToString:NSRTFDPboardType])
		{
			pbData = [pboard dataForType:NSRTFDPboardType];
			if (pbData)
				pbString = [[[NSAttributedString alloc] initWithRTFD:pbData documentAttributes:NULL] autorelease];
		}
		if ([pbType isEqualToString:NSRTFPboardType])
		{
			pbData = [pboard dataForType:NSRTFPboardType];
			if (pbData)
				pbString = [[[NSAttributedString alloc] initWithRTF:pbData documentAttributes:NULL] autorelease];
		}
	}
	
	// create document type (=html) dictionary -------------------------

	NSMutableDictionary *dict;
	if (pbString)
	{
		dict = [NSMutableDictionary dictionaryWithObjectsAndKeys: NSHTMLTextDocumentType, NSDocumentTypeDocumentAttribute, nil];
		// no embedded CSS (just pure HTML without styles)
		NSMutableArray *excludedElements = [NSMutableArray array];
		//strict XHTML
		[excludedElements addObjectsFromArray:[NSArray arrayWithObjects:@"APPLET", @"BASEFONT", @"CENTER", @"DIR", @"FONT", @"ISINDEX", @"MENU", @"S", @"STRIKE", @"U", nil]];
		//no embedded CSS
		[excludedElements addObject:@"STYLE"];
		//allow inline CSS for styles
		if (!withStyles)
		{
			[excludedElements addObject:@"SPAN"];
		}
		[excludedElements addObject:@"Apple-converted-space"];
		[excludedElements addObject:@"Apple-converted-tab"];
		[excludedElements addObject:@"Apple-interchange-newline"];
		[dict setObject:excludedElements forKey:NSExcludedElementsDocumentAttribute];
		[dict setObject:[NSNumber numberWithInt:NSUTF8StringEncoding] forKey:NSCharacterEncodingDocumentAttribute]; //UTF8
		[dict setObject:[NSNumber numberWithInt:2] forKey:NSPrefixSpacesDocumentAttribute];
	}

	//	create HTML data from attributed string, then convert data back to string -------------------------
	
	NSData *data = nil;
	NSMutableString *htmlString = nil;
	//convert attributed string (rtf/d) to html data
	if ([pbString length])
		data = [pbString dataFromRange:NSMakeRange(0, [pbString length]) documentAttributes:dict error:NULL];
	//convert html data to mutable string (of html code)
	if (data)
	{
		NSString *tmpString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		if (tmpString)
		{
			htmlString = [[[NSMutableString alloc] initWithCapacity:[tmpString length]] autorelease];
			[htmlString setString:tmpString]; 
		}
	}	

	NSString *htmlSnippit = nil;

	//	cleanup HTML code and get snippit -------------------------

	if (htmlString && [htmlString length])
	{
		// remove extraneous path elements generated by Cocoa in HTML code for image URLs
		[htmlString replaceOccurrencesOfString:@"file:///" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [htmlString length])];
		// find range of html between <body> </body> tags (we're making a pastable snippit)
		int beginIndex = [htmlString rangeOfString:@"<body>" options:NSCaseInsensitiveSearch].location + 7;
		int endIndex = [htmlString rangeOfString:@"</body>" options:NSCaseInsensitiveSearch].location;
		NSRange range = NSMakeRange(beginIndex, endIndex - beginIndex);
		// check bounds, extract snippit
		if (range.location !=NSNotFound && range.length < [htmlString length])
		{
			htmlSnippit = [htmlString substringWithRange:range];
		}
	}

	// show snippit to user in new plain text document

	if (htmlSnippit)
	{
		//open a new plain text document
		NSString *typeName = NSLocalizedString(@"Text Document (.txt)", @"name of the file format: Text Document (.txt)");
		NSError *outError;
		id docController = [JHDocumentController sharedDocumentController];
		id document = [docController makeUntitledDocumentOfType:typeName error:&outError];
		if (document == nil) { return NO; }
		[docController addDocument:document];
		if ([docController shouldCreateUI])
		{
			[document makeWindowControllers];
			[document showWindows];
		}
		//insert string into doc
		[[document firstTextView] insertText:htmlSnippit];
		//set the Bean document's encoding accessors, in case user saves snippit as text document
		[document setDocEncoding:NSUTF8StringEncoding];
		[document setDocEncodingString:@"Unicode (UTF-8)"];
	}
	if (![htmlSnippit length])
	{
		return NO;
	}
	return YES;
}

-(void)htmlSnippit:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
	
	BOOL withStyles = NO, success;
	success = [self htmlSnippitFromPasteboard:pboard WithStyles:(BOOL)withStyles];
	if (!success) *error = NSLocalizedString(@"Error: couldn't convert text.", @"Error: couldn't convert text.");
}

-(void)htmlSnippitWithStyles:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
	BOOL withStyles = YES, success;
	success = [self htmlSnippitFromPasteboard:pboard WithStyles:(BOOL)withStyles];
	if (!success) *error = NSLocalizedString(@"Error: couldn't convert text.", @"Error: couldn't convert text.");
}

@end
