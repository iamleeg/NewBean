/*
 JHLayoutManager.m (subclass of NSLayoutManager)

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
 
//Thanks to the following folks...

//-------------------
//	showInvisibles based on code posted by Peter Borg on cocoabuilder.com 
//	Jan 3 2005 (Smultron also uses it) 20 June 2007 JH

//-------------------
//	showInvisibles code was greatly improved by Keith Blount (so that changing 
//	spacing before and after paragraphs now does not cause the invisibles' characters
//	to draw in the wrong places) 22 FEB 08 JH


#import "JHLayoutManager.h"
#import "JHDocument.h" //hasMultiplePages (drawGlyphs) 
#import "NSTextViewExtension.h" //drawPageSeparatorAtYPos

@implementation JHLayoutManager

-(id)init
{
	if (self = [super init])
	{
		//cache color for invisibles in dictionary
		//todo: should probably bind to color pref
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
		NSData *invisiblesColorData = [defaults objectForKey:@"prefInvisiblesColor"];
		[self setInvisiblesColor:[NSUnarchiver unarchiveObjectWithData:invisiblesColorData]];
		if (invisiblesColor==nil) [self setInvisiblesColor:[NSColor blueColor]];
		[self setInvisiblesAttributes:[NSDictionary dictionaryWithObject:[self invisiblesColor] forKey:NSForegroundColorAttributeName]];

		//initialize accessor vars
		showInvisibleCharacters = NO;
		showRulerAccessories = NO;

		// Cache invisible characters for speed
		unichar spaceUnichar =  0x00B7;
		spaceCharacter = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%C", spaceUnichar]];
		unichar tabUnichar = 0x2192;
		tabCharacter = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%C", tabUnichar]];
		unichar newlineUnichar = 0x00b6;
		newlineCharacter = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%C", newlineUnichar]];
		unichar softReturnUnichar = 0x21B5;
		softReturnCharacter = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%C", softReturnUnichar]];
		unichar pageBreakUnichar = 0x2666; //0x29EB; // 0x23AE; 
		pageBreakCharacter = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%C", pageBreakUnichar]];
		unichar nonBreakingSpaceUnichar = 0x02EF;
		nonBreakingSpaceCharacter = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%C", nonBreakingSpaceUnichar]];
		
		// Get descender for invisibles font (the default attributed string font, which we use for invisibles)
		invisiblesFontDescender = [[NSFont fontWithName:@"Helvetica" size:12.0] descender];
		
		// Cache bound rects - they won't change, so we don't want to keep calling them whilst drawing
		NSDictionary *invisibleAttributes = nil;
		spaceCharBounds = [spaceCharacter boundingRectWithSize:NSMakeSize(1e7,100)
													   options:NSStringDrawingUsesLineFragmentOrigin
													attributes:invisibleAttributes];
		
		tabCharBounds = [tabCharacter boundingRectWithSize:NSMakeSize(1e7,100)
												   options:NSStringDrawingUsesLineFragmentOrigin
												attributes:invisibleAttributes];
		
		newlineCharBounds = [newlineCharacter boundingRectWithSize:NSMakeSize(1e7,100)
														   options:NSStringDrawingUsesLineFragmentOrigin
														attributes:invisibleAttributes];
		
		softReturnCharBounds = [softReturnCharacter boundingRectWithSize:NSMakeSize(1e7,100)
																 options:NSStringDrawingUsesLineFragmentOrigin
															  attributes:invisibleAttributes];
		
		pageBreakCharBounds = [pageBreakCharacter boundingRectWithSize:NSMakeSize(1e7,100)
															   options:NSStringDrawingUsesLineFragmentOrigin
															attributes:invisibleAttributes];

		nonBreakingSpaceCharBounds = [nonBreakingSpaceCharacter boundingRectWithSize:NSMakeSize(1e7,100)
															   options:NSStringDrawingUsesLineFragmentOrigin
															attributes:invisibleAttributes];
		
		//show the alternate colors in the example text field, if we're using them
		if ([defaults boolForKey:@"prefOmitSpaces"])
		{
			showSpaces = NO;
		}
		else
		{
			showSpaces = YES;
		}
		
		//	this will scale images so that they do not 'disappear' from connected textContainers (unless line spacing is too great); note that only view is scaled (when displayed and printed in Bean), not image itself
		//
		//	ImageManager > openPanelDidEnd also has code to shrink an image to fit it's text container; this involves actual resizing of image; while this code, in continuous text mode, images appear original size and are only shrunk to fit in layout view
		//
		//	ImageManager > openPanelDidEnd code scales image to fit page (not container), but in column mode the image will be too big; we use this cocoa function now to prevent that; the downside is the image might took smaller to user than it would if the file is opened in another app 12 DEC 08 JH
		int scaleDown = 0; //NSScaleProportionally (deprecated in 10.4)
		//int doNotScale = 2;
		[self setDefaultAttachmentScaling: scaleDown];
	}
	return self;
}

-(void)dealloc
{
	[spaceCharacter release];
	[tabCharacter release];
	[newlineCharacter release];
	[softReturnCharacter release];
	[pageBreakCharacter release];
	[nonBreakingSpaceCharacter release];
	[invisiblesColor release];
	[invisiblesAttributes release];
	
	[super dealloc];
}

//method has two added behaviors: 1) draw invisibles 2) draw container-break line
- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange atPoint:(NSPoint)containerOrigin
{
	//NOTE: holding down scroller buttons causes uneven drawing and scrolling -- I think too much drawing is going on 23 FEB 09 JH
	//	above is actually a problem when Leopard is run on PPC macs; Tiger itself or Leopard on intel do not have this problem
	//NOTE: tried regex here for finding index of char to draw; no sig. speed improvement

	//NSLog(@"drawGlyphsRange:%@", NSStringFromRange(glyphRange));
	
	id doc = [[[[self firstTextView] window] windowController] document];
			
	if ([self showInvisibleCharacters] || ![doc hasMultiplePages])
	{
		NSString *string = [[self textStorage] string];
		NSRange characterRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
		unsigned charIndex, end = NSMaxRange(characterRange);
		for (charIndex = characterRange.location; charIndex < end; charIndex++)
		{
			unichar characterToCheck = [string characterAtIndex:charIndex];
			NSString *characterToDraw = nil;
			NSRect charBounds;
			float xOffset = 0.0;
			float yOffset = 0.0;
			
			NSRange invGlyphRange = NSMakeRange(NSNotFound,0);	// We'll only get this range as and when we need it, once.
			
			// Space character
			if (characterToCheck == ' ' && showSpaces)
			{
				characterToDraw = spaceCharacter;
				charBounds = spaceCharBounds;
				
				// Centre the character horizontally
				invGlyphRange = [self glyphRangeForCharacterRange:NSMakeRange(charIndex,1) actualCharacterRange:NULL];
				float charWidth = [self boundingRectForGlyphRange:NSMakeRange(invGlyphRange.location,1)
												  inTextContainer:[self textContainerForGlyphAtIndex:invGlyphRange.location effectiveRange:nil]].size.width;
				xOffset = MAX(0,roundf(charWidth/2.0) - roundf([spaceCharacter sizeWithAttributes:invisiblesAttributes].width/2.0));
				yOffset = 1.0;
			}
			// non-breaking space character
			else if (characterToCheck == 0x00A0)
			{
				characterToDraw = nonBreakingSpaceCharacter;
				charBounds = nonBreakingSpaceCharBounds;
				// Centre the character horizontally
				invGlyphRange = [self glyphRangeForCharacterRange:NSMakeRange(charIndex,1) actualCharacterRange:NULL];
				float charWidth = [self boundingRectForGlyphRange:NSMakeRange(invGlyphRange.location,1)
												  inTextContainer:[self textContainerForGlyphAtIndex:invGlyphRange.location effectiveRange:nil]].size.width;
				xOffset = MAX(0,roundf(charWidth/2.0) - roundf([spaceCharacter sizeWithAttributes:invisiblesAttributes].width/2.0));
				yOffset = 1.0;
			}			
			// Tab character
			else if (characterToCheck == '\t')
			{
				characterToDraw = tabCharacter;
				charBounds = tabCharBounds;
				
				// Centre the character horizontally
				invGlyphRange = [self glyphRangeForCharacterRange:NSMakeRange(charIndex,1) actualCharacterRange:NULL];
				float charWidth = [self boundingRectForGlyphRange:NSMakeRange(invGlyphRange.location,1)
												  inTextContainer:[self textContainerForGlyphAtIndex:invGlyphRange.location effectiveRange:nil]].size.width;
				xOffset = MAX(0,roundf(charWidth/2.0) - roundf([tabCharacter sizeWithAttributes:invisiblesAttributes].width/2.0));
				yOffset = 1.0;
			}
			// Return character
			else if (characterToCheck == '\n' 
					 || characterToCheck == '\r'
					 || characterToCheck == 0x2029)
			{
				characterToDraw = newlineCharacter;
				charBounds = newlineCharBounds;
				xOffset = 2.0;
			}
			// Soft line separator character
			else if (characterToCheck == 0x2028)
			{
				characterToDraw = softReturnCharacter;
				charBounds = softReturnCharBounds;
				xOffset = 2.0;
				yOffset = 1.0;
			}
			//typesetter subclass now forces linebreak for pagebreak in non-layout view (see actionForControlCharacterAtIndex) 16 AUG 08 JH
			else if (characterToCheck == 0x000c)
			{

				//we draw horizontal line to indicate pagebreak instead of invisible character 28 AUG 08 JH
				charBounds = pageBreakCharBounds;
				//----- draw horizontal line in textView to represent page break in non-layout view -----
				float yPos;
				id textView = nil, container = nil;
				id containerArray = [self textContainers];
				if (containerArray)
				{
					container = [containerArray objectAtIndex:0];
				}
				if (container)
				{
					textView = [container textView];
				}
				if (textView)
				{
					//draw page break lines only for non-layout view
					if (![doc hasMultiplePages])
					{
						if (invGlyphRange.location == NSNotFound)
						{
							invGlyphRange = [self glyphRangeForCharacterRange:NSMakeRange(charIndex,1) actualCharacterRange:NULL];
						}
						NSRect lineRect = [self lineFragmentRectForGlyphAtIndex:invGlyphRange.location effectiveRange:NULL];
						yPos = containerOrigin.y + lineRect.origin.y + lineRect.size.height ;
						[[NSColor darkGrayColor] set];
						NSRect tvFrame = [textView frame];
						NSRect frame = NSMakeRect(tvFrame.origin.x, yPos, tvFrame.size.width, .5);
						//NSLog(@"draw page break line");
						NSRectFill(frame);
					}
				}
								//broken bar for drawn invisible char 0x00A6
				characterToDraw = pageBreakCharacter; //pageBreakCharacter;
				charBounds = softReturnCharBounds;
				xOffset = 2.0;
				yOffset = 1.0;
			}
			
			if (characterToDraw != nil && [self showInvisibleCharacters])
			{
				if (invGlyphRange.location == NSNotFound)
					invGlyphRange = [self glyphRangeForCharacterRange:NSMakeRange(charIndex,1) actualCharacterRange:NULL];
				
				NSRect lineRect = [self lineFragmentRectForGlyphAtIndex:invGlyphRange.location effectiveRange:NULL];
				NSPoint loc = [self locationForGlyphAtIndex:invGlyphRange.location];
				
				NSRect drawingRect = NSMakeRect(containerOrigin.x + lineRect.origin.x + loc.x + xOffset,
												containerOrigin.y + lineRect.origin.y + loc.y - invisiblesFontDescender - charBounds.size.height + yOffset,
												charBounds.size.width,
												charBounds.size.height);
				
				[characterToDraw drawWithRect:drawingRect
									  options:NSStringDrawingUsesLineFragmentOrigin
								   attributes:invisiblesAttributes];
			}
			#pragma unused(charBounds)
		}
	}
	[super drawGlyphsForGlyphRange:glyphRange atPoint:containerOrigin];
}

-(void)setShowInvisibleCharacters:(BOOL)flag { showInvisibleCharacters = flag; }
-(BOOL)showInvisibleCharacters { return showInvisibleCharacters; }

-(void)setShowRulerAccessories:(BOOL)flag { showRulerAccessories = flag; }
-(BOOL)showRulerAccessories { return showRulerAccessories; }

//informs shared typesetter of desired behavior; YES when Layout NOT shown; NO when layout shown
-(void)setShouldDoLineBreakForFormFeed:(BOOL)flag { shouldDoLineBreakForFormFeed = flag; }
-(BOOL)shouldDoLineBreakForFormFeed { return shouldDoLineBreakForFormFeed; }

//tell NSTextTableExtension what color to draw boarders of invisible text tables
- (NSColor *)invisiblesColor
{
	return invisiblesColor;
}

- (void)setInvisiblesColor:(NSColor *)color
{
	[invisiblesColor autorelease];
	invisiblesColor = [color copy];
}

//tell self what color to draw invisibles
-(void)setInvisiblesAttributes:(NSDictionary *)dictionary;
{
	[invisiblesAttributes autorelease];
	invisiblesAttributes = [dictionary copy];
}

-(NSDictionary *)invisiblesAttributes;
{
	return invisiblesAttributes;
}

- (NSView *)rulerAccessoryViewForTextView:(NSTextView *)view paragraphStyle:(NSParagraphStyle *)style ruler:(NSRulerView *)ruler enabled:(BOOL)isEnabled
{
	//	show Cocoa ruler widgets when ruler is visible (set at startup based on NSUserDefault: showRulerWidgets) 3 July 2007 JH
	if ([self showRulerAccessories])
	{
		//if would be nice to turn off ruler accessory widgets that we don't want enabled when plain text docs are open (list text lists) but
		//	we allow spacing, alignment, etc. otherwise for plain text files for the purposes of printing them (disallow this in the future?)
		//	so keep widgets enabled and shown for now
		//if (![view isRichText]) isEnabled = NO;
		NSView *accessory = [super rulerAccessoryViewForTextView:view paragraphStyle:style ruler:ruler enabled:isEnabled];
		return accessory;
	}
	//	don't show ruler widgets when ruler is visible
	else
		return nil;
}

//	page breaks can cause this method (in Leopard) to return bad info
//	bug: range extends to lineFrangment of prev. or next containers having 0x000C form feed characters causing overlaid text in multiple textViews rdar:6151919

- (NSRange) glyphRangeForBoundingRect:(NSRect)bounds 
					  inTextContainer:(NSTextContainer *)container;
{
	//the code that error checks for bad ranges for multiple containers below really slows down layout
	//	when one continuous text view is used; in that case we use super's implementation, since we won't
	//	run into the bad range bug there anyway 20 DEC 08 JH
	id doc = [[[[self firstTextView] window] windowController] document];
	if (doc && ![doc hasMultiplePages])
	{
		return [super  glyphRangeForBoundingRect:bounds inTextContainer:container];
	}
	
	NSRange range = [super glyphRangeForBoundingRect:bounds inTextContainer:container];
	NSRange cRange = [self glyphRangeForTextContainer:container];
	
	//NSLog(@"r:%@", NSStringFromRange(range));
	//NSLog(@"c:%@", NSStringFromRange(cRange));
	
	//prevent Leopard frameworks bug where if glyph index 0 is visible, sometimes glyphRangeForBoundingRect can return 0,0 while glyphRangeForTextContainer returns range for second container!
	if (range.length > 0) //23 NOV 08 JH was range.length > 1
	{
		if (range.location < cRange.location)
		{
			//NSLog(@"glyphRangeForBoundingRect went short");
			range.location = cRange.location;
		}
		if (range.length > cRange.length)
		{
			//NSLog(@"glyphRangeForBoundingRect went long");
			range.length = cRange.length;
		}
	}
	return range;
}

@end
