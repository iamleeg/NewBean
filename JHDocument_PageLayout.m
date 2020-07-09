/*
	JHDocument_PageLayout.m
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
 
#import "JHDocument_PageLayout.h"
#import "JHDocument_Print.h" //textRectForContainerIndex, applyUpdatedPrintInfo
#import "JHDocument_LiveWordCount.h" //liveWordCount
#import "JHDocument_View.h" //rememberVisibleTextRange, restoreVisibleTextRange

@implementation JHDocument ( JHDocument_PageLayout )

#pragma mark -
#pragma mark ---- Add and Remove Page ----

// ******************* Add and Remove Page ********************

- (void)addPage:(id)sender
{
	NSTextView *textView = nil;
	NSTextContainer *textContainer = nil;
	NSArray	*textContainers = [[self layoutManager] textContainers];
	PageView *pageView = [theScrollView documentView];
	//column/gutter info
	unsigned int numColumns = [self numberColumns];
	unsigned int gutter = [self columnsGutter];

	//NSLog(@"numberColumns:%u gutter:%u", numColumns, gutter);

	//iterate creating a page of column(s) of NSTextContainer and their NSTextView
 	unsigned cnt;
	if (numColumns < 1 || numColumns > 5) numColumns = 1;

	for (cnt = 1; cnt <= numColumns; cnt++) 
	{
		//if applyUpdatedPrintInfo has removed all but the first container (leaving the first textView to preserve
		//the text state) but the number of columns (=textContainers) on the first page exceeds one, just add the
		//columns on the first page that need adding 23 NOV 08 JH
		if (![self isPreservingTextViewState] && [textContainers count]==1 && cnt == 1 && numColumns > 1)
		{
			cnt = 2;
		}
		
		int numberGutters = numColumns - 1;
		float columnWidth = ([self viewWidth] - gutter * numberGutters) / numColumns;
		//checks to prevent negative column width or gutter width due to too small page and too large gutter...result isn't pretty, but indicates to user that things are too squished and need changing
		if (columnWidth < 0) columnWidth = 10;
		if (columnWidth * numColumns + gutter * numberGutters > [self viewWidth])
		{
			gutter = ([self viewWidth] - columnWidth * numColumns) / numberGutters;
			if (gutter < 0) gutter = 0;
		} 
		float columnHeight = [self viewHeight];
		
		//NSLog(@"columnWidth:%1.2f columnHeight:%1.2f", columnWidth, columnHeight);

		//	create and configure NSTextContainer
		textContainer = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(columnWidth, columnHeight)] autorelease];
		[textContainer setWidthTracksTextView:YES];
		[textContainer setHeightTracksTextView:YES];
		//	increased padding here AND increased rect for textView returned below (to fix caret redraw problems)
		[textContainer setLineFragmentPadding:1.0];
		
		//	pageCount determines y position of textView/container *to be added*
		int futureContainerIndex = [textContainers count] + ([self isPreservingTextViewState] ? -1 : 0);
		int futurePageIndex = [self pageNumberForContainerAtIndex:futureContainerIndex] - 1;
		
		//figure size of textView rect
		NSRect textFrame = NSZeroRect;
		//the final -1 is the fudge amount to keep the text cursor visible
		float pageHeight = [self viewHeight] + [printInfo bottomMargin] + [self pageSeparatorLength] + [printInfo topMargin];
		
		//NOTE: formerly, we used cnt to determine horizontalOffset, but cnt often was not what we expected, for reasons we still don't understand...typical pattern of progression of cnt and creation of containers ought to be (1)23123123123, but was often something like (1)12123123323323123...this could happen even after all docAttributes were initially loaded, for instance upon change of number of columns...problem was evident and consistant for some common layouts, but not others 26 NOV 08 JH 
		
		//horizontal column index (0 to 4) on current page
		float horitonalOffset = futureContainerIndex - (futurePageIndex * numColumns);
		//horiz. column index * gutter and column width
		float columnXOffset = gutter * horitonalOffset + columnWidth * horitonalOffset;

		//NSLog(@"count:%i horizontalOffset:%1.2f containerIndex:%i pageIndex:%i", cnt, horitonalOffset, futureContainerIndex, futurePageIndex);
		
		textFrame.origin.x = [self pageSeparatorLength] + [printInfo leftMargin] + columnXOffset - 1;
		textFrame.origin.y = [self pageSeparatorLength] + [printInfo topMargin] + (futurePageIndex * pageHeight); 
		textFrame.size.height = [self viewHeight];
		//the +2 is the fudge amount to keep the text cursor visible
		textFrame.size.width = columnWidth + 2;

		//NSLog(NSLog(@"tvRect:%@", NSStringFromRect(textFrame));
		
		//	create and configure NSTextView	
		textView = [[[NSTextView alloc] initWithFrame:textFrame textContainer:textContainer] autorelease];	
		[textView setMinSize:NSMakeSize(textFrame.size.width, textFrame.size.height)];
		[textView setMaxSize:NSMakeSize(textFrame.size.width, textFrame.size.height)];
		[textView setHorizontallyResizable:NO];
		[textView setVerticallyResizable:NO];

		//for debugging columns
		//[textView setBackgroundColor:[NSColor cyanColor]];
		
		//*should* always be a pageView
		if ([[theScrollView documentView] isKindOfClass:[PageView class]])
		{	
			//	add a 'page'
			[pageView addSubview:textView];
			[[self layoutManager] addTextContainer:textContainer];
		}
		//textView = nil; //tv is needed below
	}
	
	//	recalculate and refresh image of pages on screen
	int containerIndex = [textContainers count] - 1 + ([self isPreservingTextViewState] ? -1 : 0);
	int numPages = [self pageNumberForContainerAtIndex:containerIndex];
	[pageView setNumberOfPages:numPages];
	[pageView recalculateFrame];
	
	//	NOTE: ruler disappears unless we make it visible again (why?). Shouldn't created textViews inherit this from previous and still visible textViews? This doesn't happen in Text Edit, which uses similar code. A negative side effect of settingRulersVisible is the visible textView doesn't redraw correctly when a page is added, so we have to send theScrollView a needsDisplay message.
	if ([self areRulersVisible]) { [theScrollView setRulersVisible:YES]; }
	else { [theScrollView setRulersVisible:NO]; }
	
	// force redraw to remove artifacts
	[pageView setForceRedraw:YES];
	[pageView setNeedsDisplay:YES];

	//	update page count if page is added but no text is selected 19 MAR 08 JH
	if ([self shouldDoLiveWordCount] && textView && [textView selectedRange].length==0)
	{
		[self liveWordCount:nil];
	}
}

- (void)removePage:(id)sender
{
	NSArray *textContainers = [[self layoutManager] textContainers];
	NSTextContainer *lastContainer = [textContainers lastObject];
	PageView *pageView = [theScrollView documentView];
	
	[[lastContainer textView] removeFromSuperview];
	[[lastContainer layoutManager] removeTextContainerAtIndex:[textContainers count] - 1];

	unsigned int newNumPages = [self pageNumberForContainerAtIndex:[textContainers count] - 1]; 
	[pageView setNumberOfPages:newNumPages];
	[pageView recalculateFrame];
	
	//	maintain ruler state
	if (areRulersVisible) { [theScrollView setRulersVisible:YES]; }
	else { [theScrollView setRulersVisible:NO]; }
	
	// force redraw to remove artifacts
	[pageView setForceRedraw:YES];
	[pageView setNeedsDisplay:YES];

	//force word count to update when text is deleted
	if ([self shouldDoLiveWordCount] && [textStorage length]==0)
	{
		[self performSelector:@selector(liveWordCount:) withObject:nil afterDelay:0.0f];
	}
}

#pragma mark -
#pragma mark ---- Page Layout Methods ----

// ******************* Page Layout Methods ********************

//	page layout lets user change paperSize and orientation
- (void)doPageLayout:(id)sender
{
	[self rememberVisibleTextRange]; // <==remember
	NSPrintInfo *tempPrintInfo = [[[self printInfo] copy] autorelease];
	NSPageLayout *pageLayout = [NSPageLayout pageLayout];
	//added undo method 29 AUG 08 JH
	[[self undoManager] registerUndoWithTarget:self selector:@selector(undoLayoutChangeWithPrintInfo:) object:[self printInfo]];
	[[self undoManager] setActionName:NSLocalizedString(@"Change Layout", @"undo action: Change Layout.")];
	
	[pageLayout beginSheetWithPrintInfo:tempPrintInfo modalForWindow:[theScrollView window] 
							   delegate:self
						 didEndSelector:@selector(didEndPageLayout:returnCode:contextInfo:)
							contextInfo:(void *)tempPrintInfo];
}

- (void)didEndPageLayout:(NSPageLayout *)pageLayout returnCode:(int)result contextInfo:(void *)contextInfo
{
	NSPrintInfo *tempPrintInfo = (NSPrintInfo *)contextInfo;
	PageView *pageView = [theScrollView documentView];
	[self setPrintInfo:tempPrintInfo];
	if ([pageView respondsToSelector:@selector(setPrintInfo:)])
	{
		[pageView setPrintInfo:tempPrintInfo];
		[pageView setForceRedraw:YES]; //fixed a screen redraw bug 22 JAN 08 JH
		[pageView setNeedsDisplay:YES];
	}
	[self applyUpdatedPrintInfo];
	[self doForegroundLayoutToCharacterIndex:INT_MAX];
	[self restoreVisibleTextRange]; // <==restore
}

//undo method for doPageLayout
- (void)undoLayoutChangeWithPrintInfo:(NSPrintInfo *)pInfo
{
	//for redo...
	[[self undoManager] registerUndoWithTarget:self selector:@selector(undoLayoutChangeWithPrintInfo:) object:[self printInfo]];
	[[self undoManager] setActionName:NSLocalizedString(@"Change Layout", @"undo action: Change Layout.")];
	NSPrintInfo *tempPrintInfo = pInfo;
	PageView *pageView = [theScrollView documentView];
	[self setPrintInfo:tempPrintInfo];
	if ([pageView respondsToSelector:@selector(setPrintInfo:)])
	{
		[pageView setPrintInfo:tempPrintInfo];
		[pageView setForceRedraw:YES]; //fixed a screen redraw bug 22 JAN 08 JH
		[pageView setNeedsDisplay:YES];
	}
	[self applyUpdatedPrintInfo];
	[self doForegroundLayoutToCharacterIndex:INT_MAX];
	[self restoreVisibleTextRange]; // <==restore
}

// ******************* doForegroundLayoutToCharacterIndex ********************

//	force total layout to avoid slow background repagination (code is from Text Edit!)
- (void)doForegroundLayoutToCharacterIndex:(unsigned)loc
{
	unsigned len;
	//	if no loc, layout whole doc
	if (loc==0) loc=INT_MAX; //INT_MAX;
	if (loc > 0 && (len = [[self textStorage] length]) > 0)
	{
		NSRange glyphRange;
		if (loc >= len) { loc = len - 1; }
		//	find out which glyph index the desired character index corresponds to
		glyphRange = [[self layoutManager] glyphRangeForCharacterRange:NSMakeRange(loc, 1) actualCharacterRange:NULL];
		if (glyphRange.location > 0)
		{
			//	now cause layout by asking a question which has to determine where the glyph is
			(void)[[self layoutManager] textContainerForGlyphAtIndex:glyphRange.location - 1 effectiveRange:NULL];
		}
	}
}

#pragma mark -
#pragma mark ---- Layout Helpers ----

// ******************* Layout Helpers ********************

//calculates size of text container based on index
- (NSRect)textRectForContainerIndex:(unsigned)containerIndex 
{	
	unsigned numColumns = [self numberColumns];
	unsigned gutter = [self columnsGutter];
	int numberGutters = numColumns - 1;
	int pageIndex = [self pageNumberForContainerAtIndex:containerIndex] - 1;
	float columnWidth = ([self viewWidth] - gutter * numberGutters) / numColumns;
	//the final -1 is the fudge amount to keep the text cursor visible
	float pageHeight = [printInfo paperSize].height + [self pageSeparatorLength];
	float columnXOffset = (gutter * containerIndex) + (columnWidth * containerIndex);
	NSRect textFrame = NSZeroRect;
	textFrame.origin.x = [self pageSeparatorLength] + [printInfo leftMargin] + columnXOffset - 1;
	textFrame.origin.y = [self pageSeparatorLength] + [printInfo topMargin] + (pageIndex * pageHeight); 
	textFrame.size.height = [self viewHeight];
	//the +2 is the fudge amount to keep the text cursor visible
	textFrame.size.width = columnWidth + 2;
	return textFrame;
}

//returns actual page number (first page is 1)
-(int)pageNumberForContainerAtIndex:(int)containerIndex
{
	//since index starts at 0, we add one
	float numberContainer = containerIndex + 1;
	float numberColumns = [self numberColumns];
	
	//divide number containers by number columns (ex: 7 containers / 3 columns = ceil(2.33) = locaton of pg 3)
	float fVal = numberContainer / numberColumns;
	//round up
	int pages = ceil(fVal);
	if (pages) return pages;
	else return 1;
}

@end