/*
	NSTextTable(Extension).m
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

#import "NSTextTable(Extension).h" 
#import "JHLayoutManager.h"

@implementation NSTextTable (Extension)

//	note: method swizzled so we can call original implementation, then our own code

//	when showing invisible characters,  also draw a highlighted border around text blocks in tet tables when border is 'invisible'
//this reveals table to users who may not be aware of them (for instance, in text copied from webpages)
- (void)drawBackgroundForBlockSwizzle:(NSTextTableBlock *)block withFrame:(NSRect)frameRect inView:(NSView *)controlView characterRange:(NSRange)charRange layoutManager:(NSLayoutManager *)layoutManager
{
	//call original implementation of method
	[self drawBackgroundForBlockSwizzle:block withFrame:frameRect inView:controlView characterRange:charRange layoutManager:layoutManager];
	//	if showInvisibleCharacters and border = 0, highlight frameRect of table cell
	if ([(JHLayoutManager *)layoutManager showInvisibleCharacters]
				&& [block widthForLayer:NSTextBlockBorder edge:NSMinXEdge] == 0)
	{
		[[(JHLayoutManager *)layoutManager invisiblesColor] set];
		frameRect = NSInsetRect(frameRect, +1.0, +1.0);
		NSFrameRectWithWidth(frameRect, .5);
	}
}


@end