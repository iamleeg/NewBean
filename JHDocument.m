/*
	JHDocument.m
	Bean
	
	-------------------------------------------------------------------------
	
	Bean is open source and is released under the GNU General Public License. See 'GNU-GPL.html' in the Help folder for full text of license.
	
	NOTE: A commericially released application that reuses Bean's GNU-GPL licensed source code in a substantial way MUST ALSO BE OPEN SOURCE according to the license!*
	
	Source code included here that is not covered by the GNU-GPL is clearly labeled (for example: TextFinder.[mh]).

	*NOTE: Bean's source code has been released before under a parallel license by the copyright owner.

	-------------------------------------------------------------------------

	Started 11 JUL 2006 by James Hoover
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

#import "JHDocument.h"
#import "GLOperatingSystemVersion.h"

/*
//	for genstrings...connects strings below to localized versions of the names of the file types!
NSLocalizedString(@"Rich Text with Graphics Document (.rtfd)", @"name of file format: Rich Text with Graphics Document (.rtfd)");
NSLocalizedString(@"Bean Document (.bean)", @"name of the file format: Bean Document (.bean)");
NSLocalizedString(@"Web Archive (.webarchive)", @"name of the file format: Web Archive (.webarchive)");
NSLocalizedString(@"Rich Text Format (.rtf)", @"name of the file format: Rich Text Format (.rtf)");
NSLocalizedString(@"Word 97 (.doc)", @"name of the file format: Word 97 (.doc)");
NSLocalizedString(@"Word 2003 XML (.xml)", @"name of the file format: Word 2003 XML (.xml)");
NSLocalizedString(@"Web Page (.html)", @"name of the file format: Web Page (.html)");
NSLocalizedString(@"Text Document (.txt)", @"name of the file format: Text Document (.txt)");
NSLocalizedString(@"Text (you provide extension)", @"name of the file format: Text (you provide extension)");
NSLocalizedString(@"Word 2007 (.docx)", @"name of the file format: Word 2007 (.docx)");
NSLocalizedString(@"OpenDocument (.odt)", @"name of the file format: OpenDocument (.odt)");
*/

//	key for invalid file format (fileType)
#define kCFStringEncodingInvalidId (0xffffffffU)

//lots of accessors here, shared among JHDocument class's many categories
@implementation JHDocument

#pragma mark -
#pragma mark Autosave

// n.b. only changes behaviour on 10.7+
+ (BOOL)autosavesInPlace
{
    return YES;
}

#pragma mark -
#pragma mark ---- Init, Dealloc, Load Nib ----

// ******************* Init ********************
//	see catgegory JHDocument_Initialize for other initialization methods

