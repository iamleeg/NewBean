/*
	NSRulerMarkerExtension.m
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

#import "NSRulerMarkerExtension.h"
#import "JHScrollView.h"

//	WAS: a category so we can substitute our own images instead of std. NSRulerMarker images upon init
//	IS NOW: rotates type of tab stop upon double-click on marker

@implementation NSRulerMarker ( NSRulerMarkerExtension )

/*	NOTE: swapping out ruler widget images here doesn't work with resolution independence because the image name we depend on to identify the widgets is NULL when the widgets are created (I'm supposing) using new xml language
//	when experimenting with Quartz Debug, I find that higher than 1.0 resolution widgets don't have image names to identify them
//	instead use representedObject, which is set after the marker is initialized
	 
//	this method based on the GNUStep NSRulerMarker.m code by Fred Kiefer
- (id)initWithRulerView:(NSRulerView *)ruler
		 markerLocation:(float)location
				  image:(NSImage *)image
			imageOrigin:(NSPoint)imageOrigin

{
	//call superclass (of NSRulerMarker)
	self = [super init];

	if (ruler == nil || image == nil)
		//shouldn't happen; how to handle gracefully?
		[NSException raise: NSInvalidArgumentException format: @"No view or image for ruler marker"];
	
	//	for testing:
	//NSLog([NSString stringWithFormat:@"image name of ruler marker: ->%@<-", [image name]]);
	
	//these are marked private in the NSRulerMarker header, but it seems unlikely they will change
	_location = location;
	_imageOrigin = imageOrigin;
	_ruler = ruler;
	
	//	I'm guessing representedObject (here, a descriptive string) tells ruler class what kind of marker it is
		
	if ([[image name] isEqualToString:@"NSTextRulerIndent"])
	{
		NSImage *altImage;
		altImage = [NSImage imageNamed:@"TextRulerIndent"];
		[altImage retain];
		[_image release];
		_image = altImage;
		[self setRepresentedObject:@"NSHeadIndentRulerMarkerTag"];
	}
	else if ([[image name] isEqualToString:@"NSTextRulerFirstLineIndent"])
	{
		NSImage *altImage;
		altImage = [NSImage imageNamed:@"TextRulerFirstLineIndent"];
		[altImage retain];
		[_image release];
		_image = altImage;
		[self setRepresentedObject:@"NSFirstLineHeadIndentRulerMarkerTag"];

	}
	else if ([[image name] isEqualToString:@"NSTextRulerLeftTab"])
	{
		NSImage *altImage;
		altImage = [NSImage imageNamed:@"TextRulerLeftTab"];
		[altImage retain];
		[_image release];
		_image = altImage;
		[self setRepresentedObject:@"NSTailIndentRulerMarkerTag"];
		
	}
	else if ([[image name] isEqualToString:@"NSTextRulerCenterTab"])
	{
		NSImage *altImage;
		altImage = [NSImage imageNamed:@"TextRulerCenterTab"];
		[altImage retain];
		[_image release];
		_image = altImage;
	}
	else if ([[image name] isEqualToString:@"NSTextRulerRightTab"])
	{
		NSImage *altImage;
		altImage = [NSImage imageNamed:@"TextRulerRightTab"];
		[altImage retain];
		[_image release];
		_image = altImage;
	}
	else if ([[image name] isEqualToString:@"NSTextRulerDecimalTab"])
	{
		NSImage *altImage;
		altImage = [NSImage imageNamed:@"TextRulerDecimalTab"];
		[altImage retain];
		[_image release];
		_image = altImage;
	}
	else
	{
		//when experimenting with Quartz Debug, I find that higher than 1.0 resolution widgets don't have image names to identify them
		//we just retain the image here and use it, whatever it is, without the substitution happening above 10 NOV 08 JH
		[image retain];
		[_image release];
		_image = image;
	}
	
	//needed
	[self setMovable:YES];

	return self;
}

- (void) dealloc
{
  [_image release];
  [super dealloc];
}
*/

