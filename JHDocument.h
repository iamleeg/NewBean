/*
  JHDocument.h
  Bean

  Created 11 JUL 2006 by JH.
  ReWrite/Refactor July 2008 JH
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

#ifdef DEBUG_BUILD
//cool stuff from Smultron by Peter Borg (Apache license)
#define LogBool(bool) NSLog(@"The value of "#bool" is %@", bool ? @"YES" : @"NO")
#define LogInt(number) NSLog(@"The value of "#number" is %d", number)
#define LogFloat(number) NSLog(@"The value of "#number" is %f", number)
#define Log(obj) NSLog(@"The value of "#obj" is %@", obj)
#define LogChar(characters) NSLog(@#characters)
#define Start NSDate *then = [NSDate date]
#define Stop NSLog(@"Time elapsed: %f seconds", [then timeIntervalSinceNow] * -1)
#define Pos NSLog(@"File=%s line=%d proc=%s", strrchr("/" __FILE__,'/')+1, __LINE__, __PRETTY_FUNCTION__)
#endif


 //prepare for 64 bit
// typedef int NSInteger; 
// typedef unsigned int NSUInteger; 
// typedef float CGFloat; //double on 64 bit systems


//example new common localization label
//#define OKBUTTON NSLocalizedString(@"OK", @"OK-button")

#import <Cocoa/Cocoa.h>
#import "JHLayoutManager.h" //showInvisibleCharacters; showRulerAccessories
#import "KBWordCountingTextStorage.h"
#import "JHWindow.h"
#import "JHScrollView.h"
#import "PageView.h"
#import "NSAttributedString-EncodeRTFwithPictures.h"

@interface JHDocument : NSDocument
{
	//pointers
	JHLayoutManager *layoutManager;
	KBWordCountingTextStorage *textStorage;
	NSSpellChecker *spellChecker; //autorelease
	NSAttributedString *loadedText;
	NSDictionary *altTextColor;
	NSString *newLineChar; //autorelease
	NSPrintInfo *printInfo;
	NSDictionary *options; //autorelease
	NSMutableDictionary *docAttributes;
	NSColor *textViewBackgroundColor;
	NSColor *theBackgroundColor;
	NSTimer *autosaveTimer;
	NSString *currentFileType;
	NSDate *fileModDate;
	NSString *originalFileName;
	NSString *docEncodingString;
	NSDictionary *hfsFileAttributes;
	NSNumberFormatter *thousandFormatter;
	NSDictionary *oldAttributes;
	NSSegmentedControl* segStyleControl;
	NSMenu *highlightPopupMenu;
	NSMenu *dateTimePopupMenu;
	NSDictionary *_oldTypingAttributes; //for restoring attributes after alternate font is turned off
	NSDictionary *_alternateFontDictionary; //holds alternate font attributes
	NSColor *_altCursorColor;
	
	//doc types
	NSString *RTFDDoc;
	NSString *BeanDoc;
	NSString *WebArchiveDoc;
	NSString *RTFDoc;
	NSString *DOCDoc;
	NSString *XMLDoc;
	NSString *HTMLDoc;
	NSString *TXTDoc;
	NSString *TXTwExtDoc;
	NSString *OpenDoc; // Leopard only
	NSString *DocXDoc; // Leopard only
		
	//outlets
	//	----- Document Window -----
	IBOutlet JHWindow *docWindow;
	IBOutlet JHScrollView *theScrollView;
	IBOutlet NSSlider *zoomSlider;
	IBOutlet NSTextField *zoomAmt;
	IBOutlet NSTextView *condensedTextView;
	IBOutlet NSTextField *liveWordCountField; // in status bar
	IBOutlet NSButton *floatButton;
	IBOutlet NSButton *backgroundButton;
	// ----- message sheet -----
	IBOutlet NSPanel *messageSheet; // 'Please Wait...'
	//	----- toolbar controls -----
	IBOutlet NSView *segmentedStyleControlView;
	IBOutlet NSSegmentedControl *segmentedStyleControl;
	
	//for loading user defaults
	IBOutlet NSUserDefaultsController *sharedUserDefaultsController;
	
	//variables
	int numberOfWords;
	int words;
	int numberOfChars;
	int failedDocType;
	int autosaveTime;
	int highlightType;
	int headerFooterSetting;
	int headerFooterStyle;
	int headerFooterStartPage;
	int _numberColumns;
	int _columnsGutter;
	unsigned int smartQuotesStyleTag;
	unsigned docEncoding;
	unsigned int savedEditLocation;
	unsigned int linkPrefixTag;
	float viewWidth;
	float viewHeight;
	float pageSeparatorLength;
	float lineFragPosYSave;
	float pointsPerUnitAccessor;
	BOOL isDocumentSaved;
	BOOL restoreShowInvisibles;
	BOOL isFloating;
	BOOL shouldUseAltTextColors;
	BOOL restoreAltTextColors;
	BOOL shouldDoLiveWordCount;	
	BOOL hasMultiplePages;
	BOOL isRTFForWord; //is RTF for Word
	BOOL areRulersVisible;
	BOOL isTerminatingGracefully;
	BOOL isTransientDocument;
	BOOL shouldRestorePageViewAfterPrinting;
	BOOL shouldShowHorizontalScroller;
	BOOL shouldCreateDatedBackup;
	BOOL needsDatedBackup;
	BOOL doAutosave;
	BOOL shouldCheckForGraphics;
	BOOL showMarginsGuide;
	BOOL isLossy;
	BOOL readOnlyDoc;
	BOOL isDirty;
	BOOL shouldConstrainScroll;
	BOOL shouldUseSmartQuotes;
	BOOL registerUndoThroughShouldChange;
	BOOL needsAutosave;
	BOOL showPageNumbers;
	BOOL pageWasAdded; // used in JHDocument_TextSystemDelegate
	BOOL fullScreen; //full screen method
	BOOL shouldRestoreRuler; //full screen method
	BOOL shouldRestoreToolbar; //full screen method
	BOOL shouldRestoreAltTextColors; //full screen method
	BOOL shouldRestoreFullScreen; //full screen method
	BOOL shouldRestoreLayoutView; //full screen method
	BOOL textLengthIsZero; //JHDocument_ReadWrite
	BOOL resizingImage; //JHDocument_Text ; NSTextAttachmentCell(Extension)
	BOOL isPreservingTextViewState; //used by addPage
	BOOL useSmartQuotesSuppliedByTextSystem; //to remember initial pref
	BOOL wasCreatedUsingNewDocumentTemplate; //determines if old filename should appear in Save As dialog
	BOOL shouldUseAltTextColorsInFullScreen;
	BOOL shouldUseAltTextColorsInNonFullScreen;
	BOOL suppressRestoringTextRange;
	BOOL cursorWasVisible;
	BOOL isEditingList;
	BOOL _alternateFontActive;
	NSSize contentSizeBeforeFullScreen;
	NSRect oldFrameRect;
	NSRange visibleTextRange; // for getter in _View
	unichar SINGLE_OPEN_QUOTE;
	unichar SINGLE_CLOSE_QUOTE;
	unichar DOUBLE_OPEN_QUOTE;
	unichar DOUBLE_CLOSE_QUOTE;
	
	// CopyPaste begin
	BOOL wasPasteboard; /* to detect whether CopyPaste asked for the window */
	NSString* pbname; /* the pastboard in which CopyPaste expects the data */
	// CopyPaste end
}

