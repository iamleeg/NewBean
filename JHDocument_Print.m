/*
	JHDocument_Print.m
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
 
#import "JHDocument_Print.h"
#import "JHDocument_View.h" //toggleLayoutView
#import "JHDocument_PageLayout.h" //removePage, textRectForContainerIndex

//TODO: make separate off-screen print view

@implementation JHDocument ( JHDocument_Print )

#pragma mark -
#pragma mark ---- Print Method ----

// ******************* the print method *******************

//	prints directly from the scrollView's document view
- (void)printDocument:(id)sender
{
	//	if continuous text view, create pageView because we actually print from that view
	if (![self hasMultiplePages])
	{
		[self setShouldRestorePageViewAfterPrinting:YES];
		[self rememberVisibleTextRange];
		[self toggleLayoutView:nil];
		if ([[theScrollView documentView] isKindOfClass:[PageView class]])
		{
			[[theScrollView documentView] setForceRedraw:YES];
		}
	}
	else
	{
		[self setShouldRestorePageViewAfterPrinting:NO];
	}
	//	if alternate text colors in use, since we print directly from the pageView, change to standard colors before printing
	if ([[[self firstTextView] backgroundColor] isEqual:[self textViewBackgroundColor]])
	{
		//	get rid of temp color attributes
		[[self layoutManager] removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:NSMakeRange(0, [[[self firstTextView] textStorage] length])];
		//	set background color to white
		[[self firstTextView] setBackgroundColor:[self theBackgroundColor]];
		if ([[theScrollView documentView] isKindOfClass:[PageView class]])
		{
			[[theScrollView documentView] setShouldUseAltTextColors:NO];
			//[[theScrollView documentView] setForceRedraw:YES]; // not needed
		}
		//[[theScrollView documentView] setNeedsDisplay:YES]; // not needed
		[self setRestoreAltTextColors:YES];
	}
	//	if showing Invisible Characters, make them invisible again so they don't print, then restore them
	if ([[self layoutManager] showInvisibleCharacters])
	{
		[self setRestoreShowInvisibles:YES];
		[[self layoutManager] setShowInvisibleCharacters:NO];
		[[self firstTextView] setNeedsDisplay:YES];
	}
	
	//	otherwise we get weird mixtures of Layout and Continuous view
	[[theScrollView documentView] setForceRedraw:YES];
	[[theScrollView documentView] setNeedsDisplay:YES];
	// force redraw to remove artifacts / alt colors in pageView margin
	[theScrollView display];
	
	//	ensure all pages are laid out by the layout manager (in case of background pagination)
	if ([layoutManager firstUnlaidCharacterIndex] < [textStorage length])
	{
		[self doForegroundLayoutToCharacterIndex:INT_MAX]; // must be INT_MAX or all pages of document will not print
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//	printing of header and footers is ALWAYS turned on
	//	but pageView RETURNS the header and footer strings only if user preferences say so
	[defaults setValue:[NSNumber numberWithBool:YES] forKey:NSPrintHeaderAndFooter];
		
	//	print to PDF (if menu action sends proper tag)
	if ([sender respondsToSelector:@selector(tag)] && [sender tag]==100)
	{
		int exportFileNumber = 0;
		//	get path with extension removed, then add .pdf extension
		NSString *thePathMinusExtension = [[self fileName] stringByDeletingPathExtension];
		NSString *theExportPath = [NSString stringWithFormat:@"%@%@", thePathMinusExtension, @".pdf"];
		//	to avoid overwriting previous export, add sequential numbers to filename just before extension
		while ([[NSFileManager defaultManager] fileExistsAtPath:theExportPath] && exportFileNumber < 1000)
		{
			exportFileNumber = exportFileNumber + 1;
			theExportPath = [NSString stringWithFormat:@"%@%@%i%@", thePathMinusExtension, @" ", exportFileNumber, @".pdf"];
		}
		NSPrintInfo *pdfPrintInfo;
		//NSPrintInfo *sharedInfo;  //dead code
		//NSMutableDictionary *sharedDict;  //dead code
		NSPrintOperation *printOp;
		NSMutableDictionary *pdfPrintInfoDict;
		//	get shared info
		//sharedInfo = [NSPrintInfo sharedPrintInfo];  //dead code
		//sharedDict = [sharedInfo dictionary];  //dead code
		pdfPrintInfoDict = [NSMutableDictionary dictionaryWithDictionary:[printInfo dictionary]];
		//	change bits we're interested in
		[pdfPrintInfoDict setObject:NSPrintSaveJob forKey:NSPrintJobDisposition];
		[pdfPrintInfoDict setObject:theExportPath forKey:NSPrintSavePath];
		pdfPrintInfo = [[NSPrintInfo alloc] initWithDictionary: pdfPrintInfoDict]; // ===== init
		[pdfPrintInfo setHorizontalPagination: NSAutoPagination];
		[pdfPrintInfo setVerticalPagination: NSAutoPagination];
		[pdfPrintInfo setVerticallyCentered:NO];
		printOp = [NSPrintOperation
					printOperationWithView:[theScrollView documentView]
					printInfo:pdfPrintInfo ];				
		[printOp setShowPanels:NO];
		[printOp runOperationModalForWindow:[ [theScrollView documentView] window]
					delegate:self
					didRunSelector:@selector(printOperationDidRun:success:contextInfo:) 
					contextInfo:NULL ];
		[pdfPrintInfo release]; // ===== release
		//	show exported file in Finder for the user
		[[NSWorkspace sharedWorkspace] selectFile:theExportPath inFileViewerRootedAtPath:nil];
	}
	//	print to printer
	else
	{
	//	we print directly from the scrollView's documentView
		NSPrintOperation *op = [NSPrintOperation
					printOperationWithView:[theScrollView documentView]
					printInfo:[self printInfo] ];				
		[op	runOperationModalForWindow:[ [theScrollView documentView] window]
					delegate:self
					didRunSelector:@selector(printOperationDidRun:success:contextInfo:) 
					contextInfo:NULL ];
	}
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation
					 success:(BOOL)success
				 contextInfo:(void *)info
{
	if (!success)
	{
		//	error message here?
	}
	//	if we un-enabled alternate text display colors to print, we restore them here
	if ([self restoreAltTextColors])
	{
		//	set foreground to temp color
		NSRange wholeRange = NSMakeRange(0, [textStorage length]);
		id textRange = [NSValue valueWithRange:wholeRange];
		[textStorage applyTheTempAttributesToRange:textRange];
		//	set background to temp background color
		[[self firstTextView] setBackgroundColor:textViewBackgroundColor];
		if ([[theScrollView documentView] isKindOfClass:[PageView class]])
		{
			[[theScrollView documentView] setShouldUseAltTextColors:YES];
		}
		//[[theScrollView documentView] setNeedsDisplay:YES]; //not needed
		[self setRestoreAltTextColors:NO];
	}
	//	restore showing invisibles, if necessary
	if ([self restoreShowInvisibles])
	{
		[[self layoutManager] setShowInvisibleCharacters:YES];
		[[self firstTextView] setNeedsDisplay:YES];
		[self setRestoreShowInvisibles:NO];
	}
	//	if we switched to pageView in order to print from it, switch back to continuous textView
	if ([self shouldRestorePageViewAfterPrinting])
	{
		[self toggleLayoutView:nil];
		[self restoreVisibleTextRange];
	}
	
	//	needed to force reapplication of alt colors
	if ([[theScrollView documentView] isKindOfClass:[PageView class]])
	{
		[[theScrollView documentView] setForceRedraw:YES];
	}
	[[theScrollView documentView] display];
}

#pragma mark -
#pragma mark ---- Print Info  ----

// ************************** Print Info ***************************

//	below 'printInfo' methods are from TextEdit
- (void)applyUpdatedPrintInfo
{
	NSRect rect = NSZeroRect;
	rect.size = [printInfo paperSize];
	//	figure width of textContainer
	[self setViewWidth:(rect.size.width - [printInfo leftMargin]- [printInfo rightMargin])];
	//	figure height of textContainer
	[self setViewHeight:(rect.size.height - [printInfo topMargin] - [printInfo bottomMargin])];

	PageView *pageView = [theScrollView documentView];
	//	remove text containers so they will repopulate with correct sizes
	if ([[theScrollView documentView] isKindOfClass:[PageView class]])
	{
		NSArray *textContainers = [[self layoutManager] textContainers];
		unsigned cnt = [textContainers count];
		while (cnt-- > 1)
		{
			[self removePage:self];
		}
			
		//we keep the first one to preserve text state and just resize it
		if ([[[self layoutManager] textContainers] count]==1)
		{ 
			//textView resize
			NSRect textFrame = [self textRectForContainerIndex:0];
			NSTextContainer *textContainer = [textContainers objectAtIndex:0];
			[[textContainer textView] setFrame:textFrame];
			//container resize
			unsigned numColumns = [self numberColumns];
			unsigned gutter = [self columnsGutter];
			int numberGutters = numColumns - 1;
			float columnWidth = ([self viewWidth] - gutter * numberGutters) / numColumns;
			float columnHeight = [self viewHeight];
			[textContainer setContainerSize:NSMakeSize(columnWidth, columnHeight)];
		}
			
		[pageView setPrintInfo:[self printInfo]];
		//	in case a page is added or removed
		[pageView recalculateFrame];
		//	if the page size was changed
		[pageView setNeedsDisplay:YES]; 	
	}
	//	maintain ruler state
	(areRulersVisible) ? [theScrollView setRulersVisible:YES] : [theScrollView setRulersVisible:NO];
}

- (void)setPrintInfo:(NSPrintInfo *)anObject	
{
	if (printInfo == anObject) return;
	[printInfo autorelease];
	printInfo = [anObject copyWithZone:[self zone]];
}

//	create and return the printInfo lazily
- (NSPrintInfo *)printInfo
{
	PageView *pageView = [theScrollView documentView];
	if (printInfo == nil)
	{
		[self setPrintInfo:[NSPrintInfo sharedPrintInfo]];
		[pageView setPrintInfo:[NSPrintInfo sharedPrintInfo]];
		[printInfo setHorizontalPagination:NSFitPagination];
		[printInfo setHorizontallyCentered:NO];
		[printInfo setVerticallyCentered:NO];
	}
	return printInfo;
}

@end