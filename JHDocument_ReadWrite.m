
/*
	JHDocument_ReadWrite.m
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

// methods to read and write files (open, save, export, backup)
#import "JHDocument_ReadWrite.h"
#import "JHDocument_Initialize.h" //applyPlainTextSettings
#import "JHDocument_DocAttributes.h" //for setDocAttribtues 
#import "JHDocument_Text.h" //for alternateFontActive
#import "GetInfoManager.h" //for autosave controls
#import "GLOperatingSystemVersion.h"

#import <Carbon/Carbon.h> //for Applescript descriptor stuff in associateFileWithBean

//	Bean's creator code, registered with Apple
const OSType kMyAppCreatorCode = 'bEAN';

@interface NSSavePanel(SnowLeopard)
//get rid of compiler error (for 10.6 API method)
- (void)setNameFieldStringValue:(NSString *)value;
@end

@implementation JHDocument ( JHDocument_ReadWrite )

// CopyPaste begin
#pragma mark -
#pragma mark --- Save to pasteboard if a window was opened after service request from CopyPaste ---


- (void) setWasPasteboard:(BOOL)was
{
	wasPasteboard = was;	
}

- (BOOL) wasPasteboard
{
	return wasPasteboard;	
}

- (void) setPbname:(NSString*)pb
{
	pbname = [pb copy];
}

-(BOOL) wasServiceRequest
{
	if(wasPasteboard) // if CopyPaste asked for a window, save its contents here into the old pasteboard.
	{
		if(pbname)
		{
			NSArray* mytypes = nil;
			NSPasteboard* pboard= [NSPasteboard pasteboardWithName: pbname];
			if ([textStorage containsAttachments]) 
			{
				mytypes = [NSArray arrayWithObjects:NSRTFPboardType,NSRTFDPboardType,nil];
			}
			else
				mytypes = [NSArray arrayWithObjects:NSRTFPboardType,nil];
			//	if ([mytypes count] > 0)
			{
				[pboard declareTypes:(NSArray *)mytypes owner:(id)nil];
				
				NSData *rtfData = [[self textStorage]   RTFFromRange:(NSMakeRange(0, [[self textStorage]  length]))   documentAttributes:nil];
				[pboard setData:rtfData forType:NSRTFPboardType];
				if ([textStorage containsAttachments]) 
				{
					NSData *rtfdData = [[self textStorage]   RTFDFromRange:(NSMakeRange(0, [[self textStorage]  length]))   documentAttributes:nil];
					[pboard setData:rtfdData forType:NSRTFDPboardType];
				}
				//	[[self textStorage] writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)mytypes];
			}
			//			wasPasteboard = NO;
			//			pbname = nil;
			//			isTransientDocument = YES;
			//			isDocumentSaved = YES;
			//[mytypes release];
			return YES;
		}
	}
	return NO;
	
}

// CopyPaste end

#pragma mark -
#pragma mark ---- Open File ----

// ******************* UTI for file ********************

//	reports on UTI of incoming file, used for instance in identifying .doc files without .doc extension
//	function by Kenny Leung, from CocoaBuilder.com
NSString *universalTypeForFile(NSString *filename)
{
	OSStatus status;
	CFStringRef uti;
	FSRef fileRef;
	Boolean isDirectory;
	uti = NULL;
	status = FSPathMakeRef((UInt8 *)[filename fileSystemRepresentation], &fileRef,
						   &isDirectory);
	if ( status != noErr ) {
		return nil;
	}
	status = LSCopyItemAttribute(&fileRef, kLSRolesAll,
								 kLSItemContentType, (CFTypeRef *)&uti);
	if ( status != noErr ) {
		return nil;
	}
	return (NSString *)uti;
}

// ******************* Read fileWrapper ********************

//	this method reads in the data for ALL filetypes readable by Bean
- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper 
					 ofType:(NSString *)typeName
					  error:(NSError **)outError
{
	//	note: RTFD is Bean's native format; .Bean format files are just RTFD with a '.bean' extension
	
	//--- set fileType based on extension, UTI, & OS Type ---/ 
	
	//	examine file's UTI
	BOOL forceDocFormat = NO;
	NSString *theFileName = [self fileName];
	NSString *theUTI = universalTypeForFile(theFileName);
	//	file's OS Code
	NSString *theFileType = nil;
	NSString *theFileApp = nil;
	[[NSWorkspace sharedWorkspace] getInfoForFile:[self fileName] application:&theFileApp type:&theFileType];
	
	//	if UTI says .doc but no extension, force .doc (10 July 2007 BH)
	if (([theUTI isEqualToString:@"com.microsoft.word.doc"] 
		 || [theFileType isEqualToString:@"'W8BN'"]) 
		&& ![typeName isEqualToString:DOCDoc])
	{
		[self setCurrentFileType:DOCDoc];
		[self setFileType:DOCDoc];
		forceDocFormat = YES;
	}
	//	if OS Type is RTF, but no extension, force .rtf
	else if ([theFileType isEqualToString:@"'RTF '"] && ![typeName isEqualToString:RTFDoc])
	{
		[self setCurrentFileType:RTFDoc];
		[self setFileType:RTFDoc];
	} 
	//	otherwise set currentFileType to typeName (which is based on extension)
	else
	{
		[self setCurrentFileType:typeName];
	}
	
	//--- remember HFS file attributes for re-saving ---/ 
	
	//	keep HFS file attributes around for adding to file after save (fileType, creatorCode)
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *thePath = nil;
	thePath = [self fileName];
	if ([fileManager isReadableFileAtPath:thePath])
	{
		NSDictionary *fileAttributes = [fileManager fileAttributesAtPath:thePath traverseLink:YES];
		if (fileAttributes != nil)
		{
			[self setHfsFileAttributes:fileAttributes];
		}
	}
	
	theFileName = nil;
	theUTI = nil;
	theFileType = nil;
	theFileApp = nil;
	
	//--- read in document ---/ 
		
	//NSLog(@">%@<", [self fileName]); //NULL means opening unsaved autosave file
	//TODO: check somehow for when Bean tries to open an autosaved doc that causes it to crash; causing it to again try to open the autosaved document which causes it to crash again 
	BOOL extensionError = NO;

	//	catch case where someone names a text file with arbitrary (ie, wrong) extension (eg .rtfd)
	//	which will cause Bean to crash when it tries to open the file 4 AUG 08 JH
	if ([self fileName] && ([typeName isEqualToString:RTFDDoc] || [typeName isEqualToString:BeanDoc])
		&& ![[NSWorkspace sharedWorkspace] isFilePackageAtPath:[self fileName]] )
	{
		extensionError = YES;
	}
	
	//	if BEAN or RTFD (ie, bundles), we load it here
	if (([typeName isEqualToString:RTFDDoc] || [typeName isEqualToString:BeanDoc])
		//	to catch case where someone names a text file with an arbitrary (ie, wrong) extension such as .rtfd, which will cause Bean to crash when it tries to save the file (17 May 2007 BH)
		&& !extensionError)
	{
		NSDictionary *docAttrs;
		loadedText = [[NSAttributedString alloc] initWithRTFDFileWrapper:fileWrapper documentAttributes:&docAttrs];
		if (loadedText)
		{
			[self setDocAttributes:docAttrs];
		}
		return YES;
	}
	//	check for other types of file packages (=folders) besides RTFD and BEAN and inform user that we don't read them
	//	re-opening autosaved docs don't return a fileName (?) so we test for that here 12 AUG 08 JH 
	if (extensionError || ([self fileName] && [[NSWorkspace sharedWorkspace] isFilePackageAtPath:[self fileName]]))
	{
		[self setCurrentFileType:@"invalidFileType"]; // this will create an alert and make document nil
		return YES;
	}
	
	//	if not BEAN or RTFD, load the remaining types
	else if ([typeName isEqualToString:RTFDoc] )
	{
		options = [NSDictionary dictionaryWithObject:NSRTFTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	}
	else if ([typeName isEqualToString:DOCDoc] || forceDocFormat)
	{
		options = [NSDictionary dictionaryWithObject:NSDocFormatTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	}
	else if ([typeName isEqualToString:HTMLDoc])
	{
		
		options = [NSDictionary dictionaryWithObject:NSPlainTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		//	get the string from the HTML file so we can see if the encoding is specified
		NSData *textData = [[NSData alloc] initWithContentsOfFile:[self fileName]];
		NSString *theString = [[NSString alloc] initWithData:textData encoding:NSISOLatin1StringEncoding];
		NSScanner *seekCharset = [NSScanner scannerWithString:theString];
		NSStringEncoding encoding = 0;
		[seekCharset scanUpToString:@"charset=" intoString:NULL];
		//	this is the location of the 'name' of the encoding
		unsigned encStringLocation = [seekCharset scanLocation] + 8;
		//	if not specified in file, try UTF-8
		if ([seekCharset scanLocation]==[theString length])
		{
			//scanner reached end without finding 'charset' so we try UTF-8
			options = [NSDictionary  dictionaryWithObject:[NSNumber numberWithUnsignedInt:NSUTF8StringEncoding] forKey:NSCharacterEncodingDocumentAttribute];
			[self setDocEncoding:NSUTF8StringEncoding];
			[self setDocEncodingString:@"Unicode (UTF-8)"];
		} 
		//	try to figure out which encoding is specified
		else
		{
			[seekCharset scanUpToString:[NSString stringWithFormat:@"%C", 0x0022] intoString:NULL];
			//	this is the length of the 'name' of the encoding
			unsigned encStringLength = [seekCharset scanLocation] - encStringLocation;
			//	this is the name of the encoding
			encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)[theString substringWithRange:NSMakeRange(encStringLocation,encStringLength)]));
			if (encoding && !(encoding==kCFStringEncodingInvalidId))
			{
				options = [NSDictionary  dictionaryWithObject:[NSNumber numberWithUnsignedInt:encoding] forKey:NSCharacterEncodingDocumentAttribute];
				[self setDocEncoding:encoding];
				NSString *setEncString = [NSString localizedNameOfStringEncoding:encoding];
				if (setEncString) { [self setDocEncodingString:setEncString]; }
			}
		}
		[textData release];
		[theString release];
	}
	else if ([typeName isEqualToString:TXTDoc] || [typeName isEqualToString:TXTwExtDoc])
	{
		//	plain text type document
		options = [NSDictionary dictionaryWithObject:NSPlainTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		//	extract string from text file and try to determine the encoding
		//	note: we can determine UTF-16 (encoding=10) and UTF-8 with byte marker (encoding==4) with some certainty; if encoding cannot be determined ([self docEncoding=nil]), we do more tests farther down
		NSError *encError = nil;
		NSStringEncoding fileEncoding = 0;
		if ([[NSFileManager defaultManager] fileExistsAtPath:[self fileName]])
		{
			NSString *aString = [[NSString alloc] initWithContentsOfFile:[self fileName] usedEncoding:&fileEncoding error:&encError];
			//NSLog(@"isUnicodeText: %@ (%i)", [NSString localizedNameOfStringEncoding:fileEncoding], fileEncoding);
			[aString release];
			//	specify UTF-16 (=10) or UTF-8 (=4) if these types are determined
			//	note: only Unicode encoding can be determined this way...the heuristic is not smart
			if (fileEncoding==NSUTF8StringEncoding) //	=4
			{
				options = [NSDictionary  dictionaryWithObject:[NSNumber numberWithUnsignedInt:NSUTF8StringEncoding] forKey:NSCharacterEncodingDocumentAttribute];
				[self setDocEncoding:NSUTF8StringEncoding];
				[self setDocEncodingString:@"Unicode (UTF-8)"];
			}
			else if (fileEncoding==NSUnicodeStringEncoding) //	=10
			{
				options = [NSDictionary  dictionaryWithObject:[NSNumber numberWithUnsignedInt:NSUnicodeStringEncoding] forKey:NSCharacterEncodingDocumentAttribute];
				[self setDocEncoding:NSUnicodeStringEncoding];
				[self setDocEncodingString:@"Unicode (UTF-16)"];
			}
			//	test whether file actually is UTF-8, just without unicode byte marker
			//	NOTE: we can't similarly test for UTF-16 because it will always return a string - but not always a meaningful one
			else if (fileEncoding==0)
			{
				NSData *textData = [[NSData alloc] initWithContentsOfFile:[self fileName]];
				NSString *string = [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];
				//	only well-formed UTF-8 will produce a string
				if (string)
				{ 
					options = [NSDictionary  dictionaryWithObject:[NSNumber numberWithUnsignedInt:NSUTF8StringEncoding] forKey:NSCharacterEncodingDocumentAttribute];
					[self setDocEncoding:NSUTF8StringEncoding];
					[self setDocEncodingString:@"Unicode (UTF-8)"];
				}
				[textData release];
				[string release];
			}			
		}
	}
	else if([typeName isEqualToString:XMLDoc])
	{
		options = [NSDictionary dictionaryWithObject:NSWordMLTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	} 
	else if([typeName isEqualToString:WebArchiveDoc])
	{
		options = [NSDictionary dictionaryWithObject:NSWebArchiveTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	}
	//	new in Bean 1.1.0
	else if([typeName isEqualToString:OpenDoc])
	{
		// if Tiger, not compatible
		if ([GLOperatingSystemVersion isBeforeLeopard])
		{
			//	an alert sheet will show in windowControllerDidLoadNib
			//	this way we don't fight frameworks and can dismiss the failed-to-open document easily
			[self setCurrentFileType:@"invalidFileType"];
			return YES;
		}
		//	Leopard is compatible
		else
		{
			options = [NSDictionary dictionaryWithObject:NSOpenDocumentTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		}
	} 
	//	new in Bean 1.1.0
	else if([typeName isEqualToString:DocXDoc])
	{
		// if Tiger, not compatible
		if ([GLOperatingSystemVersion isBeforeLeopard])
		{
			//	an alert sheet will show in windowControllerDidLoadNib
			//	this way we don't fight frameworks and can dismiss the failed-to-open document easily
			[self setCurrentFileType:@"invalidFileType"];
			return YES;
		}
		//	Leopard is compatible
		else
		{
			options = [NSDictionary dictionaryWithObject:NSOfficeOpenXMLTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		}
	} 
	
	// if filename has no extension, try reading as RTF string; if string is produced, set type as RTF (27 May 2007 BH)
	if ([[[self fileName] pathExtension] isEqualToString:@""])
	{
		NSDictionary *docAttrs;
		loadedText = [[NSAttributedString alloc] initWithRTF:[fileWrapper regularFileContents] documentAttributes:&docAttrs];
		if (loadedText)
		{
			[self setDocAttributes:docAttrs];
			[self setCurrentFileType:RTFDoc];
			[self setFileType:RTFDoc];
			return YES;
		}
	}
	
	//	we invoke readFromData and then initWithData for all file types above -- except those with directory wrappers (ie, .RTFD & .BEAN) 
	if (options != nil)
	{
		//	if plain text
		if ([[self currentFileType] isEqualToString:TXTDoc] 
			|| [[self currentFileType] isEqualToString:HTMLDoc]
			|| [[self currentFileType] isEqualToString:TXTwExtDoc])  
			
		{
			//	if .txt or .html and encoding was sussed above, get as string using encoding
			if ([self docEncoding])
			{
				NSData *textData = [[NSData alloc] initWithContentsOfFile:[self fileName]];
				NSString *theString = [[NSString alloc] initWithData:textData encoding:[self docEncoding]];
				if (theString)
				{ 
					loadedText = [[NSAttributedString alloc] initWithString:theString];
				}
				//	if no string, may be bad/incorrect encoding
				//	we notify user of (potential) problem and try to read file as 'plain text' below
				else
				{
					[self setDocEncoding:0];
					[self setDocEncodingString:@"Unknown"];
				}
				[textData release];
				[theString release];
			}
			//	if no encoding yet; let Cocoa try to figure it out - but ONLY with .txt files (no zips, tiffs, etc.)
			else
			{
				if ([typeName isEqualToString:TXTDoc])
				{
					NSDictionary *docAttrs;
					//	let Cocoa try to determine encoding (encoding may be stored in the file system in Leopard)
					loadedText = [[NSAttributedString alloc] initWithData:[fileWrapper regularFileContents] options:options documentAttributes:&docAttrs error:nil];
					unsigned int encoding = [[docAttrs valueForKey:NSCharacterEncodingDocumentAttribute] unsignedIntValue];
					//	if frameworks guessed Mac Roman (the default guess), try ISOLatin1 instead, which is more probably correct
					if (encoding==30)
					{
						//	see if ISOLatin1 encoding produces valid string
						options = [NSDictionary  dictionaryWithObject:[NSNumber numberWithUnsignedInt:NSISOLatin1StringEncoding] forKey:NSCharacterEncodingDocumentAttribute];
						loadedText = nil;
						loadedText = [[NSAttributedString alloc] initWithData:[fileWrapper regularFileContents] options:options documentAttributes:&docAttrs error:nil];
						//	since we almost certainly don't know encoding at this point, cause encoding-choice sheet to show should we make this a bool (shouldShowEncodingSheet)
						encoding = 0;
					}
					/*
					//appears to be never called
					if (loadedText = nil)
					{
						NSString *string = [[[NSString alloc] initWithData:[fileWrapper regularFileContents] encoding:[NSString defaultCStringEncoding]] autorelease];
						loadedText = [[NSAttributedString alloc] initWithString:string];
					}
					*/
					if (![self docEncoding] && encoding)
					{
						[self setDocEncoding:encoding];
						[self setDocEncodingString:[NSString localizedNameOfStringEncoding:encoding]];
						//NSLog(@"encoding (readFromFileWrapper): %@ (%u)", [NSString localizedNameOfStringEncoding:encoding], encoding);
					}
				}
			}
			if (loadedText)
			{ 
				return YES;
			}
		} 
		//	if not plain text
		else
		{
			NSDictionary *docAttrs;
			loadedText = [[NSAttributedString alloc] initWithData:[fileWrapper regularFileContents] options:options documentAttributes:&docAttrs error:nil];
			if (loadedText)
			{
				[self setDocAttributes:docAttrs];
				return YES;
			}
		}
	}
	
	// still nothing? try to read as "RTF with .doc extension" file 
	if (!loadedText && [typeName isEqualToString:DOCDoc])
	{
		// .doc files don't always load since sometimes they are .rtf files in disguise, so check for this
		NSDictionary *docAttrs;
		loadedText = [[NSAttributedString alloc] initWithRTF:[fileWrapper regularFileContents] documentAttributes:&docAttrs];
		if (loadedText)
		{
			[self setDocAttributes:docAttrs];
			[self setIsRTFForWord:YES];
			return YES;
		}
	}
	
	//	could not read the file - an alert will be generated and document set to nil
	[self setCurrentFileType:@"invalidFileType"];
	NSBeep();
	return YES;
}

