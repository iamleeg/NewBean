/*
  NSTypesetter(Extension).h
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

//NOTE: I had tried to make this a subclass, but being a singleton that also needs to be re-entrant sometimes (when locked/busy), this did not work; app crashed when trying to init a temporary second copy of typesetter, so went with category and swizzle instead   

#import "NSTypesetter(Extension).h"
#import "JHLayoutManager.h"

@implementation NSTypesetter(Extension)

/* Control/format character handling */
/* This method returns the action associated with a control character. */
//	if continuous text view, cause line break to indicate form feed (page break) since typesetter doesn't do this consistantly

- (NSTypesetterControlCharacterAction)actionForControlCharacterAtIndexSwizzle:(unsigned)charIndex;
{
	id lm = [self layoutManager];
	//	if responds to selector, then instance of JHLayoutManager (would not want to alter behavior otherwise)
	if ([lm respondsToSelector:@selector(shouldDoLineBreakForFormFeed)] && [lm shouldDoLineBreakForFormFeed])
	{
		unichar c = [[[self attributedString] string] characterAtIndex:charIndex];
		//if pagebreak (=form feed char)
		if (c == 0x000C)
		{
			//do linebreak for visual feedback to user
			return NSTypesetterLineBreakAction;
		}
	}
	return [self actionForControlCharacterAtIndexSwizzle:charIndex];
}

@end