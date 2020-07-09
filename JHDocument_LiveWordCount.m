/*
	JHDocument_LiveWordCount.m
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
 
#import "JHDocument_LiveWordCount.h"
#import "JHDocument_PageLayout.h" //pageNumberForContainerAtIndex
#import "PageView.h" //isKindOfClass:[PageView class]
//#import "TextFinder.h" //for numberOfMatchesForRegex (count, then remove newlines from character total)
#import "GLOperatingSystemVersion.h"

@implementation JHDocument ( JHDocument_LiveWordCount )

#pragma mark -
#pragma mark ---- Statistics Sheet and Counting Methods  ----

// ******************* Statistics Sheet / Live Word Count Methods ********************

// ******************* Live Word Count ********************
-(IBAction)liveWordCount:(id)sender
{
	if (![self shouldDoLiveWordCount])
		return;

	//	method is called by notification sometimes when opening a document before theScrollView responds -- why?
	//	ex: start app; show Get Info sheet; dismiss sheet; close window; File > New
	//	check for that here
	if (!theScrollView || ![theScrollView respondsToSelector:@selector(documentView)])
		return;

	if ([[sender object] isKindOfClass:[PageView class]] && [sender object]!=[theScrollView documentView] )
		//notification not meant for us
		return;

	//if layout just finished (but still ![self showPageNumbers]), turn on visible page range in status bar
	BOOL pageRangeChanged = NO;
	if ([sender respondsToSelector:@selector(name)] && [[sender name] isEqualToString:@"PagesVisibleInPageViewDidChangeNotification"])
	{
		pageRangeChanged = YES;
	}
	if (![self showPageNumbers] && pageRangeChanged)
	{
		[self setShowPageNumbers:YES];
	}

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL showPageNumbersInStatusBar = [defaults boolForKey:@"prefShowPageNumbersInStatusBar"];
	PageView *pageView = [theScrollView documentView];
	//	live word count
	numberOfWords = [textStorage wordCount];
	numberOfChars =  [textStorage length];
	
	//NOTE: can remove newLines from total of characters by using regex, but I'm not sure it's work the extra 10% cpu time;
	//can do a total in the Get Info panel with the newlines removed
	
	//int newLines = [[textStorage string] numberOfMatchesForRegex:@"\n" options:0 sender:NULL];
	//numberOfChars = numberOfChars - newLines;
	
	NSString *liveWordCountString;
	//	to avoid confusing display of page numbers incrementing while layout engine is paginating a file that has just been loaded, we have an accessor here; accessor showPageNumbers is set to YES when initial layout is done 
	if ([self hasMultiplePages] && showPageNumbersInStatusBar && [self showPageNumbers])
	{

		int lastContainerIndex = [[[self layoutManager] textContainers] count] - 1;
		int numPages = [self pageNumberForContainerAtIndex:lastContainerIndex];
		int highPage = 0;
		int lowPage = 0;

		lowPage = [pageView lowPageNumVisible];
		highPage = [pageView highPageNumVisible];
		
		//NSLog([NSString stringWithFormat:@"%i, %i", lowPage, highPage]);
		
		NSString *pageNumbersString;
		NSString *pagesString;
		NSString *ofString = NSLocalizedString(@"statusbar string:(space)of(space)", @"word _of_ in status bar: range of visible pages(space)of(space)total pages");
		if (lowPage && highPage && lowPage != highPage)
		{
			pageNumbersString = [NSString stringWithFormat:@"%i-%i%@%i", lowPage, highPage, ofString, numPages];
			pagesString = NSLocalizedString(@" Pages:", @"status bar label for number of pages in document (pages, *plural*): Pages:");
		}
		else if (lowPage && highPage && lowPage == highPage)
		{
			pageNumbersString = [NSString stringWithFormat:@"%i%@%i", lowPage, ofString, numPages];
			pagesString = NSLocalizedString(@" Page:", @"status bar label for number of pages in document  (page, *singular*): Page:");
		}
		else
		{
			pageNumbersString = [NSString stringWithFormat:@"%i", numPages];
			pagesString = NSLocalizedString(@" Pages:", @"status bar label for number of pages in document (pages, *plural*): Pages:");
		}
		liveWordCountString = [[NSString alloc] initWithFormat:@"%@ %@ %@ %@ %@ %@", NSLocalizedString(@"Words:", @"Status bar label for number of words in document: Words:"), [self thousandFormatedStringFromNumber:[NSNumber numberWithInt:numberOfWords]], NSLocalizedString(@" Characters:", @"status bar label for number of characters in document: Characters:"), [self thousandFormatedStringFromNumber:[NSNumber numberWithInt:numberOfChars]], pagesString, pageNumbersString];
	}
	else
	{
		liveWordCountString = [[NSString alloc] initWithFormat:@"%@ %@ %@ %@", 
			NSLocalizedString(@"Words:", @"Status bar label for number of words in document: Words:"),
			[self thousandFormatedStringFromNumber:[NSNumber numberWithInt:numberOfWords]],
			NSLocalizedString(@" Characters:", @"status bar label for number of characters in document: Characters:"),
			[self thousandFormatedStringFromNumber:[NSNumber numberWithInt:numberOfChars]]];
	}
	//set string
	[liveWordCountField setStringValue:liveWordCountString];
	
	BOOL isTiger = NO;
	if ([GLOperatingSystemVersion isBeforeLeopard])
	{
		isTiger = YES;
	}
	//bugfix: textfield for word count doesn't update display in Tiger; force it to (setNeedsDisplay:YES doesn't do the job)
	if (pageRangeChanged && isTiger)
	{
		[liveWordCountField display];
	}
	
	[liveWordCountString release];
	numberOfWords = 0;
	numberOfChars = 0;
	[liveWordCountField setTextColor:[NSColor blackColor]];
}

//	borrowed from Smultron!
- (NSString *)thousandFormatedStringFromNumber:(NSNumber *)number
{
	return [thousandFormatter stringFromNumber:number];
}

/*
//this is what we formerly used to count words; it produced good results, but its downside was that it
//		counted hyphenated, em-dashed, etc. phrases as one word; it would slow down and become annoying
//		around 1M words (it would only fire after two seconds of user non-activity to decrease the perception
//		of lag time) 
- (unsigned)wordCountForString:(NSString *)textString
{
	numberOfWords = 0;
	NSScanner *scanner = [NSScanner scannerWithString:textString];
	while (![scanner isAtEnd])
	{
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
		if ([scanner scanCharactersFromSet:[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] intoString:nil])
			numberOfWords++;
	}
	return numberOfWords;
}
*/