- (id)init
{
	//	call superclass for inheritance
	self = [super init];
	if (self)
	{
	
		//	if no JHDocument.nib, show error alert and exit
		if (![NSBundle loadNibNamed:@"JHDocument" owner:self])
		{
			NSLog(@"Failed to load JHDocument.nib");
			[NSApp activateIgnoringOtherApps:YES];
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			NSBeep();
			//actually more likely app was moved while runnning; added 'renamed or moved' to the localized string 27 JUNE 08 JH
			[alert setMessageText:NSLocalizedString(@"Bean will quit due to an unrecoverable error. Perhaps the app was renamed while Bean was running?", @"alert title: Bean will quit due to an unrecoverable error. Perhaps the app was renamed while Bean was running?")];
			[alert setInformativeText:NSLocalizedString(@"Bean could not find JHDocument.nib.", @"alert text: Bean could not find JHDocument.nib.")];
			[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
			[alert runModal];
			[self release];
			[NSApp terminate:nil];
			return nil;
		}
		
		//	LSMinimumSystemVersion in info.plist should take care of OS X version compatibility check, but 10.3 ignores this key (known bug)
		//	however, not sure below check works either; version compatibility check from Smultron by Peter Borg
        if ([GLOperatingSystemVersion isBeforeTiger])
        {
            [NSApp activateIgnoringOtherApps:YES];
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            //added '10.4 or greater' to localized string 27 JUNE 08 JH
            [alert setMessageText:NSLocalizedString(@"You need Mac OS X 10.4 \\U2018Tiger\\U2019 to run Bean", @"alert title: You need Mac OS X 10.4 Tiger to run Bean.")];
            [alert setInformativeText:@""];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
            [alert runModal];
            [NSApp terminate:nil];
        }
		
		//	create layoutManager and textStorage (backing text system)
		textStorage = [[KBWordCountingTextStorage alloc] init];
		[textStorage setDelegate:self];
		layoutManager = [[JHLayoutManager alloc] init];
		[layoutManager setDelegate:self];
		[layoutManager setShouldDoLineBreakForFormFeed:NO]; //not needed for layoutView
		[textStorage addLayoutManager:[self layoutManager]];
		[layoutManager release];
		
		//	BUGFIX: inconsistant kerning was result of Bean not calling this method (Apple wrote back about a bug report).  11 JUNE 08 JH
		//	Strange that app performance isn't effected by turning on high quality kerning. Why not keep it on all the time?
		//	NOTE: when screen fonts are NOT used, kerning is IMPROVED but the system preference to turn off antialiasing below a size threshold is IGNORED
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults boolForKey:@"prefRespectAntialiasingThreshold"])
		{
			[layoutManager setUsesScreenFonts:YES];
		}
		else
		{
			[layoutManager setUsesScreenFonts:NO];
		}
						
		//	internal identifiers for the document types specified in info.plist
		//	a note about localizing the names of fileTypes...the NSString identifiers below point to localized strings; so whereas unlocalized fileType name strings would reference Info.plist, these localized strings reference InfoPlist.strings
		//	NOTE:'human-readable' string must *EXACTLY* match the names in InfoPlist.strings!
		//	ALSO: the defaultType (for save panel) returned by NSDocumentController is in Bean returned by a subclass of NSDocumentController, JHDocumentController, which returns not the usual first document type in info.plist, but rather whatever item has been selected in the Preferences popup for Default Save Type, or, if there is no Preference, then (.rtfd) 11 July 2007 BH
		
		//	can these be defined on one place instead of InfoPlist.strings, Localizable.strings, JHDocument.h, JHDocument.m?
		//	Text Edit (Leopard) declares these as globals in Document.m, but that doesn't work for us. Why not?
		//	An #include file with modularly global declarations does not work either
		//	Perhaps a class that returns these strings is a better obj-c approach to static strings?

		RTFDDoc = @"Rich Text with Graphics Document (.rtfd)";
		BeanDoc = @"Bean Document (.bean)";
		WebArchiveDoc = @"Web Archive (.webarchive)";
		RTFDoc = @"Rich Text Format (.rtf)";
		DOCDoc = @"Word 97 (.doc)";
		XMLDoc = @"Word 2003 XML (.xml)";
		HTMLDoc = @"Web Page (.html)";
		TXTDoc = @"Text Document (.txt)";
		TXTwExtDoc = @"Text (you provide extension)";
		//	new in Bean 1.1.0 ; not Tiger compatible
		//	for Tiger, items are removed from save panel and failure to open these types produces alert
		OpenDoc = @"OpenDocument (.odt)";
		DocXDoc = @"Word 2007 (.docx)";

		//	set defaults for accessors; avoids updateChangeCount in some cases
		isFloating = NO;
		restoreAltTextColors = NO;
		restoreShowInvisibles = NO;
		shouldDoLiveWordCount = NO;
		hasMultiplePages = YES;
		isRTFForWord = NO;
		areRulersVisible = YES;
		isTransientDocument = YES;
		isTerminatingGracefully = NO;
		doAutosave = NO;
		shouldCheckForGraphics = YES;
		isDocumentSaved = NO;
		isLossy = NO;
		isPreservingTextViewState = NO;
		shouldConstrainScroll = YES;
		shouldCreateDatedBackup = NO;
		wasCreatedUsingNewDocumentTemplate = NO;
		shouldUseAltTextColorsInNonFullScreen = NO;
		shouldUseAltTextColorsInFullScreen = NO;
		needsDatedBackup = NO;
		needsAutosave = NO;
		readOnlyDoc = NO;
		useSmartQuotesSuppliedByTextSystem = NO;
		docEncoding = 0;
		linkPrefixTag = 0;
		autosaveTime = 0;
		_numberColumns = 1;
		_columnsGutter = 0;
		isEditingList = NO;
		_alternateFontActive = NO;
		//	should Bean use centimeters or inches for this document's ruler and sheets? use user pref or check NSGlobalDomain for default
		[self isCentimetersOrInches];
		
		//	create formatter for get info and word count 1 Sept 2007 JH
		thousandFormatter = [[NSNumberFormatter alloc] init];
		[thousandFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[thousandFormatter setFormat:@"#,##0"];
	}
	return self;
}

