//
//  KBRulerView.m
//  -------------
//
//  Created by Keith Blount on 25/05/2008.
//  Copyright 2008 Keith Blount. All rights reserved.
//

#import "KBRulerView.h"

@interface KBRulerView (Private)
- (NSImage *)imageForRepresentedObject:(id)representedObject;
@end

@implementation KBRulerView

/* --------- addition for Bean
// a variation that I was experimenting with for Bean, but ruler markers don't show up well on dark background -- JH
- (void)drawRect: (NSRect)aRect
{
	id doc = [[[self window] windowController] document];
	if ([doc hasMultiplePages])
	{
		NSColor *bgGray = (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4 ?
					   [NSColor lightGrayColor] :
					   [NSColor colorWithCalibratedWhite:0.941 alpha:1.0]);
		[bgGray set];
		NSRectFill(aRect);
	}
	else
	{
		[[NSColor whiteColor] set];
		NSRectFill(aRect);
	}
	[self drawHashMarksAndLabelsInRect:aRect];
	[self drawMarkersInRect:aRect];
	[[NSColor darkGrayColor] set];
	[NSBezierPath fillRect:NSMakeRect(0.0,[self baselineLocation]+[self ruleThickness]-1.0, [self bounds].size.width, 1.0)];
}
*/

/* Keith Blount's implementation of drawRect and a popup menu for ruler widgets

- (void)drawRect:(NSRect)aRect
{
	NSColor *bgGray = (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4 ?
					   [NSColor windowBackgroundColor] :
					   [NSColor colorWithCalibratedWhite:0.941 alpha:1.0]);
	
	NSRect rect1, rect2;
	NSDivideRect([self bounds], &rect1, &rect2, [self ruleThickness], NSMaxYEdge);
	[bgGray set];
	[NSBezierPath fillRect:rect2];
	
	NSView *docView = [[self scrollView] documentView];
	NSRect docRect = [self convertRect:[docView bounds] fromView:docView];
	NSDivideRect(rect1, &rect1, &rect2, docRect.size.width, NSMinXEdge);
	
	
	[[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] set];
	[NSBezierPath fillRect:rect1];
	
	[self drawHashMarksAndLabelsInRect:aRect];
	[self drawMarkersInRect:aRect];
	
	[bgGray set];
	[NSBezierPath fillRect:rect2];
	
	[[NSColor colorWithCalibratedWhite:0.4 alpha:1.0] set];
	[NSBezierPath fillRect:NSMakeRect(NSMaxX(rect1)-1.0,rect1.origin.y,1.0,rect1.size.height)];
	
	
	[NSBezierPath fillRect:NSMakeRect(0.0,NSMaxY([self bounds])-1.0,[self bounds].size.width,1.0)];
	
	//[[NSColor blackColor] set];
	[NSBezierPath fillRect:NSMakeRect(0.0,[self ruleThickness]-1.0, [self bounds].size.width, 1.0)];
}

static float _KBRVCtrlClickLocation = 0.0;

- (NSMenu *)menuForEvent:(NSEvent *)anEvent
{
	_KBRVCtrlClickLocation = [self convertPoint:[anEvent locationInWindow] fromView:nil].x;
	
	NSMenu *menu = [[NSMenu alloc] init];
	NSMenuItem *item;
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add Left Tab",nil) action:@selector(addTabFromMenu:) keyEquivalent:@""];
	[item setTarget:self];
	[item setTag:NSLeftTabStopType];
	[item setImage:[NSImage imageNamed:([NSColor currentControlTint] == NSGraphiteControlTint ? @"KBTextRulerLeftTabGraphite" : @"KBTextRulerLeftTab")]];
	[menu addItem:item];
	[item release];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add Center Tab",nil) action:@selector(addTabFromMenu:) keyEquivalent:@""];
	[item setTarget:self];
	[item setTag:NSCenterTabStopType];
	[item setImage:[NSImage imageNamed:([NSColor currentControlTint] == NSGraphiteControlTint ? @"KBTextRulerCenterTabGraphite" : @"KBTextRulerCenterTab")]];
	[menu addItem:item];
	[item release];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add Right Tab",nil) action:@selector(addTabFromMenu:) keyEquivalent:@""];
	[item setTarget:self];
	[item setTag:NSRightTabStopType];
	[item setImage:[NSImage imageNamed:([NSColor currentControlTint] == NSGraphiteControlTint ? @"KBTextRulerRightTabGraphite" : @"KBTextRulerRightTab")]];
	[menu addItem:item];
	[item release];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add Decimal Tab",nil) action:@selector(addTabFromMenu:) keyEquivalent:@""];
	[item setTarget:self];
	[item setTag:NSDecimalTabStopType];
	[item setImage:[NSImage imageNamed:([NSColor currentControlTint] == NSGraphiteControlTint ? @"KBTextRulerDecimalTabGraphite" : @"KBTextRulerDecimalTab")]];
	[menu addItem:item];
	[item release];
	
	return [menu autorelease];
}

- (void)addTabFromMenu:(id)sender
{
	int tag = [sender tag];

	NSTextTab *tab = [[NSTextTab alloc] initWithType:tag location:_KBRVCtrlClickLocation];
	
	NSRulerMarker *marker = [[NSRulerMarker alloc] initWithRulerView:self
													  markerLocation:_KBRVCtrlClickLocation
															   image:[self imageForRepresentedObject:tab]
														 imageOrigin:NSMakePoint(0,0)];
	
	[marker setRepresentedObject:tab];
	[tab release];
	
	if ([[self clientView] respondsToSelector:@selector(rulerView:shouldAddMarker:)])
	{
		if ([[self clientView] rulerView:self shouldAddMarker:marker] == NO)
		{
			[marker release];
			return;
		}
	}
	
	if ([[self clientView] respondsToSelector:@selector(rulerView:willAddMarker:atLocation:)])
		[[self clientView] rulerView:self willAddMarker:marker atLocation:_KBRVCtrlClickLocation];
	
	[self addMarker:marker];
	
	if ([[self clientView] respondsToSelector:@selector(rulerView:didAddMarker:)])
		[[self clientView] rulerView:self didAddMarker:marker];
	
	[marker release];
}
*/