//swizzle allows calling original class's implementation in a category
- (BOOL)trackMouseSwizzle:(NSEvent *)theEvent adding:(BOOL)adding
{
	id ruler = [self ruler];
	id clientView = [ruler clientView];
	id scrollView = [clientView enclosingScrollView];
	BOOL doExtraRelease = NO;
	BOOL isTab = [(NSRulerMarker *)[self representedObject] isKindOfClass:[NSTextTab class]];
	//NSLog(@"representedObject:%@", [self representedObject]);

	//if double-click (cf Page.app) or option-click on marker + sanity check + only if clicking on a text tab
	if (([theEvent clickCount]==2 || [scrollView isOptionKeyDown]) && !adding && ruler && clientView && isTab)
	{
		//prepare to create a different tab stop type...
		NSTextTabType type = [(NSTextTab *)[self representedObject] tabStopType];
		NSTextTabType newType = 0;
		NSString *imgName;

		switch (type)
		{
			//NSLeftTabStopType > NSRightTabStopType
			case NSLeftTabStopType:
			{
				newType = NSRightTabStopType;
				imgName = @"TextRulerRightTab";
				break;
			}
			//NSRightTabStopType > NSCenterTabStopType
			case NSRightTabStopType:
			{
				newType = NSCenterTabStopType;
				imgName = @"TextRulerCenterTab";
				break;
			}
			//NSCenterTabStopType > NSDecimalTabStopType
			case NSCenterTabStopType:
			{
				newType = NSDecimalTabStopType;
				imgName = @"TextRulerDecimalTab";
				break;
			}
			//NSDecimalTabStopType or future types > NSLeftTabStopType
			default:
			{
				newType = NSLeftTabStopType;
				imgName = @"TextRulerLeftTab";
				break;
			}
		}

		//create image for tab stop...
		if ([NSColor currentControlTint] == NSGraphiteControlTint)
		{
			//adjust for graphite interface setting as opposed to aqua		
			imgName = [imgName stringByAppendingString:@"Graphite"];
		}
		NSImage *img = [NSImage imageNamed:imgName];
		if (!img) return NO;

		//create ruler marker for new tab stop (to replace old one)...
		NSRulerMarker *marker = [[NSRulerMarker alloc] // <===== init
				  initWithRulerView: ruler
				  markerLocation: [self markerLocation]
				  image: img
				  imageOrigin: NSMakePoint(0, 0)];
		NSTextTab *tab = [[NSTextTab alloc] initWithType: newType // <===== init
					location: [(NSTextTab *)[self representedObject] location]];
		[marker setRepresentedObject: tab];

		// ask permission to add marker...
		if ([clientView respondsToSelector:@selector(rulerView:shouldAddMarker:)])
		{
			if ([clientView rulerView:ruler shouldAddMarker:marker] == YES)
			{
				//and add it...
				if ([clientView respondsToSelector:@selector(rulerView:willAddMarker:atLocation:)])
					[clientView rulerView:ruler willAddMarker:marker atLocation:[(NSTextTab *)[self representedObject] location]];

				[ruler addMarker:marker];

				if ([clientView respondsToSelector:@selector(rulerView:didAddMarker:)])
					[clientView rulerView:ruler didAddMarker:marker];

				//and remove old marker...
				if ([clientView respondsToSelector:@selector(rulerView:shouldRemoveMarker:)])
				{
					if ([clientView rulerView:ruler shouldRemoveMarker:self] == YES)
					{
						//retain self so not dealloc'd when marker (self) is removed from ruler; release later if doExtraRelease says so...
						[self retain]; // <===== retain
						doExtraRelease = YES;
						[ruler removeMarker:self];
						if ([clientView respondsToSelector:@selector(rulerView:didRemoveMarker:)])
							[clientView rulerView:ruler didRemoveMarker:self];
					}
				}
			}
		}
		//cleanup
		if (marker) [marker release]; // <===== release
		if (tab) [tab release]; // <===== release
		if (doExtraRelease) [self release]; // <===== release
		return NO;
	}
	else
	{
		return [self trackMouseSwizzle:theEvent adding:adding];
		//	TODO: if option key + mouse down on left indent *or* left first line indent, move the other marker
		//	how? perhaps: search markers array, send willMoveMarker, setLocation for marker, send didMoveMarker msgs
	}
}

@end

