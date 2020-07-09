/*
 Subclass: JHLayoutManager.h

 Revised 30 DEC 2006 by JH
 Cleaned up 21 NOV 2007 JH
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

//	showInvisibles method based on code posted by Peter Borg (see cocoabuilder.com Jan 3 2005)
//	improved by Keith Blount

#import <Cocoa/Cocoa.h>

@class KBWordCountingTextStorage;

@interface JHLayoutManager : NSLayoutManager 
{
	// Cache invisible control character information for speed
	NSString *spaceCharacter;
	NSString *tabCharacter;
	NSString *newlineCharacter;
	NSString *softReturnCharacter;
	NSString *pageBreakCharacter;
	NSString *nonBreakingSpaceCharacter;
	NSColor	*invisiblesColor;
	NSDictionary *invisiblesAttributes;
	NSRect spaceCharBounds;
	NSRect tabCharBounds;
	NSRect softReturnCharBounds;
	NSRect newlineCharBounds;
	NSRect pageBreakCharBounds;
	NSRect nonBreakingSpaceCharBounds;
	float invisiblesFontDescender;
		
	BOOL showInvisibleCharacters;
	BOOL showRulerAccessories;
	BOOL showSpaces;
	BOOL shouldDoLineBreakForFormFeed;
}

-(void)setShowInvisibleCharacters:(BOOL)flag;
-(BOOL)showInvisibleCharacters;
-(void)setShowRulerAccessories:(BOOL)flag;
-(BOOL)showRulerAccessories;
-(void)setShouldDoLineBreakForFormFeed:(BOOL)flag;
-(BOOL)shouldDoLineBreakForFormFeed;

-(void)setInvisiblesColor:(NSColor *)color;
-(NSColor *)invisiblesColor;
-(void)setInvisiblesAttributes:(NSDictionary *)dictionary;
-(NSDictionary *)invisiblesAttributes;

@end
