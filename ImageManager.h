/*
  ImageManager.h
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

//inserts images into documents as attachments (adjusting for size if necessary)
@interface ImageManager : NSObject
{
	//tracks document for previews and encoding change
	JHDocument *document;
	//	----- Image Resizer -----
	IBOutlet NSPanel *imageSheet;
	IBOutlet NSSlider *imageSlider;
	IBOutlet NSTextField *imageSliderTextField;
	//localization
	IBOutlet NSButton *resizeImageButton;
	IBOutlet NSButton *cancelButton;
	//	----- vars -----
	unsigned int imageLocation;
	NSSize imageSize;
	id _sender;
}

//publicize
-(IBAction)insertImageAction:(id)sender;
-(IBAction)showSheet:(id)sender; //resize image sheet
-(IBAction)resizeImageSliderAction:(id)sender;
-(IBAction)resizeImageSheetCloseAction:(id)sender;

//forward declare
- (NSFileWrapper *)fileWrapperForImage:(NSImage *)anImage withMaxWidth:(float)newWidth withMaxHeight:(float)newHeight;
- (NSImage *)cellImageForAttachment:(NSTextAttachment *)attachment;

//accessors
-(JHDocument *)document;
-(void)setDocument:(JHDocument *)aDocument;
-(id)sender;
-(void)setSender:(id)aSender;
-(void)setImageLocation:(unsigned int)theLoc;
-(unsigned int)imageLocation;
-(NSSize)imageSize;
-(void)setImageSize:(NSSize)size;

@end