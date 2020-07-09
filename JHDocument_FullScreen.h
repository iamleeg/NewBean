/*
  JHDocument_FullScreen.h
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

//	enter and exit full screen; remember interface settings for return from full screen 
@interface JHDocument (JHDocument_FullScreen)

-(void)showFullScreen:(BOOL)flag withAnimation:(BOOL)flag;
//	adjusts amount of horizontal padding applied to left and right of text container in full screen mode
//	according to a slider in Preferences
-(IBAction)adjustFullScreenHorizontalPadding:(id)sender;
//20111025-2 renamed method to avoid conflict with OS X 10.7 framework method name 
-(IBAction)bean_toggleFullScreen:(id)sender;

//accessors
-(BOOL)fullScreen;
-(void)setFullScreen:(BOOL)flag;

-(NSRect)oldFrameRect;
-(void)setOldFrameRect:(NSRect)rect;

-(BOOL)shouldRestoreRuler;
-(void)setShouldRestoreRuler:(BOOL)flag;

-(BOOL)shouldRestoreToolbar;
-(void)setShouldRestoreToolbar:(BOOL)flag;

-(void)setShouldRestoreAltTextColors:(BOOL)flag;
-(BOOL)shouldRestoreAltTextColors;

-(void)setShouldRestoreLayoutView:(BOOL)flag;
-(BOOL)shouldRestoreLayoutView;

-(BOOL)shouldRestoreFullScreen;
-(void)setShouldRestoreFullScreen:(BOOL)flag;

-(NSSize)contentSizeBeforeFullScreen;
-(void)setContentSizeBeforeFullScreen:(NSSize)size;

@end