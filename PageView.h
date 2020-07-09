/*
 PageView.h
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

@class JHScrollView;
@class JHDocument;

//a container for multiple textViews to create a 'page layout' view
@interface PageView : NSView
{
	NSColor *backgroundColor;
	NSColor *textViewBackgroundColor;
	NSPrintInfo *printInfo;
	NSMenu *pagePopupMenu; //context menu when layout margin is double-clicked

	//cached for speed
	NSShadow *firstShadow;
	NSShadow *secondShadow;
	NSShadow *noShadow;
	NSMutableDictionary *theTextAttrs;

	int numberOfPages;
	int theCurrentPage; //for printing headers and footers
	int firstPageVisible; //used to determine index of first visible character when toggling layout
	int highPageNumVisible; //for status bar
	int lowPageNumVisible; //for status bar
	float pageSeparatorLength;
	BOOL showRulerWidgets;
	BOOL shouldUseAltTextColors;
	BOOL showPageShadow;
	BOOL showMarginsGuide; //used for menu validation
	BOOL forceRedraw;
	NSRect previousDrawRect;
	NSRect previousVisibleRect;
}

- (void)initializePagePopupMenu;
- (void)recalculateFrame;
- (float)pageSeparatorLength;
- (void)forceViewNeedsDisplay;

//pageView relies on its document to tell it how to behave
- (void)setBackgroundColor:(NSColor *)color;
- (NSColor *)backgroundColor;

- (void)setNumberOfPages:(int)newNumberOfPages;
- (int)numberOfPages;

- (void)setShouldUseAltTextColors:(BOOL)flag ;
- (BOOL)shouldUseAltTextColors;

- (void)setTextViewBackgroundColor:(NSColor*)aColor;
- (NSColor *)textViewBackgroundColor;

- (void)setPrintInfo:(NSPrintInfo *)anObject;
- (NSPrintInfo *)printInfo;

//optimization stuff
- (void)setPreviousVisibleRect:(NSRect)aRect;
- (NSRect)previousVisibleRect;

- (void)setForceRedraw:(BOOL)flag;
- (BOOL)forceRedraw;

//toggle view elements
- (void)setShowMarginsGuide:(BOOL)flag;
- (BOOL)showMarginsGuide;

- (void)setShowPageShadow:(BOOL)flag;
- (BOOL)showPageShadow;

- (void)setShowRulerWidgets:(BOOL)flag;
- (BOOL)showRulerWidgets;

//header and footer
- (NSAttributedString *)pageFooter;
- (NSAttributedString *)pageHeader;

- (void)setTheCurrentPage:(int)newCurrentPage;
- (int)theCurrentPage;

-(void)setFirstPageVisible:(int)i;
-(int)firstPageVisible;

-(void)setHighPageNumVisible:(int)i;
-(int)highPageNumVisible;

-(void)setLowPageNumVisible:(int)i;
-(int)lowPageNumVisible;

@end