- (NSImage *)imageForRepresentedObject:(id)representedObject
{
	if (representedObject == nil)
		return nil;
	
	// Intercepting text tabs is simple enough - we just check the type and swap in our own image.
	if ([representedObject isKindOfClass:[NSTextTab class]])
	{	
		NSTextTabType type = [(NSTextTab *)representedObject tabStopType];
		NSString *imgName = (type == NSCenterTabStopType ? @"TextRulerCenterTab" :
							 type == NSRightTabStopType ? @"TextRulerRightTab" :
							 type == NSDecimalTabStopType ? @"TextRulerDecimalTab" :
							 @"TextRulerLeftTab");
		
		if ([NSColor currentControlTint] == NSGraphiteControlTint)
		{
			imgName = [imgName stringByAppendingString:@"Graphite"];
		}
		return [NSImage imageNamed:imgName];
	}
	
	// First line head indent, head indent and tail indent all have strings as their represented this - I know this from NSLogging.
	else if ([representedObject isKindOfClass:[NSString class]])
	{
		NSString *tagString = (NSString *)representedObject;
		NSString *imgName = nil;
		
		if ([tagString isEqualToString:@"NSHeadIndentRulerMarkerTag"] || [tagString isEqualToString:@"NSTailIndentRulerMarkerTag"])
			imgName = @"TextRulerIndent";
		
		else if ([tagString isEqualToString:@"NSFirstLineHeadIndentRulerMarkerTag"])
			imgName = @"TextRulerFirstLineIndent";

		if ([NSColor currentControlTint] == NSGraphiteControlTint)
			imgName = [imgName stringByAppendingString:@"Graphite"];
		
		if (imgName != nil)
			return [NSImage imageNamed:imgName];
	}
	
	return nil;
}

- (void)setMarkers:(NSArray *)markers
{
	NSEnumerator *e = [markers objectEnumerator];
	NSRulerMarker *marker;
	while (marker = [e nextObject])
	{
		NSImage *image = [self imageForRepresentedObject:[marker representedObject]];
		if (image != nil)
			[marker setImage:image];
	}
	
	[super setMarkers:markers];
}

- (void)addMarker:(NSRulerMarker *)aMarker
{
	NSImage *image = [self imageForRepresentedObject:[aMarker representedObject]];
	if (image != nil)
		[aMarker setImage:image];
	
	[super addMarker:aMarker];
}

- (BOOL)trackMarker:(NSRulerMarker *)aMarker withMouseEvent:(NSEvent *)theEvent
{
	NSImage *image = [self imageForRepresentedObject:[aMarker representedObject]];
	if (image != nil)
		[aMarker setImage:image];
	
	return [super trackMarker:aMarker withMouseEvent:theEvent];
}

@end
