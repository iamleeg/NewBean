/*
	NSTextContainer(Extension).m
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

#import "NSTextContainer(Extension).h"

@implementation NSTextContainer ( Extension )

//BUGFIX: it seems like the first thing people try to do after launching Bean for the first time is to drop a huge image into Bean in layout mode; while the layoutManager can auto-shrink images to fit a container, if the line spacing is > 1, the layoutManager simply won't lay out the image cell or subsequent text; to the user, the text just 'disappears'
//	so here, we limit height of proposedLineFragment to height of its textContainer
//	TODO: might be handy to reduce maxLineHeight of paragraph to image size height / average char height in this case

- (NSRect)lineFragmentRectForProposedRectSwizzle:(NSRect)proposedRect 
						   sweepDirection:(NSLineSweepDirection)sweepDirection 
						movementDirection:(NSLineMovementDirection)movementDirection 
							remainingRect:(NSRectPointer)remainingRect
{
	//if proposedLineFrag.size.height is > textContainer's height, limit it to container's height 
	if (proposedRect.size.height > [self containerSize].height)
		proposedRect.size.height = [self containerSize].height;
			
	return [self lineFragmentRectForProposedRectSwizzle:proposedRect 
						   sweepDirection:sweepDirection 
						movementDirection:movementDirection 
							remainingRect:remainingRect];
}

@end