// ******************* Revert To Saved Method *******************
- (IBAction)revertDocumentToSaved:(id)sender
{
	//	ask if user wants to revert to the original document
	int choice = NSAlertDefaultReturn;
	NSString *title = NSLocalizedString(@"Revert document to saved version?", @"alert title: Revert document to saved version?");
	//action is now undoable, since anything effecting the whole document should be undoable 1 AUG 08 JH
	//NSString *infoString = NSLocalizedString(@"This action is undoable.", @"alert text: You will lose unsaved changes.");
	choice = NSRunAlertPanel(title, @"", NSLocalizedString(@"Revert", @"button: Revert (translator: it means, revert document to previously saved version)"), @"", NSLocalizedString(@"Don\\U2019t Revert", @"button: Don't Revert (to previously saved version)"));
	// 1 continue
	if (choice==NSAlertDefaultReturn)
	{
		//do nothing
	}
	//don't revert
	else if (choice==NSAlertOtherReturn)
	{
		return;
	}
	NSError *theError = nil;
	[self readFromURL:[self fileURL] ofType:[self fileType] error:&theError];
	//	loadedText is typically released in windowControllerDidLoadNib
	//	but since the nib is already loaded, we can use loadedText here and release it
	if (loadedText != nil)
	{
		id tv = [self firstTextView];
		//make revert action undoable
		if ([tv shouldChangeTextInRange:NSMakeRange(0, [textStorage length]) replacementString:[loadedText string]])
		{
			[[layoutManager textStorage] replaceCharactersInRange:NSMakeRange(0,[[layoutManager textStorage] length]) 
											 withAttributedString:loadedText];
			loadedText = nil;
			[loadedText release];
			if ([[self currentFileType] isEqualToString:TXTDoc] || [[self currentFileType] isEqualToString:TXTwExtDoc])
			{
				[self applyPlainTextSettings];
			}
		}
		[[self firstTextView] didChangeText];
	}
	[[self undoManager] setActionName:NSLocalizedString(@"undo action: Revert to Saved", @"undo action: Revert to Saved")];
}

#pragma mark -
#pragma mark ---- Check Before Save ----

//	******************* Check Before Save *******************

//	checks if file has newer modification date than one from our last save 
//	must precede checkBeforeSaveWithContextInfo
- (BOOL)isEditedExternally
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:[self fileName]])
	{
		NSDate *curModDate = [self fileModDate];
		NSDate *newModDate = nil;
		newModDate = [[[NSFileManager defaultManager] fileAttributesAtPath:[self fileName] traverseLink:YES] fileModificationDate];
		//	if new not-yet-saved document, then NOT externally edited
		if (![self isDocumentSaved])
		{
			return NO;
		}
		return [curModDate isEqual:newModDate] ? NO : YES;
	} 
	else
	{
		return NO;
	}
}

