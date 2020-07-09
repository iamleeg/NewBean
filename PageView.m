/*
 PageView.m
 Bean
 
 Created by James Hoover on 7/11/06.
 Revised 22 DEC 2007 JH
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

#import "PageView.h"
#import "JHScrollView.h" //setting background color, etc.
#import "JHDocument.h" //for currentSystemVersion
#import "PrefWindowController.h" //show header and footer control in Preferences (contextual popup menu)
#import "JHDocument_PageLayout.h" //doPageLayout for contextual popup menu
#import "JHDocument_View.h" //zoom select for contextual popup menu
#import "JHDocument_DocAttributes.h" //for docAttributes

//a container for multiple textViews to create a 'page layout' view
@implementation PageView

#pragma mark -
#pragma mark ---- Init, Dealloc, etc. ----

// ******************* Init, Dealloc, etc. ********************

- (id)initWithFrame:(NSRect)frame
{
	if (self = [super initWithFrame:frame]) 
	{
		// thought about using a custom color for the background...
		//	backingColor = [NSColor colorWithCalibratedRed:0.5 green:0.7 blue:0.7 alpha:1.0];
		NSColor *backingColor = [[NSColor lightGrayColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
		[self setBackgroundColor:backingColor];	
		[self setPrintInfo:[NSPrintInfo sharedPrintInfo]];
		[self setNumberOfPages:1];
		[self setShowPageShadow:YES];
		
		//cached shadows and font to increase speed
		
		//CREATE PAGE SHADOW
		firstShadow = [[NSShadow alloc] init]; // ===== init
		//set shadow (for page rect)
		[firstShadow setShadowOffset:NSMakeSize(0.0, 0.0)]; 
		[firstShadow setShadowBlurRadius:12.0]; 
		//use a partially transparent color for shapes that overlap.
		[firstShadow setShadowColor:[[NSColor darkGrayColor] colorWithAlphaComponent:0.7]]; 
		
		//CREATE TEXT SHADOW
		secondShadow = [[NSShadow alloc] init];  // ===== init
		//set shadow (for page rect)
		[secondShadow setShadowOffset:NSMakeSize(0.0, 0.0)]; 
		[secondShadow setShadowBlurRadius:8.0]; 
		//use a partially transparent color for shapes that overlap.
		[secondShadow setShadowColor:[[NSColor darkGrayColor] colorWithAlphaComponent:0.9]]; 
		
		//DON'T DRAW A SHADOW 
		noShadow = [[NSShadow alloc] init];  // ===== init
		[noShadow setShadowColor:nil]; 
		
		theTextAttrs = [[NSMutableDictionary alloc] init];  // ===== init
		
		// pageCount label font
		NSFont *aFont = [NSFont fontWithName: @"Arial" size: 12];
		//use system font on error (Lucida Grande, it's nice)
		if (aFont == nil) aFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
		//Macs without Arial would complain of nil object, so added error code (17 May 2007 BH)
		if (aFont) [theTextAttrs setObject: aFont forKey: NSFontAttributeName];
		//	white text
		[theTextAttrs setObject: [NSColor whiteColor] forKey:NSForegroundColorAttributeName];
		
		//display popup context menu when margin is clicked
		[self initializePagePopupMenu];
	}
	return self;
}

- (void)dealloc
{
	//release cached
	[pagePopupMenu release]; // ===== release
	[firstShadow release]; // ===== release
	[secondShadow release]; // ===== release
	[noShadow release]; // ===== release
	[theTextAttrs release]; // ===== release
	//release accessor ivars
	if (backgroundColor) [backgroundColor release];
	if (printInfo) [printInfo release];
	[super dealloc];
}

-(BOOL)isFlipped
{
	return YES;
}

-(BOOL)isOpaque
{
	return YES;
}

- (void)awakeFromNib
{
	//set up ruler view
	NSScrollView *theScrollView = [self enclosingScrollView];
	// Make sure scroll view has same colour as our background
	if (theScrollView && backgroundColor)
	{
		[theScrollView setBackgroundColor:[self backgroundColor]];
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL showRuler = [defaults boolForKey:@"prefShowVerticalRuler"];
	[theScrollView setHasVerticalRuler:showRuler];

	[theScrollView setHasHorizontalRuler:YES];
	//conpensate ruler for page position offset
	NSRulerView *xruler = [theScrollView horizontalRulerView];
	[xruler setOriginOffset:[self pageSeparatorLength]];
	//vertical ruler offset
	NSRulerView *yruler = [theScrollView verticalRulerView];
	[yruler setOriginOffset:[self pageSeparatorLength]];
	
	BOOL showShadow = [defaults boolForKey:@"prefShowPageShadow"];
	[self setShowPageShadow:showShadow];
}

#pragma mark -
#pragma mark ---- drawRect ----

// ******************* drawRect ********************

//	NOTE: Leopard's NSLayoutManager is very slow at laying out text in multiple containers -- a 650K file took NINE TIMES as long to lay out in Text Edit on Leopard vs. Tiger. To test, place cursor at end of doc; switch to Wrap to Window; then switch back to Wrap to Page and time how long it takes the layout manager to finish the job.
//	Addendum - 10.5.4 seems a bit better

//	NOTE: Leopard calls drawRect here MUCH more often than Tiger. Every cursor blink, every glyph added when temporary attributes are used, even for every mouse movement. (I believe it's trying to draw the area under the textView in the enclosing pageView, which seems to me to be a bug, since it is not responsible for that, but perhaps this is necessary for 'layering' sibling views, which is a new feature of Leopard.) I have read complaints about this on the forums of Nisus, Scrivener, etc. Appears to affect PPC macs the most (Leopard was not really designed with them in mind). No easy fix, apparently, except to hijack NSTextView and NSLayoutManager. Unless we treat the symptoms here, the app runs unbearably slow with even medium size files. 	

//	NOTE: Can we optimize drawRect in NSTextView by coalescing redraws during rapid typing? (example: if > 3 keypresses in time < .12 second, skip drawRect in textView, but have .12 second timer which draws changes if needed after ignoring drawing (would have to save drawGlyphs range ignored for previous calls). NOTE: Tiger did coalesce screen redraws for rapid typing; not sure why it was removed in Leopard, because it could be a performance bottleneck for very fast typists, especially on PPC macs. Since we don't currently subclass NSTextView, I put this note here.

//	we try to decrease the (huge, unnecessary) number of drawRect messages the PageView class gets in Leopard by comparing the documentVisibleRect to previously drawn documentVisibleRect; if different, we draw. We also implement a 'forceDraw' flag for when the rect doesn't change but drawing needs to happen.
//	NOTE: since we only redraw upon change of docVisibleArea, dragging ruler markers will not cause a redraw without a method delegated from NSRulerView in NSTextViewExtensions which sets forceRedraw to YES 

- (void)drawRect:(NSRect)rect
{
	
	//this method causes a slowdown when a scroller button is held down by the mouse
	//note: above slowdown is result of Leopard code meant for faster processor w/ GPU running on a PPC -- too many draws; can't fix easily 
	
	//NSLog(@"initial pageView drawRect:%@", NSStringFromRect(rect));
	
	// -------------------- OPTIMIZATION --------------------
	
	//	draw only if documentVisibleRect has changed or forceDraw flag is set
	//	note: documentVisibleRect is the area of the PageView shown by the clipView of the scrollView
	NSRect docVisibleRect = [[self enclosingScrollView] documentVisibleRect];
	if (NSEqualRects(docVisibleRect, [self previousVisibleRect]) && ![self forceRedraw])
	{
		return;
	}
	//	reset flag
	[self setForceRedraw:NO];
	
	//NSLog(@"after optimization pageView drawRect:%@", NSStringFromRect(rect));

	// -------------------- DRAWING CODE --------------------

	if ([[NSGraphicsContext currentContext] isDrawingToScreen])
	{

		//NSLog(@"actual drawing pageView drawRect:%@", NSStringFromRect(rect));
		BOOL printHeaderFooter = NO;
		JHDocument *doc = [[[self window] windowController] document];
		int headerFooterSetting = [doc headerFooterSetting];
		if (headerFooterSetting==0)
		{
			printHeaderFooter = [[[NSUserDefaults standardUserDefaults] valueForKey:@"prefPrintHeaderFooter"] boolValue];
		}
		else if (headerFooterSetting==1)
		{
			printHeaderFooter = NO;
		}
		else if (headerFooterSetting==2)
		{
			printHeaderFooter = YES;
		}
		
		//draw GRAY BACKGROUND on which 'pages' rest in multiple page view mode
		[backgroundColor set];
		[NSBezierPath fillRect:rect];
		
		if ([self showPageShadow]) { [firstShadow set]; }
		
		//get paper size
		NSSize paperSize = [printInfo paperSize];
		
		//	determines the color of the margin guide (light vs. dark) -- from TextForge source code
		//	NSDeviceRGBColorSpace avoids "no redComponent defined" error (if user chooses from gray-scale chooser in color panel)
		NSColor *tvBackgroundColor = [[self textViewBackgroundColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
		float darkness;
		darkness = ( (222 * [tvBackgroundColor redComponent]) 
					+ (707 * [tvBackgroundColor greenComponent]) 
					+ (71 * [tvBackgroundColor blueComponent]) ) / 1000;
		

		//	prepare some stuff for drawing headers and footers (create pointer just once)
		NSDictionary *theHeaderAttrs, *theFooterAttrs;
		if (printHeaderFooter)
		{
			theHeaderAttrs = [[self pageHeader] attributesAtIndex:0 effectiveRange:NULL];
			theFooterAttrs = [[self pageFooter] attributesAtIndex:0 effectiveRange:NULL];
		}

		//	for determining if header/footer should print; used later
		unsigned lowPageVisible = 0, highPageVisible = 0;
		
		//DRAW PAGE	(i.e., area outside text container but inside page edge)			
		unsigned cnt;
		for (cnt = 0; cnt <= ([self numberOfPages] - 1); cnt++) 
		{
			//determine paper size
			NSRect pageRect = NSZeroRect;
			pageRect.size = [printInfo paperSize];
			pageRect.origin = ([self frame].origin);
			pageRect.origin.x = [self pageSeparatorLength];
			pageRect.origin.y = [self pageSeparatorLength] + cnt * (paperSize.height + [self pageSeparatorLength]);
			
			//fills margin of page drawn on screen (around text container) with appropriate color
			([self shouldUseAltTextColors]) ? [[self textViewBackgroundColor] set] : [[NSColor whiteColor] set];
			
			//	determine if page is visible
			NSRect testRect = NSIntersectionRect(pageRect, rect);
			//	if intersection between pageRect and drawRect, draw page because it is visible in the clipView
			if (testRect.size.width != 0 && testRect.size.height != 0)
			{
				if (lowPageVisible > 0)
				{
					highPageVisible = cnt + 1;
				}
				else
				{
					lowPageVisible = cnt + 1;
				}
				
				//	draw white page rect
				NSRectFill(pageRect);
				
				//if no pageShadow, draw rectangle around page instead
				if (![self showPageShadow])
				{
					[[NSColor colorWithCalibratedWhite: .2 alpha: 1.0] set];
					[NSBezierPath setDefaultLineWidth:0.5];
					[NSBezierPath strokeRect:pageRect];
				}
				
				//draws MARGINS GUIDE (a light frame just outside editable text area)
				if ([self showMarginsGuide])
				{
					NSRect frame = NSZeroRect;
					frame.size = [printInfo paperSize];
					//arbitrarily added 2 so that left margin text wouldn't visually butt up against margin guide
					frame.origin.x = [printInfo leftMargin] + [self pageSeparatorLength] - 2;
					frame.origin.y = [self pageSeparatorLength] + [printInfo topMargin] 
					+ (cnt * (([printInfo paperSize].height) + [self pageSeparatorLength])) - 2; 
					frame.size.height = [printInfo paperSize].height - [printInfo topMargin] - [printInfo bottomMargin] + 4;
					//arbitrarily added 4 so that right margin text wouldn't visually butt up against margin guide
					frame.size.width = [printInfo paperSize].width - [printInfo leftMargin]- [printInfo rightMargin] + 4;
					if (shouldUseAltTextColors)
					{
						if (darkness > 0.5) { [[NSColor darkGrayColor] set]; }
						else { [[NSColor lightGrayColor] set]; }
					}
					else
					{
						[[NSColor darkGrayColor] set];
					}
					frame = NSInsetRect(frame, -1.0, -1.0);
					NSFrameRectWithWidth(frame, 0.3);
				}
			}
		}
		
		//this draws PAGE COUNT on view just above each page
		for (cnt = 0; cnt <= ([self numberOfPages] - 1); cnt++)
		{
			[self setTheCurrentPage:cnt + 1];
			
			// only one page is visible, so adjust numbers
			if (highPageVisible < lowPageVisible) { highPageVisible = lowPageVisible; }

			//NSLog(@"highPage:%u, lowPage:%u", highPageVisible, lowPageVisible);
			
			[self setHighPageNumVisible:highPageVisible];
			[self setLowPageNumVisible:lowPageVisible];
			
			//	only draw to screen when page number label and header/footer is in visible rect!
			if (cnt >= lowPageVisible - 1 && cnt <= highPageVisible - 1)
			{
				NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
				BOOL showPageNumbersInLayoutView = [defaults boolForKey:@"prefShowPageNumbersInLayoutView"];

				if (showPageNumbersInLayoutView)
				{
					NSString *pageCount = nil;
					pageCount = [[NSString alloc] initWithFormat:@"%@ %i", NSLocalizedString(@"Page ", @"layout view label: Page_"), cnt + 1]; // ==== init
					
					NSPoint theTextPos;
					//pos for page count
					theTextPos = NSMakePoint(5 + [self pageSeparatorLength], [self pageSeparatorLength] 
											 + cnt * ((paperSize.height) + [self pageSeparatorLength]) - 18);
					
					//draw shadow for page count label
					//CREATE SHADOW (if page shadow is off, this just makes the page count more visible
					//			doesn't seem to slow down the scroll or display like the page shadow does)
					if (![self showPageShadow]) { [secondShadow set]; }
					
					//draw page count label
					[pageCount drawAtPoint:theTextPos withAttributes:theTextAttrs];
					
					[pageCount release]; // ==== release
				}
				
				//this draws HEADER and FOOTER on view just inside paperSize
				if (printHeaderFooter)
				{
					float headerStringX = 15 + [self pageSeparatorLength];
					float headerStringY = [self pageSeparatorLength] + cnt * ((paperSize.height) + [self pageSeparatorLength]) + [printInfo topMargin] * .4;
					float footerStringY = [self pageSeparatorLength] + (cnt + 1) * ((paperSize.height) + [self pageSeparatorLength]) - [printInfo bottomMargin] * .6 - [self pageSeparatorLength];
					[noShadow set];
					[[[self pageHeader] string] drawAtPoint:NSMakePoint(headerStringX, headerStringY) withAttributes:theHeaderAttrs];
					[[[self pageFooter] string] drawAtPoint:NSMakePoint(headerStringX, footerStringY) withAttributes:theFooterAttrs];
					
					//NSLog(@"header/footer printed to page:%i", cnt + 1);
				}
				
				//for testing drawRect - set textView isOpaque:NO and setDrawsBackground:NO
				//if (rect.origin.x != 0.0) { [[NSColor blueColor] set]; [NSBezierPath fillRect:rect]; }
			}
		}		

		//	for determining index of first visible character in clipview before toggle layout
		[self setFirstPageVisible:lowPageNumVisible];

	}
	
	//	for comparison on the next go
	[self setPreviousVisibleRect:docVisibleRect];
	
	/*
	 //	for testing drawRect
	 if (rect.origin.x > 26.0 && rect.origin.y < 28.0)
	 {
		 [[NSColor redColor] set];
		 NSRect test = NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
		 NSFrameRectWithWidth(test, 5);
	 }
	*/
}

