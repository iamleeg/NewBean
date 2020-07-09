/*
  JHDocument_Misc.h
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

#import <Cocoa/Cocoa.h>
#import "JHDocument.h"

//	various helper and action methods
@interface JHDocument (JHDocument_Misc)

//publicize
-(void)undoChangeLeftMargin:(int)theLeftMargin 
				 rightMargin:(int)theRightMargin 
				   topMargin:(int)theTopMargin
				bottomMargin:(int)theBottomMargin;
-(void)undoChangeColumns:(int)numColumns gutter:(int)gutter;

-(IBAction)toggleToolbarShownAction:(id)sender;
-(IBAction)makeTemplateAction:(id)sender;

//	to silence compiler warning in EncodingManager
-(void)undoChangeEncodingWithTag:(int)tag andTitle:(NSString *)title;

//for logging
//-(NSString *)stringFromColor:(NSColor *)inColor;

@end