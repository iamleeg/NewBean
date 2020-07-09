/*
	JHDocument_DocAttributes.m
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
 
#import "JHDocument_DocAttributes.h"
#import "JHDocument_Initialize.h" //contentViewSize, applyContentViewSize
#import "JHDocument_FullScreen.h" //shouldRestoreAltTextColors
#import "JHDocument_ReadWrite.h" //textLengthIsZero accessor
#import "JHDocument_Backup.h" //beginAutosavingDocument
#import "JHDocument_Print.h" //printInfoUpdates
#import "JHDocument_View.h" //toggleLayoutView, updateZoomSlider
#import "JHDocument_AltColors.h" //switchTextColors
#import "GLOperatingSystemVersion.h"

@implementation JHDocument ( JHDocument_DocAttributes )

#pragma mark -
#pragma mark ---- Document Attributes ----

//	******************* Document Attributes ********************

//	returns a dictionary of document-wide attribtues
//	we use this object to remember Get Properties sheet keywords as well
-(NSDictionary *)docAttributes
{
	return docAttributes;
}

//	update dictionary of document-wide attributes, for instance when a file is read-in or Get Properties sheet is used
-(void)setDocAttributes:(NSDictionary *)newDocAttributes
{
	if (newDocAttributes && ![newDocAttributes isEqualTo:nil])
	{
		[docAttributes autorelease];
		docAttributes = [newDocAttributes copy];
	}
}

//	returns a dictionary of document attributes, used when saving files
//	also, creates docAttributes object when none exists to keep track of things from, eg, Get Properties panel

//	TODO: all this stuff being placed in keywords should go into the resource fork, since none of it is crucial content!!!

- (NSMutableDictionary *) createDocumentAttributesDictionary
{
	//	view scale
	float zoomValue = [zoomSlider floatValue];
	
	//	open in layout view? layout view = 1; continuous view = 0 
	//	historical note: formerly, we also did viewmode 2 (fitWidth) and 3 (fitPage)
	//	but Word opens these in outline mode; so we handle those viewmodes now with keywords.
	int showLayout = [self hasMultiplePages];
	
	//	create a 'keyword' for saving the cursor location
	//	TODO: shouldn't add these kinds of keywords in for HTML export
	int cursorLoc = [[self firstTextView] selectedRange].location;
	NSString *cursorLocation = nil;
	if (cursorLoc > 0) { cursorLocation = [NSString stringWithFormat:@"cursorLocation=%i", cursorLoc]; }
	
	//	create a 'keyword' for saving the Fit to Width/Fit to Page if needed  // 12 MAY 08 JH
	NSString *fitViewType = nil;
	if ([theScrollView isFitWidth]) { fitViewType = @"fitsPagesWidth=1"; }
	if ([theScrollView isFitPage]) { fitViewType = @"fitsWholePages=1"; }
	
	//	create a 'keyword' for saving key that tells whether to do automaticBackup at close
	NSString *automaticBackup = nil;
	if ([self shouldCreateDatedBackup]) { automaticBackup = @"automaticBackup=1"; } 
	
	//	create a 'keyword' for saving alt colors if shouldUseAltTextColors AND not using them only because of full screen mode
	NSString *alternateColors = nil;
	
	if ([self shouldUseAltTextColors] && ![self shouldRestoreAltTextColors]
				&& !([self fullScreen] && [self shouldUseAltTextColors] && ![self shouldUseAltTextColorsInNonFullScreen]))
	{
		alternateColors = @"alternateColors=1";
	}
	
	//	create a 'keyword' to inform Bean that the text is supposed to be zero length (but one character was saved to preserve attributes)
	//	zeroLengthText1 means delete placeholder character upon opening document
	NSString *zeroLengthText = nil;
	if ([self textLengthIsZero]) { zeroLengthText = @"zeroLengthText=1"; }
	
	//	create a 'keyword' for saving whether to do Autosave
	NSString *autosaveInterval = nil;
	if ([self doAutosave])
	{
		if ([self autosaveTime])
		{
			autosaveInterval = [NSString stringWithFormat:@"autosaveInterval=%i", [self autosaveTime]];
		}
	}
	
	//save header/footer settings when Format > Header/Footer... > Lock settings for header/footer is selected
	NSString *headerFooter = nil;
	if ([self headerFooterSetting] > 0)
	{
		headerFooter = [NSString stringWithFormat:@"headerFooter=%istyle=%istartPage=%i", [self headerFooterSetting] - 1, [self headerFooterStyle], [self headerFooterStartPage]];
	}

	//columns
	NSString *columns = nil;
	if ([self numberColumns] > 1)
	{
		columns = [NSString stringWithFormat:@"columns=%igutter=%i", [self numberColumns], [self columnsGutter]];
	}

	//	keywords array holds keywords from docAttributes dictionary plus our special document attribute keywords
	NSMutableArray *keywords = [NSMutableArray arrayWithCapacity:0];
	NSArray *anArray = [[self docAttributes] objectForKey:NSKeywordsDocumentAttribute];
	if ([anArray count])
		[keywords addObjectsFromArray:[NSArray arrayWithArray:anArray]];
	//	add special Bean keywords
	if (cursorLocation) { [keywords addObject:cursorLocation]; }
	if (automaticBackup) { [keywords addObject:automaticBackup]; }
	if (autosaveInterval) { [keywords addObject:autosaveInterval]; }
	if (zeroLengthText) { [keywords addObject:zeroLengthText]; }
	if (alternateColors) { [keywords addObject:alternateColors]; }
	if (fitViewType) { [keywords addObject:fitViewType]; } // 12 MAY 08 JH
	if (headerFooter) { [keywords addObject:headerFooter]; } //18 NOV 08 JH
	if (columns) { [keywords addObject:columns]; } //18 NOV 08 JH
	
	//don't save 'alt colors' background color as document background color
	NSColor *backgroundColor;
	
	if ([self shouldUseAltTextColors] && [[self firstTextView] allowsDocumentBackgroundColorChange]) 
	{
		backgroundColor = [self theBackgroundColor];
	}
	else if ([self shouldUseAltTextColors] && ![[self firstTextView] allowsDocumentBackgroundColorChange])
	{
		backgroundColor = [NSColor whiteColor];
	}
	else
	{
		backgroundColor = [[self firstTextView] backgroundColor];
	}
	
	//	create document attributes dictionary
	//	NOTE: for some reason, NSKeywordDocumentAttribute must precede the 'string' property attrs or it is not saved
	//	NSViewSize is window size
	//	we ceil NSViewZoomDocAttr so saved value = slider value
	NSMutableDictionary *dict;
	dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSValue valueWithSize:[self contentViewSize]], NSViewSizeDocumentAttribute, 
				[NSNumber numberWithInt:showLayout], NSViewModeDocumentAttribute,
				[NSValue valueWithSize:[self paperSize]], NSPaperSizeDocumentAttribute, 
				[NSNumber numberWithFloat:ceil(zoomValue * 100)], NSViewZoomDocumentAttribute, 
				[NSNumber numberWithInt:[self readOnlyDoc] ? 1 : 0], NSReadOnlyDocumentAttribute, 
				[NSNumber numberWithFloat:[[self printInfo] leftMargin]], NSLeftMarginDocumentAttribute, 
				[NSNumber numberWithFloat:[[self printInfo] rightMargin]], NSRightMarginDocumentAttribute, 
				[NSNumber numberWithFloat:[[self printInfo] bottomMargin]], NSBottomMarginDocumentAttribute, 
				[NSNumber numberWithFloat:[[self printInfo] topMargin]], NSTopMarginDocumentAttribute,
				backgroundColor, NSBackgroundColorDocumentAttribute, 
				keywords, NSKeywordsDocumentAttribute,		
				[[self docAttributes] valueForKey:NSAuthorDocumentAttribute], NSAuthorDocumentAttribute,
				[[self docAttributes] valueForKey:NSCompanyDocumentAttribute], NSCompanyDocumentAttribute,
				[[self docAttributes] valueForKey:NSCopyrightDocumentAttribute], NSCopyrightDocumentAttribute,
				[[self docAttributes] valueForKey:NSTitleDocumentAttribute], NSTitleDocumentAttribute,
				[[self docAttributes] valueForKey:NSSubjectDocumentAttribute], NSSubjectDocumentAttribute,
				[[self docAttributes] valueForKey:NSCommentDocumentAttribute], NSCommentDocumentAttribute,
				[[self docAttributes] valueForKey:NSEditorDocumentAttribute], NSEditorDocumentAttribute,
				nil];
	
	return dict;
}

//	use document attributes dictionary to set paper size, margins, etc.
-(void)applyDocumentAttributes
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id val;
	BOOL fitWidthOrPageIsActive = NO;

	// the following code determines whether document is automatically overwritten later; for instance, Word docs created in Word are always lossy when opened in Bean, but Word docs created in Bean are not lossy, so we warn before overwriting in the first case (in the 'Save' routines), but not in the second case
	int wasConvertedVal;
	wasConvertedVal = [[docAttributes objectForKey:NSConvertedDocumentAttribute] intValue];
	// conversion may have been lossy 
	//	note: nil filename means was imported as Untitled so lossy conversion does not matter
	if (wasConvertedVal < 0 && [self fileName]) { [self setLossy:YES]; }
	// conversion was not lossy
	else if (wasConvertedVal > 0) { [self setLossy:NO]; }
	//	file was original format, or locked and imported as Untitled
	else { [self setLossy:NO]; }
	
	//get keyword array, remove and use cursorLocation, use document properties array
	if (val = [docAttributes objectForKey:NSKeywordsDocumentAttribute])
	{
		NSMutableArray *keywords = [NSMutableArray arrayWithCapacity:0];
		[keywords addObjectsFromArray:[NSArray arrayWithArray:val]];
		unsigned cnt = [keywords count];
		while (cnt-- > 0)
		{
			NSString *keywordString = [[NSString alloc] initWithString:[keywords objectAtIndex:cnt]];
			if ([keywordString length] > 15)
			{
				//	searches for cursorLocation= string and if found retrieves the int and makes it the location of the selected range
				//	note: tested for breakage (eg, if cursorLocation=banana) 30 JUL 08 JH
				if ([keywordString length] > 14 && [[keywordString substringWithRange:NSMakeRange(0, 15)] isEqualToString:@"cursorLocation="])
				{
					if ([defaults boolForKey:@"prefRestoreCursorLocation"])
					{
						//	intValue on a string returns 0 is not decimal text representation of number, which is OK for us
						int cursorLocation = [[keywordString substringFromIndex:15] intValue];
						if (cursorLocation > 0 && cursorLocation < ([textStorage length] + 1))
						{
							[[self firstTextView] setSelectedRange:NSMakeRange(cursorLocation, 0)];
						}
					}
					[keywords removeObjectAtIndex:cnt];
				}
				//	searches for automaticBackup= string and if found set accessor to do it at document close
				if ([keywordString length] > 15 && [[keywordString substringWithRange:NSMakeRange(0, 16)] isEqualToString:@"automaticBackup="])
				{
					//	intValue should return 0 at bad info here, which just means to backup
					BOOL automaticBackup = [[keywordString substringFromIndex:16] intValue];
					if (automaticBackup == YES) { [self setShouldCreateDatedBackup:YES]; }
					[keywords removeObjectAtIndex:cnt];
				}
				//	searches for shouldAutosave= string and if found set accessor to do it at document close
				if ([keywordString length] > 16 && [[keywordString substringWithRange:NSMakeRange(0, 17)] isEqualToString:@"autosaveInterval="])
				{
					//	intValue should return 0 at bad info here, which just means to backup
					int autosaveInterval = [[keywordString substringFromIndex:17] intValue];
					//	start autosave if interval is meaningful
					if (autosaveInterval > 0 && autosaveInterval < 61)
					{
						[self setDoAutosave:YES];
						[self setAutosaveTime:autosaveInterval];
						[self beginAutosavingDocumentWithInterval:autosaveInterval];
					}
					[keywords removeObjectAtIndex:cnt];
				}
				//	searches for cursorLocation= string and if found retrieves the int and makes it the location of the selected range
				if ([keywordString length] > 15 && [[keywordString substringWithRange:NSMakeRange(0, 16)] isEqualToString:@"alternateColors="])
				{
					//	intValue should return 0 at bad info here, which results in no alt colors
					BOOL alternateColors = [[keywordString substringFromIndex:16] intValue];
					if (alternateColors && ![self shouldUseAltTextColors])
					{
						[self switchTextColors:self];
					}
					[keywords removeObjectAtIndex:cnt];
				}
				//	searches for cursorLocation= string and if found retrieves the int and makes it the location of the selected range
				if ([keywordString length] > 14 && [[keywordString substringWithRange:NSMakeRange(0, 15)] isEqualToString:@"zeroLengthText="])
				{
					//	intValue should return 0 at bad info here, which just means to backup
					BOOL zeroLength = [[keywordString substringFromIndex:15] intValue];
					if (zeroLength && [textStorage length]==1)
					{
						NSDictionary *charAttributes = [textStorage attributesAtIndex:0 effectiveRange:NULL];
						[textStorage deleteCharactersInRange:NSMakeRange(0, 1)];
						if (charAttributes)
						{
							[[self firstTextView] setTypingAttributes:charAttributes];
						}
					}
					[keywords removeObjectAtIndex:cnt];
				}
				//	moved settings for fitWidth/fitPage to keywords to avoid opening document in outline view in MS Word! 12 MAY 08 JH
				//	searches for fitsPagesWidth=1 string and if found set accessor to do it at document open
				if ([keywordString length] > 14 && [[keywordString substringWithRange:NSMakeRange(0, 15)] isEqualToString:@"fitsPagesWidth="])
				{
					//	intValue should return 0 at bad info here, which just means to ignore
					BOOL fitWidth = [[keywordString substringFromIndex:15] intValue];
					if (fitWidth == YES)
					{ 
						[theScrollView setIsFitWidth:YES];
						[theScrollView setIsFitPage:NO];
						fitWidthOrPageIsActive = YES;
					}
					[keywords removeObjectAtIndex:cnt];
				}
				//	searches for fitsWholePages=1 string and if found set accessor to do it at document open
				if ([keywordString length] > 14 && [[keywordString substringWithRange:NSMakeRange(0, 15)] isEqualToString:@"fitsWholePages="])
				{
					//	intValue should return 0 at bad info here, which just means to ignore
					BOOL fitPage = [[keywordString substringFromIndex:15] intValue];
					if (fitPage == YES)
					{ 
						[theScrollView setIsFitWidth:NO];
						[theScrollView setIsFitPage:YES];
						fitWidthOrPageIsActive = YES;
					}
					[keywords removeObjectAtIndex:cnt];
				}

				//	searches for fitsWholePages=1 string and if found set accessor to do it at document open
				if ([keywordString length] > 31 && [[keywordString substringWithRange:NSMakeRange(0, 13)] isEqualToString:@"headerFooter="])
				{
					//	error on these items should result in 0, which is okay
					BOOL printHeaderFooter = [[keywordString substringFromIndex:13] intValue]; 
					if (!printHeaderFooter)
					{
						//don't show header/footer and ignore pref settings
						[self setHeaderFooterSetting:1];
					}
					else
					{
						//show header/footer and ignore pref settings
						[self setHeaderFooterSetting:2];
						//	get style of header footer
						int theHeaderFooter = [[keywordString substringWithRange:NSMakeRange(20, 1)] intValue];
						if (theHeaderFooter < 10)
						{ 
							[self setHeaderFooterStyle:theHeaderFooter];
							int theStartPage = [[keywordString substringFromIndex:31] intValue];
							[self setHeaderFooterStartPage:theStartPage];
						}
					}
					[keywords removeObjectAtIndex:cnt];
				}
				
				//
				if ([keywordString length] > 16 && [[keywordString substringWithRange:NSMakeRange(0, 8)] isEqualToString:@"columns="])
				{
					//	error on these items should result in 0, which skips this code (default is 1)
					int columns = [[keywordString substringWithRange:NSMakeRange(8, 1)] intValue]; 
					if (columns > 0 && columns < 6)
					{
						//show header/footer and ignore pref settings
						[self setNumberColumns:columns];
						//	get style of header footer
						int gutter = [[keywordString substringFromIndex:16] intValue];
						if (gutter >= 0 && gutter < 50)
						{ 
							[self setColumnsGutter:gutter];
						}
						else
						{
							[self setColumnsGutter:15];
						}
					}
					[keywords removeObjectAtIndex:cnt];
				}
			}
			[keywordString release];
		}
		// replace 'keywords' array in docAttributes with revised array, retaining Author, Title, etc. but without special Bean keywords
		NSMutableDictionary *revisedDocAttributes;
		revisedDocAttributes = [[docAttributes mutableCopy] autorelease];
		if (revisedDocAttributes)
		{
			[revisedDocAttributes setObject:keywords forKey:NSKeywordsDocumentAttribute];
		}
		[self setDocAttributes:revisedDocAttributes];
	}
	
	//	note: contentViewSize (= NSViewSizeDocumentAttribute) is frame size of contentView of docWindow
	if (val = [docAttributes objectForKey:NSViewSizeDocumentAttribute]) 
	{
		[self applyContentViewSize:[val sizeValue]];
	}
	
	//	get paperSize
	if (val = [docAttributes objectForKey:NSPaperSizeDocumentAttribute])
	{
		NSSize paperSize = [val sizeValue];
		// BUGFIX: .doc and .odt types *always* open is US letter (Cocoa file filter doesn't read paper size)
		//	so use default paper size setting from system print user prefs 14 AUG 09 JH
		id docType = [docAttributes objectForKey:NSDocumentTypeDocumentAttribute];
		if ([GLOperatingSystemVersion isAtLeastLeopard] && (docType==NSDocFormatTextDocumentType || docType==NSOpenDocumentTextDocumentType))
		{
			//get user pref paper size
			NSSize aSize = [[[[NSPrintInfo sharedPrintInfo] dictionary] objectForKey:NSPrintPaperSize] sizeValue];
			//safety check
			if (!NSEqualSizes(aSize, NSZeroSize))
				paperSize = aSize;
		}
		else if ([GLOperatingSystemVersion isBeforeLeopard] && docType==NSDocFormatTextDocumentType)
		{
			//get user pref paper size
			NSSize aSize = [[[[NSPrintInfo sharedPrintInfo] dictionary] objectForKey:NSPrintPaperSize] sizeValue];
			//safety check
			if (!NSEqualSizes(aSize, NSZeroSize))
				paperSize = aSize;
		}
		[self setPaperSize:paperSize];
	}
	
	//set background color
	if (val = [docAttributes objectForKey:NSBackgroundColorDocumentAttribute])
	{
		[self setTheBackgroundColor:val];
		[[self firstTextView] setBackgroundColor: [self theBackgroundColor]];
		[theScrollView setBackgroundColor:[NSColor lightGrayColor]];
	}

	//	zoom value / view scale
	if (val = [docAttributes objectForKey:NSViewZoomDocumentAttribute])
	{
		[theScrollView setScaleFactor:[val floatValue] / 100];
		[self updateZoomSlider];
	}
	// prevent nil value
	if ([theScrollView scaleFactor]==0)
	{
		[theScrollView setScaleFactor:1.0];
		[self updateZoomSlider];
	}
	
	//	get margins
	if (val = [docAttributes objectForKey:NSLeftMarginDocumentAttribute]) { [[self printInfo] setLeftMargin:[val floatValue]]; }
	if (val = [docAttributes objectForKey:NSRightMarginDocumentAttribute]) { [[self printInfo] setRightMargin:[val floatValue]]; }
	if (val = [docAttributes objectForKey:NSBottomMarginDocumentAttribute]) { [[self printInfo] setBottomMargin:[val floatValue]]; }
	if (val = [docAttributes objectForKey:NSTopMarginDocumentAttribute]) { [[self printInfo] setTopMargin:[val floatValue]]; }
	
	//	special case: document-wide attributes are not saved for the following formats, and cocoa defaults are weird, so we provide some default margins for these formats: Word, HTML, WebArchive, Text
	if (val = [docAttributes objectForKey:NSDocumentTypeDocumentAttribute])
	{
		if (val==NSDocFormatTextDocumentType || 
				val==NSHTMLTextDocumentType ||
				val==NSWebArchiveTextDocumentType ||
				val==NSPlainTextDocumentType)
			[self applyDefaultDocumentAttributes];
		else if ([GLOperatingSystemVersion isAtLeastLeopard] && val == NSOpenDocumentTextDocumentType)
			[self applyDefaultDocumentAttributes];
	}
	
	//	set layout view on/off per NSViewModeDocumentAttribute; 0=continuous, 1=layout view
	//	NOTE: in old bean files: 2=fitWidth, 3=fitPage; settings will resave as keywords
	//	note: Text Edit treats ints > 1 as Page Layout
	//	because layout is default, toggle to continuous text view if needed before layout occurs
	if ([[docAttributes objectForKey:NSViewModeDocumentAttribute] intValue]==0 && ![self isTransientDocument])
	{
		[self setShowLayoutView:NO];
	}

	//	since these higher number values (2, 3) cause problems when documents are opened in Word (where they mean 'open in outline view'), we stick this information into the keywords field of the document now (*ahem* complain at the desk), but we still look for these values in old Bean documents. 12 MAY 08 JH
	//	fit width
	else if ([[docAttributes objectForKey:NSViewModeDocumentAttribute] intValue]==2)
	{
		[theScrollView setIsFitWidth:YES];
		[theScrollView setIsFitPage:NO];
	}
	//	fit page
	else if ([[docAttributes objectForKey:NSViewModeDocumentAttribute] intValue]==3)
	{
		[theScrollView setIsFitWidth:NO];
		[theScrollView setIsFitPage:YES];
	}
		
	//	arbitrary zoom - neither fit width nor fit height
	else if ([[docAttributes objectForKey:NSViewModeDocumentAttribute] intValue]==1)
	{
		//to prevent keywords setting set above being reversed
		if (!fitWidthOrPageIsActive)
		{
			[theScrollView setIsFitWidth:NO];
			[theScrollView setIsFitPage:NO];
		}
	} 
	//for new documents -- fit pages width preference
	else
	{
		if ([defaults boolForKey:@"prefUseFitWidth"])
		{
			[theScrollView setIsFitWidth:YES];
			[theScrollView setIsFitPage:NO];
		}
		else
		{
			[theScrollView setIsFitWidth:NO];
			[theScrollView setIsFitPage:NO];
		}
	}
	
	//	setReadOnly
	if ([docAttributes objectForKey:NSReadOnlyDocumentAttribute])
	{
		//	means we can look and we can save but we can't edit
		[self setReadOnlyDoc:YES];
		[[self firstTextView] setEditable:NO];
	}
}

-(void)applyDefaultMargins
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	//	get left margin from defaults in preferences
	float leftMargin = 0;
	leftMargin = [defaults boolForKey:@"prefIsMetric"] 
		? [[defaults valueForKey:@"prefDefaultLeftMargin"] floatValue] * 28.35 
		: [[defaults valueForKey:@"prefDefaultLeftMargin"] floatValue] * 72.0;
	if (leftMargin) { [printInfo setLeftMargin:leftMargin]; }
	else { [printInfo setLeftMargin:0]; }
	
	//	get right margin from defaults in preferences
	float rightMargin = 0;
	rightMargin = [defaults boolForKey:@"prefIsMetric"] 
		? [[defaults valueForKey:@"prefDefaultRightMargin"] floatValue] * 28.35 
		: [[defaults valueForKey:@"prefDefaultRightMargin"] floatValue] * 72.0;
	if (rightMargin) { [printInfo setRightMargin:rightMargin]; }
	else { [printInfo setRightMargin:0]; }
	
	//	get top margin from defaults in preferences
	float topMargin = 0;
	topMargin = [defaults boolForKey:@"prefIsMetric"] 
		? [[defaults valueForKey:@"prefDefaultTopMargin"] floatValue] * 28.35 
		: [[defaults valueForKey:@"prefDefaultTopMargin"] floatValue] * 72.0;
	if (topMargin) { [printInfo setTopMargin:topMargin]; }
	else { [printInfo setTopMargin:0]; }
	
	//	get bottom margin from defaults in preferences
	float bottomMargin = 0;
	bottomMargin = [defaults boolForKey:@"prefIsMetric"] 
		? [[defaults valueForKey:@"prefDefaultBottomMargin"] floatValue] * 28.35 
		: [[defaults valueForKey:@"prefDefaultBottomMargin"] floatValue] * 72.0;
	if (bottomMargin) { [printInfo setBottomMargin:bottomMargin]; }
	else { [printInfo setBottomMargin:0]; }
}

// when needed, set margins based on user Preferences
-(void)applyDefaultDocumentAttributes
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	//moved to separate method
	[self applyDefaultMargins];

	//	use custom zoom if 1) pref says so, or 2) plain text and pref says to ignore 1) 26 JAN 08 JH 
	if (![defaults boolForKey:@"prefUseFitWidth"] || // ===== note that remainder is bracketed
				([defaults boolForKey:@"prefUseFitWidth"]
				&& [defaults boolForKey:@"prefDontUseFitWidthForPlainText"]
				&& ![[self firstTextView] isRichText]))
	{
		[theScrollView setIsFitWidth:NO]; //25 JAN 08 JH
		[theScrollView setIsFitPage:NO];
		//	get prefDefaultZoom from user defaults
		float defaultScaleFactor;
		//	convert to a scale factor
		defaultScaleFactor = [[defaults valueForKey:@"prefDefaultZoom"] floatValue] / 100.0;
		//	watch for errors
		if (defaultScaleFactor < 0.1 || defaultScaleFactor > 4.0) defaultScaleFactor = 1.2;
		//	and set the zoom scale
		[theScrollView setScaleFactor:defaultScaleFactor];
		[self updateZoomSlider];	
	}
	//	use fit width if pref says so
	else
	{
		[theScrollView setIsFitWidth:YES]; //25 JAN 08 JH
		[theScrollView setIsFitPage:NO];
		float scaleFactor = [[[theScrollView documentView] superview] frame].size.width / [[theScrollView documentView] frame].size.width;
		[theScrollView setScaleFactor:scaleFactor];
		[self updateZoomSlider];
	}
	
	//	if pref says so, use saved default window size if available; otherwise, use original nib size ('Factory Setting')
	if ([defaults boolForKey:@"prefUseCustomWindowSize"])
	{
		if ([defaults stringForKey:@"NSWindow Frame prefCustomWindowSize"])
		{
			[docWindow setFrameUsingName:@"prefCustomWindowSize"];
		}
	}
}

@end