//	getters - pointers
-(JHLayoutManager *)layoutManager;
-(KBWordCountingTextStorage *)textStorage;
-(NSTextView *)firstTextView;
-(JHWindow *)docWindow;
-(id)theScrollView;

//	getters - other stuff
-(BOOL)usesKeywords;
-(float)pageSeparatorLength; //page spacer
-(void)isCentimetersOrInches;
-(BOOL)isStationaryPad:(NSString *)path;

//	accessors
-(void)setIsTerminatingGracefully:(BOOL)flag;
-(BOOL)isTerminatingGracefully;

-(void)setIsTransientDocument:(BOOL)flag;
-(BOOL)isTransientDocument;

-(void)setShouldCreateDatedBackup:(BOOL)flag;
-(BOOL)shouldCreateDatedBackup;

-(void)setNeedsDatedBackup:(BOOL)flag;
-(BOOL)needsDatedBackup;

-(void)setDoAutosave:(BOOL)flag;
-(BOOL)doAutosave;

-(void)setNeedsAutosave:(BOOL)flag;
-(BOOL)needsAutosave;

-(void)setAutosaveTime:(int)interval;
-(int)autosaveTime;

-(void)setFileModDate:(NSDate *)date;
-(NSDate *)fileModDate;

-(void)setOriginalFileName:(NSString*)aFileName;
-(NSString *)originalFileName;

- (void)setHfsFileAttributes:(NSDictionary*)newAttributes;
-(NSDictionary *)hfsFileAttributes;

-(void)setShouldCheckForGraphics:(BOOL)flag;
-(BOOL)shouldCheckForGraphics;

-(void)setCurrentFileType:(NSString*)typeName;
-(NSString *)currentFileType;

-(void)setLossy:(BOOL)flag;
-(BOOL)isLossy;

-(void)setIsRTFForWord:(BOOL)flag;
-(BOOL)isRTFForWord;

-(void)setDocEncoding:(unsigned)newDocEncoding;
-(unsigned)docEncoding;

-(void)setDocEncodingString:(NSString*)anEncodingString;
-(NSString *)docEncodingString;

-(void)setFloating:(BOOL)flag;
-(BOOL)isFloating;

