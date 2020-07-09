/*
	ImageManager.m
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

#import "ImageManager.h"
#import "JHDocument.h"

@implementation ImageManager

#pragma mark -
#pragma mark ---- init, Dealloc ----

- (void)dealloc
{
	if (_sender) [_sender release];
	if (document) [document release];
	[super dealloc];
}

#pragma mark -
#pragma mark ---- Insert Image ----

// ******************* Insert Image ********************

-(IBAction)insertImageAction:(id)sender
{
	//sender is document of interest
	id doc = sender;
	[self setDocument:doc];
	id docWindow = [doc docWindow];
	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:YES];
	//image file types we can insert
	NSArray *fileTypes = [ NSArray arrayWithObjects:
						  @"eps", @"ps", @"tiff", 
						  @"tif", @"jpg", @"jpeg", @"gif", @"png", 
						  @"pict", @"pic", @"pct", @"bmp", @"ico", 
						  @"icns", @"psd", @"jp2", nil ];
	//this eventually calls openPanelDidEnd
	[openPanel beginSheetForDirectory:nil file:nil types:fileTypes modalForWindow:docWindow 
						modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

//	inserts images into RTFD and BEAN documents by placing a copy of the image file into the document's package (ie folder)
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	id doc = [self document];
	id pInfo = [doc printInfo];
	//open panel is os x singleton; don't release
	[NSApp endSheet:sheet];
	[sheet orderOut:nil];
	if (returnCode==NSOKButton)
	{
		//	go through chosen filenames
		NSEnumerator *enumerator = [[sheet filenames] objectEnumerator];
		NSString  *fName;
		NSFileWrapper *fWrap = nil;
		while (fName = [enumerator nextObject])
		{
			//	get the size of the image
			NSImage *img = [[[NSImage alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fName]]autorelease];
			if (img)
			{
				//	get firstLineIndent from user Prefs
				NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
				float firstLineIndent = 0;
				firstLineIndent = [defaults boolForKey:@"prefIsMetric"]
						? [[defaults valueForKey:@"prefDefaultFirstLineIndent"] floatValue] * 28.35 
						: [[defaults valueForKey:@"prefDefaultFirstLineIndent"] floatValue] * 72.0;
				//	if image TOO BIG to display correctly, resize to fit in layout made
				//	TODO: problem still remains of image with too large line height that never displays in layout view
				if ([img size].width > ([pInfo paperSize].width - [pInfo leftMargin]- [pInfo rightMargin] - firstLineIndent))
				{
					//	size constraints
					float maxWidth = floor([pInfo paperSize].width - [pInfo leftMargin]- [pInfo rightMargin] - firstLineIndent - 5);
					//	avoid returning zero for height 16 DEC 07 JH
					int theDefaultLineSpacing = [defaults integerForKey:@"prefDefaultLineSpacing"] ? [defaults integerForKey:@"prefDefaultLineSpacing"] : 1.0; 
					//	adjust for gap due to line spacing 21 Aug 2007 JH
					float maxHeight = floor([pInfo paperSize].height - [pInfo topMargin] - [pInfo bottomMargin] - 5) * 
					theDefaultLineSpacing;
					// determine scale factor needed to fit within size constraints.
					float widthScale = (float) maxWidth / (float) [img size].width;
					float heightScale = (float) maxHeight / (float) [img size].height;
					float scaleFactor = 1.0;
					scaleFactor = MIN(widthScale, heightScale);
					//	apply scaleFactor to width and height
					float newWidth = floor([img size].width * scaleFactor);
					float newHeight = floor([img size].height * scaleFactor);
					//	return file wrap containing image with new size (but without loss of resolution)
					fWrap = [self fileWrapperForImage:img withMaxWidth:newWidth withMaxHeight:newHeight];
					NSString *imgName = [fName lastPathComponent];
					[fWrap setFilename: imgName];
					[fWrap setPreferredFilename: imgName];
				}
				//	image size is OK so just make fileWrapper
				else
				{
					//	make a fileWrapper for the image
					fWrap = [[[NSFileWrapper alloc] initWithPath: fName] autorelease];
					//	name fileWrap with its original filename (if available)
					NSString *imgName = [fName lastPathComponent];
					[fWrap setFilename: imgName];
					[fWrap setPreferredFilename: imgName];
				}
							
				if (fWrap)
				{
					//	make a text attachment and attach the fileWrapper
					NSTextAttachment *ta = [[NSTextAttachment alloc] initWithFileWrapper: fWrap];
					
					//	NOTE: Attachments inserted in nil text, or at the beginning of paragraphs, have nil attributes so we fix this in KBWordCountingTextStorage by overriding replaceCharactersInRange and adding the typingAttributes form the textView to the textAttachment; this also works for pasted graphics and drap'n'dropped graphics
					
					//	make an attributed string with the attachment attached
					NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:ta];
					[ta release];					
					NSRange selRange = [[doc firstTextView] selectedRange];
					//	NOTE: we could probably just use insertText here, but would not get a special undo action
					//	for undo
					if ([[doc firstTextView] shouldChangeTextInRange:selRange replacementString:[attachmentString string]])
					{
						//	insert graphic
						//	note: replaceCharacters... has special code that prevents the attachments from nuking the paragraph attributes and from nuking the typingAttributes, which is why we use it instead of insertAttributedString: atIndex:
						[[doc textStorage] replaceCharactersInRange:NSMakeRange(selRange.location, 0) withAttributedString:attachmentString];
						//end undo
						[[doc firstTextView] didChangeText];
						//name undo for menu
						[[doc undoManager] setActionName:NSLocalizedString(@"Insert Graphic", @"undo action: Insert Graphic")];
					}
				}
				else
				{
					//	no file wrapper for image
					NSBeep();
				}
			}
		}
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
}

#pragma mark -
#pragma mark ---- Resize Image ----

// ******************* Resize Image ********************

//	prepares, then shows image resizing sheet
-(IBAction)showSheet:(id)sender
{

	//NOTE that here, 'sender' is control calling action, not doc, which is set through an accessor before sheet is called
	[self setDocument: sender];
	id doc = sender;
	id docWindow = [doc docWindow];
	id ts = [doc textStorage];
	id tv = [doc firstTextView];
	id pInfo = [doc printInfo];
	
	//imageSheet's behavior set in nib = [x] release when closed
	if(imageSheet== nil) { [NSBundle loadNibNamed:@"ResizeImages" owner:self]; }
	if(imageSheet== nil)
	{ 
		NSLog(@"Could not load ResizeImage.nib.");
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}
	
	//load localization strings
	[resizeImageButton setTitle:NSLocalizedString(@"button: Resize Image", @"")];
	[cancelButton setTitle:NSLocalizedString(@"button: Cancel", @"")];
		
	unsigned scanLoc = 0;
	unsigned int locAttachment = 0;
	//	if menu action (rather than user clicked on image cell), we find the closest selected attachment if there is one 
	//	and make it alone the selected range
	if ([[self sender] tag]==4)
	{
		NSString *stringToScan = [[ts string] substringWithRange:[tv selectedRange]];
		//	system defined NSAttachmentCharacter = 0xfffc
		NSScanner *seekAttachment = [NSScanner scannerWithString:stringToScan];
		[seekAttachment scanUpToString:[NSString stringWithFormat:@"%C", NSAttachmentCharacter] intoString:NULL];
		scanLoc = [seekAttachment scanLocation];
		unsigned stringLength = [stringToScan length];
		if (scanLoc==stringLength)
		{
			NSBeep();
			[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
			return;
		}
	}
	//get image loc and save it for other methods
	locAttachment = [tv selectedRange].location + scanLoc;
	[self setImageLocation:locAttachment];
	[tv setSelectedRange:NSMakeRange(locAttachment, 0)];
	// this JHDocument accessor tells attachmentCell to keep drawing selection outline
	// even tho selection was dismissed to avoid Leopard's visual boingy effect
	[doc setResizingImage:YES];
	// should not change read only doc
	if (![tv shouldChangeTextInRange:NSMakeRange([self imageLocation], 1) replacementString:nil])
	{
		NSBeep();
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}		
	//	get attachment at insertion point
	NSTextAttachment *ta = [ ts attribute:NSAttachmentAttributeName 
				atIndex:[self imageLocation]
				effectiveRange:NULL ];
	//	get cell image
	NSImage *image = nil;
	image = [self cellImageForAttachment:ta];
	//	adjust slider maxValue relative to print info page width and image width
	float maxValue = ([pInfo paperSize].width - [pInfo leftMargin]- [pInfo rightMargin]) / [image size].width;
	
	//	if width paper / width image < 1, (i.e., image is large in size), set maxValue = 1
	if (maxValue < 1.0) { maxValue = 1.0; }
	[imageSlider setMaxValue:maxValue];
	//	original image value = 1
	[imageSlider setObjectValue:[NSNumber numberWithFloat:1.0]];
	[imageSliderTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Image Size: %.1f%%", @"Image Size: (number as percent is inserted here at runtime)"), [imageSlider floatValue] * 100]];
	//	show the image resizer sheet
	[NSApp beginSheet:imageSheet modalForWindow:docWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];
	[imageSheet orderFront:nil];
}

-(IBAction)resizeImageSliderAction:(id)sender
{
	//sender is control calling action, not doc
	id doc = [self document];
	id ts = [doc textStorage];
	id tv = [doc firstTextView];

	//	get attachment at insertion point
	NSTextAttachment *ta = [ts attribute:NSAttachmentAttributeName 
				atIndex:[self imageLocation]
				effectiveRange:NULL ];
	//	get image from attachmentCell
	NSImage *image = nil;
	image = [self cellImageForAttachment:ta];
	//	if [self imageSize] is not NSZeroSize, it's already been set to remember the size if the user cancels the resize, so leave it
	if (image && NSEqualSizes([self imageSize], NSZeroSize))
	{
		//	remember the size for multipling by the slider value
		[self setImageSize:[image size]];
	}

	//check: is lockFocus needed in Leopard or Tiger? it made resize image very blurry under SL
	//[image lockFocus];
	//	resize the cell image to show user what size saved picture will be (actual image in fileWrapper is not resized until the sheet is closed)
	[image setScalesWhenResized:YES];
	[image setSize: NSMakeSize(floor([self imageSize].width * [imageSlider floatValue]),floor([self imageSize].height * [imageSlider floatValue]))];
	
	[tv centerSelectionInVisibleArea:self];
	//remove screen artifacts
	[tv setNeedsDisplay:YES];
	//[image unlockFocus];
	[imageSliderTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Image Size: %.1f%%", @"Image Size: (number as percent is inserted here at runtime)"), [imageSlider floatValue] * 100]];
	//causes view to update
	[[tv layoutManager] textContainerChangedGeometry:[tv textContainer]];
	
}

// action for when resizing control sheet is dismissed (image was resized or action was canceled)
-(IBAction)resizeImageSheetCloseAction:(id)sender
{
	//sender is control calling action, not doc
	id doc = [self document];
	id ts = [doc textStorage];
	id tv = [doc firstTextView];
	
	//	if we pass an index of 0 to attribute:atIndex:effectiveRange: it complains; setting the selectedRange works tho
	[tv setSelectedRange:NSMakeRange([self imageLocation], 1)];
	[doc setResizingImage:NO]; // 24 APR 08 JH
	//	if cancel/escape chosen, return image cell to original size and dismiss panel 
	if (![sender tag])
	{
		//	get attachment at insertion point
		NSTextAttachment *ta = [ ts attribute:NSAttachmentAttributeName 
											   atIndex:[tv selectedRange].location
										effectiveRange:NULL ];
		//	get image from attachmentCell
		NSImage *image = nil;
		image = [self cellImageForAttachment:ta];
		//	return imageCell size to it's original value; attached file was not yet changed
		if (image) { [image setSize:[self imageSize]]; }
		[[tv layoutManager] textContainerChangedGeometry:[tv textContainer]];
		//	zero it out
		[self setImageSize:NSZeroSize];
		//	dismiss sheet
		[NSApp endSheet:imageSheet];
		[imageSheet orderOut:sender];
		return;
	}
	//	get image from attachment to be replaced
	NSTextAttachment *ta = [ts attribute:NSAttachmentAttributeName
				atIndex:[tv selectedRange].location
				effectiveRange:NULL];				
	//	get fileWrapper contents
	NSData *theData = [[ta fileWrapper] regularFileContents];
	//	and make an NSImage from them
	NSImage *oldImage = nil;
	if (theData)
	{
		oldImage = [[[NSImage alloc] initWithData:theData]autorelease];
	}
	else 
	{
		NSBeep();
		return;
	}
	if (oldImage) 
	{
		NSFileWrapper *fw = nil;
		float maxHeight = floor([oldImage size].height * [imageSlider floatValue]);
		float maxWidth = floor([oldImage size].width * [imageSlider floatValue]);
		fw = [self fileWrapperForImage:oldImage  withMaxWidth:maxWidth withMaxHeight:maxHeight];
		if (!fw) 
		{
			NSBeep();
			return;
		}
		
		//	make an NSAttributedString holding the new attachment
		NSTextAttachment *newTa = [[NSTextAttachment alloc] initWithFileWrapper: fw];
		NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:newTa];
		
		//	insert it
		[tv shouldChangeTextInRange:NSMakeRange([self imageLocation], 1) replacementString:[attachmentString string]];
		//	if we don't remind the old attachment of its size, the new attachment undo's to the old attachment, but the old attachment has the size of the new one -- why?
		[[self cellImageForAttachment:ta] setSize:[self imageSize]];
		//	replace old image attachment with new (ie, resized) image attachment
		[ts replaceCharactersInRange:NSMakeRange([self imageLocation], 1) withAttributedString:attachmentString];
		[[tv layoutManager] textContainerChangedGeometry:[tv textContainer]];
		//	end undo
		[tv didChangeText];
		[[doc undoManager] setActionName:NSLocalizedString(@"Resize Picture", @"undo action: Resize Picture")];
		//	clean up artifacts
		[[doc theScrollView] display];
		[tv setNeedsDisplay:YES];
		//	reset the imageSize accessor
		[self setImageSize:NSZeroSize];
		//	release objects
		[newTa release];
	}
	//	dismiss sheet
	[NSApp endSheet:imageSheet];
	[imageSheet orderOut:sender];
	//fixed leak 15 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[imageSheet close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
}

#pragma mark -
#pragma mark ---- Image Helpers ----

// ******************* Image Helpers ********************

//	return a fileWrapper (or nil upon failure) for an image of adjusted size from the passed-in image
- (NSFileWrapper *)fileWrapperForImage:(NSImage *)anImage withMaxWidth:(float)newWidth withMaxHeight:(float)newHeight
{
	//	get the rep and resize it.
	//	msg on cocoabuilder.com by Todd Heberlein on Tue Dec 09 2003 helped me with this
	NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData: [anImage TIFFRepresentation]];
	[rep TIFFRepresentation];  // flush
	[rep setSize:NSMakeSize(newWidth, newHeight)];  // reset the size
	NSData *data = nil; // = [rep representationUsingType:NSTIFFFileType properties:nil]; //dead code
	
	//	get jpeg data from imageRep
	if (rep)
	{
		NSDictionary *compression = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.8] forKey:NSImageCompressionFactor];
		data = [rep representationUsingType:NSJPEGFileType properties:compression];
		//	test code
		//	note: not used; jpeg seems sufficient
		//	NSDictionary *compression = [NSDictionary dictionaryWithObject:@"NSTIFFCompressionLZW" forKey:NSImageCompressionMethod];
		//	data = [rep representationUsingType:NSTIFFFileType properties:compression];
	}
	else
	{
		//	failed
		NSBeep();
		return nil;
	}
	//	create new fileWrapper to hold new image
	NSFileWrapper *fw = [[[NSFileWrapper alloc] initRegularFileWithContents: data] autorelease];
	//	come up with a name for the file
	NSString *imgPathName = [anImage name];
	if( !imgPathName )
		imgPathName = @"image";
	//	a fileWrapper must have a path!
	imgPathName = [imgPathName stringByAppendingPathExtension: @"jpg"];
	[fw setFilename: imgPathName];
	[fw setPreferredFilename: imgPathName];
	return fw;
}

//	9 July 2007 BH recast theImageCell as id to get rid of 'Not part of protocol' compiler warning for [attachmentCell image]
- (NSImage *)cellImageForAttachment:(NSTextAttachment *)attachment
{
	id theImageCell = nil;
	theImageCell = [attachment attachmentCell] ;
	BOOL success = [[theImageCell image] isValid];
	if (success) return [theImageCell image];
	else return nil;
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

-(id)sender
{
	return _sender;
}

-(void)setSender:(id)aSender
{
	[aSender retain];
	[_sender release];
	_sender = aSender;
}

-(unsigned int)imageLocation { return imageLocation; }
-(void)setImageLocation:(unsigned int)theLoc { imageLocation = theLoc; }

//	remembers original size value for image
- (NSSize)imageSize { return imageSize; }
- (void)setImageSize:(NSSize)size { imageSize = size; }



@end