/*
  JHDocument_AltColors.h
  Bean

  Refactored 25 JUL 08 JH
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
#import "JHDocument.h"

//	applies and removes alternate editing colors (temporaryAttributes) for text and background on the display
@interface JHDocument (JHDocument_AltColors)

-(void)loadAltTextColors;

-(IBAction)switchTextColors:(id)sender;
-(IBAction)textColors:(id)sender;

-(NSColor *)altCursorColor;
-(void)setAltCursorColor:(NSColor *)color;

@end