//	from Keith Blount's KSWordCountingTextStorage - we use this for consistancy with the live word count
//	called by the textSystemDelegate
- (unsigned)wordCountForString:(NSAttributedString *)tmpString
{
	unsigned wc = 0;
	NSCharacterSet *lettersAndNumbers = [NSCharacterSet alphanumericCharacterSet];
	int index = 0;
	while (index < ([tmpString length]))
	{
		int newIndex = [tmpString nextWordFromIndex:index forward:YES];
		NSString *word = [[tmpString string] substringWithRange:NSMakeRange(index, newIndex-index)];
		// Make sure it is a valid word - ie. it must contain letters or numbers, otherwise don't count it
		if ([word rangeOfCharacterFromSet:lettersAndNumbers].location != NSNotFound)
			{ wc++; }
		index = newIndex;
	}
	return wc;
}

// ******************* Turn Live Word Counting On and Off ********************

//	
-(IBAction)selectLiveWordCounting:(id)sender
{
	if ([sender state]==NSOnState) 
	{
		[sender setState:NSOffState];
		[self setShouldDoLiveWordCount:NO];
		[liveWordCountField setTextColor:[NSColor darkGrayColor]];
		[liveWordCountField setObjectValue:NSLocalizedString(@"B  E  A  N", @"status bar label: B  E  A  N")];	
	}
	//	turn live word counting on
	else
	{ 
		[sender setState:NSOnState];
		[self setShouldDoLiveWordCount:YES];
		[liveWordCountField setTextColor:[NSColor blackColor]];
	}
}

@end
