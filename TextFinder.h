#import <Cocoa/Cocoa.h>

#define Forward YES
#define Backward NO

#define Last_Replace_String__Key	@"FindPanelLastReplaceString"

@interface TextFinder : NSObject
{
	NSString *findString;
	id findTextField;
	id replaceTextField;
	id ignoreCaseButton;
	id findNextButton;
	id statusField;
	id findPanel;
	BOOL lastFindWasSuccessful;		/* A bit of a kludge */

	//if NO, new behavior: retain selection after replace/replace all
	//if YES, old behavior: no selection following replace/replace all
	BOOL _noSelectionAfterReplace;
	
	/* for Bean */
	NSArray *regExPatterns;
	NSError *_error;
	id rangePopupButton;
	id patternPopupButton;
	id useRegExButton;
}

/* Common way to get a text finder. One instance of TextFinder per app is good enough. */
+ (id)sharedInstance;

/* Main method for external users; does a find in the first responder. Selects found range or beeps. */
- (BOOL)find:(BOOL)direction;

/* Loads UI lazily */
- (NSPanel *)findPanel;

/* Gets the first responder and returns it if it's an NSTextView */
- (NSTextView *)textObjectToSearchIn;

/* Get/set the current find string. Will update UI if UI is loaded */
- (NSString *)findString;
- (void)setFindString:(NSString *)string;
- (void)setFindString:(NSString *)string writeToPasteboard:(BOOL)flag;

/* Misc internal methods */
- (void)appDidActivate:(NSNotification *)notification;
- (void)loadFindStringFromPasteboard;
- (void)loadFindStringToPasteboard;

/* Methods sent from the find panel UI */
- (void)findNext:(id)sender;
- (void)findPrevious:(id)sender;
- (void)findNextAndOrderFindPanelOut:(id)sender;
- (void)replace:(id)sender;
- (void)replaceAndFind:(id)sender;
- (void)replaceAndFindPrevious:(id)sender;
- (void)replaceAll:(id)sender;
- (void)orderFrontFindPanel:(id)sender;
- (void)takeFindStringFromSelection:(id)sender;
- (void)jumpToSelection:(id)sender;

// methods added for Bean...

// another action method available to Find panel UI
- (IBAction)findAll:(id)sender;

// changes findTextField background color to indicate regex engine is in use
- (IBAction)regExButtonAction:(id)sender;

@end

@interface NSString (NSStringTextFinding)

// NOTE: selectedRange here is range currently selected, not range to search in; we start search at NSMaxRange(selectedRange)
- (NSRange)findString:(NSString *)string selectedRange:(NSRange)selectedRange options:(unsigned)mask wrap:(BOOL)wrapFlag;

// adds search for regular expressions to Bean via ICU (libicucore.dylib) and RegExKitLite (by John Engelhart, regexkit.sourceforge.net)
// (id)sender lets us set an accessor in the sender (TextFinder) in case there is an error with regex, e.g. invalid regex
// NOTE: selectedRange here is range currently selected, not range to search in; we start search at NSMaxRange(selectedRange)
- (NSRange)rangeOfRegex:(NSString *)string selectedRange:(NSRange)selectedRange options:(unsigned)options wrap:(BOOL)wrap sender:(id)sender;

//utility method
//- (int)numberOfMatchesForRegex:(NSString *)regex options:(unsigned)options sender:(id)sender;

@end