-(void)setViewWidth:(float)width;
-(float)viewWidth;

-(void)setViewHeight:(float)height;
-(float)viewHeight;

-(void)setPaperSize:(NSSize)size;
-(NSSize)paperSize;

//find panel Replace buttons are enabled according to this KVC method accessor
-(void)setReadOnlyDoc:(BOOL)flag;
-(BOOL)readOnlyDoc;

-(void)setShouldRestorePageViewAfterPrinting:(BOOL)flag;
-(BOOL)shouldRestorePageViewAfterPrinting;

-(void)setRestoreShowInvisibles:(BOOL)flag;
-(BOOL)restoreShowInvisibles;

-(void)setRestoreAltTextColors:(BOOL)flag;
-(BOOL)restoreAltTextColors;

-(void)setHasMultiplePages:(BOOL)flag;
-(BOOL)hasMultiplePages;

-(void)setShouldUseAltTextColors:(BOOL)flag;
-(BOOL)shouldUseAltTextColors;

-(void)setTextViewBackgroundColor:(NSColor*)aColor;
-(NSColor *)textViewBackgroundColor;

-(void)setTheBackgroundColor:(NSColor*)aColor;
-(NSColor *)theBackgroundColor;

-(void)setAltTextColor:(NSColor *)newColor;
-(NSDictionary *)altTextColor;

-(void)setAreRulersVisible:(BOOL)flag;
-(BOOL)areRulersVisible;

-(void)setShowMarginsGuide:(BOOL)flag;
-(BOOL)showMarginsGuide;

-(void)setShouldShowHorizontalScroller:(BOOL)flag;
-(BOOL)shouldShowHorizontalScroller;

//tells addPage if prev. textView is being kept around for shared textView state
-(void)setPreservingTextViewState:(BOOL)flag;
-(BOOL)isPreservingTextViewState;

-(void)setLinkPrefixTag:(unsigned int)theTag;
-(unsigned int)linkPrefixTag;

-(void)setOldAttributes:(NSDictionary*)someAttributes;
-(NSDictionary *)oldAttributes;

-(void)setShouldDoLiveWordCount:(BOOL)flag;
-(BOOL)shouldDoLiveWordCount;

-(void)setShowPageNumbers:(BOOL)flag;
-(BOOL)showPageNumbers;
	
-(float)lineFragPosYSave; //determines if clipView scrollsToPoint
-(void)setLineFragPosYSave:(int)lineFragPosY;

-(void)setIsDocumentSaved:(BOOL)flag;
-(BOOL)isDocumentSaved;

-(void)setShouldConstrainScroll:(BOOL)toConstrainScrollOrNotToConstrainScroll;
-(BOOL)shouldConstrainScroll;

-(void)setSavedEditLocation:(unsigned int)editLocationToSave;
-(unsigned int)savedEditLocation;

-(void)setShouldUseSmartQuotes:(BOOL)flag;
-(BOOL)shouldUseSmartQuotes;

-(void)setRegisterUndoThroughShouldChange:(BOOL)flag;
-(BOOL)registerUndoThroughShouldChange;

-(void)setSmartQuotesStyleTag:(unsigned int)theTag;
-(unsigned int)smartQuotesStyleTag;

-(void)setResizingImage:(BOOL)flag;
-(BOOL)resizingImage;

-(void)setPointsPerUnitAccessor:(float)points;
-(float)pointsPerUnitAccessor;

-(void)setUseSmartQuotesSuppliedByTextSystem:(BOOL)flag;
-(BOOL)useSmartQuotesSuppliedByTextSystem;

-(void)setWasCreatedUsingNewDocumentTemplate:(BOOL)flag;
-(BOOL)wasCreatedUsingNewDocumentTemplate;

-(void)setShouldUseAltTextColorsInFullScreen:(BOOL)flag;
-(BOOL)shouldUseAltTextColorsInFullScreen;

-(void)setShouldUseAltTextColorsInNonFullScreen:(BOOL)flag;
-(BOOL)shouldUseAltTextColorsInNonFullScreen;

-(void)setSuppressRestoringTextRange:(BOOL)flag;
-(BOOL)suppressRestoringTextRange;

// 0 (default) = use prefs; 1 = no header/footer; 2 = use header/footer
-(void)setHeaderFooterSetting:(int)setting;
-(int)headerFooterSetting;

// which style of header/footer to use
-(void)setHeaderFooterStyle:(int)style;
-(int)headerFooterStyle;

//	= number pages to skip before header/footer is used
-(void)setHeaderFooterStartPage:(int)startPage;
-(int)headerFooterStartPage;

-(void)setNumberColumns:(int)number;
-(int)numberColumns;

-(void)setColumnsGutter:(int)width;
-(int)columnsGutter;

typedef struct {
	id delegate;
	SEL shouldCloseSelector;
	void *contextInfo;
} SelectorContextInfo;

@end
