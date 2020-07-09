/*
	JHDocument_AltColors.m
	Bean
		
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
 
#import "JHDocument_AltColors.h"
#import "JHDocument_FullScreen.h" // [self fullScreen];
#import "NSTextViewExtension.h" // setCursorCompositeLighter

@implementation JHDocument ( JHDocument_AltColors )

#pragma mark -
#pragma mark ---- Alternate Colors ----

// ******************* Alternate Colors ********************

//	retrieve 'alternate' colors from user defaults when 1) Bean starts, or 2) alt colors are turned on after being switched off, since they may have changed in user Prefs
-(void)loadAltTextColors
{
	//TODO: need some error checking here...use defaults if bad values...
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	NSData *dataAltTextColor = [defaults objectForKey:@"altTextColor"];

	NSColor *theTextColor = [NSUnarchiver unarchiveObjectWithData:dataAltTextColor];
	[self setAltTextColor:theTextColor];
	[textStorage setTheTempAttributes:[self altTextColor]];
	NSData *dataAltBackgroundColor = [defaults objectForKey:@"altBackgroundColor"];

	NSColor *aBackgroundColor = [NSUnarchiver unarchiveObjectWithData:dataAltBackgroundColor];
	[self setTextViewBackgroundColor:aBackgroundColor];
	dataAltTextColor = nil;
	dataAltBackgroundColor = nil;
}

//	action for the menu item that toggles alternate display colors for text on/off
-(IBAction)switchTextColors:(id)sender
{
	if ([self shouldUseAltTextColors])
	{
		//alt colors are on; turn them off
		[self setShouldUseAltTextColors:NO];
		//keep track of altColors in fullScreen and normal mode separately
		if ([self fullScreen]) { [self setShouldUseAltTextColorsInFullScreen:NO]; }
		else { [self setShouldUseAltTextColorsInNonFullScreen:NO]; }
	}
	else
	{
		//remember non-Alternate Colors background color
		[self setTheBackgroundColor:[[self firstTextView] backgroundColor]];
		//alt colors are off, get them (they may have changed) and turn them on
		[self loadAltTextColors];
		[self setShouldUseAltTextColors:YES]; //this methods updates pageView background colors too
		//keep track of altColors in fullScreen and normal mode separately
		if ([self fullScreen]) { [self setShouldUseAltTextColorsInFullScreen:YES]; }
		else { [self setShouldUseAltTextColorsInNonFullScreen:YES]; }
	}
	[self textColors:nil];
}

//	forces recolor of ALL text using temporary attributes (alternate colors) when needed and if necessary
- (void) updateAltTextColors
{
	[textStorage setTheTempAttributes:[self altTextColor]];
	NSRange wholeRange = NSMakeRange(0, [textStorage length]);
	id textRange = [NSValue valueWithRange:wholeRange];
	[textStorage applyTheTempAttributesToRange: textRange];
	[[self firstTextView] setBackgroundColor:[self textViewBackgroundColor]];
}

-(float)darknessForColor:(NSColor *)inColor
{
	float darkness = 0;
	if ([inColor respondsToSelector:@selector(redComponent)])
	{
		darkness = ((222 * [inColor redComponent])
				+ (707 * [inColor greenComponent]) 
				+ (71 * [inColor blueComponent]))
				/ 1000;
	}
	return darkness;
}

// ******************* Toggle Color Methods ********************
//	this method, called by switch(=Toggle)TextColors menu action, changes from default white background and colored text to user-defined text color on top of user-defined background color, or vice versa, depending on [self shouldUseAltTextColors].
//	basically, the idea is you can do white text on blue background type stuff; other advantages: 1) no psychological 'blank white sheet' stumbling block when beginning to write, 2) easier on the eyes over time, 3) 'customizable'
- (IBAction)textColors:(id)sender
{
	NSTextView *textView = [self firstTextView];
	// activate alternate editing colors
	if ([self shouldUseAltTextColors])
	{
		[textStorage setShouldUseAltTextColors:YES];
		//	set temp text attr
		[self updateAltTextColors];
		//	this is necessary if user chooses gray-scale chooser from color panel ("no redComponent defined," etc errors)	
		NSColor *tvBackgroundColor = [[self textViewBackgroundColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	
		//	used for regular cursor shape 
		//	this part of the method (determining the color of the insertion point) is from TextForge.
		float darkness = [self darknessForColor:tvBackgroundColor];
		//	is light background
		if (darkness > 0.5)
			[textView setInsertionPointColor:[NSColor blackColor]];
		//	is dark background
		else
			[textView setInsertionPointColor:[NSColor whiteColor]];
		
		//	used for wide cursor shape 
		//calculate custom cursor color
		id fgColor = [[self altTextColor] objectForKey:NSForegroundColorAttributeName];
		NSColor *altCursorColor = [fgColor blendedColorWithFraction:.5 ofColor:tvBackgroundColor];
		//remember for wide cursor mode
		[self setAltCursorColor:altCursorColor];
		float fgDarkness = [self darknessForColor:fgColor];
		float cursorDarkness = [self darknessForColor:altCursorColor];
		//is foreground text darker than cursor color? then use composite darker (so text shows through cursor)
		if (fgDarkness <= cursorDarkness)
			[textView setCursorCompositeLighter:NO];
		else
			[textView setCursorCompositeLighter:YES];
		
		if (!hasMultiplePages)
		{
			//	bug fix 4 Aug 2007 (white scroll view was visible when textView was zoomed out) 
			[theScrollView setBackgroundColor:[self textViewBackgroundColor]];
			[theScrollView setNeedsDisplay:YES];
		}
		else
		{
			[theScrollView setBackgroundColor:[NSColor lightGrayColor]];
			[theScrollView setNeedsDisplay:YES];
		}
	}
	//	de-activate alternate editing colors
	else
	{
		//	restore original, traditional NSTextView colors; remove temp color attr
		[textStorage setShouldUseAltTextColors:NO];
		[layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName 
										 forCharacterRange:NSMakeRange(0, [[textView textStorage] length])];
		[textView setBackgroundColor:[self theBackgroundColor]];
		
		//insertion point color from prefs
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
		NSColor *cursorColor = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"prefCursorColor"]];
		if (!cursorColor) cursorColor = [NSColor blackColor];
		[[self firstTextView] setInsertionPointColor:cursorColor];
		
		if (!hasMultiplePages)
		{
			//	bug fix 4 Aug 2007 (white scroll view was visible when textView was zoomed out) 
			[theScrollView setBackgroundColor:[self theBackgroundColor]];
			[theScrollView setNeedsDisplay:YES];
		}
	}
}

-(NSColor *)altCursorColor;
{
	return _altCursorColor;
}

-(void)setAltCursorColor:(NSColor *)color;
{
	[_altCursorColor autorelease];
	_altCursorColor = [color copy];
}

@end