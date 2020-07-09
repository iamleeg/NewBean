/*
 JHScrollView.h
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
#import <Foundation/NSGeometry.h>

//	class includes code based on PlacardScrollView (allowing extra buttons in scroller) by Dan Wood (public domain)
//	Original Source: <http:(remove me)//cocoa.karelia.com/AppKit_Classes/PlacardScrollView__.m>
//	(See copyright notice at <http:(remove me)//cocoa.karelia.com>)

//	subclass of NSScrollView based on ScalingScrollView.m Copyright (c) 1995-2005 by Apple Computer Author: Mike Ferris
@interface JHScrollView : NSScrollView
{
	float scaleFactor;
	BOOL isFitWidth;
	BOOL isFitPage;
	BOOL isOptionKeyDown;
	BOOL isShiftKeyDown;
	
	IBOutlet NSButton *pageUpButton;
	IBOutlet NSButton *pageDownButton;
	IBOutlet NSView *placard; //view with page up and page down buttons
}

//	the pageup/down buttons should really be in their own view, then that view inserted into the scroll view hierarchy
- (void)setPageUpAndDownButtonsEnabled:(BOOL)flag;

//	accessors
- (void)setScaleFactor:(float)factor;
- (void)setScaleFactorWithoutDisplay:(float)scaleFactor;
- (float)scaleFactor;
- (BOOL)isFitWidth;
- (void)setIsFitWidth:(BOOL)flag;
- (BOOL)isFitPage;
- (void)setIsFitPage:(BOOL)flag;
- (void) setPlacard:(NSView *)inView;
- (NSView *) placard;

- (BOOL)isOptionKeyDown;
- (void)setOptionKeyDown:(BOOL)flag;

-(BOOL)isShiftKeyDown;
-(void)setShiftKeyDown:(BOOL)flag;

@end
