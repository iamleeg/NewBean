//
//  KBWordCountingTextStorage.h
//  ---------------------------
//
//  (c) Keith Blount 2005
//
//	A simple text storage subclass that provides a live word count, and ensures that no more
//	attributes than necessary get stripped in -fixAttachmentAttributeInRange:.
//

#import <Cocoa/Cocoa.h>

@class JHDocument;

extern NSString *KBTextStorageStatisticsDidChangeNotification;

@interface KBWordCountingTextStorage : NSTextStorage
{
	NSMutableAttributedString *text;
	unsigned wordCount;
	
	// JH additions for bean
	NSDictionary *oldAttributes;
	NSDictionary *theTempAttributes;
	NSDictionary *altTextColor;
	BOOL shouldUseAltTextColors;
	BOOL shouldHideFontColorsWithAltColors;
	//BOOL _isDoingExtraProcessing;
}

/* Restore text with word count intact */
- (id)initWithAttributedString:(NSAttributedString *)aString wordCount:(unsigned)wc;

/* Word count accessor */
- (unsigned)wordCount;

// additions by James Hoover for Bean :: 20 July 2007 //

//publicize
-(void)setOldAttributes:(NSDictionary*)someAttributes;
-(NSDictionary *)oldAttributes;
-(void)setShouldUseAltTextColors:(BOOL)flag;
-(BOOL)shouldUseAltTextColors;

//forward declare
-(void) fixLineHeightForImageWithIndex:(int)index;
-(void)setTheTempAttributes:(NSDictionary*)newTempAttributes;
-(NSDictionary*)theTempAttributes;
-(void)applyTheTempAttributesToRange:(id)theRange;
-(void)setShouldHideFontColorsWithAltColors:(BOOL)flag;
-(BOOL)shouldHideFontColorsWithAltColors;

//-(BOOL)isDoingExtraProcessing;
//-(void)setDoingExtraProcessing:(BOOL)flag;

@end