//returns YES for go ahead and save (no problems); returns NO for a problem exists and we will take care of saving
-(BOOL)checkBeforeSaveWithContextInfo:(void *)contextInfo isClosing:(BOOL)isClosing
{

	// CopyPaste begin
	if([self wasServiceRequest])
	{
		if (pbname)
			[pbname release];
		[self close];
		return NO;
	}
	//CopyPaste end


	NSString *docName = [NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"firstLevelOpenQuote", nil), [self displayName], NSLocalizedString(@"firstLevelCloseQuote", nil)]; 
	
	if ([self isLossy] || [self isEditedExternally])
	{	
		//	alert that imported doc has changed
		NSString *title;
		NSString *infoText;
		if ([self isLossy] && ![self isEditedExternally])
		{ 
			//	changes were made to a doc that was imported lossy AND has been externally edited
			if ([[self fileType] isEqualToString:DOCDoc])
			{
				title = [NSString stringWithFormat:NSLocalizedString(@"Overwriting the original %@ file may cause images and page/paragraph formatting to be lost. Overwrite?", @"alert title: Overwriting the original (filename extension inserted at runtime) file may cause images and page/paragraph formatting to be lost. Overwrite?"), [self fileType]];
				infoText = NSLocalizedString(@"You can save as another document to preserve the original.", @"alert text: You can save as another document to preserve the original.");
			//Bean cannot tell the difference between an .xml file it creates, and an original WordML file, so it warns each time about overwriting
			//NOTE: is there a better solution? Some internal .xml flag we can look for (such as 'enbedded attachments')? 31 May 2007 BH
			}
			else if ([[self fileType] isEqualToString:XMLDoc])
			{
				title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to overwrite the original %@ file?", @"alert title (shown when saving to XML file format, since Bean can't tell native Bean XML from MS XML): Are you sure you want to overwrite the original (filename extension inserted at runtime) file?"), [self fileType]];
				infoText = NSLocalizedString(@"You can save as another document to preserve the original.", @"alert text: You can save as another document to preserve the original.");
			}
			//overwriting original may cause images to be lost alert
			else
			{
				title = [NSString stringWithFormat:NSLocalizedString(@"Overwriting the original %@ file may cause images to be lost. Overwrite?", @"alert title (when overwriting imported documents): Overwriting the original (file extension name inserted at runtime) file may cause images and some formatting to be lost. Overwrite?"), [self fileType]];
				infoText = NSLocalizedString(@"You can save as another document to preserve the original.", @"alert text: You can save as another document to preserve the original.");
			}
		}
		//edited externally alert
		//Apple incorporated this alert (as seen for example in Text Edit in 10.4) into the AppKit for 10.5
		//under 10.5, this causes two similar looking alerts to appear, so we now only show alert if 10.4 (still get duplication for alert just below, though)
		else if (![self isLossy] && [self isEditedExternally])
		{
				title = [NSString stringWithFormat:NSLocalizedString(@"The file for the document %@ has been changed by another application since you opened or saved it. Overwrite?", @"alert title: The file for the document (document name inserted at runtime--no trailing space)has been changed by another application since you opened or saved it. Overwrite?"), docName];
				infoText = NSLocalizedString(@"You can save as another document to make sure no changes are lost.", @"text alert (shown when user tries to save a file that has been externally edited in another program): You can save as another document to make sure no changes are lost.");
		}
		//imported AND has been edited externally warning -- will still get two similar looking alerts under Leopard (hopefully very rare!)
		else
		{
			title = [NSString stringWithFormat:NSLocalizedString(@"The document %@ was imported, and also has been changed by another application since you opened or saved it. Overwrite?", @"alert title: The document (document name inserted at runtime--no trailing space)was imported, and also has been changed by another application since you opened or saved it. Overwrite?"), docName];
			infoText = [NSString stringWithFormat:NSLocalizedString(@"Overwriting the original %@ file might cause images, formatting, and recent changes to be lost.", @"alert text: Overwriting the original (file extension name inserted at runtime) file might cause images, formatting, and recent changes to be lost."), [self fileType]];
		}
		//	!flag means doc is not closing, so we pass nil as contextInfo since no callback on canCloseWithDelegeate is needed
		if (!isClosing) { contextInfo = nil; }
		
		if (![self isLossy] && [self isEditedExternally] && [GLOperatingSystemVersion isAtLeastLeopard])
		{
			//dont' put up alert if doc had been externally edited and OS is 10.5+, since AppKit does its own alert 7 Oct 08 JH
		}
		else
		{
			NSBeginAlertSheet(title, NSLocalizedString(@"Overwrite", @"button: Overwrite"), NSLocalizedString(@"Save As...", @"button: Save As..."), NSLocalizedString(@"Cancel", @"button: Cancel"), docWindow, self, NULL, 
							  @selector(lossyDocAlertDidEnd:returnCode:contextInfo:), contextInfo, infoText); 
			/*
			 Returning 'no' means saving the doc is our responsibility now (because it failed the checkBeforeSave test).
			 Problems will have to be presented post-attempted-save by willPresentErrors.
			 Also, if isClosing is flagged, callback to canCloseWithDelegate SEL is now our job. 
			 */
			return NO;
		}
	}
	
	//	if file or file package (=folder) is LOCKED, alert user and cancel any close command
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDictionary *theFileAttrs = [fm fileAttributesAtPath:[self fileName] traverseLink:YES];
	if ([[theFileAttrs objectForKey:NSFileImmutable] boolValue] == YES)
	{
		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved because the file is locked.", @"alert title: The document (document name inserted at runtime) could not be saved because the file is locked."), docName];
		NSString *theInformativeString = NSLocalizedString(@"To keep your changes, save as a different document.", @"alert text: To keep your changes, save as a different document.");
		if (!isClosing)
			contextInfo = nil;
		NSBeginCriticalAlertSheet(title, NSLocalizedString(@"Save As...", @"button: Save As..."), NSLocalizedString(@"Unlock and Save", @"button: Unlock and Save"), NSLocalizedString(@"Cancel", @"button: Cancel"), docWindow, self, NULL, 
								  @selector(lockedDocAlertDidEnd:returnCode:contextInfo:), contextInfo, theInformativeString); 
		return NO;
	}
	return YES;
}

#pragma mark -
#pragma mark ---- Save File ----

// ***************** Save File ********************

//in 10.6, Bean's saved rtf and rtfd etc. files are not opened in Bean upon double-click due to Finder ignoring the file's creator codes
//	Bad OS X, Bad!! Instead the filename extension is used to determine the opening app (which is of course Text Edit).
//	I would like to take the opportunity to state that this sucks because in the old system, you could have it both ways (all of one type
//		open in one app, or each opens in its creator app), and now that freedom is gone.
//	The hack below allows Bean to claim its own files once again by using the file association mechanism in Finder
//	NOTE: I don't like to resort to an Applescript to do this but I don't know how else to go about it

//	ALSO NOTE: although we set app association to 'path' of application Bean, it seems to work no matter what folder we subsequently move the app to 
/*
//we used to do it this way (compiling the script on the fly) but there was a noticeable pause, even on a fast machine, and quitting during the pause could crash the app
-(IBAction)associateFileWithBean:(id)sender
{
	if ([self fileName])
	{
		NSDictionary* errorDict;
		//NSAppleEventDescriptor* returnDescriptor = NULL;
		NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:
			
		[NSString stringWithFormat:
			@"\
			if application \"Bean\" is running\n\
			tell application \"System Events\"\n\
			set default application of file (\"%@\" as text) to (path to application \"Bean\")\n\
			end tell\n\
			end if",
		[self fileName]]];

		//returnDescriptor = 
		[scriptObject executeAndReturnError: &errorDict]; //quit during pause caused by compile can cause crash? BOOL for appShouldTerminate?
		[scriptObject release];
	}
}
*/

//from http:(remove_me)//developer.apple.com/mac/library/technotes/tn2006/tn2084.html
//calling compiled applescript is faster than compiling applescript on the fly 10 FEB 2010 JBH
- (IBAction)associateFileWithBean:(id)sender
{
	// load the script from a resource by fetching its URL from within our bundle
	// the precompiled applescript is in the resource folder of the app bundle
	NSString* path = [[NSBundle mainBundle] pathForResource:@"associate_app" ofType:@"scpt"];
	if (path != nil && [self fileName])
	{
		NSURL* url = [NSURL fileURLWithPath:path];
		if (url != nil)
		{
			NSDictionary* errors = [NSDictionary dictionary];
			NSAppleScript* appleScript =
					[[NSAppleScript alloc] initWithContentsOfURL:url error:&errors];
			if (appleScript != nil)
			{
				// create the first parameter
				NSAppleEventDescriptor* firstParameter =
						[NSAppleEventDescriptor descriptorWithString:[self fileName]];
				// create and populate the list of parameters (in our case just one)
				NSAppleEventDescriptor* parameters = [NSAppleEventDescriptor listDescriptor];
				[parameters insertDescriptor:firstParameter atIndex:1];

				// create the AppleEvent target
				ProcessSerialNumber psn = {0, kCurrentProcess};
				NSAppleEventDescriptor* target =
				[NSAppleEventDescriptor
						descriptorWithDescriptorType:typeProcessSerialNumber
						bytes:&psn
						length:sizeof(ProcessSerialNumber)];

				NSAppleEventDescriptor* handler =
						[NSAppleEventDescriptor descriptorWithString:
						[@"associate_app" lowercaseString]];

				// create the event for an AppleScript subroutine,
				// set the method name and the list of parameters
				NSAppleEventDescriptor* event =
						[NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite
								eventID:kASSubroutineEvent
								targetDescriptor:target
								returnID:kAutoGenerateReturnID
				transactionID:kAnyTransactionID];
				[event setParamDescriptor:handler forKeyword:keyASSubroutineName];
				[event setParamDescriptor:parameters forKeyword:keyDirectObject];

				// call the event in AppleScript
				if (![appleScript executeAppleEvent:event error:&errors]);
				{
					// report any errors from 'errors'
					//don't care
 				}
				[appleScript release];
			}
			else
			{
			   // report any errors from 'errors'
			}
		}
	}
}

//	called by the 'Save' menu item and Autosave method
-(IBAction)saveTheDocument:(id)sender
{

	// CopyPaste begin
	if([self wasServiceRequest])
	{
		if (pbname)
			[pbname release];
		[self close];
		return;
	}
	//CopyPaste end
	

	if ([self fileName]==nil)
	{
		//	if no filename, call Save As and save the file
		[self runModalSavePanelForSaveOperation:NSSaveAsOperation delegate:NULL didSaveSelector:nil contextInfo:NULL];
		
		if ([self originalFileName])
		{
			[self setOriginalFileName:nil];
		}
	}
	else
	{
		//	else, just save the file
		if ([self checkBeforeSaveWithContextInfo:nil isClosing:NO])
		{
			[self saveDocument:nil];
		}
	}
}

- (BOOL)saveToURL:(NSURL *)absoluteURL 
		 ofType:(NSString *)typeName
		 forSaveOperation:(NSSaveOperationType)saveOperation
		 error:(NSError **)outError
{
	BOOL result;
	
	//	if zero length text, save one char (space) and add zeroLengthText=1 keyword to preserve attributes
	//	we remove placeholder space upon opening document when we see the keyword //15 Feb 08 JH
	if (![textStorage length] && [[self firstTextView] isRichText])
	{
		//	we use accessor, not bool, because textLengthIsZero is looked at when creating the document attribute dictionary
		[self setTextLengthIsZero:YES];
		NSDictionary *theAttributes = [[self firstTextView] typingAttributes];
		if (theAttributes)
		{
			NSAttributedString *placeholderString = [[[NSAttributedString alloc] initWithString:@" " attributes:theAttributes]autorelease];
			[textStorage replaceCharactersInRange:NSMakeRange(0,[textStorage length]) withAttributedString:placeholderString];
		}
	}
	else
	{
		[self setTextLengthIsZero:NO];
	}
	
	//document will not show as dirty after save (because it coalesces keystrokes for undo) unless we close undo grouping here
	//how Text Edit Leopard does it: [[self windowControllers] makeObjectsPerformSelector:@selector(breakUndoCoalescing)];
	if (saveOperation!=NSAutosaveOperation) [[self firstTextView] breakUndoCoalescing];
	
	//	call super; this NSDocument method calls writeToURL, which calls fileWrapperOfType, where the real action is
	result = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
	
	//	remove placeholder character
	if ([self textLengthIsZero] && [textStorage length])
	{
		[textStorage deleteCharactersInRange:NSMakeRange(0,[textStorage length])];
	}
	
	//	bookkeeping if save was successful
	if (result)
	{
		BOOL shouldSetFileModDate = NO;
		//if 10.6 & pref=YES & filetype=rtf or rtfd
		
		//2.4.4 11 MAY 2011 the pause while the Applescript is prepared to run can cause the app to crash if Quit is selected immediately after saving a file for the first time since launch; to prevent crashes, we go with the default behavior of the OS, which is to associate rtf and rtfd with Text Edit, unless otherwise specified by the user via the Finder
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults boolForKey:@"prefShouldAssociateFileWithBean"])
		{
			if ([GLOperatingSystemVersion isAtLeastSnowLeopard] && [[NSUserDefaults standardUserDefaults] boolForKey:@"prefAssociateDocumentWithBean"]
						&& ([[self fileType] isEqualToString:RTFDDoc] || [[self fileType] isEqualToString:RTFDoc])) {
				//tell Finder to associate rtf or rtfd file with Bean (in 10.6, this doesn't happen because creator codes are ignored by Finder)
				[self associateFileWithBean:self];
				shouldSetFileModDate = YES;
			}
		}
		
		//	mark document as saved
		[self setIsDocumentSaved:YES];
		//	can't be lossy anymore because of write
		[self setLossy:NO];
		//	remember file mod date for check for external edit
		NSDate *modDate = nil;
		modDate = [[[NSFileManager defaultManager] fileAttributesAtPath:[self fileName] 
					traverseLink:YES] fileModificationDate];
		if (modDate) {
			[self setFileModDate:[[[NSFileManager defaultManager] fileAttributesAtPath:[self fileName] 
					traverseLink:YES] fileModificationDate]];
			//if we don't reset the fileModDate, the frameworks warn us that file has been externally modified, because settings the Open With...
			// Finder override apparently changes the file mode date (!)
			if (shouldSetFileModDate) {
				[self setFileModificationDate:modDate];
			}
		}
		//	file was saved, so backup is necessary *IF* shouldCreateDatedBackup==YES
		[self setNeedsDatedBackup:YES];
	}
	
	return result;
}

// ***************** fileWrapperOfType ********************

