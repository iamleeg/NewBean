/*
	NSTextAttachmentCell(Extension).m
	Bean

	Started 11 JUL 2006 by James Hoover

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

#import "NSTextAttachmentCell(Extension).h" 
#import "JHDocument_Text.h" // for [document resizingImage]

@implementation NSTextAttachmentCell (Extension)

//	draw a highlighted border around the image cell to indicate selection or image resizing in progress
- (void)drawWithFrame:(NSRect)cellFrame 
			   inView:(NSView *)controlView 
	   characterIndex:(unsigned)charIndex
		layoutManager:(NSLayoutManager *)layoutManager
{

	[self drawWithFrame: cellFrame 
				 inView: controlView
		 characterIndex: charIndex];
	
	//	BUGFIX: 2008-04-24 -[NSCFArray objectAtIndex:]: index (0) beyond bounds (0) upon Quit app with doc with image
	if ([[NSApp orderedDocuments] count]==0) return;
	
	NSRange theRange = [[layoutManager firstTextView] selectedRange];
	id document = [[NSApp orderedDocuments] objectAtIndex:0];
	//	here we draw a highlighted border around the image cell to indicate selection or image resizing in progress
	if ((charIndex >= theRange.location && charIndex < theRange.location + theRange.length && theRange.length > 0)
				|| ([document resizingImage] && charIndex == theRange.location))
	{
		NSRect frame = NSZeroRect;
		frame.size = cellFrame.size;
		frame.origin = cellFrame.origin;
		// get dictionary of selectedTextAttributes to find selection color
		NSDictionary *selTextAttr = nil;
		NSColor *theColor = nil;
		if (document)
			selTextAttr = [[document firstTextView] selectedTextAttributes];
		if (selTextAttr)
			theColor = [selTextAttr objectForKey:NSBackgroundColorAttributeName];
		if (theColor)
		{
			[theColor set];
			frame = NSInsetRect(frame, -1.0, -1.0);
			NSFrameRectWithWidth(frame, 3);
		}
	}
}

/*
//code (not used) that intends to shrink image cell when large size + line height = not visible in container
//if we divide attachment image cell frame height by containing paragraph's line height (example: triple-spaced text = / 3)
//	it allows line fragment to be seem within text container (rather than spilling out), but it adds a lot of wasted space to layout;
//	a better solution is to setMaximumLineHeight to image cell height / proposedLineFrag
//	or use documentation to tell user to set Force Line Height - At Most: using Inspector
- (NSRect)cellFrameForTextContainerSwizzle:(NSTextContainer *)textContainer proposedLineFragment:(NSRect)lineFrag glyphPosition:(NSPoint)position characterIndex:(NSUInteger)charIndex
{
	
	//call original method code
	NSRect aRect = [self cellFrameForTextContainerSwizzle:textContainer proposedLineFragment:lineFrag glyphPosition:position characterIndex:charIndex
	];
	
	NSTextStorage *ts = [[textContainer layoutManager] textStorage];
	float lineHeight = [[ts attribute:NSParagraphStyleAttributeName atIndex:charIndex effectiveRange:NULL] lineHeightMultiple];
	
	//aRect.origin = [self cellBaselineOffset];
	//aRect.size = [self cellSize];

	if (lineHeight > 1)
	{
		aRect.size.width = (aRect.size.width / (lineHeight));
		aRect.size.height = (aRect.size.height / (lineHeight));	
	}
	return aRect;
}
*/


@end