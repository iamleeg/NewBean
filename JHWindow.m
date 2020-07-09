/*
	JHWindow.m
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

#import "JHWindow.h"
#import "JHDocument_FullScreen.h" //for fullScreen

@implementation JHWindow

#pragma mark -
#pragma mark ---- Cleanup   ----

- (void)dealloc
{
	if (fullScreenTimer) [fullScreenTimer release];
	[super dealloc];
}

#pragma mark -
#pragma mark ---- Full Screen Helper  ----

// ******************* Full Screen Helper ********************

//	for full screen window with title bar off of screen (really just moved up so that it's not visible)
//	well, this works for Leopard but NOT for Tiger...hmm 12 March 08 JH
- (NSRect)constrainFrameRect:(NSRect)rect toScreen:(NSScreen*)screen
{
	if ([[[self windowController] document] fullScreen])
	{
		//	if full screen, extend height past top of screen so title bar is not visible
		if ([self shouldAdjustForTitleBar])
		{
			float theAdjustmentHeight = 0.0;
			theAdjustmentHeight = [self heightMenuBar];
			rect.size.height = rect.size.height + theAdjustmentHeight;
			[self setShouldAdjustForTitleBar: NO];
		}
		return(rect);
	}
	else
	{
		return [super constrainFrameRect:rect toScreen:screen];
	}
}

#pragma mark -
#pragma mark ---- Fade In  ----

// ******************* Fade In ********************

//enterFullScreen, fadeIn, returnFromFullScreen, fadeOut lifted from Smultron by Peter Borg (Apache license) 20 JUL 08 JH
- (void)fadeIn
{
	if ([self alphaValue] < 1.0) {
		[self setAlphaValue:([self alphaValue] + 0.05)];
	} else {		
		if (fullScreenTimer != nil) {
			[fullScreenTimer invalidate];
			[fullScreenTimer release];
			fullScreenTimer = nil;
		}
	}
}

- (void)enterFullScreen
{	
	fullScreenTimer = [[NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(fadeIn) userInfo:nil repeats:YES] retain];
}

- (void)returnFromFullScreen
{
	fullScreenTimer = [[NSTimer scheduledTimerWithTimeInterval:0.005 target:self selector:@selector(fadeIn) userInfo:nil repeats:YES] retain];
	
}

/* 
//	we don't use
- (void)fadeOut
{
	if ([self alphaValue] > 0) {
		[self setAlphaValue:([self alphaValue] - 0.05)];
	} else {		
		if (fullScreenTimer != nil) {
			[fullScreenTimer invalidate];
			[fullScreenTimer release];
			fullScreenTimer = nil;
		}
	}	
}
*/

#pragma mark -
#pragma mark ---- Accessors  ----

// ******************* Accessors ********************

-(BOOL)shouldAdjustForTitleBar
{
	return shouldAdjustForTitleBar; 
}

-(void)setShouldAdjustForTitleBar:(BOOL)flag;
{
	shouldAdjustForTitleBar = flag;
}

-(float)heightMenuBar
{
	return heightMenuBar;
}

-(void)setHeightMenuBar:(float)height
{
	heightMenuBar = height;
}

@end