//	WRITE fileWrapper to disk
- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError
{
	//	update currentFileType in case it's changed
	[self setCurrentFileType:typeName];
	
	//--- set key for fileType here  ---/ 
	
	//	get a dictionary of the document-wide attributes for this file
	NSMutableDictionary *dict = [self createDocumentAttributesDictionary];
	
	if ([typeName isEqualToString:RTFDDoc] || [typeName isEqualToString:BeanDoc])
	{
		[dict setObject:NSRTFDTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	}
	else if ([typeName isEqualToString:DOCDoc])
	{
		//	a few users report that Apple's .doc reader/writer can be unreliable for larger documents, so we have an option to read and save .doc files as RTF format (with .doc extension) 16 MAY 08 JH 
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults boolForKey:@"prefDocIsRTF"])
		{
			[dict setObject:NSRTFTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		}
		else
		{
			//	note: Apple's .doc converter neither writes nor reads pagesize and margins attributes
			//	since Word 97 is now an open specification, so you would think this would work!
			[dict setObject:NSDocFormatTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		}
	}
	else if ([typeName isEqualToString:HTMLDoc])
	{
		[dict setObject:NSPlainTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		//	text encoding should have been parsed out when opened; if not, use UTF-8 (=4)
		unsigned enc = [self docEncoding] ? [self docEncoding] : 4;
		[dict setObject:[NSNumber numberWithUnsignedInt:enc] forKey:NSCharacterEncodingDocumentAttribute];
	}
	else if ([typeName isEqualToString:TXTDoc] || [typeName isEqualToString:TXTwExtDoc])
	{
		[dict setObject:NSPlainTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		
		//	use previous encoding if there is one
		if ([self docEncoding])
		{
			[dict setObject:[NSNumber numberWithUnsignedInt:[self docEncoding]] forKey:NSCharacterEncodingDocumentAttribute];
		}
		//	else default to UTF-8 (more 'compact' and universal than UTF-16 since UNIX and most HTML are UTF-8)
		else
		{
			//	note: OS X and Windows NT+ are UTF-16 internally, but that doesn't count for much in reading files
			//	also: MS Word seems to read UTF-8 and UTF-16 with the same ease, but Write.exe and Notepad.exe are clueless
			[dict setObject:[NSNumber numberWithUnsignedInt:4] forKey:NSCharacterEncodingDocumentAttribute];
			//	these need setting for 'Get Info...' to report encoding
			[self setDocEncoding:NSUTF8StringEncoding];
			[self setDocEncodingString:@"Unicode (UTF-8)"];
			/* 
			 NOTE TO SELF:
			 The following constants are provided by NSString as possible string encodings.
			 NSASCIIStringEncoding = 1,
			 NSNEXTSTEPStringEncoding = 2,
			 NSJapaneseEUCStringEncoding = 3,
			 NSUTF8StringEncoding = 4,			//std linux and HTML
			 NSISOLatin1StringEncoding = 5,
			 NSSymbolStringEncoding = 6,
			 NSNonLossyASCIIStringEncoding = 7,
			 NSShiftJISStringEncoding = 8,
			 NSISOLatin2StringEncoding = 9,
			 NSUnicodeStringEncoding = 10,		//std OS X
			 NSWindowsCP1251StringEncoding = 11,
			 NSWindowsCP1252StringEncoding = 12, //1252 is the common latin windows encoding
			 NSWindowsCP1253StringEncoding = 13, 
			 NSWindowsCP1254StringEncoding = 14, 
			 NSWindowsCP1250StringEncoding = 15,
			 NSISO2022JPStringEncoding = 21,
			 NSMacOSRomanStringEncoding = 30,
			 NSProprietaryStringEncoding = 65536
			 */
		}
	}
	else if ([typeName isEqualToString:XMLDoc])
	{
		[dict setObject:NSWordMLTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	}
	else if ([typeName isEqualToString:RTFDoc])
	{
		[dict setObject:NSRTFTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	}
	else if ([typeName isEqualToString:WebArchiveDoc])
	{
		[dict setObject:NSWebArchiveTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		//BUGFIX: if background color is WHITE or NONE you get BLACK (ie, no) background
		NSColor *color = nil;
		color = [[dict objectForKey:NSBackgroundColorDocumentAttribute] colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
		if (!color || (1 == [color whiteComponent] && 1 == [color alphaComponent])) {
			[dict setObject:[NSColor colorWithCalibratedRed:.99 green:1.0 blue:1.0 alpha:1] forKey:NSBackgroundColorDocumentAttribute];
		}
	}
	// new in Bean 1.1.0
	else if ([typeName isEqualToString:OpenDoc])
	{
		if ([GLOperatingSystemVersion isBeforeLeopard])
		{
			//	don't do anything; nil will be returned and willPresentError will present the appropriate error msg
			[self setFailedDocType:1];
		}
		else
		{
			[dict setObject:NSOpenDocumentTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		}
	}
	// new in Bean 1.1.0
	else if ([typeName isEqualToString:DocXDoc])
	{
		if ([GLOperatingSystemVersion isBeforeLeopard])
		{
			//	don't do anything; nil will be returned and willPresentError will present the appropriate error msg
			[self setFailedDocType:2];
		}
		else
		{
			[dict setObject:NSOfficeOpenXMLTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		}
	}
	
	//--- oddball case: RTF as .doc ---/ 
	
	//	if .doc file was RTF in disguise (determined in readFromFileWrapper), save it as RTF
	if ([self isRTFForWord])
	{
		[dict setObject:NSRTFTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	}
	
	//--- return file wrapper here ---/ 
	
	//	dict tells fileWrapperFromRange what file format to write
	if ([typeName isEqualToString:RTFDDoc] || [typeName isEqualToString:BeanDoc])
	{
		return [textStorage RTFDFileWrapperFromRange:NSMakeRange(0,[textStorage length]) documentAttributes:dict];
	}
	//	if you don't return NSData, you get the directory structure of these types of files, but not zipped!
	if ([typeName isEqualToString:OpenDoc] || [typeName isEqualToString:DocXDoc])
	{
		// returns NSData
		id theData = [textStorage dataFromRange:NSMakeRange(0,[textStorage length]) documentAttributes:dict error:outError];
		if (theData)
		{
			return [[[NSFileWrapper alloc] initRegularFileWithContents:theData] autorelease];
		}
	}
	else
	{
		return [textStorage fileWrapperFromRange:NSMakeRange(0,[textStorage length]) documentAttributes:dict error:outError];
	}
	return nil;
}

// ***************** fileAttributesToWriteToURL ********************

//	Cocoa does not write creator code and HFS filetype by default...override fileAttributesToWriteToURL to do this
//	NOTE: creator codes are ignored by the Finder under OS X 10.6 (see associateFileWithBean method)
//	NOTE: although the release notes for 10.6 say that the fileWrapper methods preserve metadata like creator codes
//	 (see: "New Support for Preserving Metadata in NSFileWrapper (New since November 2008 Seed"),
//	 in practical tests I did not find that to be the case, so I'm using this code even for 10.6
- (NSDictionary *)fileAttributesToWriteToURL:(NSURL *)absoluteURL 
			ofType:(NSString *)typeName 
			forSaveOperation:(NSSaveOperationType)saveOperation 
			originalContentsURL:(NSURL *)absoluteOriginalContentsURL 
			error:(NSError **)outError 
{

	//	if a creator code was saved upon open, use it; otherwise, use: bEAN (which is registered with Apple) 
	NSMutableDictionary *fileAttributes = [[super fileAttributesToWriteToURL:absoluteURL
				ofType:typeName forSaveOperation:saveOperation
				originalContentsURL:absoluteOriginalContentsURL
				error:outError] mutableCopy];
				
	//	if HFSTypeCode exists in hfsFileAttributes dict (from when file was opened) AND doc is not involved in a Save As... operation, then add original fileType code to file; otherwise, give it an appropriate new one
	if (![[self hfsFileAttributes] fileHFSTypeCode]==0 && !(saveOperation==NSSaveAsOperation))
	{
		[fileAttributes setObject:[ NSNumber numberWithUnsignedInt:[[self hfsFileAttributes] fileHFSTypeCode] ] forKey:NSFileHFSTypeCode];
	}
	else
	{
		if ([typeName isEqualToString:RTFDoc])
			{ [fileAttributes setObject:[NSNumber numberWithUnsignedLong:'RTF '] forKey:NSFileHFSTypeCode]; }
		else if ([typeName isEqualToString:DOCDoc])
			{ [fileAttributes setObject:[NSNumber numberWithUnsignedLong:'W8BN'] forKey:NSFileHFSTypeCode]; }
		else if ([typeName isEqualToString:TXTDoc])
			{ [fileAttributes setObject:[NSNumber numberWithUnsignedLong:'TEXT'] forKey:NSFileHFSTypeCode]; }
		else
		{	
			//nothing 
		}
	}
	
	//	if HFSCreatorCode exists in hfsFileAttributes dict (from when file was opened) AND doc is not involved in a Save As... operation, then add original code to file; otherwise, make creator code bEAN (=Bean's creator code)
	if (![[self hfsFileAttributes] fileHFSCreatorCode]==0 && !(saveOperation==NSSaveAsOperation))
	{
		[fileAttributes setObject:[ NSNumber numberWithUnsignedInt:[[self hfsFileAttributes] fileHFSCreatorCode] ] forKey:NSFileHFSCreatorCode];
	}
	
	//	but, if fileType is .doc, we make MS Word creator
	else if ([typeName isEqualToString:DOCDoc])
	{
		[fileAttributes setObject:[NSNumber numberWithUnsignedLong:'MSWD'] forKey:NSFileHFSCreatorCode];
	}
	
	//	for documents we create, we can strongly associate them with Bean in Launch Services by including Bean's creator code
	//	note: we DONT want .html or .webarchive to open automatically in Bean, but rather in Safari, etc.!
	else if (![typeName isEqualToString:HTMLDoc] 
				&& ![typeName isEqualToString:WebArchiveDoc] 
				&& ![typeName isEqualToString:TXTDoc]
				&& ![typeName isEqualToString:TXTwExtDoc])
	{
		//creator code, registered with APPLE, is bEAN
		[fileAttributes setObject:[NSNumber numberWithUnsignedInt:kMyAppCreatorCode] forKey:NSFileHFSCreatorCode];
	}
	else
	{
		//no creator code, so .html, .webarchive & misc text files will open in Safari etc. and not Bean
	}
	return [fileAttributes autorelease];
}


// ******************* export to HTML ********************

-(IBAction)exportToHTML:(id)sender 
{
	// default: Export > to HTML with styles [=embedded CSS]
	BOOL noCSS = FALSE;
	// alt: Export > to HTML (no styles) [=no CSS]
	if ([sender tag]==1) { noCSS = TRUE; }

	//	this part creates a folder for the exported file index.html and the objects that go with it
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *theHTMLPath = [[self fileName] stringByDeletingPathExtension];
	int exportNumber = 0;
	NSError *theError = nil;
	
	//	we don't export images now, so this is unused
	//BOOL exportImageSuccess = YES;
	
	//	path of the HTML containing folder
	NSString *theHTMLFolderPath = [NSString stringWithFormat:@"%@%@", theHTMLPath, @" - html"];
	//	to avoid overwriting previous export, add sequential numbers to folder name
	while ([fm fileExistsAtPath:theHTMLFolderPath isDirectory:NULL] && exportNumber < 1000)
	{
		exportNumber = exportNumber + 1;
		theHTMLFolderPath = nil;
		theHTMLFolderPath = [NSString stringWithFormat:@"%@%@%i", theHTMLPath, @" - html", exportNumber];
	}
	[fm createDirectoryAtPath:theHTMLFolderPath attributes:nil];
	
	//if the folder was created, write the exported html file inside it
	if ([fm fileExistsAtPath:theHTMLFolderPath isDirectory:NULL])
	{
		NSError *outError = nil;
	
		//remember current background color
		NSColor *someColor = [[self firstTextView] backgroundColor];
		//use non-Alternate Color mode background color during export
		[[self firstTextView] setBackgroundColor:[self theBackgroundColor]];

		//	get doc-wide dictionary and set type to HTML
		NSMutableDictionary *dict = [self createDocumentAttributesDictionary];
		[dict setObject:NSHTMLTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
		
		// export with no embedded CSS (just pure HTML without styles)
		if (noCSS)
		{
			NSMutableArray *excludedElements = [NSMutableArray array];
			//strict HTML (NOT XHTML) 2.4.3 2 FEB 2010 JBH
			[excludedElements addObject:@"XML"];
			//deprecated in HTML 4.0
			[excludedElements addObjectsFromArray:[NSArray arrayWithObjects:@"APPLET", @"BASEFONT", @"CENTER", @"DIR", @"FONT", @"ISINDEX", @"MENU", @"S", @"STRIKE", @"U", nil]];
			//no embedded CSS
			[excludedElements addObject:@"STYLE"];
			[excludedElements addObject:@"SPAN"];
			[excludedElements addObject:@"Apple-converted-space"];
			[excludedElements addObject:@"Apple-converted-tab"];
			[excludedElements addObject:@"Apple-interchange-newline"];
			[dict setObject:excludedElements forKey:NSExcludedElementsDocumentAttribute];
		}
		
		//UTF=8
		[dict setObject:[NSNumber numberWithInt:NSUTF8StringEncoding] forKey:NSCharacterEncodingDocumentAttribute];
		//2 spaces for indented elements
		//todo: make number of spaces a hidden preference? 
		[dict setObject:[NSNumber numberWithInt:2] forKey:NSPrefixSpacesDocumentAttribute];

		//	create data object for HTML
		NSData *data = [[self textStorage] dataFromRange:NSMakeRange(0, [textStorage length]) documentAttributes:dict error:&outError];

		//restore remembered color AFTER exporting data for HTML
		if (someColor)
		{	
			[[self firstTextView] setBackgroundColor:someColor];
		}
		// just in case
		else
		{
			[[self firstTextView] setBackgroundColor:[NSColor whiteColor]];
		}
		
		//rewrote below bit 27 FEB 09 JH
		
		//	get html code as string from HTML data object
		NSString *tmpString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		NSMutableString *htmlString = nil;
		if (tmpString)
		{
			// make the string mutable
			htmlString = [[[NSMutableString alloc] initWithCapacity:[tmpString length]] autorelease];
			[htmlString setString:tmpString]; 
		}
		// remove extraneous path elements generated by Cocoa in HTML code for image URLs
		if (htmlString && [htmlString length]) [htmlString replaceOccurrencesOfString:@"file:///" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [htmlString length])];
		// write it to file
		if (htmlString && [htmlString length])
		{
			//	path for index.html, the exported HTML file
			NSString *theHTMLPath = [NSString stringWithFormat:@"%@%@", theHTMLFolderPath, @"/index.html"];
			NSURL *theHTMLURL = [NSURL fileURLWithPath:theHTMLPath];
			//	write index.html file
			[htmlString writeToURL:theHTMLURL atomically:YES encoding:NSUTF8StringEncoding error:&theError];
			
			/*
			 //	NOT USED!
			 //	write picture attachments to html export folder
			 //	note: the scale of these pictures in a document is not the same as the scale when placed in HTML; rather than rescaling or whatever, just export the HTML and let the user drop the image files into the HTML file's containing folder
			 
			 NSMutableAttributedString *theAttachmentString = [[NSMutableAttributedString alloc] initWithAttributedString:textStorage];
			 NSRange strRange = NSMakeRange(0, [theAttachmentString length]);
			 while (strRange.length > 0)
			 {
			 NSRange effectiveRange;
			 id attr = [theAttachmentString attribute:NSAttachmentAttributeName atIndex:strRange.location effectiveRange:&effectiveRange];
			 strRange = NSMakeRange(NSMaxRange(effectiveRange), NSMaxRange(strRange) - NSMaxRange(effectiveRange));
			 if(attr)
			 {
			 NSTextAttachment *attachment = (NSTextAttachment *)attr;
			 NSFileWrapper *fileWrapper = [attachment fileWrapper];
			 NSString *fileWrapperPath = [fileWrapper filename];
			 NSString *pictureExportPath = [NSString stringWithFormat:@"%@%@%@", theHTMLFolderPath, @"/", fileWrapperPath];
			 //NSLog(pictureExportPath);
			 BOOL success = YES;
			 success = [fileWrapper writeToFile:pictureExportPath atomically:YES updateFilenames:YES];
			 if (success==NO) exportImageSuccess = NO;
			 attachment = nil;
			 fileWrapper = nil;
			 fileWrapperPath = nil;
			 pictureExportPath = nil;
			 }
			 }			
			 [theAttachmentString release];
			 */
		}
	}
	//there was an error in creating the export folder
	else
	{
		NSBeep();
	}
	//	error alert dialog
	if (![fm fileExistsAtPath:theHTMLFolderPath isDirectory:NULL] || theError)
	{
		NSString *anError = [theError localizedDescription];
		NSString *alertTitle = nil;
		if (theError)
		{
			alertTitle =  [NSString stringWithFormat:NSLocalizedString(@"Export to HTML failed: %@", @"alert title: Export to HTML failed: (localized reason for failure automatically inserted at runtime)"), anError];
		}
		else
		{
			alertTitle = NSLocalizedString(@"Export to HTML failed.", @"Export to HTML failed.");
		}
		[[NSAlert alertWithMessageText:alertTitle
						 defaultButton:NSLocalizedString(@"OK", @"OK")
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:NSLocalizedString(@"A problem prevented the document from being exported to HTML format.", @"alert text: A problem prevented the document from being exported to HTML format.")] runModal];
		alertTitle = nil;
	}
	
	/*
	 else if (theError==nil && exportImageSuccess == NO)
	 {
	 [[NSAlert alertWithMessageText:NSLocalizedString(@"There was a problem exporting image files.", @"Title of alert indicating that there was a problem exporting image files.")
	 defaultButton:NSLocalizedString(@"OK", @"OK")
	 alternateButton:nil
	 otherButton:nil
	 informativeTextWithFormat:NSLocalizedString(@"You can manually drag image files from the Finder into the revealed HTML file's folder to solve the problem.", @"Text of alert indicating you can manually drag image files from the Finder into the revealed HTML file's folder to solve the problem.")] runModal];
	 }
	 */
	
	else
	{
		//	show exported file in Finder for the user
		[[NSWorkspace sharedWorkspace] selectFile:theHTMLFolderPath inFileViewerRootedAtPath:nil];
	}
}

//	"Export to DOC (with Picures)" menu action
//	thanks to Keith Blount for figuring out how to inject encoded pictures into the RTF stream before saving the document and thanks to BW for writing up the code...see EncodeRTFwithPictures on CocoaDev.com for details
-(IBAction)saveRTFwithPictures:(id)sender
{
	NSString *formatStr = nil; //	for alert msgs
	NSString *extString = nil; //	extension for saved filename
	NSFileManager *fm = [NSFileManager defaultManager];
	//	.rtf
	if ([sender tag]==0)
	{
		extString = @".rtf";
		formatStr = NSLocalizedString(@"RTF with images", @"name of export format used in alert dialog upon failure to export: RTF with images");
	}
	//	.doc
	else
	{
		extString = @".doc";
		formatStr = NSLocalizedString(@"DOC with images" , @"name of export format used in alert dialog upon failure to export: DOC with images");
	}
	//	new filename to save to
	int exportFileNumber = 0;
	//	get path with extension removed, then add .rtf extension
	NSString *thePathMinusExtension = [[self fileName] stringByDeletingPathExtension];
	NSString *theExportPath = [NSString stringWithFormat:@"%@%@", thePathMinusExtension, extString];
	//	to avoid overwriting previous export, add sequential numbers to filename just before extension
	while ([fm fileExistsAtPath:theExportPath] && exportFileNumber < 1000)
	{
		exportFileNumber = exportFileNumber + 1;
		theExportPath = [NSString stringWithFormat:@"%@%@%i%@", 
						 thePathMinusExtension, @" ", exportFileNumber, extString];
	}
	//	get string with pictures encoded in hex
	NSError *outError = nil;
	NSString *stringWithEncodedPics = nil;
	NSAttributedString *textString = nil;
	textString = [textStorage copy];
	//	note: this is a category on NSAttributedString, created by Keith Blount and coded by BW (EncodeRTFwithPictures)
	stringWithEncodedPics = [textString encodeRTFwithPictures];
	BOOL success = YES;
	success =[stringWithEncodedPics writeToURL:[NSURL fileURLWithPath:theExportPath] atomically:YES encoding:NSASCIIStringEncoding error:&outError];	
	[textString release];
	//	file was written out, so give OSType and Creator Code file attributes
	if (success)
	{
		NSDictionary *fileAttributes = [fm fileAttributesAtPath:theExportPath traverseLink:YES];
		NSMutableDictionary *newFileAttrs = [NSMutableDictionary dictionaryWithDictionary:fileAttributes];
		if (newFileAttrs)
		{
			//	OStype = rtf
			if ([sender tag]==0) { [newFileAttrs setObject:[NSNumber numberWithUnsignedLong:'RTF '] forKey:NSFileHFSTypeCode]; }
			//	OSType = doc
			else { [newFileAttrs setObject:[NSNumber numberWithUnsignedLong:'W8BN'] forKey:NSFileHFSTypeCode]; }
			//	creator = MS Word
			[newFileAttrs setObject:[NSNumber numberWithUnsignedLong:'MSWD'] forKey:NSFileHFSCreatorCode];
			//	if writing the changed attributes fails, it's not that important
			[fm changeFileAttributes:newFileAttrs atPath:theExportPath];
		}
		fileAttributes = nil;
	}
	
	//	error alert dialog
	if (outError)
	{
		NSString *errDesc = nil;
		errDesc = [outError localizedDescription];
		[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Export document to %@ format failed: %@", @"alert title: Export document to (localized format name inserted at runtime, ex: 'Doc with images') format failed: (localizedErrorDescription automatically inserted at runtime)"), formatStr, errDesc]
						 defaultButton:NSLocalizedString(@"OK", @"OK")
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:NSLocalizedString(@"A problem prevented the document from being exported.", @"alert text: A problem prevented the document from being exported.")] runModal];
		errDesc = nil;
	} else {
		//	show exported file in Finder for the user
		[[NSWorkspace sharedWorkspace] selectFile:theExportPath inFileViewerRootedAtPath:nil];
	}
	//	zero everything out
	formatStr = nil;
	extString = nil;
	theExportPath = nil;
	thePathMinusExtension = nil;
	textString = nil;
	stringWithEncodedPics = nil;
	outError = nil;
}

#pragma mark -
#pragma mark ---- Save Panel ----

-(NSString *)suggestedTitleString
{
	NSString *titleString = nil;
	//SUGGEST a filename to the user in the save panel based on the first few words of text in the document
	if ([self fileName]==nil && [textStorage length])
	{
		//strip attributes and attachments
		NSRange aRange = [[textStorage string] lineRangeForRange:NSMakeRange(0, 1)];
		//if longer than 10 chars
		if (aRange.length > 10)
		{
			//don't allow more than 32 chars (arbitrary)
			if (aRange.length > 40) { aRange.length = 40; }
			NSMutableCharacterSet *tempTrimTitleSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
			[tempTrimTitleSet formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
			[tempTrimTitleSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
			//make string
			NSString *tempTitleString = [[textStorage string] substringWithRange:aRange];
			//trim any unwanted trailing characters
			NSString *preTrimString = [tempTitleString stringByTrimmingCharactersInSet:tempTrimTitleSet];
			NSCharacterSet *controlChars = [NSCharacterSet controlCharacterSet];
			NSRange controlCharRange = [preTrimString rangeOfCharacterFromSet:controlChars];
			//remove any unwanted control characters
			if (controlCharRange.location != NSNotFound)
			{
				titleString = [preTrimString substringWithRange:NSMakeRange(0, controlCharRange.length)];
			}
			else
			{
				titleString = preTrimString;
			}
			//else, do nothing since a title string of decent length could not be created
			[tempTrimTitleSet release];
		}
	}
	if (titleString && [titleString length] > 7 && [titleString length] < 41) {
		return titleString;
	}
	else {
		return nil;
	}
}

// ***************** Save Panel ********************

- (BOOL)prepareSavePanel:(NSSavePanel *)sp
{
	[sp setDelegate:self]; // must nil this out in panel:isValidFilename; otherwise crash
	[sp setCanSelectHiddenExtension:YES];
   	[sp setExtensionHidden:YES]; 
	//for testing purposes
	//[sp setAllowsOtherFileTypes:NO];
	
	//	if a locked file was opened as Untitled (but not as default new document template), show original name here as a reminder
	if ([self originalFileName] && ![self wasCreatedUsingNewDocumentTemplate])
	{
		[sp setMessage:[NSString stringWithFormat:NSLocalizedString(@"Original file was named: \\U201C%@\\U201D", @"message in Save File sheet, informing user: Original file was named: (original document name is inserted at runtime)."), [[self originalFileName]lastPathComponent]]];
	}
	
	//below adds a help button to the save panel (next to the file formats popup button) which opens help on file formats
	id(theView) = [sp accessoryView]; //view containing the format popup list

	//2.4.3 2 FEB 2010 JBH the filetype popup button in the save panel was widened under 10.6 so that the help button which we add as a subview overlaps it
	// so just add help button if savepanel is expanded; still looks wonky is panel is un-expanded while up though
	//2.4.4 11 MAY 2011 removed since help anchors no longer work thanks to revised SL help system
	/*
	if ([sp isExpanded]) {
		//accessory view frame
		NSRect theRect = [[theView superview] frame];
		//position for help button
		NSRect helpButtonRect = NSMakeRect(theRect.origin.x + theRect.size.width - 35, (theRect.size.height * .5) - 12.5, 25, 25);
		//create the help button programmatically
		NSButton *helpButton = [[[NSButton alloc] initWithFrame: helpButtonRect] autorelease];
		[helpButton setToolTip:NSLocalizedString(@"Help with file formats", @"tooltip: Help with file formats (for a button which opens the help page for file formats)")];
		NSButtonCell *helpButtonCell = [[[NSButtonCell alloc] init] autorelease];
		[helpButtonCell setTitle:@""];
		[helpButtonCell setBezelStyle:NSHelpButtonBezelStyle];
		[helpButtonCell setTarget:[NSApp delegate]];
		[helpButtonCell setAction:@selector(displayHelp:)];
		[helpButton setEnabled:YES];
		[helpButton setTag:0];
		[helpButton setCell: helpButtonCell];
		//keeps button aligned to right side of superView upon resizing save panel 
		[helpButton setAutoresizingMask:NSViewMinXMargin];
		[[theView superview] addSubview: helpButton];	
	}
	*/
	
	
	//	find NSPopUpButton containing file format names and delete ODT and DOCX if OS X version is TIGER since these docTypes are not Tiger compatible
	//	how: navigate savePanel's accessory view and delete menu items from NSPopUpButton with title = incompatible file format
	//	if this fails, savePanel:isValidFilename will show alert upon attempted save; if that fails, fileWrapper > willPresentError will show alert
	
	//	if Tiger...
	if ([GLOperatingSystemVersion isBeforeLeopard])
	{
		//	get subviews of accessory view
		NSArray *theSubviews = [theView subviews];
		unsigned int i, count = [theSubviews count]; 
		for (i = 0; i < count; i++)
		{
			//	this should be an NSView holding all the controls of the savePanel's accessory view
			NSView *v = [theSubviews objectAtIndex:i]; 
			if ([v isKindOfClass:[NSView class]])
			{
				NSArray *theControls = [v subviews];
				unsigned int d, theCount = [theControls count];
				//	iterate thru controls
				for (d = 0; d < theCount; d++)
				{
					id control = [theControls objectAtIndex:d];
					//	examine each control looking for file format popup menu
					if ([control isKindOfClass:[NSPopUpButton class]] && [control respondsToSelector:@selector(removeItemWithTitle:)])
					{
						//	remove the incompatible file formats
						if ([control itemWithTitle:NSLocalizedString(DocXDoc, @"localized name of Word 2007 file format in Bean")])
						{ [control removeItemWithTitle:NSLocalizedString(DocXDoc, @"localized name of Word 2007 file format in Bean")]; }
						if ([control itemWithTitle:NSLocalizedString(OpenDoc, @"localized name of OpenDocument file format in Bean")])
						{ [control removeItemWithTitle:NSLocalizedString(OpenDoc, @"localized name of OpenDocument file format in Bean")]; }
					}
				}
			}
		} 
	}
	
	//if prefs say to, suggest filename in save panel based on first words of document text 
	//this turned out to be hard to do for reasons stated here:
	//
	//panel's _nameField string is not set to "Untitled.???" until AFTER this method, so we can't set it here.
	//one way: create category on NSSavePanel.h with accessor methods for the (private!) ivar _nameField, then to set the filename from panel:isValidFilename: for example. But using a private ivar is bad.
	//also, we can't use [doc setFilename] because we actually set the filename that way; it shows up in the document's titlebar before the save is done and looks confusing.
	//so, instead we walk the view hierarchy of the save panel to find the NSTextField _nameField via context, then set it using a doSelector command after prepareSavePanel is finished
	//
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	//disabled by menu verification on Tiger; use hack on Leopard; use native API on Snow Leopard
	if ([defaults boolForKey:@"prefSuggestFilename"])
	{
		if ([GLOperatingSystemVersion isBeforeSnowLeopard])
		{
			//get subviews of save panel's contentView
			NSArray *subviews = [[sp contentView] subviews];
			//look at all of them, in case a view has been inserted, or moved
			unsigned int i, count = [subviews count];
			//examine each subview 
			for (i = 0; i < count; i++)
			{
				id subview = [subviews objectAtIndex:i];
				NSArray *containedSubviews = [subview subviews];
				if ([containedSubviews count] > 0)
				{
					//get contained subview
					id containedSubview = [containedSubviews objectAtIndex:0];
					if ([containedSubview isKindOfClass:[NSView class]])
					{
						NSArray *furtherContainedSubviews = [containedSubview subviews];
						if ([furtherContainedSubviews count] > 0)
						{
							//then next level of subview, which in turn contains controls
							id furtherContainedSubview = [furtherContainedSubviews objectAtIndex:0];
							//there are typically three controls: 0 = nameField, 1 = NSPopupButton, 2 = label: Save As...
							if ([[furtherContainedSubview subviews] count] > 2)
							{
								id nameField = [[furtherContainedSubview subviews] objectAtIndex:0];
								//chances are really slim this would match anything else...
								if ([[[furtherContainedSubview subviews] objectAtIndex:2] isKindOfClass:[NSTextField class]]
									&& [nameField isKindOfClass:[NSTextField class]]
									&& [nameField respondsToSelector:@selector(stringValue)])
								{
									//since nameField is not set until *after* prepareSavePanel, we do this:
									[self performSelector:@selector(setStringValueForSavePanelTextField:) withObject:nameField afterDelay:0.0f];
								}
							}
						}
					}
				}
			}
		}
		else if ([GLOperatingSystemVersion isAtLeastSnowLeopard])
		{
			if ([sp respondsToSelector:@selector(setNameFieldStringValue:)])
			{
				NSString *titleString = nil;
				titleString = [self suggestedTitleString];
				if (titleString) {
					[sp setNameFieldStringValue:titleString];
				}
			}
		}
	}
	return YES;
}

//set suggested filename in save panel for versions before 10.6
-(void)setStringValueForSavePanelTextField:(NSTextField *)nameField
{
	NSString *titleString = [self suggestedTitleString];
	if (nameField != nil && [nameField respondsToSelector:@selector(setStringValue:)])
	{
		[nameField setStringValue:@""];
		[nameField setStringValue:titleString];
	}
}

//	check filename supplied by user in Save Panel and warn user if there is a problem or inconsistancy
- (BOOL)panel:(id)sender isValidFilename:(NSString *)filename
{
	[sender setDelegate:nil]; //Bean will crash when save panel goes away unless you remove self (JHDocument) as delegate
	NSTextView *theTextView = [self firstTextView]; 
	NSString *theExtension = [[filename pathExtension] uppercaseString];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *docName = [NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"firstLevelOpenQuote", nil), [self displayName], NSLocalizedString(@"firstLevelCloseQuote", nil)]; 
	
	BOOL isDir = NO;
	[fm fileExistsAtPath:filename isDirectory:&isDir];
	BOOL isPkg = [[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename];
	//warn user that file (probably a filename with no extension of type TXTwExtDoc) can overwrite folder of same name, erasing contents 
	if (isDir && !isPkg)
	{
		NSBeep();
		NSString *folderName = [filename lastPathComponent];
		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"A folder already uses the name \\U201C%@.\\U201D", @"alert title: A folder already uses the name (folder name inserted at runtime). (alert called to warn a user not to overwrite a folder with a file)"), folderName];
		NSString *theInformativeString = NSLocalizedString(@"Overwriting this folder will destroy its contents! Choose another name.", @"alert text: Overwriting this folder will destroy its contents! Choose another name.");
		NSAlert *lockedFolderAlert = [NSAlert alertWithMessageText:title defaultButton:NSLocalizedString(@"OK", @"OK") alternateButton:nil otherButton:nil
										 informativeTextWithFormat:theInformativeString];
		[lockedFolderAlert runModal];
		return NO;
	}
	
	//	alert user that the containing FOLDER is LOCKED
	NSDictionary *theFolderAttrs = [fm fileAttributesAtPath:[filename stringByDeletingLastPathComponent] traverseLink:YES];
	if ([[theFolderAttrs objectForKey:NSFileImmutable] boolValue] == YES) {
		NSString *theFolderName = [[filename stringByDeletingLastPathComponent]lastPathComponent];
		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"The folder \\U201C%@\\U201D is locked.", @"alert title: The folder (folder name inserted at runtime) is locked. (alert called when a save cannot proceed)"), theFolderName];
		NSString *theInformativeString = NSLocalizedString(@"Documents cannot be saved in a locked folder. Choose another location.", @"alert text: Documents cannot be saved in a locked folder. Choose another location.");
		NSAlert *lockedFolderAlert = [NSAlert alertWithMessageText:title defaultButton:NSLocalizedString(@"OK", @"OK") alternateButton:nil otherButton:nil
										 informativeTextWithFormat:theInformativeString];
		[lockedFolderAlert runModal];
		return NO;
	}
	
	//	alert user that the file is LOCKED
	NSDictionary *theFileAttrs = [fm fileAttributesAtPath:filename traverseLink:YES];
	if ([[theFileAttrs objectForKey:NSFileImmutable] boolValue] == YES)
	{
		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"The file %@ is locked.", @"alert title: The file is locked. (alert called when a save cannot proceed)"), docName];
		NSString *infoText = NSLocalizedString(@"Locked files cannot be overwritten. Save the document with a new name to keep your changes.", @"alert text: Locked files cannot be overwritten. Save the document with a new name to keep your changes.");
		NSAlert *lockedFileAlert = [NSAlert alertWithMessageText:title defaultButton:NSLocalizedString(@"OK", @"OK") alternateButton:nil otherButton:nil
									   informativeTextWithFormat:infoText];
		[lockedFileAlert runModal];
		return NO;
	}	
	
	//	ODT and DOCX are not compatible with Tiger - warn user
	//	prepareSavePanel should have removed incompatible fileTypes by this point, but this is fall through code, just in case...
	if ([GLOperatingSystemVersion isBeforeLeopard])
	{
		if ([theExtension isEqualToString:@"ODT"] || [theExtension isEqualToString:@"DOCX"])
		{
			NSString *theDocType = nil;
			if ([theExtension isEqualToString:@"ODT"])
			{ theDocType = OpenDoc; }
			else if ([theExtension isEqualToString:@"DOCX"])
			{ theDocType = DocXDoc; }
			else
			{ theDocType = @""; }
			
			int choice;
			NSString *title = [NSString stringWithFormat:NSLocalizedString(@"alert title: Bean requires OS X 10.5 \\U2018Leopard\\U2019 to support the file format %@.", @"alert title: Bean requires OS X 10.5 \\U2018Leopard\\U2019 to support the file format %@."), theDocType];
			NSString *infoText = [NSString stringWithFormat:NSLocalizedString(@"alert text: Please select another file format.", @"Please select another file format.")];
			choice = NSRunAlertPanel(title,
									 infoText,
									 NSLocalizedString(@"OK", @"button: OK"),
									 nil,
									 nil);
			//	1: means save was cancelled so user can pick another file format
			if (choice==NSAlertDefaultReturn)
			{ 
				return NO;
			}
		}
	}
	
	//	if there are graphics but a graphics-capable format was not chosen, offer 'recovery' choice
	if ([theTextView importsGraphics] && [theTextView isRichText])
	{
		//	show alert if extension is RTF, DOC, or XML, or plain text, because they don't save images
		if ([textStorage containsAttachments]
			//	kosher for images
			&& ![theExtension isEqualToString:@"RTFD"] 
			&& ![theExtension isEqualToString:@"BEAN"]
			&& ![theExtension isEqualToString:@"WEBARCHIVE"]
			//	plain text is special case, handled later 
			&& ![theExtension isEqualToString:@"TXT"]
			//	these do not handle images, so we show alert (BUG FIX 17 May 2007 BH)
			&& ([theExtension isEqualToString:@"RTF"] 
				|| [theExtension isEqualToString:@"DOC"] 
				|| [theExtension isEqualToString:@"XML"]
				|| [theExtension isEqualToString:@"ODT"]
				|| [theExtension isEqualToString:@"DOCX"] ) )
		{
			int choice;
			NSString *docTitle = [self displayName];
			NSString *title = [NSString stringWithFormat:NSLocalizedString(@"The document \\U201C%@\\U201D contains images, but the selected file format does not support saving images.", @"alert title: The document contains images, but the selected file format does not support saving images."), docTitle];
			NSString *theInformativeString = NSLocalizedString(@"Choose \\U2018Save As...\\U2019 to select another format, or choose \\U2018Save Anyway\\U2019 to save without images and attachments.", @"alert text (shown upon attempt to save document with images to non-image capable format): Choose 'Save As...' to select another format, or choose 'Save Anyway' to save without images and attachments. (translator: the translation of Save Anyway needs to match the translation given to the key 'button: Save Anyway')");
			choice = NSRunAlertPanel(title, 
									 theInformativeString,
									 NSLocalizedString(@"Save As...", @"button: Save As..."),
									 NSLocalizedString(@"Save Anyway", @"button: Save Anyway"),
									 NSLocalizedString(@"Cancel", @"button: Cancel"));
			//	1: means save was cancelled so user can pick another file format
			if (choice==NSAlertDefaultReturn)
			{ 
				return NO;
			}
			//	-1: means user wanted to continue with save operation and lose graphics
			else if (choice==NSAlertAlternateReturn)
			{ 
				//	allow deletion of images even if isEditable is NO when saving to another format
				if (![theTextView isEditable]) { [theTextView setEditable:YES]; }
				int theLoc = [theTextView selectedRange].location;
				[theTextView selectAll:nil];
				[theTextView cut:nil];
				[theTextView setImportsGraphics:NO];
				[theTextView paste:nil];
				if (theLoc < [textStorage length])
				{ 
					[theTextView setSelectedRange:NSMakeRange(theLoc,0)];
					[theTextView scrollRangeToVisible:NSMakeRange(theLoc,0)];
				}
				//	restore isEditable
				if ([self readOnlyDoc]) { [theTextView setEditable:NO]; }				
			} 
			//	0: means user wants to not save and to dismiss the save panel
			else if (choice==NSAlertOtherReturn)
			{
				[sender cancel:nil]; 
				return NO;
			}
		}
	}
	
	//	if there are text attributes, but plain text format was chosen, offer user an option to choose another format so info is not lost
	//	if we find rich text + the absence of all of Bean's formats, this means .TXT (you provide extension) format (BUG FIX 17 May 2007 BH)
	if ( ([theTextView isRichText]==1 && [theExtension isEqualToString:@"TXT"]) 
		|| ([theTextView isRichText]==1
			&& ![theExtension isEqualToString:@"BEAN"] 
			&& ![theExtension isEqualToString:@"RTFD"]
			&& ![theExtension isEqualToString:@"WEBARCHIVE"]
			&& ![theExtension isEqualToString:@"RTF"] 
			&& ![theExtension isEqualToString:@"DOC"]
			&& ![theExtension isEqualToString:@"XML"]
			&& ![theExtension isEqualToString:@"ODT"]
			&& ![theExtension isEqualToString:@"DOCX"] ) )
	{
		int choice;
		//	altered alert dialog text to be less alarming (7 May 2007)
		NSString *title = NSLocalizedString(@"Save as plain text?", @"alert title: Save as plain text?");
		NSString *infoString = NSLocalizedString(@"Saving as plain text will cause text formatting, images and document properties to be discarded. Choose \\U2018Save As...\\U2019 to select another format, or choose \\U2018Save Anyway\\U2019 to save as plain text.", @"alert text: Saving as plain text will cause text formatting, images and document properties to be discarded. Choose 'Save As...' to select another format, or choose 'Save Anyway' to save as plain text. (translator: the translation of Save Anyway needs to match the translation given to the key 'button: Save Anyway')");
		choice = NSRunAlertPanel(title, 
								 infoString,
								 NSLocalizedString(@"Save As...", @"button: Save As..."), 	// ellipses
								 NSLocalizedString(@"Save Anyway", @"button: Save Anyway"), 
								 NSLocalizedString(@"Cancel", @"button: Cancel"));
		//	1 means save was cancelled so user can pick another file format
		if (choice==NSAlertDefaultReturn)
		{ 
			return NO;
		}
		// -1 means allow deletion of images even if isEditable is NO when saving to another format
		else if (choice==NSAlertAlternateReturn)
		{ 
			if (![[self firstTextView] isEditable])	{ [[self firstTextView] setEditable:YES]; }
			
			int theLoc = [theTextView selectedRange].location;
			[theTextView selectAll:nil];
			[theTextView cut:nil];
			[theTextView setImportsGraphics:NO];
			[theTextView setRichText:NO];
			[theTextView pasteAsPlainText:nil];
			[theTextView setAlignment:NSNaturalTextAlignment];
			if (theLoc < [textStorage length])
			{ 
				[theTextView setSelectedRange:NSMakeRange(theLoc,0)];
				[theTextView scrollRangeToVisible:NSMakeRange(theLoc,0)];
			}
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			//	retrieve the default font and size from user prefs; add to dictionary
			NSString *fontName = [defaults valueForKey:@"prefPlainTextFontName"];
			float fontSize = [[defaults valueForKey:@"prefPlainTextFontSize"] floatValue];
			//	create NSFont from name and size
			NSFont *aFont = [NSFont fontWithName:fontName size:fontSize];
			//	use system font on error (Lucida Grande, it's nice)
			if (aFont == nil) aFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
			//	apply font attribute to textview (for new documents)
			NSRange theRangeValue = NSMakeRange(0, [textStorage length]);
			
			//bracket changes
			[textStorage beginEditing];
			
			[textStorage addAttribute:NSFontAttributeName value:aFont range:theRangeValue];
			[textStorage addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:theRangeValue];
			[textStorage removeAttribute:NSBackgroundColorAttributeName range:theRangeValue];
			[textStorage removeAttribute:NSShadowAttributeName range:theRangeValue];
			//	also removes tables, lists, etc.
			[textStorage removeAttribute:NSParagraphStyleAttributeName range:theRangeValue]; 
			
			//bracket changes
			[textStorage endEditing];
			
			//if notes mode is active, turn it off for plain text
			if ([self alternateFontActive])
				[self setAlternateFontActive:NO];
			
			//	add 'plain text' font style to the typingAttributes
			NSDictionary *theAttributes = [theTextView typingAttributes];
			NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
			if (aFont) { [theTypingAttributes setObject:aFont forKey:NSFontAttributeName]; }
			[theTextView setTypingAttributes:theTypingAttributes];
			
			//	restore isEditable
			if ([self readOnlyDoc]) { [theTextView setEditable:NO]; }
			
			//make undoable, so we can't back into a rich text doc from a text file 5 SEP 08 JH
			[[self undoManager] removeAllActions];
		}
		//	0 means user want to not save and to dismiss the save panel
		else if (choice==NSAlertOtherReturn)
		{
			[sender cancel:nil];
			return NO;
		}
	}
	//	adjust textView to accomodate potential filetype
	if ([theExtension isEqualToString:@"RTFD"]
		|| [theExtension isEqualToString:@"BEAN"]
		|| [theExtension isEqualToString:@"WEBARCHIVE"])
	{
		//	rich text, with graphics
		[theTextView setRichText:YES];
		[theTextView  setImportsGraphics:YES];
	} 
	else if ( [theExtension isEqualToString:@"DOC"]
			 || [theExtension isEqualToString:@"XML"]
			 || [theExtension isEqualToString:@"RTF"]
			 || [theExtension isEqualToString:@"ODT"]
			 || [theExtension isEqualToString:@"DOCX"] )
	{
		//	rich text, no graphics
		[[self firstTextView]  setRichText:YES];
		[[self firstTextView]  setImportsGraphics:NO];
	}
	else if ([theExtension isEqualToString:@"TXT"]
			 || [theExtension isEqualToString:@"HTML"])
	{
		//	plain text, no graphics
		[theTextView  setRichText:NO];
		[theTextView  setImportsGraphics:NO];
	}
	// 26 MAY 08 JH refresh pageView's header info
	id docView = [theScrollView documentView];
	if ([docView isKindOfClass:[PageView class]])
	{
		[docView setForceRedraw:YES];
		[docView setNeedsDisplay:YES];
	}
	return YES;
}

- (void)lossyDocAlertDidEnd:(NSAlert *)alert 
				 returnCode:(int)returnCode
				contextInfo:(void *)callBackInfo;
{
#define lossyOverwrite	NSAlertDefaultReturn
#define lossySaveAs		NSAlertAlternateReturn
#define lossyCancel		NSAlertOtherReturn

	//	each case has two possibilities, depending on whether we need to send a message to the canClose... delegate (ie, if callBackInfo exists) or not
	SelectorContextInfo *selectorContextInfo = callBackInfo;
	switch (returnCode)
	{
		case lossyOverwrite:
		{
			//	needs callback to canCloseWithDelegate, which passed callBackInfo
			if (callBackInfo)
			{
				//	success on save = can close; failure = cannot close
				[self saveDocumentWithDelegate:selectorContextInfo->delegate
							didSaveSelector:selectorContextInfo->shouldCloseSelector
							contextInfo:selectorContextInfo->contextInfo];
				//	for some reason, if save fails here [self isDocumentEdited] returns no and cmd-Q does not ask to save changes
				//	so we force app to ask whether changes should be saved
				if (selectorContextInfo->shouldCloseSelector)
				{
					[self updateChangeCount:NSChangeDone];
				}
			}
			else
			{
				[self saveDocument:nil];
			}
			break;
		}
		case lossyCancel:
		{
			//	=go back to editing, so send NO to canCloseWithDelegate callback, which passed callBackInfo
			if (callBackInfo)
			{ 
				//	send 'NO' callback to selector (= can close without save)
				void (*meth)(id, SEL, JHDocument *, BOOL, void*);
				meth = (void (*)(id, SEL, JHDocument *, BOOL, void*))[selectorContextInfo->delegate methodForSelector:selectorContextInfo->shouldCloseSelector];
				if (meth)
				{
					meth(selectorContextInfo->delegate, selectorContextInfo->shouldCloseSelector, self, NO, selectorContextInfo->contextInfo);
				}
			}
			//	=cancel with no callback needed (since check as not called from canCloseWithDelegate)
			else
			{
				//	nothing to do but return to editing
			}
			break;
		}	
		case lossySaveAs:
		{
			//	save old filename, use it to remind user of original name (via prepareSavePanel)
			if ([self fileName])
			{
				[self setOriginalFileName:[self fileName]];
			}
			[self setFileName:nil];
			[self setLossy:NO];
			[self setFileModDate:nil];
			//	sends callback to canCloseWithDelegate (success on save = can close; failure = cannot close)
			if (callBackInfo)
			{
				[self saveDocumentWithDelegate:selectorContextInfo->delegate
							didSaveSelector:selectorContextInfo->shouldCloseSelector 
							contextInfo:selectorContextInfo->contextInfo];
			}
			else
			{
				[self runModalSavePanelForSaveOperation:NSSaveAsOperation delegate:self didSaveSelector:@selector(document:didSaveAfterAlert:contextInfo:) contextInfo:nil];
			}
			[self setOriginalFileName:nil];
			break;
		}
	}
	//	free memory
	if (selectorContextInfo)
	{	
		free(selectorContextInfo);
	}
}

- (void)lockedDocAlertDidEnd:(NSAlert *)alert 
				 returnCode:(int)returnCode
				contextInfo:(void *)callBackInfo;
{

#define lockedSaveAs		NSAlertDefaultReturn
#define lockedUnlockAndSave	NSAlertAlternateReturn
#define lockedCancel		NSAlertOtherReturn

	//each case has two possibilities, depending on whether we need to send a message to the canClose... delegate (ie, if callBackInfo exists) or not
	SelectorContextInfo *selectorContextInfo = callBackInfo;
	switch (returnCode)
	{
		case lockedCancel:
		{
			//	=go back to editing, so send NO to canCloseWithDelegate callback, which passed callBackInfo
			if (callBackInfo)
			{ 
				//	send 'NO' callback to selector (= can close without save)
				void (*meth)(id, SEL, JHDocument *, BOOL, void*);
				meth = (void (*)(id, SEL, JHDocument *, BOOL, void*))[selectorContextInfo->delegate methodForSelector:selectorContextInfo->shouldCloseSelector];
				if (meth)
				{
					meth(selectorContextInfo->delegate, selectorContextInfo->shouldCloseSelector, self, NO, selectorContextInfo->contextInfo);
				}
			}
			break;
		}	
		case lockedSaveAs:
		{
			//	save old filename, use it to remind user of original name (via prepareSavePanel)
			if ([self fileName])
			{
				[self setOriginalFileName:[self fileName]];
			}
			[self setFileName:nil];
			[self setLossy:NO];
			[self setFileModDate:nil];
			//	sends callback to canCloseWithDelegate (success on save = can close; failure = cannot close)
			if (callBackInfo)
			{
				//	send 'NO' callback to selector (= can close without save)
				void (*meth)(id, SEL, JHDocument *, BOOL, void*);
				meth = (void (*)(id, SEL, JHDocument *, BOOL, void*))[selectorContextInfo->delegate methodForSelector:selectorContextInfo->shouldCloseSelector];
				if (meth)
				{
					meth(selectorContextInfo->delegate, selectorContextInfo->shouldCloseSelector, self, NO, selectorContextInfo->contextInfo);
				}
				[self runModalSavePanelForSaveOperation:NSSaveAsOperation delegate:self didSaveSelector:@selector(document:didSaveAfterAlert:contextInfo:) contextInfo:nil];
			}
			else
			{
				[self runModalSavePanelForSaveOperation:NSSaveAsOperation delegate:self didSaveSelector:@selector(document:didSaveAfterAlert:contextInfo:) contextInfo:nil];
			}
			[self setOriginalFileName:nil];
			break;
		}
		case lockedUnlockAndSave:
		{
			//	unlock file
			NSDictionary *unlockFileDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:NO] forKey:NSFileImmutable];
			if ([self fileName]) [[NSFileManager defaultManager] changeFileAttributes:unlockFileDict atPath:[self fileName]];
			[self setLossy:NO];
			//	sends callback to canCloseWithDelegate (success on save = can close; failure = cannot close)
			if (callBackInfo)
			{
				[self saveDocumentWithDelegate:selectorContextInfo->delegate
							didSaveSelector:selectorContextInfo->shouldCloseSelector 
							contextInfo:selectorContextInfo->contextInfo];
			}
			else
			{
				[self saveDocument:nil];
			}
		}
	}
	//	free memory
	if (selectorContextInfo)
		free(selectorContextInfo);
}

#pragma mark -
#pragma mark --- Present Save/Write Errors ---

// ******************* Present Save/Write Errors ********************

- (NSError *)willPresentError:(NSError *)error
{
	if ([[error domain] isEqualToString:NSCocoaErrorDomain])
	{
		NSString *errorString = nil;
		int errorCode = [error code];
		
		NSString *docName = [NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"firstLevelOpenQuote", nil), [self displayName], NSLocalizedString(@"firstLevelCloseQuote", nil)]; 
		
		NSFileManager *fm = [NSFileManager defaultManager];
		//	range of cocoa errors possible when writing files
		if ( (errorCode >= 512 && errorCode <= 640 ) || errorCode==66062)
		{
			if (errorCode==NSFileWriteInvalidFileNameError)
			{
				errorString = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved because the filename is not valid.", @"alert title: The document (document name inserted at runtime) could not be saved because the filename is not valid."), docName];
			}
			else if (errorCode==NSFileWriteOutOfSpaceError)
			{
				errorString = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved due to lack of space.", @"alert title: The document (document name inserted at runtime) could not be saved due to lack of space."), docName];
			}
			else if (errorCode==NSFileWriteNoPermissionError)
			{
				errorString = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved due to lack of permission to write the file.", @"alert title: The document (document name inserted at runtime) could not be saved due to lack of permission to write the file."), docName];
			}
			//	write error, so try to determine exact error
			else if (errorCode==NSFileWriteUnknownError)
			{
				//	folder not writable
				if 	(![fm isWritableFileAtPath:[[self fileName] stringByDeletingLastPathComponent]])
				{
					NSDictionary *theFolderAttrs = [fm fileAttributesAtPath:[[self fileName] stringByDeletingLastPathComponent] traverseLink:YES];
					//	error: containing folder is locked
					if ([[theFolderAttrs objectForKey:NSFileImmutable] boolValue] == YES) 
					{
						errorString = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved because the containing folder is locked.", @"alert title: The document (document name inserted at runtime) could not be saved because the containing folder is locked."), docName];
					}
					//	some other problem writing to folder
					else 
					{
						errorString = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved because of a problem writing to the folder.", @"alert title: The document (document name inserted at runtime) could not be saved because of a problem writing to the folder."), docName];
					}
				}
				else if (![fm isWritableFileAtPath:[self fileName]])
				{
					NSDictionary *theFileAttrs = [fm fileAttributesAtPath:[self fileName] traverseLink:YES];
					//	error: file is locked
					if ([[theFileAttrs objectForKey:NSFileImmutable] boolValue] == YES)
					{	
						errorString = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved because the file is locked.", @"alert title: The document (document name inserted at runtime) could not be saved because the file is locked."), docName];						
					}
					//	unknown error
					else
					{
						errorString = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved due to an unknown error.", @"alert title: The document (document name inserted at runtime) could not be saved due to an unknown error."), docName];
					}
				}
			//	determine kind of error (we know it's not a write error)
			}
			// error 66062 (not a compatible file format)
			else if (errorCode==NSTextWriteInapplicableDocumentTypeError)
			{
				int theType = [self failedDocType];
				switch (theType)
				{
					case 1:
					{
						errorString = [NSString stringWithFormat:NSLocalizedString(@"alert title: The document could not be saved because Bean requires OS X 10.5 \\U2018Leopard\\U2019 to support the file format %@. Please select another format.", @"alert title: The document could not be saved because Bean requires OS X 10.5 \\U2018Leopard\\U2019 to support the file format %@. Please select another format."), OpenDoc];
						break;
					}
					case 2:
					{
						errorString = [NSString stringWithFormat:NSLocalizedString(@"alert title: The document could not be saved because Bean requires OS X 10.5 \\U2018Leopard\\U2019 to support the file format %@. Please select another format.", @"alert title: The document could not be saved because Bean requires OS X 10.5 \\U2018Leopard\\U2019 to support the file format %@. Please select another format."), DocXDoc];				
						break;
					}
					default:
					{
						errorString = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved in the chosen format.", @"alert title: The document (document name inserted at runtime) could not be saved in the chosen format."),docName];
						break;
					}
				}
				[self setFailedDocType:0];
			}
			//	unknown error
			else
			{
				errorString = [NSString stringWithFormat:NSLocalizedString(@"The document %@ could not be saved due to an unknown error.", @"alert title: The document (document name inserted at runtime) could not be saved due to an unknown error."), docName];
			}
			//	std dialog says "File Could not Be Saved" [OK]; we add more detail and a Save As option
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:4];
			[userInfo setObject:errorString forKey:NSLocalizedDescriptionKey];
			[userInfo setObject: NSLocalizedString(@"Try saving as another document to keep your changes.", @"alert text: Try saving as another document to keep changes. (alert shown upon failure to save document)")
						 forKey:NSLocalizedRecoverySuggestionErrorKey];
			[userInfo setObject:self forKey:NSRecoveryAttempterErrorKey];
			[userInfo setObject:[NSArray arrayWithObjects: NSLocalizedString(@"Save As...", @"button: Save As..."), 
				NSLocalizedString(@"Cancel", @"button: Cancel"), nil] forKey:NSLocalizedRecoveryOptionsErrorKey];
			NSError *newError = nil;
			newError = [[[NSError alloc] initWithDomain:[error domain] code:[error code] userInfo:userInfo] autorelease];
			return newError;
		}
	}
	return [super willPresentError:error];
}

//must precede methods that call it
- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo
{
	/*
	//automatic?
	if (!didRecover)
		[self updateChangeCount:NSChangeDone];
	*/
}

- (void)attemptRecoveryFromError:(NSError *)error 
					 optionIndex:(unsigned int)recoveryOptionIndex 
						delegate:(id)inDelegate 
			  didRecoverSelector:(SEL)inDidRecoverSelector
					 contextInfo:(void *)inContextInfo
{
	//	user picked 'Save As...' recovery
	if (recoveryOptionIndex == 0)
	{
		//	save old filename, use it to remind user of original name (via prepareSavePanel)
		[self setOriginalFileName:[[self fileName] lastPathComponent]];
		int newFileNumber = 0;
		NSString *thePathMinusExtension = [[self fileName] stringByDeletingPathExtension];
		NSString *thePathExtension = [[self fileName] pathExtension];
		//	for recovery from a save file error, attempt to save open document to a new filename using Save As...
		//	what if there is no extension?
		NSString *theNewPath = [NSString stringWithFormat:@"%@%@.%@", thePathMinusExtension, 
			NSLocalizedString(@" copy", @"text to add into filename after initial name and before extension when user encounters an error saving the file and chooses to attempt to save as a renamed file, which is a ' copy'. (Note the space before the word ' copy'."), thePathExtension];
		while ([[NSFileManager defaultManager] fileExistsAtPath:theNewPath] && newFileNumber < 1000)
		{
			newFileNumber = newFileNumber + 1;
			theNewPath = [NSString stringWithFormat:@"%@%@%i%@%@", 
				thePathMinusExtension, @" ", newFileNumber, @".", thePathExtension];
		}
		[self setFileName:theNewPath];
		[self runModalSavePanelForSaveOperation:NSSaveAsOperation delegate:self didSaveSelector:@selector(document:didSaveAfterAlert:contextInfo:) contextInfo:nil];
	}
	else
		[self didPresentErrorWithRecovery:NO contextInfo:nil];
}

- (void)document:(NSDocument *)doc didSaveAfterAlert:(BOOL)didSave contextInfo:(void  *)contextInfo
{
	[self didPresentErrorWithRecovery:didSave contextInfo:nil];
}

#pragma mark -
#pragma mark --- Accessors ---

// ******************* Accessors ********************

-(BOOL)textLengthIsZero
{
	return textLengthIsZero;
}

-(void)setTextLengthIsZero:(BOOL)flag
{
	textLengthIsZero = flag;
}

-(int)failedDocType
{
	return failedDocType;
}

//	remembers type of file that failed to open so customized error messages can use this information in willPresentError
//	0 = none; 1 = OpenDoc; 2 = DocXDoc
-(void)setFailedDocType:(int)error;
{
	failedDocType = error;
}

@end