// ******************* Dealloc ********************

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[self firstTextView] setDelegate:nil];
	[[self layoutManager] setDelegate:nil];

	//weird crash 4 MARCH 09
	//NSLog(@"%i", [[[self layoutManager]invisiblesColor]retainCount]);

	//	"When you release the NSTextStorage object, it releases its NSLayoutManagers, which release their NSTextContainers, which in turn release their NSTextViews." ("Assembling the Text System by Hand" Apple) 
	[textStorage release];
	[altTextColor release];
	[printInfo release];
	if (loadedText)	[loadedText release]; //shouldn't happen
	
	//added a bunch of releases I had omitted 29 Sept 08 BH
	if (docAttributes) [docAttributes release];
	if (textViewBackgroundColor) [textViewBackgroundColor release]; 
	if (theBackgroundColor) [theBackgroundColor release]; 
	if (currentFileType) [currentFileType release]; 
	if (fileModDate) [fileModDate release]; 
	if (originalFileName) [originalFileName release]; 
	if (docEncodingString) [docEncodingString release];
	if (hfsFileAttributes) [hfsFileAttributes release];
	if (oldAttributes) [oldAttributes release];
	if (_oldTypingAttributes) [_oldTypingAttributes release];
	if (_alternateFontDictionary) [_alternateFontDictionary release];
	if (_altCursorColor) [_altCursorColor release];

	if (segStyleControl) [segStyleControl release];
	if (highlightPopupMenu) [highlightPopupMenu release];
	if (dateTimePopupMenu) [dateTimePopupMenu release];
	
	if (RTFDDoc) [RTFDoc release];
	if (BeanDoc) [BeanDoc release];
	if (WebArchiveDoc) [WebArchiveDoc release];
	if (RTFDoc) [RTFDoc release];
	if (DOCDoc) [DOCDoc release];
	if (XMLDoc) [XMLDoc release];
	if (HTMLDoc) [HTMLDoc release];
	if (TXTDoc) [TXTDoc release];
	if (TXTwExtDoc) [TXTwExtDoc release];
	if (OpenDoc) [OpenDoc release];
	if (DocXDoc) [DocXDoc release];
	
	[thousandFormatter release];
	
	[super dealloc];
}

- (NSString *)windowNibName
{
	//	overriding the nib file name makes JHDocument the nib's owner
	//	not sure why this is necessary since JHDocument is established as nib's owner in IB, but oh well
	return @"JHDocument";
}

-(BOOL)isFlipped
{
	return YES;
}

#pragma mark -
#pragma mark ---- Reporters ----

// ******************* Reporters ********************

-(JHLayoutManager *)layoutManager { return layoutManager; }

-(KBWordCountingTextStorage *)textStorage { return textStorage; }

-(NSTextView *)firstTextView { return [layoutManager firstTextView]; }

-(JHWindow *)docWindow { return docWindow; }

-(id)theScrollView { return theScrollView; }

//tells GetInfoManager whether to enable certain controls
-(BOOL)usesKeywords
{
	if ([self fileURL]
		&& ![[self fileType] isEqualToString:TXTDoc]
		&& ![[self fileType] isEqualToString:HTMLDoc]
		&& ![[self fileType] isEqualToString:WebArchiveDoc]
		&& ![[self fileType] isEqualToString:TXTwExtDoc])	
	{ return YES; }
	else
	{ return NO; }
}

//hardcoded
-(float)pageSeparatorLength { return 15.0; }

-(void)isCentimetersOrInches
{

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSInteger units = [defaults integerForKey:@"prefUnits"];
	switch (units)
	{
		// metric
		case 3:
		{
			//	28.35 points per cm (NOTE: RTF uses twips, and 20 twips = 1 point)
			[self setPointsPerUnitAccessor:28.35];
			break;
		}
		//	U.S.
		case 2:
		{
			//	72 points per inch
			[self setPointsPerUnitAccessor:72.0];
			break;
		}
		//	system preference
		default:
		{
			//use Inches as object
			NSString *measurementUnits = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleMeasurementUnits"];	
			if ([@"Inches" isEqual:measurementUnits])
			{
				//	72 points per inch
				[self setPointsPerUnitAccessor:72.0];
			}
			else
			{
				//	28.35 points per cm (NOTE: RTF uses twips, and 20 twips = 1 point)
				[self setPointsPerUnitAccessor:28.35];
			}
			break;
		}
	}
}

