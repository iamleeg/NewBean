/*
	JHDocument_Initialize.m
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
 
#import "JHDocument_Initialize.h"
#import "JHDocument_Text.h" //setSmartQuotesStyleAction
#import "JHDocument_AltColors.h" //textColors, loadAltTextColors
#import "JHDocument_FullScreen.h" //isFullScreen
#import "JHDocument_Toolbar.h" //setupToolbar
#import "JHDocument_PageLayout.h" //addPage
#import "JHDocument_Print.h" //printInfoUpdates
#import "JHDocument_View.h" //toggleLayoutView, toggleInvisiblesAction
#import "JHDocument_LiveWordCount.h" //liveWordCount
#import "JHDocument_DocAttributes.h" //docAttributes creation, setting, getting, defaults
#import "JHDocument_Toolbar.h" //update segmentedStyleControl
#import "NSTextViewExtension.h"; //setBeanCursorShape

//to silence compiler warnings (10.6 methods, but we use 10.5 SDK)
@interface NSTextView (SnowLeopard)
- (void)setAutomaticDashSubstitutionEnabled:(BOOL)flag;
- (void)setAutomaticTextReplacementEnabled:(BOOL)flag;
@end

@implementation JHDocument ( JHDocument_Initialize )

#pragma mark -
#pragma mark ---- Document Setup ----

// ******************* Document Setup ********************

- (void)awakeFromNib
{

	//use Leopard dark grey gradient and raised labels as backing for status bar in Leopard (image preset in IB)
	if ([docWindow respondsToSelector:@selector(setContentBorderThickness:forEdge:)])
	{
		[[liveWordCountField cell] setBackgroundStyle:NSBackgroundStyleRaised];
		[[zoomAmt cell] setBackgroundStyle:NSBackgroundStyleRaised];
	}
	//else use Tiger's shade of grey for status bar
	else
	{
		[backgroundButton setImage: [NSImage imageNamed: @"statusbarTiger.png"]];
	}

}

//	add code here that needs to be executed once the windowController has loaded the document's window.
- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	//	call super
	[super windowControllerDidLoadNib:aController];
	
	//	close document if file was not a format that Bean can read (10 June 2007 JH)
	if ([[self currentFileType] isEqualToString:@"invalidFileType"])
	{
		[self invalidFileAlert];
	}
	
	// ----- misc setup -----

	//	save initial window size and position for Untitled docs//
	//	experimented with it; not very consistant, perhaps meant for Apps that have only one window 18 June 2007 
	//[[theScrollView window] setFrameAutosaveName:@"MyWindow"]; //not used!
	
	//	set pointer to user defaults for later
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//	set pointer to shared spell checker pointer for later
	spellChecker = [NSSpellChecker sharedSpellChecker];
		
	//	set 'default' print info
	[self setPrintInfo:[NSPrintInfo sharedPrintInfo]];
	[printInfo setHorizontalPagination:NSFitPagination];

	// ----- if data from file, load textStorage -----

	//	if plain or attributed text was loaded from document's file, load it into text storage
	if (loadedText) 
	{
		[textStorage replaceCharactersInRange:NSMakeRange(0,[textStorage length]) withAttributedString:loadedText];
		[self setIsTransientDocument:NO]; //not empty Untitled
		[self setIsDocumentSaved:YES]; //not Untitled
		NSFileManager *fm = [NSFileManager defaultManager];
		NSDictionary *theFileAttrs = [fm fileAttributesAtPath:[self fileName] traverseLink:YES];
		if ([self fileName])
		{
			//	if file is locked, open an 'Untitled' doc with the contents of the original, that is, treat is as a 'template'
			if ([[theFileAttrs objectForKey:NSFileImmutable] boolValue] == YES || [self isStationaryPad:[self fileName]])
			{
				[self setOriginalFileName:[self fileName]]; //remember for reminder in save dialog
				[self setFileName:nil];
				[self setLossy:NO];
				[self setIsDocumentSaved:NO];
				[self setFileModDate:nil];
			}
			else
			{
				//	otherwise, remember file mod date to compare before saving later to see if the file has been externally edited
				[self setFileModDate:[[fm fileAttributesAtPath:[self fileName] traverseLink:YES] fileModificationDate]];
			}
		}
	}
	
	// ----- setup textView -----
		
	//	add first page
	[self addPage:self];
	//	setup firstTextsView shared state
	[self setupInitialTextViewSharedState];
	
	// ----- if no text, apply default attribtues -----
	
	//	if new document, get default typingAttributes (incl. font) and pagesize/margins that are indicated in Preferences and apply
	if (loadedText==nil)
	{
		[self applyDefaultTypingAttributes];
		//	we supply default margins too
		[self applyDefaultDocumentAttributes];
	}
	
	//main menu: New (Special) > Plain Text Document was called, and a doc was inited with type TXTDoc 8 Oct 08 JH
	if ([[self fileType] isEqualToString:TXTDoc])
	{
		[[self firstTextView] setRichText:NO];
		[self setCurrentFileType:TXTDoc];
	}
	
	// ----- if text, apply attributes -----

	//	if text or html, use default _plain_ text font from user defaults and some default margins
	if (![[self firstTextView] isRichText])
	{
		//	added to give layout view reasonable margins and prepare for fitWidth (25 May 2007 BH)
		[self applyDefaultDocumentAttributes];
		//	for txt and html, use continuous text view
		[self setShowLayoutView:NO];
		//	prepare to open plain text file (appropriate font, etc.)
		[self applyPlainTextSettings];
	}
	//	otherwise, use attributes from the file (pageSize, margins) if they exist (won't exist for new docs) 
	else
	{
		//setSuppress... suppresses scrollView jump caused by windowDidResize > restoreVisibleTextRange
		[self setSuppressRestoringTextRange:YES];
		[self applyDocumentAttributes];
		[self performSelector:@selector(setSuppressRestoringTextRange:) withObject:NO afterDelay:0.0];
	}
	
	//apply changes to margins, pagesize, columns, etc.
	[self applyUpdatedPrintInfo];
	
	// ----- do layout -----

	//	background layout is too slow for PPC macs running Leopard, so we force complete layout unless pref says otherwise
	if ([defaults boolForKey:@"prefBackgroundPagination"])
	{
		//	doForegroundLayout...just enough to prevent vertical scroller from racing to top of page
		//	Intel macs are great at background pagination -- almost no slowdown
		[self doForegroundLayoutToCharacterIndex:20000];
	}
	else
	{
		//	force layout of whole thing
		//	ppc macs, esp. those runnning Leopard, are too pokey when background pagination is working
		[self doForegroundLayoutToCharacterIndex:INT_MAX];
	}
	
	// ----- interface stuff -----
	
	//	should scroll of scrollview constrain to show insertion point approx in middle of screen (based on user Pref)? 
	BOOL shouldConstrain = [defaults boolForKey:@"prefConstrainScroll"];
	[self setShouldConstrainScroll:shouldConstrain];
	
	//	force doc to scroll to restored insertion point
	if ([self hasMultiplePages]) { [self constrainScrollWithForceFlag:YES]; }
	else { [[self firstTextView] centerSelectionInVisibleArea:self]; }
	
	//	apply user Preferences 
	[self applyPrefs];
	
	//	toolbar
	[self setupToolbar];
	//	force update of segmented style control in toolbar
	NSNotification *notification = [NSNotification notificationWithName:@"NSTextViewDidChangeSelectionNotification" object:[self firstTextView]];
	[self updateSegmentedStyleControl:notification];

	BOOL y = [defaults integerForKey:@"prefShowToolbar"];
	[[docWindow toolbar] setVisible:y];

	if (![defaults boolForKey:@"prefLiveWordCount"])
	{
		//	this makes the status bar look nice when no counting occcurs
		[liveWordCountField setObjectValue:NSLocalizedString(@"B  E  A  N", @"status bar label: B  E  A  N")];	
		[liveWordCountField setTextColor:[NSColor darkGrayColor]];
	}
	else
	{
		[self liveWordCount:nil]; //report initial count
	}

	//  BUGFIX problem where if loadedText & selRange(0,0), *initial* typing uses nil attributes. Why does that happen?
	if ([[self firstTextView] isRichText] && [textStorage length] && NSEqualRanges([[self firstTextView] selectedRange], NSMakeRange(0,0)))
	{
		NSDictionary *establishedAttributes = [textStorage attributesAtIndex:0 effectiveRange:NULL];
		[[self firstTextView] setTypingAttributes:establishedAttributes];
	}

	//	zero out text string
	[loadedText autorelease];
	loadedText = nil;
	
	//	set focus (otherwise, initial typing does nothing!)
	if (theScrollView)
	{
		[[theScrollView window] makeFirstResponder:[self firstTextView]];
		[[theScrollView window] setInitialFirstResponder:[self firstTextView]];
		//setup ruler for inches
		if ([self pointsPerUnitAccessor] > 30)
		{
			[[theScrollView horizontalRulerView] setMeasurementUnits:@"Inches"];
			[[theScrollView verticalRulerView] setMeasurementUnits:@"Inches"];
		}
		//else for centimeters
		else
		{
			[[theScrollView horizontalRulerView] setMeasurementUnits:@"Centimeters"];
			[[theScrollView verticalRulerView] setMeasurementUnits:@"Centimeters"];
		}
	}
	
	//minSize in nib doesn't seem to stick; too small a window size causes a display bug in our code
	[[theScrollView window] setMinSize:NSMakeSize(100, 100)];

	// ----- start notifications -----
	
	//	register for notifications (note: 'object:NULL' means change in any view sends notification)
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	//	for full screen hide and restore
	[nc addObserver:self selector: @selector(windowBecameMain:) name:NSWindowDidBecomeMainNotification object:NULL];
	[nc addObserver:self selector: @selector(windowResignedMain:) name:NSWindowDidResignMainNotification object:NULL];
	[nc addObserver:self selector: @selector(applicationDidUpdateDocument:) name:NSApplicationDidUpdateNotification object:NULL];
	//	for word counting text storage
	[nc addObserver:self selector:@selector(liveWordCount:) name:@"KBTextStorageStatisticsDidChangeNotification" object:textStorage];
	[nc addObserver:self selector:@selector(liveWordCount:) name:@"PagesVisibleInPageViewDidChangeNotification" object:NULL];
	//	for automatic backup upon quit
	[nc addObserver:self selector:@selector(backupDocumentAtQuitAction:) name:@"NSApplicationWillTerminateNotification" object:NULL];
	//	so can show very top of pageView when pageUp key is pressed
	[nc addObserver:self selector:@selector(scrollUpWhenAtBeginning:) name:@"NSTextViewDidChangeSelectionNotification" object:NULL];
	// for segmented style control in toolbar
	[nc addObserver:self selector:@selector(updateSegmentedStyleControl:) name:@"NSTextViewDidChangeSelectionNotification" object:NULL];

	//if necessary...
	[self closeTransientDocument];
}

// initialise the firstTextView (which shares its attributes across subsequent textViews)
- (void)setupInitialTextViewSharedState
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSTextView *textView = [self firstTextView];
	
	[textView setDelegate:self];
	[textView setSelectable:YES];
	[textView setEditable:YES];
	[textView setUsesFontPanel:YES];
	[textView setUsesRuler:YES];
	[textView setUsesFindPanel:YES];
	[textView setAllowsUndo:YES];
	
	BOOL allowColorChange = [defaults boolForKey:@"prefAllowBackgroundColorChange"];
	[textView setAllowsDocumentBackgroundColorChange:allowColorChange];
	
	BOOL enableSmartCopyPaste = [defaults boolForKey:@"prefSmartCopyPaste"];
	[textView setSmartInsertDeleteEnabled:enableSmartCopyPaste];

	//hidden prefs in 2.4.2 (only prefTextReplacement == TRUE for factory settings)
	//need 10.5
	if ([textView respondsToSelector:@selector(setAutomaticLinkDetectionEnabled:)]) {
		[textView setAutomaticLinkDetectionEnabled:[defaults boolForKey:@"prefLinkDetection"]];
	}
	if ([textView respondsToSelector:@selector(setGrammarCheckingEnabled:)]) {
		[textView setGrammarCheckingEnabled:[defaults boolForKey:@"prefGrammarChecking"]];
	}
	//need 10.6
	//how to silence compiler warnings for 10.6 methods (we build on 10.5 SDK)
	if ([self currentSystemVersion] >= 0x1060) {
		if ([textView respondsToSelector:@selector(setAutomaticTextReplacementEnabled:)]) {
			[textView setAutomaticTextReplacementEnabled:[defaults boolForKey:@"prefTextReplacement"]];
		}
		if ([textView respondsToSelector:@selector(setAutomaticDashSubstitutionEnabled:)]) {
			[textView setAutomaticDashSubstitutionEnabled:[defaults boolForKey:@"prefDashSubstitution"]];
		}
	}
	
	NSString *fType = [self currentFileType];
	//	Rich Text With Graphics
	if ([fType isEqualToString:RTFDDoc] 
		|| [fType isEqualToString:BeanDoc] 
		|| [fType isEqualToString:WebArchiveDoc])
	{
		[textView setRichText:YES];
		[textView setImportsGraphics:YES];
	} 
	//	Rich Text, No Graphics
	else if ([fType isEqualToString:DOCDoc]
			 || [fType isEqualToString:XMLDoc] 
			 ||  [fType isEqualToString:RTFDoc])
	{
		[textView setRichText:YES];
		[textView setImportsGraphics:NO];
	}
	//	Plain Text, No Graphics
	else if ([fType isEqualToString:TXTDoc] 
			 || [fType isEqualToString:HTMLDoc] 
			 || [fType isEqualToString:TXTwExtDoc])
	{
		[textView setRichText:NO];
		[textView setImportsGraphics:NO];
	}
	else
	{
		[textView setRichText:YES];
		[textView setImportsGraphics:YES];
		[textView setDrawsBackground:YES];		
	}
	// white is default, before other changes
	[self setTheBackgroundColor:[NSColor whiteColor]];
	
	//get insertion point color from prefs
	NSColor *cursorColor = [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"prefCursorColor"]];
	if (!cursorColor) cursorColor = [NSColor blackColor];
	[textView setInsertionPointColor:cursorColor];
	//get insertion point shape from prefs
	int shape = [[defaults objectForKey:@"prefCursorShape"] intValue];
	if (shape < -1 || shape > 2) shape = 0;
	[textView setBeanCursorShape:shape];

}

//	retrieve saved user preferences from the Preferences window when a document loads
-(void) applyPrefs 
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	PageView *pageView = [theScrollView documentView];
	NSTextView *textView = [self firstTextView];
	
	if ([defaults boolForKey:@"prefLiveWordCount"])
	{ 
		[self setShouldDoLiveWordCount:YES];
	}
	else 
	{
		[self setShouldDoLiveWordCount:NO];
		[liveWordCountField setTextColor:[NSColor darkGrayColor]];
		[liveWordCountField setObjectValue:NSLocalizedString(@"B  E  A  N", @"status bar label: B  E  A  N")];	
	}
	
	if ([defaults boolForKey:@"prefShowMarginGuides"]) 
	{
		if ([[theScrollView documentView] isKindOfClass:[PageView class]])
		{
			[pageView setShowMarginsGuide:YES];
		}
		[self setShowMarginsGuide:YES];
	} 
	else
	{
		if ([[theScrollView documentView] isKindOfClass:[PageView class]])
		{
			[pageView setShowMarginsGuide:NO];
		}
		[self setShowMarginsGuide:NO];
	}
	
	if ([defaults boolForKey:@"prefShowHorizontalScroller"]) 
	{
		[self setShouldShowHorizontalScroller:YES];
	} 
	else
	{
		[self setShouldShowHorizontalScroller:NO];
		[theScrollView setHasHorizontalScroller:NO]; 
	}
	
	if ([defaults boolForKey:@"prefShowRuler"])
	{
		[self setAreRulersVisible:YES];
		[theScrollView setRulersVisible:YES];
	}
	else
	{
		[self setAreRulersVisible:NO];
		[theScrollView setRulersVisible:NO];
	}
	
	if ([defaults boolForKey:@"prefShowRulerWidgets"])
	{
		[layoutManager setShowRulerAccessories:YES];
	}
	else
	{
		[layoutManager setShowRulerAccessories:NO];
	}
	//	read in alt colors from user prefs
	[self loadAltTextColors];
	
	//	for new docs without altColors, apply altColors if prefs say so
	if ([self fileName]==nil && ![self shouldUseAltTextColors])
	{
		if ([defaults boolForKey:@"prefUseAltColors"])
		{
			[self setShouldUseAltTextColors:YES];
			[self setShouldUseAltTextColorsInNonFullScreen:YES];
			[self textColors:nil];
		}
	}
	//	keep track of altColors in full screen mode separately from regular mode
	if ([defaults boolForKey:@"prefFullScreenUseAlternateColors"])
	{
		[self setShouldUseAltTextColorsInFullScreen:YES];
	}
	
	if ([defaults boolForKey:@"prefUseSpellcheck"])
	{
		[textView setContinuousSpellCheckingEnabled:YES];
	}
	else
	{
		[textView setContinuousSpellCheckingEnabled:NO];
	}
	
	// BUGFIX this would reverse view setting in opened template; addded check for isTransientDocument for Bean 2.2.0
	// default view is layout; toggle to continuous for new docs if pref says so
	// NOTE: this is a document setting while the others are interface settings -- can cause problems, see bug
	if (![defaults boolForKey:@"prefShowLayoutView"] && [self fileName]==nil && [self isTransientDocument])
	{
		[self setShowLayoutView:NO];
	}
	
	//	show invisible chars?
	if ([defaults boolForKey:@"prefShowInvisibles"])
	{ 
		[self toggleInvisiblesAction:nil];
	}
	
	//	absolutely don't want Smart Quotes substituted into HTML code or other types of code
	if (![[self fileType] isEqualToString:HTMLDoc] && ![[self fileType] isEqualToString:TXTwExtDoc])
	{
		//modified to allow turning-on of NSTextView automatic quote substitution for Leopard 10.5 + 5 OCT 08 JH
		
		//	this preferencce setting indicates what unicode characters are used for smart quotes
		[self setSmartQuotesStyleAction:self];
		
		//	use Smart Quotes?
		BOOL smartQuotes = [defaults boolForKey:@"prefSmartQuotes"];
	
		//	use Bean Smart Quotes (= 0) or OS X 10.5+ Smart Quotes (=1)?
		int	smartQuotesType = [[defaults valueForKey:@"prefSmartQuotesSuppliedByTag"]intValue];
		
		//	remember if doc uses Bean vs NSTextView Smart Quotes (for reactivating them after turning them off)
		[self setUseSmartQuotesSuppliedByTextSystem:smartQuotesType];
		
		
		//turn on Bean Smart Quotes
		if (smartQuotes && smartQuotesType==0)
		{
			//NSLog(@"text view inited with Bean Smart Quotes");
			[self setShouldUseSmartQuotes:YES];
			if ([[self firstTextView] respondsToSelector:@selector(setAutomaticQuoteSubstitutionEnabled:)])
			{
				[[self firstTextView] setAutomaticQuoteSubstitutionEnabled:NO];
			}
		}
		//turn on NSTextView supplied Smart Quotes
		else if (smartQuotes && smartQuotesType==1)
		{
			//NSLog(@"textview inited with Leopard's Smart Quotes");
			[self setShouldUseSmartQuotes:NO];
			if ([[self firstTextView] respondsToSelector:@selector(setAutomaticQuoteSubstitutionEnabled:)])
			{
				[[self firstTextView] setAutomaticQuoteSubstitutionEnabled:YES];
			}
		}
		//don't use Smart Quotes
		else
		{
			[self setShouldUseSmartQuotes:NO];
			if ([[self firstTextView] respondsToSelector:@selector(setAutomaticQuoteSubstitutionEnabled:)])
			{
				[[self firstTextView] setAutomaticQuoteSubstitutionEnabled:NO];
			}
		}
	}
	//	if pref is YES, initial window opened is centered, and subsequent windows cascade from its position
	if ([defaults boolForKey:@"prefCenterInitialWindow"])
	{ 
		 [docWindow center];
	}
}

//	for new docs
-(void)applyDefaultTypingAttributes
{
	//	set pointer to user defaults for later
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//	retrieve default typing attributes for cocoa
	NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy]; //====copy
	//	get line spacing attribute from defaults in preferences
	switch ([defaults integerForKey:@"prefDefaultLineSpacing"]) //binding is selectedTag
	{
		case 0: //single space
			[theParagraphStyle setLineHeightMultiple:1.0];
			break;
		case 2: //double space
			[theParagraphStyle setLineHeightMultiple:2.0];
			break;
		case 3: //1.2 space
			[theParagraphStyle setLineHeightMultiple:1.2];
			break;
		default: //1.5 space
			[theParagraphStyle setLineHeightMultiple:1.5];
			break;
	}
	//	get first line indent from defaults in preferences
	float firstLineIndent = 0;
	firstLineIndent = [defaults boolForKey:@"prefIsMetric"]
	? [[defaults valueForKey:@"prefDefaultFirstLineIndent"] floatValue] * 28.35 
	: [[defaults valueForKey:@"prefDefaultFirstLineIndent"] floatValue] * 72.0;
	if (firstLineIndent) { [theParagraphStyle setFirstLineHeadIndent:firstLineIndent]; }
	
	//	make a dictionary of the attributes
	NSMutableDictionary *theTypingAttributes = [ [[NSMutableDictionary alloc] initWithObjectsAndKeys:theParagraphStyle, 
												  NSParagraphStyleAttributeName, nil] autorelease];
	[theParagraphStyle release]; //====release
	
	//	retrieve the default font name and size from user prefs; add to dictionary
	NSString *richTextFontName = [defaults valueForKey:@"prefRichTextFontName"];
	float richTextFontSize = [[defaults valueForKey:@"prefRichTextFontSize"] floatValue];
	//	create NSFont from name and size
	NSFont *aFont = [NSFont fontWithName:richTextFontName size:richTextFontSize];
	//	use system font on error (Lucida Grande, it's nice)
	if (aFont == nil) aFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	//	add font to typingAttributes
	if (aFont) [theTypingAttributes setObject:aFont forKey:NSFontAttributeName];
	
	//	apply to textview (for new documents)
	[[self firstTextView] setTypingAttributes:theTypingAttributes];

	//	setup pageView container size, etc.
	[self applyUpdatedPrintInfo];
}

//	if fileType is plain text, apply default plain text settings
-(void)applyPlainTextSettings
{
	//	I don't believe the below does anything useful anymore, so line is commented out 29 JUL 08 JH
	//	do this otherwise fontColorAttributes gets reset to black
	//if ([self shouldUseAltTextColors]) { [self textColors:nil]; }
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	//	retrieve the preferred font and size from user prefs
	NSString *plainTextFontName = [defaults valueForKey:@"prefPlainTextFontName"];
	float plainTextFontSize = [[defaults valueForKey:@"prefPlainTextFontSize"] floatValue];
	//	create that NSFont
	NSFont *aFont = [NSFont fontWithName:plainTextFontName size:plainTextFontSize];
	//	use system font on error
	if (aFont == nil) { aFont = [NSFont systemFontOfSize:[NSFont systemFontSize]]; }
	//	apply font attribute to textview (for new documents)
	[textStorage addAttribute:NSFontAttributeName value:aFont range:NSMakeRange(0, [textStorage length])];
	//	get paper size and figure textContainer size

	//	update size of PageView if active
	[self applyUpdatedPrintInfo];
	
	//	if document was (probably) an empty plain text template file, supply UTF-8 as default
	if ([textStorage length]==0)
	{
		[self setDocEncoding:NSUTF8StringEncoding];
		[self setDocEncodingString:@"Unicode (UTF-8)"];
	}
	//	if encoding wasn't determined by OS X, show a sheet asking user to select encoding
	if (![self docEncoding] && ![[self currentFileType] isEqualToString:TXTwExtDoc])
	{
		NSControl *fakeSender = [[NSControl alloc] init];
		[fakeSender setTag:2];
		[self performSelector:@selector(showBeanSheet:) withObject:fakeSender afterDelay:0.0f];
		[fakeSender release];
	}
	
	NSMutableParagraphStyle *theParagraphStyle = nil;
	// BUGFIX: add boundary check 12 MAY 08 JH
	if ([textStorage length])
	{
		theParagraphStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
	}
	if (theParagraphStyle == nil) 
	{
		theParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	}
	else
	{
		id tv = [self firstTextView];
		theParagraphStyle = [[theParagraphStyle mutableCopyWithZone:[tv zone]] autorelease];
	}
	
	//	Apply default style from Preferences to plain text *if* prefApplyToText box is checked 
	//	we ignore HTML and TXTwExtDoc files, since they are probably code of some sort
	if ([defaults boolForKey:@"prefApplyToText"] && [[self currentFileType] isEqualToString:TXTDoc])
	{
		//	get line spacing attribute from defaults in preferences
		switch ([defaults integerForKey:@"prefDefaultLineSpacing"]) //selectedTag binding
		{
			case 0: //single space
				[theParagraphStyle setLineHeightMultiple:1.0];
				break;
			case 2: //double space
				[theParagraphStyle setLineHeightMultiple:2.0];
				break;
			case 3: //1.2 space
				[theParagraphStyle setLineHeightMultiple:1.2];
				break;		
			default: //1.5 space
				[theParagraphStyle setLineHeightMultiple:1.5];
				break;
		}
		//	get first line indent from defaults in preferences
		float firstLineIndent = 0;
		firstLineIndent = [defaults boolForKey:@"prefIsMetric"]
			? [[defaults valueForKey:@"prefDefaultFirstLineIndent"] floatValue] * 28.35 
			: [[defaults valueForKey:@"prefDefaultFirstLineIndent"] floatValue] * 72.0;
		if (firstLineIndent) [theParagraphStyle setFirstLineHeadIndent:firstLineIndent];
	} 
	//	if prefs say don't apply default style, add one attribute to make sure all attributes are not nil
	//	nil attributes drive inspector controls crazy
	else
	{
		[theParagraphStyle setLineHeightMultiple:1.0];
	}
	//	make a dictionary of the attributes
	NSMutableDictionary *theTypingAttributes = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:theParagraphStyle, 
		NSParagraphStyleAttributeName, nil] autorelease];
	//	BUGFIX: add font to typingAttributes (for when no text is present) 12 MAY 08 JH
	[theTypingAttributes setObject:aFont forKey:NSFontAttributeName];
	[textStorage addAttribute:NSParagraphStyleAttributeName value:theParagraphStyle range:NSMakeRange(0,[textStorage length])];
	[[self firstTextView] setTypingAttributes:theTypingAttributes];
}

-(void)invalidFileAlert
{
	NSBeep();
	//	to keep window from flashing into existence before it closes
	[docWindow setAlphaValue: 0.0]; 
	NSString *titleString = [NSString stringWithFormat:NSLocalizedString(@"The document \\U201C%@\\U201D could not be opened by Bean.", @"alert title: The document (document name inserted at runtime) could not be opened by Bean."), [self displayName]];
	// alert if file is ODT or DOCX format (not TIGER compatible)
	NSString *infoString;
	if ( ([[self fileType] isEqualToString:OpenDoc] || [[self fileType] isEqualToString:DocXDoc]) && [self currentSystemVersion] < 0x1050)
	{
		infoString = [NSString stringWithFormat:NSLocalizedString(@"alert text: Bean requires OS X 10.5 \\U2018Leopard\\U2019 or above to support the file format %@.", @"alert text: Bean requires OS X 10.5 'Leopard' or above to support the file format (name of file format inserted at runtime)."), [self fileType]];
	}
	//generic alert - couldn't open file
	else
	{
		infoString = NSLocalizedString(@"Bean cannot open documents of this type, or there is a problem with the document.", @"alert text: Bean cannot open documents of this type, or there is a  problem with the document.");
	}
	(void)NSRunAlertPanel(titleString, infoString, NSLocalizedString(@"OK", @"OK"), nil, nil);
	
	//if we just do [self close] we get an error - the toolbar attempts to validate after the window was released (Leopard only?)
	[self performSelector:@selector(close) withObject:self afterDelay:1.0f];	
}

//	close untitled document of zero length when opening a saved document
//	must precede readFromFileWrapper
- (void)closeTransientDocument
{
	JHDocument *firstDoc;
	NSArray *documents = [[NSDocumentController sharedDocumentController] documents];
	if ([self isDocumentSaved] 
				&& [documents count] == 2
				&& (firstDoc = [documents objectAtIndex:0])
				&& [firstDoc isTransientDocument] )
	{
		[firstDoc close];
	}
}

#pragma mark -
#pragma mark ---- contentViewSize ----

// ******************* contentViewSize ********************

//	contentViewSize = NSViewSizeDocumentAttribute in document attributes
//	reports frame.size of contentView of (non-full screen) docWindow
- (NSSize)contentViewSize
{
	if ([self fullScreen])
	{
		return [self contentSizeBeforeFullScreen];
	}
	else
	{
		return [NSScrollView contentSizeForFrameSize:[docWindow frame].size hasHorizontalScroller:[theScrollView hasHorizontalScroller] hasVerticalScroller:[theScrollView hasVerticalScroller] borderType:[theScrollView borderType]];
	}
}

//	changes size of contentView of docWindow, which in effect changes docWindow size
- (void)applyContentViewSize:(NSSize)size
{
	NSWindow *window = [theScrollView window];
	NSRect origWindowFrame = [window frame];
	NSSize scrollViewSize;
	scrollViewSize = [NSScrollView frameSizeForContentSize:size hasHorizontalScroller:[theScrollView hasHorizontalScroller] 
									   hasVerticalScroller:[theScrollView hasVerticalScroller] borderType:[theScrollView borderType]];
	[window setContentSize:scrollViewSize];
	[window setFrameTopLeftPoint:NSMakePoint(origWindowFrame.origin.x, NSMaxY(origWindowFrame))];
}

@end