#pragma mark -
#pragma mark ---- drawRect Helpers ----

// ******************* drawRect Helpers ********************

//	documentSizeInPage; documentRectForPageNumber
//	these override methods belong in the subclass from which the print view is generated
//	these two methods were lifted from Text Edit for GnuStep code (=Text Edit 4.0 for NextStep by Ali Ozer)

- (NSSize)documentSizeInPage
{
	NSSize paperSize = [printInfo paperSize];
	paperSize.width -= ([printInfo leftMargin] + [printInfo rightMargin]);
	paperSize.height -= ([printInfo topMargin] + [printInfo bottomMargin]);
	return paperSize;
}

- (NSRect)documentRectForPageNumber:(unsigned)pageNumber /* First page is page 0, of course! */
{
	NSRect rect = NSZeroRect;
	rect.size = [printInfo paperSize];
	rect.origin = [self frame].origin;
	rect.origin.y += ((rect.size.height + [self pageSeparatorLength]) * pageNumber) + [self pageSeparatorLength];
	rect.origin.x += [printInfo leftMargin] + [self pageSeparatorLength];
	rect.origin.y += [printInfo topMargin];
	rect.size = [self documentSizeInPage];
	return rect;
}

- (BOOL)knowsPageRange:(NSRangePointer)aRange
{
	aRange->length = numberOfPages; 
	return YES;
}