//	determine if flagged as stationary pad in the Finder
-(BOOL)isStationaryPad:(NSString *)path
{
	static uint16 kIsStationary = 0x0800;
	CFURLRef url;
	FSRef fsRef;
	FSCatalogInfo catInfo;
	BOOL success;
	url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)path, kCFURLPOSIXPathStyle, FALSE);
	if (!url) return NO;
	success = CFURLGetFSRef(url, &fsRef);
	CFRelease(url);
	//	catalog info from file system reference; isStationary status from catalog info
	if (success && (FSGetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catInfo, nil, nil, nil))==noErr)
	{ 
		return ((((FileInfo*)catInfo.finderInfo)->finderFlags & kIsStationary) == kIsStationary);
	}
	return NO;
}

#pragma mark -
#pragma mark ---- Accessors ----

// ******************* Accessors ********************

//	the same as NSDocument's fileType; a parallel variable gives us more control
-(void)setCurrentFileType:(NSString*)typeName {
	[typeName retain];
	[currentFileType release];
	currentFileType = typeName;
}

-(NSString *)currentFileType {
	return currentFileType;
}

-(void)setOriginalFileName:(NSString*)aFileName {
	[aFileName retain];
	[originalFileName release];
	originalFileName = aFileName;
}

-(NSString *)originalFileName {
	return originalFileName;
}

