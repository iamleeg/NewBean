//
//  KBRulerView.h
//  -------------
//
//  Created by Keith Blount on 25/05/2008.
//  Copyright 2008 Keith Blount. All rights reserved.
//
//	A simple NSRulerView subclass that draws a littler prettier (providing a white area) and adds
//	a contextual menu for adding text view tab stops. It also overrides all of the places where markers
//	get added so that it can intercept to see if they are text tabs. If they are, it inserts our own
//	custom images instead.
//	NOTE: Another way of adding custom images for the markers is to provide an NSRulerMarker category that
//	overrides the designated initialiser and swaps in the images there. That method is most likely quicker and
//	easier, but is also less safe.

#import <Cocoa/Cocoa.h>


@interface KBRulerView : NSRulerView
@end