- (NSRect)rectForPage:(int)page
{
	return [self documentRectForPageNumber:page-1];  //our pages numbers start from 0; the kit's from 1
}

- (void)setPrintInfo:(NSPrintInfo *)anObject
{
	//	updates page size or margins once settings are changed
	if (printInfo != anObject)
	{
		[printInfo autorelease];
		printInfo = [anObject copy];
		[self recalculateFrame];
		//	because the page size or margins might change
		[self setNeedsDisplay:YES];
	}
}

- (NSPrintInfo *)printInfo
{
	return printInfo;
}

//	force refresh of pageview to get rid of drag lines from ruler widgets
-(void)forceViewNeedsDisplay
{
	[self setForceRedraw:YES];
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark ---- recalculateFrame ----

// ******************* recalculateFrame ********************

- (void)recalculateFrame
{
	//	upon adding or removing pages
	NSSize paperSize = [printInfo paperSize];
	NSRect newFrame = [self frame];
	//	set frame height and add a bit for clearance at bottom
	newFrame.size.height = [self numberOfPages] * (paperSize.height + [self pageSeparatorLength]) + 30;
	newFrame.size.width = paperSize.width + (2 * [self pageSeparatorLength]);
	[self setFrame:newFrame];	
	[self setBoundsSize:[self frame].size];
}


#pragma mark -
#pragma mark ---- Header/Footer ----

// ******************* Header/Footer ********************

//	if page size is too small, headers and footers overflow pagesize
//	TODO: perhaps decrease font size for small margins? or use ellipsis?

//print header according to a user preference
- (NSAttributedString *)pageHeader
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//	pointer to the current document
	JHDocument *currDoc = [[[self window] windowController] document];
	
	BOOL shouldPrintHeaderFooter = NO;
	int styleHeaderFooter = 0, pagesToSkip = 0;
		
	//doc specific setting: no header/footer
	if ([currDoc headerFooterSetting]==1) 
	{
		return nil;
	}
	//if doc-specific settings say print header/footer
	else if ([currDoc headerFooterSetting]==2)
	{
		shouldPrintHeaderFooter = YES;
		styleHeaderFooter = [currDoc headerFooterStyle];
		pagesToSkip = [currDoc headerFooterStartPage] - 1;
	}
	//or no doc-specific setting but pref setting says print header/footer
	else if ([currDoc headerFooterSetting]==0 && [[defaults valueForKey:@"prefPrintHeaderFooter"] boolValue])
	{
		shouldPrintHeaderFooter = YES;
		styleHeaderFooter = [defaults integerForKey:@"prefStyleHeaderFooterTag"];
		pagesToSkip = [defaults integerForKey:@"prefHeaderFooterPagesToSkip"] - 1;
	}
	else
	{
		return nil;
	}
	
	//	retrieve the default as to whether to print std header/footer
	if (shouldPrintHeaderFooter)
	{
		int thePageNumber;
		if (![NSPrintOperation currentOperation])
		{
			thePageNumber = [self theCurrentPage];
		}
		else
		{
			thePageNumber = [[NSPrintOperation currentOperation] currentPage];
		}
		
		int containerIndex = [[[currDoc layoutManager] textContainers] count] - 1;
		int thePageTotal = [currDoc pageNumberForContainerAtIndex:containerIndex];
		
		if (pagesToSkip)
		{
			thePageNumber = thePageNumber - pagesToSkip;
			thePageTotal = thePageTotal - pagesToSkip;
			if (thePageNumber <= 0)
			{
				return nil;
			}
		}

		NSAttributedString *headerString = nil;
		
		//	retrieve default typing attributes for cocoa
		NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		//[theParagraphStyle setAlignment:NSRightTextAlignment]; //doesn't work for headers/footers!
		
		//	align header to text body margins
		NSSize paperSize = [printInfo paperSize];
		float rightMargin = [printInfo rightMargin];
		float leftMargin = [printInfo leftMargin];
		float tabValue1 = 0.0;
		float tabValue2 = 0.0;
		tabValue1 = paperSize.width - rightMargin - 16; // 16 is to compensate for fake gray page boundary in page view
		tabValue2 = leftMargin - 16;
		//	place right tab stop about a quarter inch from the right edge of the page
		NSTextTab *tabStop1;
		NSTextTab *tabStop2;
		tabStop1 = [[[NSTextTab alloc] initWithType:NSRightTabStopType location:tabValue1] autorelease]; 		
		tabStop2 = [[[NSTextTab alloc] initWithType:NSLeftTabStopType location:tabValue2] autorelease]; 		
		[theParagraphStyle setTabStops:[NSArray arrayWithObjects:nil]];
		[theParagraphStyle addTabStop:tabStop1];
		[theParagraphStyle addTabStop:tabStop2];
		
		//	make a dictionary of the attributes
		NSMutableDictionary *theAttributes = [ [[NSMutableDictionary alloc] initWithObjectsAndKeys:theParagraphStyle, NSParagraphStyleAttributeName, nil] autorelease];
		[theParagraphStyle release];
		//	retrieve the default font name and size from user prefs; add to dictionary
		NSString *richTextFontName = [defaults valueForKey:@"prefRichTextFontName"];
		float richTextFontSize = [[defaults valueForKey:@"prefRichTextFontSize"] floatValue];
		if (richTextFontSize > 2) richTextFontSize = richTextFontSize - 1;
		//	create NSFont from name and size
		NSFont *theFont = [NSFont fontWithName:richTextFontName size:richTextFontSize];
		//	use system font on error (Lucida Grande, it's nice)
		if (theFont == nil) theFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
		//	add font to typingAttributes
		if (theFont) [theAttributes setObject:theFont forKey:NSFontAttributeName];
		
		switch (styleHeaderFooter)
		{
			case 0: // filename (left aligned) + pageNumberOfTotal (right aligned)
			{
				NSString *theDisplayName = nil;
				NSString *pageNumOfTotal = [NSString stringWithFormat:NSLocalizedString(@"Page %i of %i", @"text for header or footer: Page (current page number is inserted here) of (page total is inserted here)"), thePageNumber, thePageTotal];
				if ([currDoc fileName])
					theDisplayName = [[currDoc fileName] lastPathComponent];
				else
					theDisplayName = [currDoc displayName];
				/*
				// tab char causes strings to advance to left aligned tab at left margin or right aligned tab at right margin
				*/
				headerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%C%@%C%@",@"header: filename (inserted at runtime, left aligned) + page number of total ('Page X of Y' is a localized string inserted at runtime, right aligned)."), NSTabCharacter, theDisplayName, NSTabCharacter, pageNumOfTotal] attributes:theAttributes]autorelease];
				return headerString;
				break;
			}
			case 1: // title + page number (right aligned)
			{
				NSString *titleString = [[currDoc docAttributes] objectForKey:NSTitleDocumentAttribute];
				if (!titleString) { titleString = @""; }
				headerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%C%C%@ %i",@"header: Title property from document's Get Properties... sheet (inserted at runtime), then a space as a separator, then %i (the current page number, inserted at runtime), all right aligned. Note that you can add or change characters as needed in the localized version if appropriate for different languages and can even change the order of the two variables for right-to-left languages - see the translation instructions for Bean on how to do this."), NSTabCharacter, NSTabCharacter, titleString,  thePageNumber] attributes:theAttributes]autorelease];
				return headerString;
				break;
			}
			case 2: // author + page number (right aligned)
			{
				NSString *authorString = [[currDoc docAttributes] objectForKey:NSAuthorDocumentAttribute];
				if (!authorString) { authorString = @""; }
				headerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%C%C%@ %i",@"header: Author property from document's Get Properties... sheet (inserted at runtime), then a space as a separator, then %i (the current page number, inserted at runtime). Note that you can add or change characters as needed in the localized version if appropriate for different languages and can even change the order of the two variables for right-to-left languages - see the translation instructions for Bean on how to do this."), NSTabCharacter, NSTabCharacter, authorString, thePageNumber] attributes:theAttributes]autorelease];
				return headerString;
				break;
			}
			case 3: // nothing (except page number of page total in footer)
			{
				return nil;
				break;
			}
			case 4: // nothing (except page number in footer)
			{
				return nil;
				break;
			}
			case 5: // filepath (left aligned) + date (right aligned)
			{
				NSString *filePath = [currDoc fileName];
				if (!filePath) filePath = [currDoc displayName];
				NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init]autorelease];
				[dateFormatter setDateStyle:NSDateFormatterShortStyle];
				[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
				NSDate *today = [NSDate date];
				NSString *formattedDateString = [dateFormatter stringFromDate:today];
				
				headerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%C%@%C%@",@"header: tab, filepath (example: /Users/Document/MyDocument.RTF, inserted at runtime), tab, then localized date string (inserted at runtime)."), NSTabCharacter, filePath, NSTabCharacter, formattedDateString] attributes:theAttributes]autorelease];
				return headerString;
				break;
			}
			case 6: // filename (left aligned) + date (right aligned); footer: Page # of ##
			{
				//file's display name
				NSString *theDisplayName = nil;
				//	NSString *pageNumOfTotal = [NSString stringWithFormat:NSLocalizedString(@"Page %i of %i", @"text for header or footer: Page (current page number is inserted here) of (page total is inserted here)"), thePageNumber, thePageTotal];
				if ([currDoc fileName])
					theDisplayName = [[currDoc fileName] lastPathComponent];
				else
					theDisplayName = [currDoc displayName];
				//date
				NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
				[dateFormatter setDateStyle:NSDateFormatterShortStyle];
				[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
				NSDate *today = [NSDate date];
				NSString *formattedDateString = [dateFormatter stringFromDate:today];
				//combined header
				headerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%C%@%C%@",@"header: tab, filename (example: MyDocument.RTF, inserted at runtime), tab, localized date string (inserted at runtime)."), NSTabCharacter, theDisplayName, NSTabCharacter, formattedDateString] attributes:theAttributes]autorelease];
				return headerString;
				break;
			}
			
			
			case 8: // subject (right aligned)
			{
				// from Get Properties... sheet
				NSString *theSubject = [[currDoc docAttributes] objectForKey:NSSubjectDocumentAttribute];
				if ([theSubject length])
				{
					headerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C%C%@", NSTabCharacter, NSTabCharacter, theSubject] attributes:theAttributes]autorelease];
				}
				else
				{
					return nil;
					break;
				}
				return headerString;
				break;
			}
			case 9: // title (right aligned); footer: page number of total
			{
				NSString *titleString = [[currDoc docAttributes] objectForKey:NSTitleDocumentAttribute];
				if (!titleString) { titleString = @""; }
				headerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%C%C%@",@"header: Title property from document's Get Properties... sheet (inserted at runtime); footer: page number of total."), NSTabCharacter, NSTabCharacter, titleString] attributes:theAttributes]autorelease];
				return headerString;
				break;
			}
			case 10: // title (left aligned) + author, page# (right aligned)
			{
				NSString *titleString = [[currDoc docAttributes] objectForKey:NSTitleDocumentAttribute];
				if (!titleString) { titleString = @""; }
				NSString *authorString = [[currDoc docAttributes] objectForKey:NSAuthorDocumentAttribute];
				if (!authorString) { authorString = @""; }
				headerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%C%@%C%@ %i",@"header: tab, title, tab, author (current page number inserted here)."), NSTabCharacter, titleString, NSTabCharacter, authorString, thePageNumber] attributes:theAttributes]autorelease];
				return headerString;
				break;
			}
			default:
			{
				return [super pageHeader];
				break;
			}		
		}
	}
	else
	{
		return nil;
	}
}