//this is for Alternate Colors mode ONLY!
- (void)setTextViewBackgroundColor:(NSColor*)aColor
{
	//fix for wrong colorspace bug
	aColor = [aColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if (aColor) {
		[aColor retain];
		[textViewBackgroundColor release];
		textViewBackgroundColor = aColor;
	}
}

//this is for Alternate Colors mode ONLY!
-(NSColor *)textViewBackgroundColor
{
	return textViewBackgroundColor;
}

//set the non-Alternate Color text view's background color 
-(void)setTheBackgroundColor:(NSColor*)aColor
{
	//fix for wrong colorspace bug
	aColor = [aColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if (aColor) {
		[aColor retain];
		[theBackgroundColor release];
		theBackgroundColor = aColor;	
	}
}

//get the non-Alternate Color text view's background color 
-(NSColor *)theBackgroundColor
{
	return theBackgroundColor;
}

- (void)setShouldUseAltTextColors:(BOOL)flag
{
	shouldUseAltTextColors = flag;
	[textStorage setShouldUseAltTextColors:flag];
	if ([self hasMultiplePages])
	{
		PageView *pageView = [theScrollView documentView];
		[pageView setShouldUseAltTextColors:flag];
		[pageView setTextViewBackgroundColor:[self textViewBackgroundColor]];
	}
}

- (BOOL)shouldUseAltTextColors
{
	return shouldUseAltTextColors;
}

- (void)setAltTextColor:(NSColor *)newColor
{
	//fix for wrong colorspace bug
	newColor = [newColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if (newColor)
	{
		NSDictionary *newAltColor = [[NSDictionary alloc] initWithObjectsAndKeys:newColor, NSForegroundColorAttributeName, nil];
		if (newAltColor)
		{
			[altTextColor autorelease];
			altTextColor = [newAltColor copy];
		}
		[newAltColor release];
	}
}

- (NSDictionary *)altTextColor
{
	return altTextColor;
}

- (void)setOldAttributes:(NSDictionary*)someAttributes
{
	[someAttributes retain];
	[oldAttributes release];
	oldAttributes = someAttributes;
}

-(NSDictionary *)oldAttributes
{
	return oldAttributes;
}

//	saves HFSFileAttributes so they can be written back after file is saved
- (void)setHfsFileAttributes:(NSDictionary*)newAttributes
{
	[newAttributes retain];
	[hfsFileAttributes release];
	hfsFileAttributes = newAttributes;
}

-(NSDictionary *)hfsFileAttributes
{
	return hfsFileAttributes;
}

//from Text Edit
- (void)setFileModDate:(NSDate *)date {
	if (![date isEqualTo:fileModDate]) {
		[fileModDate autorelease];
		fileModDate = [date copy];
	}
}

- (NSDate *)fileModDate {
	return fileModDate;
}

- (void)setReadOnlyDoc:(BOOL)flag
{
	[[self firstTextView] setEditable:!flag];
	readOnlyDoc = flag;
}

- (BOOL)readOnlyDoc { return readOnlyDoc; }

- (void)setDocEncodingString:(NSString*)anEncodingString
{
	[docEncodingString autorelease];
	docEncodingString = [anEncodingString copy];
}

- (NSString *)docEncodingString { return docEncodingString; }

- (void)setViewWidth:(float)width { viewWidth = width; }
- (float)viewWidth { return viewWidth; }

- (void)setViewHeight:(float)height { viewHeight = height; }
- (float)viewHeight { return viewHeight; }

- (BOOL)isFloating { return isFloating; }
- (void)setFloating:(BOOL)flag { isFloating = flag; }

- (void)setRestoreAltTextColors:(BOOL)flag { restoreAltTextColors = flag; }
- (BOOL)restoreAltTextColors { return restoreAltTextColors; }

- (void)setRestoreShowInvisibles:(BOOL)flag { restoreShowInvisibles = flag; }
- (BOOL)restoreShowInvisibles { return restoreShowInvisibles; }

- (void)setShouldDoLiveWordCount:(BOOL)flag { shouldDoLiveWordCount = flag; }
- (BOOL)shouldDoLiveWordCount { return shouldDoLiveWordCount; }

-(BOOL)hasMultiplePages { return hasMultiplePages; }
-(void)setHasMultiplePages:(BOOL)flag { hasMultiplePages = flag; }

-(BOOL)isRTFForWord { return isRTFForWord; }
-(void)setIsRTFForWord:(BOOL)flag { isRTFForWord = flag; }

- (void)setAreRulersVisible:(BOOL)flag { areRulersVisible = flag; }
- (BOOL)areRulersVisible { return areRulersVisible; }

- (void)setIsTerminatingGracefully:(BOOL)flag { isTerminatingGracefully = flag; }
- (BOOL)isTerminatingGracefully { return isTerminatingGracefully; }

- (void)setIsTransientDocument:(BOOL)flag { isTransientDocument = flag; }
- (BOOL)isTransientDocument { return isTransientDocument; }

- (void)setShouldRestorePageViewAfterPrinting:(BOOL)flag { shouldRestorePageViewAfterPrinting = flag; }
- (BOOL)shouldRestorePageViewAfterPrinting { return shouldRestorePageViewAfterPrinting; }

- (void)setShouldShowHorizontalScroller:(BOOL)flag { shouldShowHorizontalScroller = flag; }
- (BOOL)shouldShowHorizontalScroller { return shouldShowHorizontalScroller; }

//	is YES when automaticBackup=YES keyword is found in keywords of document
- (void)setShouldCreateDatedBackup:(BOOL)flag { shouldCreateDatedBackup = flag; }
- (BOOL)shouldCreateDatedBackup { return shouldCreateDatedBackup; }

//	is YES when automaticBackup=YES keyword is found in keywords of document
- (void)setNeedsDatedBackup:(BOOL)flag { needsDatedBackup = flag; }
- (BOOL)needsDatedBackup { return needsDatedBackup; }

- (BOOL)doAutosave { return doAutosave; }
- (void)setDoAutosave:(BOOL)flag { doAutosave = flag; }

- (BOOL)shouldCheckForGraphics { return shouldCheckForGraphics; }
- (void)setShouldCheckForGraphics:(BOOL)flag { shouldCheckForGraphics = flag; }

//	track BOOL because BOOL in pageView accessor is destroyed when pageView is destroyed when cycling views
- (void)setShowMarginsGuide:(BOOL)flag { showMarginsGuide = flag; }
- (BOOL)showMarginsGuide { return showMarginsGuide; }
	
- (float)pointsPerUnitAccessor { return pointsPerUnitAccessor; }
- (void)setPointsPerUnitAccessor:(float)points { pointsPerUnitAccessor = points; }

//
- (BOOL)isDocumentSaved { return isDocumentSaved; }
- (void)setIsDocumentSaved:(BOOL)flag { isDocumentSaved = flag; }
	
- (BOOL)isLossy { return isLossy; }
- (void)setLossy:(BOOL)flag { isLossy = flag; }

- (void)setLineFragPosYSave:(int)lineFragPosY { lineFragPosYSave = lineFragPosY; }
- (float)lineFragPosYSave { return lineFragPosYSave; }

- (unsigned int)docEncoding { return docEncoding; }
- (void)setDocEncoding:(unsigned int)newDocEncoding { docEncoding = newDocEncoding; }

- (BOOL)shouldConstrainScroll { return shouldConstrainScroll; }
- (void)setShouldConstrainScroll:(BOOL)flag { shouldConstrainScroll = flag; }

- (unsigned int)savedEditLocation { return savedEditLocation; }
- (void)setSavedEditLocation:(unsigned int)editLocationToSave { savedEditLocation = editLocationToSave; }

- (BOOL)shouldUseSmartQuotes { return shouldUseSmartQuotes; }
- (void)setShouldUseSmartQuotes:(BOOL)flag { shouldUseSmartQuotes = flag; }

- (BOOL)registerUndoThroughShouldChange { return registerUndoThroughShouldChange; }
- (void)setRegisterUndoThroughShouldChange:(BOOL)flag { registerUndoThroughShouldChange = flag; }

//	autosaves document only if changes have been maded since last autosave (this is the accessor)
- (BOOL)needsAutosave { return needsAutosave; }
- (void)setNeedsAutosave:(BOOL)flag { needsAutosave = flag; }

-(int)autosaveTime { return autosaveTime; }
-(void)setAutosaveTime:(int)interval { autosaveTime = interval; }

- (unsigned int)smartQuotesStyleTag { return smartQuotesStyleTag; }
- (void)setSmartQuotesStyleTag:(unsigned int)theTag { smartQuotesStyleTag = theTag; }

- (unsigned int)linkPrefixTag { return linkPrefixTag; }
- (void)setLinkPrefixTag:(unsigned int)theTag { linkPrefixTag = theTag; }

- (NSSize)paperSize { return [[self printInfo] paperSize]; }
- (void)setPaperSize:(NSSize)size { [[self printInfo] setPaperSize:size]; }

- (BOOL)showPageNumbers { return showPageNumbers; }
- (void)setShowPageNumbers:(BOOL)flag { showPageNumbers = flag; }

// accessor tells attachmentCell to keep drawing selection outline, even tho selection was dismissed (to avoid visual boingy effect)
-(BOOL)resizingImage { return resizingImage; }
-(void)setResizingImage:(BOOL)flag { resizingImage = flag; }

//changed passed flag to accessor
-(BOOL)isPreservingTextViewState { return isPreservingTextViewState; }
-(void)setPreservingTextViewState:(BOOL)flag { isPreservingTextViewState = flag; }

//remember initial pref (since prefs might change)
-(BOOL)useSmartQuotesSuppliedByTextSystem { return useSmartQuotesSuppliedByTextSystem; }
-(void)setUseSmartQuotesSuppliedByTextSystem:(BOOL)flag { useSmartQuotesSuppliedByTextSystem = flag; }

//determines whether old filename is displayed in message of NSSavePanel
-(BOOL)wasCreatedUsingNewDocumentTemplate { return wasCreatedUsingNewDocumentTemplate; }
-(void)setWasCreatedUsingNewDocumentTemplate:(BOOL)flag { wasCreatedUsingNewDocumentTemplate = flag; }

-(BOOL)shouldUseAltTextColorsInFullScreen { return shouldUseAltTextColorsInFullScreen; }
-(void)setShouldUseAltTextColorsInFullScreen:(BOOL)flag { shouldUseAltTextColorsInFullScreen = flag; } 

-(BOOL)shouldUseAltTextColorsInNonFullScreen { return shouldUseAltTextColorsInNonFullScreen; }
-(void)setShouldUseAltTextColorsInNonFullScreen:(BOOL)flag { shouldUseAltTextColorsInNonFullScreen = flag; } 

-(BOOL)suppressRestoringTextRange { return suppressRestoringTextRange; }
-(void)setSuppressRestoringTextRange:(BOOL)flag { suppressRestoringTextRange = flag; }

// 0 (default) = use prefs; 1 = no header/footer; 2 = use header/footer
-(void)setHeaderFooterSetting:(int)setting { headerFooterSetting = setting; }
-(int)headerFooterSetting { return headerFooterSetting; }

// which style of header/footer to use
-(void)setHeaderFooterStyle:(int)style { headerFooterStyle = style; }
-(int)headerFooterStyle { return headerFooterStyle; }

//	= number pages to skip before header/footer is used
-(void)setHeaderFooterStartPage:(int)startPage { headerFooterStartPage = startPage; }
-(int)headerFooterStartPage { return headerFooterStartPage; }

//	columns and gutters (in layout view)
-(void)setNumberColumns:(int)number { _numberColumns = number; }
-(int)numberColumns { return _numberColumns; }
-(void)setColumnsGutter:(int)width { _columnsGutter = width; }
-(int)columnsGutter { return _columnsGutter; }

@end