//print footer according to a user preference
- (NSAttributedString *)pageFooter
{
	//	if page size is too small, headers and footers overflow pagesize
	//	TODO: perhaps decrease font size for small margins? or use ellipsis?

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//	pointer to the current document
	JHDocument *currDoc = [[[self window] windowController] document];
	
	BOOL shouldPrintHeaderFooter = NO;
	int styleHeaderFooter = 0, pagesToSkip = 0;
	
	//doc specific setting: no header/footer
	if ([currDoc headerFooterSetting]==1) return nil;
	
	//if doc-specific settings say print header/footer
	if ([currDoc headerFooterSetting]==2)
	{
		shouldPrintHeaderFooter = YES;
		styleHeaderFooter = [currDoc headerFooterStyle];
		pagesToSkip = [currDoc headerFooterStartPage] - 1;
	}
	//or no doc-specific setting but pref setting says print header/footer
	else if ([[defaults valueForKey:@"prefPrintHeaderFooter"] boolValue] && [currDoc headerFooterSetting]==0)
	{
		shouldPrintHeaderFooter = YES;
		styleHeaderFooter = [defaults integerForKey:@"prefStyleHeaderFooterTag"];
		pagesToSkip = [defaults integerForKey:@"prefHeaderFooterPagesToSkip"] - 1;
	}

	//	retrieve the default as to whether to print std header/footer
	if (shouldPrintHeaderFooter)
	{
		int thePageNumber;
		if (![NSPrintOperation currentOperation])
		{
			thePageNumber = [self theCurrentPage];
		}
		else
		{
			thePageNumber = [[NSPrintOperation currentOperation] currentPage];
		}
		int containerIndex = [[[currDoc layoutManager] textContainers] count] - 1;
		int thePageTotal = [currDoc pageNumberForContainerAtIndex:containerIndex];
		
		if (pagesToSkip)
		{
			thePageNumber = thePageNumber - pagesToSkip;
			thePageTotal = thePageTotal - pagesToSkip;
			if (thePageNumber <= 0)
			{
				return nil;
			}
		}

		NSAttributedString *footerString = nil;
		NSMutableDictionary *theAttributes = nil;

		if (styleHeaderFooter > 2 && styleHeaderFooter < 100)
		{
			//	retrieve default typing attributes for cocoa
			NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy]; //<== copy
			//[theParagraphStyle setAlignment:NSCenterTextAlignment];

			//	place right tab stop about a quarter inch from the right edge of the page
			NSSize paperSize = [printInfo paperSize];
			float tabValue1 = paperSize.width / 2;
			NSTextTab *tabStop1;
			tabStop1 = [[[NSTextTab alloc] initWithType:NSCenterTabStopType location:tabValue1] autorelease]; 		
			[theParagraphStyle setTabStops:[NSArray arrayWithObjects:nil]];
			[theParagraphStyle addTabStop:tabStop1];
			
			//	make a dictionary of the attributes
			theAttributes = [ [[NSMutableDictionary alloc] initWithObjectsAndKeys:theParagraphStyle, NSParagraphStyleAttributeName, nil] autorelease];
			[theParagraphStyle release];//<== release
			//	retrieve the default font name and size from user prefs; add to dictionary
			NSString *richTextFontName = [defaults valueForKey:@"prefRichTextFontName"];
			float richTextFontSize = [[defaults valueForKey:@"prefRichTextFontSize"] floatValue];
			if (richTextFontSize > 2) richTextFontSize = richTextFontSize - 1;
			//	create NSFont from name and size
			NSFont *theFont = [NSFont fontWithName:richTextFontName size:richTextFontSize];
			//	use system font on error (Lucida Grande, it's nice)
			if (theFont == nil) theFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
			//	add font to typingAttributes
			if (theFont) [theAttributes setObject:theFont forKey:NSFontAttributeName];
		}

		switch (styleHeaderFooter)
		{
			case 0: // filename + page number (header only)
			{
				return nil;
				break;
			}
			case 1: // title + page number (header only)
			{
				return nil;
				break;
			}
			case 2: // author + page number (header only)
			{
				return nil;
				break;
			}
			case 3: // page number of page total in footer
			{
				NSString *pageNumOfTotal = [NSString stringWithFormat:NSLocalizedString(@"Page %i of %i", @"text for header or footer: Page (current page number is inserted here) of (page total is inserted here)"), thePageNumber, thePageTotal];
				footerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C%@", NSTabCharacter, pageNumOfTotal] attributes:theAttributes]autorelease];
				return footerString;
				break;
			}
			case 4: // page number in footer
			{
				footerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C%i", NSTabCharacter, thePageNumber] attributes:theAttributes]autorelease];
				return footerString;
				break;
			}
			case 5: // filepath + date (header) ; page number of page total (footer)
			{
				NSString *pageNumOfTotal = [NSString stringWithFormat:NSLocalizedString(@"Page %i of %i", @"text for header or footer: Page (current page number is inserted here) of (page total is inserted here)"), thePageNumber, thePageTotal];
				footerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C%@", NSTabCharacter, pageNumOfTotal] attributes:theAttributes]autorelease];
				return footerString;
				break;
			}
			case 6: //page # of ## in footer
			{
				NSString *pageNumOfTotal = [NSString stringWithFormat:NSLocalizedString(@"Page %i of %i", @"text for header or footer: Page (current page number is inserted here) of (page total is inserted here)"), thePageNumber, thePageTotal];
				footerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C%@", NSTabCharacter, pageNumOfTotal] attributes:theAttributes]autorelease];
				return footerString;
				break;
			}
			case 8: // subject (header only)
			{
				return nil;
				break;
			}
			case 9: //page # of ## in footer
			{
				NSString *pageNumOfTotal = [NSString stringWithFormat:NSLocalizedString(@"Page %i of %i", @"text for header or footer: Page (current page number is inserted here) of (page total is inserted here)"), thePageNumber, thePageTotal];
				footerString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C%@", NSTabCharacter, pageNumOfTotal] attributes:theAttributes]autorelease];
				return footerString;
				break;
			}
			case 10: // title (left aligned) + author, page# (right aligned)
			{
				return nil;
				break;
			}
			default:
			{
				return [super pageFooter];
				break;
			}
		}
	}
	else
	{
		return nil;
	}	
}

#pragma mark -
#pragma mark ---- Popup Content Menu ----

// ******************* Popup Content Menu ********************

//a double-click on the PageView margin (surrounding the TextView) reveals a contextual popup menu
- (void)mouseDown:(NSEvent *)theEvent
{
	if ([theEvent clickCount] > 1)
	{
		[NSMenu popUpContextMenu:pagePopupMenu withEvent:theEvent forView:self];
	}
}

//an action in the contextual popup menu that reveals the controls in Preferences for headers and footers 
-(void)showHeaderFooterControls
{
	id pWC = [PrefWindowController sharedInstance]; 
	if ([pWC window])
	{
		//	show Preferences window
		[pWC showWindow:nil];
		[[pWC window] orderFront:nil];
		[pWC showPrintTabView:self];
	}
}

//when the PageView is double-clicked (not the TextView), the contextual popup menu initialized here is shown
-(void)initializePagePopupMenu
{
	pagePopupMenu=[[NSMenu alloc] init];  // ===== init when class is init'd, released at dealloc
	//page setup menu item
	id pageSetupItem=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Page Setup...", @"menu item (layout context menu): Page Setup...") action:@selector(doPageLayout:) keyEquivalent:@""] autorelease];
	[pagePopupMenu addItem:pageSetupItem];
	//header and footer control menu item
	id headerFooterItem=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show Header/Footer Controls", @"menu item (layout context menu): Show Header/Footer Controls") action:@selector(showHeaderFooterControls) keyEquivalent:@""] autorelease];
	[pagePopupMenu addItem:headerFooterItem];
	//
	[pagePopupMenu addItem:[NSMenuItem separatorItem]];
	//change margins menu item
	id changeMarginsItem=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Change Margins...", @"menu item (layout context menu): Change Margins...") action:@selector(showBeanSheet:) keyEquivalent:@""] autorelease];
	[changeMarginsItem setTag:3];
	[pagePopupMenu addItem:changeMarginsItem];
	//show margin guides item
	//this is validated as either show margins or hide margins through same code as menu bar item View > Show Margins
	id showMarginsItem=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Show Margins", @"menu item (layout context menu): Show Margin Guides...") action:@selector(toggleMarginsAction:) keyEquivalent:@""] autorelease];
	[pagePopupMenu addItem:showMarginsItem];
	//
	[pagePopupMenu addItem:[NSMenuItem separatorItem]];
	//fit to width item
	id fitToWidthItem=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Fit Page Width to Window", @"menu item (layout context menu): Fit Page Width to Window") action:@selector(zoomSelect:) keyEquivalent:@""] autorelease];
	[fitToWidthItem setTag:1];
	[pagePopupMenu addItem:fitToWidthItem];
	//fit to page item
	id fitPageItem=[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Fit Whole Page to Window", @"menu item (layout context menu): Fit Whole Page to Window") action:@selector(zoomSelect:) keyEquivalent:@""] autorelease];
	[fitPageItem setTag:2];
	[pagePopupMenu addItem:fitPageItem];
}


#pragma mark -
#pragma mark ---- Accessors ----

// ******************* Accessors ********************

- (void)setBackgroundColor:(NSColor *)color
{
	color = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if (color) {
		[color retain];
		[backgroundColor release];
		backgroundColor = color;
	}
}

- (NSColor *)backgroundColor
{
	return backgroundColor;
}

- (void)setTextViewBackgroundColor:(NSColor*)aColor
{
	//FIX for possible problem where color components not defined for BW colorspace
	aColor = [aColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	[aColor retain];
	[textViewBackgroundColor autorelease];
	textViewBackgroundColor = aColor;
	[self setForceRedraw:YES];
	[self setNeedsDisplay:YES];
}

-(NSColor *)textViewBackgroundColor
{
	return textViewBackgroundColor;
}

- (int)numberOfPages
{
	return numberOfPages;
}

-(void)setNumberOfPages:(int)newNumberOfPages
{
	numberOfPages = newNumberOfPages;
}

- (void)setShouldUseAltTextColors:(BOOL)flag
{
	shouldUseAltTextColors = flag;
}

- (BOOL)shouldUseAltTextColors
{
	return shouldUseAltTextColors;
}

-(float)pageSeparatorLength
{
	return 15.0;
}

- (BOOL)showMarginsGuide
{
	return showMarginsGuide;
}

- (void)setShowMarginsGuide:(BOOL)flag
{
	showMarginsGuide = flag;
	[self setForceRedraw:YES];
	[self setNeedsDisplay:YES];
}

- (BOOL)showRulerWidgets
{
	return showRulerWidgets;
}

- (void)setShowRulerWidgets:(BOOL)flag
{
	showRulerWidgets = flag;
}

- (BOOL)showPageShadow
{
	return showPageShadow;
}

- (void)setShowPageShadow:(BOOL)flag
{
	//yes means initially set up ruler, no means no need
	showPageShadow = flag;
}

-(NSRect)previousVisibleRect
{
	return previousVisibleRect;
}

-(void)setPreviousVisibleRect:(NSRect)aRect
{
	previousVisibleRect = aRect;
}

-(BOOL)forceRedraw
{
	return forceRedraw;
}

-(void)setForceRedraw:(BOOL)flag
{
	forceRedraw = flag;
}

//	header/footer page count helper method
-(void)setTheCurrentPage:(int)newCurrentPage
{
	theCurrentPage = newCurrentPage;
}

-(int)theCurrentPage
{
	return theCurrentPage;
}

-(int)firstPageVisible
{
	return firstPageVisible;
}

-(void)setFirstPageVisible:(int)i
{
	firstPageVisible = i;
}

-(int)highPageNumVisible
{
	return highPageNumVisible;
}

-(void)setHighPageNumVisible:(int)pageNum
{
	if (highPageNumVisible != pageNum)
	{
		highPageNumVisible = pageNum;
		//check if visible yet; otherwise, crash can occur
		if ([[self window] isVisible])
		{
			id nc = [NSNotificationCenter defaultCenter];
			//notify document to update status bar, which indicates range of pages visible in this view
			[nc postNotificationName:@"PagesVisibleInPageViewDidChangeNotification" object:self];
		}
	}
}

-(int)lowPageNumVisible
{
	return lowPageNumVisible;
}

-(void)setLowPageNumVisible:(int)pageNum
{
	if (lowPageNumVisible != pageNum)
	{
		lowPageNumVisible = pageNum;
		//check if visible yet; otherwise, crash can occur
		if ([[self window] isVisible])
		{
			id nc = [NSNotificationCenter defaultCenter];
			//notify document to update status bar, which indicates range of pages visible in this view
			[nc postNotificationName:@"PagesVisibleInPageViewDidChangeNotification" object:self];
		}
	}
}

@end
