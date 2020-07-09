//
//  KBWordCountingTextStorage.m
//  ---------------------------
//
//  Keith Blount 2005
//

#import "KBWordCountingTextStorage.h"
#import "JHDocument.h" //addition for Bean

static unichar newLineChar = 0x000a;
static unichar attachmentChar = 0xfffc;

NSString *KBTextStorageStatisticsDidChangeNotification = @"KBTextStorageStatisticsDidChangeNotification";

@implementation KBWordCountingTextStorage

/*************************** Word Count Specific Methods ***************************/

#pragma mark -
#pragma mark Word Count Specific Methods

/*
 *	-wordCountForRange: uses -doubleClickAtIndex: to calculate the word count.
 *	This method was recommended for this purpose by Aki Inoue at Apple.
 *	The docs mention that such methods (actually the docs are talking about -nextWordFromIndex:forward:
 *	in this context) aren't intended for linguistic analysis, but Aki Inoue explained that this was
 *	only because they do not perform linguistic analysis and therefore may not be entirely accurate
 *	for Japanese/Chinese, but should be fine for the majority of purposes.
 *	-wordRangeForCharRange: uses -nextWordAtIndex:forward: to get a rough word range to count,
 *	because using -doubleClickAtIndex: for that method too would require more checks to stop out of bounds
 *	exceptions.
 *	UPDATE 19/09/05: Now both methods use -nextWordAtIndex:, because after extensive tests, it turns out
 *	that -doubleClickAtIndex: is incredibly slow compared to -nextWordAtIndex:.
 */

- (unsigned)wordCountForRange:(NSRange)range
{
	unsigned wc = 0;
	NSCharacterSet *lettersAndNumbers = [NSCharacterSet alphanumericCharacterSet];
	
	int index = range.location;
	int endIndex = NSMaxRange(range);
	while (index < endIndex)
	{
		//int newIndex = NSMaxRange([self doubleClickAtIndex:index]);
		
		// BUG FIX 17/09/06: added MIN() check to ensure that we count nothing that is beyond the edge of the selection.
		int newIndex = MIN(endIndex,[self nextWordFromIndex:index forward:YES]);
		
		NSString *word = [[self string] substringWithRange:NSMakeRange(index, newIndex-index)];
		// Make sure it is a valid word - ie. it must contain letters or numbers, otherwise don't count it
		if ([word rangeOfCharacterFromSet:lettersAndNumbers].location != NSNotFound)
			wc++;

		index = newIndex;
	}
	return wc;
}

- (NSRange)wordRangeForCharRange:(NSRange)charRange
{
	// Leopard fix - if there is no text, we have to return the charRange unchanged.
	if ([self length] == 0)
		return charRange;
	
	NSRange wordRange;
	wordRange.location = [self nextWordFromIndex:charRange.location forward:NO];
	wordRange.length = [self nextWordFromIndex:NSMaxRange(charRange) forward:YES] - wordRange.location;
	return wordRange;
}

- (unsigned)wordCount
{
	return wordCount;
}

/*************************** NSTextStorage Overrides ***************************/

#pragma mark -
#pragma mark NSTextStorage Overrides

// All of these methods are necessary to create a concrete subclass of NSTextStorage

- (id)init
{
	if (self = [super init])
	{
		text = [[NSMutableAttributedString alloc] init];
		wordCount = 0;

		//	for Bean 24 MAY 08 JH
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		//	set accessor to determine behavior of Alt Colors based on user pref
		//	made an accessor because it's called so often
		if ([defaults boolForKey:@"prefHideFontColorsWithAltColors"])
		{
			[self setShouldHideFontColorsWithAltColors:YES];
		}
		else
		{
			[self setShouldHideFontColorsWithAltColors:NO];
		}
		
	}
	return self;
}

- (id)initWithString:(NSString *)aString
{
	if (self = [super init])
	{
		text = [[NSMutableAttributedString alloc] initWithString:aString];
		wordCount = [self wordCountForRange:NSMakeRange(0,[text length])];
	}
	return self;
}

- (id)initWithString:(NSString *)aString attributes:(NSDictionary *)attributes
{
	if (self = [super init])
	{
		text = [[NSMutableAttributedString alloc] initWithString:aString attributes:attributes];
		wordCount = [self wordCountForRange:NSMakeRange(0,[text length])];
	}
	return self;
}

- (id)initWithAttributedString:(NSAttributedString *)aString
{
	if (self = [super init])
	{
		text = [aString mutableCopy];
		wordCount = [self wordCountForRange:NSMakeRange(0,[text length])];
	}
	return self;
}

- (id)initWithAttributedString:(NSAttributedString *)aString wordCount:(unsigned)wc
{
	if (self = [super init])
	{
		text = [aString mutableCopy];
		wordCount = wc;
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];	// According to CocoaDev, we need to do this...
	[altTextColor release];
	[text release];
	if (oldAttributes) [oldAttributes release];
	if (theTempAttributes) [theTempAttributes release];
	[super dealloc];
}

- (NSString *)string
{
	return [text string];
}

- (NSDictionary *)attributesAtIndex:(unsigned)index effectiveRange:(NSRangePointer)aRange
{
	return [text attributesAtIndex:index effectiveRange:aRange];
}

- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString
{
	int strlen = [aString length];
	int oldWordCount = wordCount;
	
	NSRange wcRange = [self wordRangeForCharRange:aRange];
	wordCount -= [self wordCountForRange:wcRange];
	NSRange changedRange = NSMakeRange(wcRange.location,
									   (wcRange.length - aRange.length) + strlen);

	// UPDATE 13/08/06: word count is updated BEFORE edited:range:changeInLength: is called. The latter method causes the
	// didProcessEditing notifications to get sent, so we must update the word count before then in case any observers
	// of those notifications want to get an accurate word count from us.
	[text replaceCharactersInRange:aRange withString:aString];
	wordCount += [self wordCountForRange:changedRange];

	int lengthChange = strlen - aRange.length;
	[self edited:NSTextStorageEditedCharacters
		   range:aRange
  changeInLength:lengthChange];
	
	// UPDATE 17/03/07: Added a user info dictionary, so that observers can register to find out how many words are typed during any given session.
	[[NSNotificationCenter defaultCenter] postNotificationName:KBTextStorageStatisticsDidChangeNotification
														object:self
													  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																[NSNumber numberWithInt:((int)wordCount-oldWordCount)], @"ChangedWordsCount",
																[NSNumber numberWithInt:lengthChange], @"ChangedCharactersCount",
																nil]];
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
	[text setAttributes:attributes range:aRange];
	
	[self edited:NSTextStorageEditedAttributes
		   range:aRange
  changeInLength:0];
}

- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)aRange
{
	[text addAttribute:name value:value range:aRange];
	[self edited:NSTextStorageEditedAttributes
		   range:aRange
  changeInLength:0];
}
//	********** Below are Additions for Bean by James Hoover **********

//	note: couldn't add these methods as a category because of the new instance variable called 'oldAttributes'

//	a text attachment inserted at the start of a paragraph will strip the paragraph's paragraphStyle, since the attachment probably has no style and the rest of the paragraph is changed to match through the fixAttributes... messages. Since this is probably not what the user intended, we overlay the textAttributes of the following character onto the attachment before it is inserted, in effect reversing the usual behavior
- (void)replaceCharactersInRange:(NSRange)aRange withAttributedString:(NSAttributedString *)attributedString

{
	//if an attachment is being inserted
	if ([[attributedString string] isEqualToString:[NSString stringWithFormat:@"%C", NSAttachmentCharacter]])
	{
		NSMutableAttributedString *mas = nil;
		//if there are saved typingAttributes (there should be)
		if ([self oldAttributes])
		{
			mas = [attributedString mutableCopy];
			//add the attributes to the attributedString to insert
			if (mas)
			{
				[mas addAttributes:[self oldAttributes] range:NSMakeRange(0,1)];
			}	
		}
		//insert the string with added attributes
		if (mas)
		{
			[super replaceCharactersInRange:aRange withAttributedString:mas];
		}
		//if things didn't work out for some reason, just do the usual thing
		else
		{
			[super replaceCharactersInRange:aRange withAttributedString:attributedString];
		}
		//copies have to be released
		[mas release];
	}
	//if not an attachment, let super do the usual thing 
	else
	{
		[super replaceCharactersInRange:aRange withAttributedString:attributedString];
	}
}

//	typingAttributes are retained for later use (sent in from the textView's delegate) whenever the insertion point in the textView changes from one location to another with an accompanying change in typingAttributes
- (void)setOldAttributes:(NSDictionary*)someAttributes
{
	[someAttributes retain];
	[oldAttributes release];
	oldAttributes = someAttributes;
}

-(NSDictionary *)oldAttributes {
	return oldAttributes;
}

//look for attachment characters isolated from text (that is, in its own paragraph) and make single space, because double space etc. looks bad and might confuse the user
- (void)fixAttachmentAttributeInRange:(NSRange)aRange
{
	int rLoc = aRange.location;
	int rLen = aRange.length;
	//	mutable attributed string length
	int masLen = [self length];
	//	string version of this mutable attributed class
	NSString *s = nil;
	
	//	make attachment single spaced if sandwiched between newLine characters
	
	s = [self string];
	//	prevent out of bounds
	if (rLoc < masLen)
	{
		unichar c = [s characterAtIndex:rLoc];
		// if first inserted chracter is attachment
		if (c == attachmentChar) 
		{
			if (rLoc > 0) //	prevent out of bounds
			{
				unichar p = [s characterAtIndex:rLoc - 1];
				//	if previous character was a newLine
				if (p == newLineChar)
				{
					if (rLoc + rLen < masLen) //	prevent out of bounds
					{
						unichar f = [s characterAtIndex:rLoc + 1];
						{
							//	if following character is newLine
							if (f == newLineChar)
							{
								//	make attachment single spaced
								[self fixLineHeightForImageWithIndex:rLoc];
							}
						}
					}
				}
			}
			//	added so image at loc==0 that is alone in a paragraph will retain single spacing upon being resized (6 Aug 2007 JH) 
			//	special case: attachment is first character
			if (rLoc == 0 && masLen > 1)
			{
				unichar fc = [s characterAtIndex:rLoc + 1]; //	following character
				if (fc == newLineChar)
				{
					//	make attachment single spaced
					[self fixLineHeightForImageWithIndex:rLoc];
				}
			}
		}
		//if first inserted character is newLine
		if (c == newLineChar) 
		{
			if (rLoc > 1) //prevent out of bounds
			{
				unichar pa = [s characterAtIndex:rLoc - 1];
				unichar pb = [s characterAtIndex:rLoc - 2];
				//if newLine + attachment precede
				if (pa == attachmentChar && pb == newLineChar)
				{
					//make attachment single spaced
					[self fixLineHeightForImageWithIndex:rLoc - 1];
				}
			}
			if (rLoc + 2 < masLen) //prevent out of bounds
			{
				unichar pc = [s characterAtIndex:rLoc + 1];
				unichar pd = [s characterAtIndex:rLoc + 2];
				//if attachment + newLine follow
				if (pc == attachmentChar && pd == newLineChar)
				{
					//make attachment single spaced
					[self fixLineHeightForImageWithIndex:rLoc + 1];
				}
			}
			//special case (at beginning of doc)
			if (rLoc == 1)
			{
				unichar pa = [s characterAtIndex:rLoc - 1];
				//if newLine is preceded by attachment at start of doc
				if (pa == attachmentChar)
				{
					//make it single spaced
					[self fixLineHeightForImageWithIndex:rLoc - 1];
				}
			}
		}
	}
	s = nil;
	[super fixAttachmentAttributeInRange:aRange]; 
}

//single spaces the lineHeight of an attachment when it's alone in a paragraph
- (void) fixLineHeightForImageWithIndex:(int)index
{
	NSMutableParagraphStyle *theParagraphStyle = nil;
	NSParagraphStyle *aParagraphStyle = [self attribute:NSParagraphStyleAttributeName atIndex:index effectiveRange:NULL];
	theParagraphStyle = [aParagraphStyle mutableCopy];
	[theParagraphStyle setLineHeightMultiple:1.0];
	// check to prevent nil value error
	if (theParagraphStyle) [self addAttribute:NSParagraphStyleAttributeName value:theParagraphStyle range:NSMakeRange(index, 1)];
	[theParagraphStyle release];
}

-(void)processEditing
{
	[super processEditing];
	//	Alternate Colors is on, colorize text using temporary attributes 23 MAY 08 JH
	if ([self shouldUseAltTextColors] && [self theTempAttributes])
	{
		NSRange theEditedRange = [self editedRange];
		//BUGFIX 19 JUNE 08 JH textList was causing crash here, as well as dead keys for creation of accented chars
		//	note/reminder: edited range is not actual final edited range because of substitutions in the text system; eg, several characters combine to create one new accented character, or bullet-tab is inserted after tab for textList item
		//	the cause of the crash: editedRange used in applyTheTempAttributesToRange could be longer than the actual range of characters available, so out of bounds would occur; but putting the method in didProcessEditing caused an unacceptable delay
		//	important: we should only change attributes of *edited range* within processEditing (or else: 'not valid to cause layout manager to do glyph generation while textStorage is being editied')

		//	colorizing Alternate Colors works like this:
		//	1) for responsiveness, apply altColors to edited range only if font is black at (index - 1); this makes an assumption that alt colors is continuing in the editedRange, which might not be true and will have to be fixed in applyTheTemptAttributesToRange, but that is okay for now (if we don't do this, letter appears black, then a fraction of a second later gets colorized, which looks clumsy and distracting)
		//	2) we then performSelector:withObject:afterDelay: to look more closely at greater ranges for possible colorization in applyTheTempAttributeToRange
		//	for example, a block of text that is mainly altColored is pasted in, everything shows up altColored, then fixAttributesInRange immediately looks at the inserted text and colorizes those ranges with color, where altColors don't apply
		
		//	TODO: is there any way to simplify/optimize the colorizing process and still make it responsive? What about ONLY adding altColor attributes to the ranges it applies to below, which will make the call to applyTheTempAttributeRange unecessary?
		//	TODO: can we apply the temporaryAttributes directly to the textStorage, so we don't cause the layoutManager to try to do glyph generation?
		
		//NOTE 22 JUNE 08 JH: I tried to move the applyTheTempAttributesToRange call to fixAttributesInRange, sending it right after calling super, but recoloring of fonts on display did not occur, even after manually invalidatingDisplayForChars, so abandonned

		//NSLog(@"theEditedRange:%@", NSStringFromRange(theEditedRange));
		if (theEditedRange.length > 0)
		{
			int loc = theEditedRange.location + theEditedRange.length - 1;
			if (loc < 1) loc = 0;
			//cache color object and create accessor? what does profiling say?
			NSColor *theColor = [self attribute:NSForegroundColorAttributeName atIndex:loc effectiveRange:NULL];	
			//BUG: MS Word 'Auto' font color, R=.03, G=.03, B=.03, so alt colors doesn't change it; we check for that now 3 OCT 08 JH 
			NSColor *fontColor = [theColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
			float darkness;
			darkness = ( (222 * [fontColor redComponent]) 
						+ (707 * [fontColor greenComponent]) 
						+ (71 * [fontColor blueComponent]) ) / 1000;
			//	if black or if MS Word 'Auto' color (RGB =.03 ?!) ...
			if ([theColor isEqualTo:[NSColor blackColor]] || theColor==NULL || darkness < 0.04)
			{
				[[[self layoutManagers] objectAtIndex:0] addTemporaryAttributes:[self theTempAttributes] forCharacterRange:[self editedRange]];
			}
			id theRange =  [NSValue valueWithRange:theEditedRange];
			//delay apply/cleanup method for altColors until outside processEditing
			//this could probably go into didProcessEditing delegate method as an alternative
			[self performSelector:@selector(applyTheTempAttributesToRange:) withObject:theRange afterDelay:0.0];
		}
	}
}

- (void)setShouldUseAltTextColors:(BOOL)flag {
	shouldUseAltTextColors = flag;
}

- (BOOL)shouldUseAltTextColors {
	return shouldUseAltTextColors;
}

//	cache the alternate text colors and apply them if needed
-(void)setTheTempAttributes:(NSDictionary*)newTempAttributes
{
	[theTempAttributes autorelease];
	theTempAttributes = [newTempAttributes copy];
	if ([self shouldUseAltTextColors])
	{
		NSRange wholeRange = NSMakeRange(0, [self length]);
		id textRange = [NSValue valueWithRange:wholeRange]; ///19 JUNE 08 changed to NSValue
		[self applyTheTempAttributesToRange: textRange];
	}
}

-(NSDictionary*)theTempAttributes
{
	return theTempAttributes;
}

//	adds temporary attributes for Alternate Color to just those ranges of text that are black
-(void)applyTheTempAttributesToRange:(id)theEditedRange
{
	NSRange theRange = [theEditedRange rangeValue];
	//bounds check: return pressed on empty list item deletes it, but processed range reported is range prior to deletion, causing out of bounds
	if (theRange.location + theRange.length <= [[self string] length])
	{
		//	use old behavior (recolor all text)
		if ([self shouldHideFontColorsWithAltColors])
		{
			NSRange textRange = NSMakeRange(0, [self length]);
			//	28 DEC 07 JH moved here (ts:processEditing) because faster here on Leopard
			[[[self layoutManagers] objectAtIndex:0] addTemporaryAttributes:[self theTempAttributes] forCharacterRange:textRange];
		}
		//	use new behavior (color only black text; display other font colors)
		else
		{
			//	added begin/endEditing calls because the changes should be grouped, no? 21 JUNE 08 JH
			//	NSLog seems to show that here they do nothing in terms of triggering textStorage cleanup or notification

			//	will hold range of color
			NSRange colorRange;
			//	for while statement iteration
			int loc = theRange.location;
			//	go thru edited range
			while (loc < theRange.location + theRange.length)
			{
				//NSLog(@"editedRange: %@", NSStringFromRange(theRange));

				//	find range of foreground color attribute at loc index
				NSColor *theColor = [self attribute:NSForegroundColorAttributeName atIndex:loc effectiveRange:&colorRange];			
				//BUG: MS Word 'Auto' font color, R=.03, G=.03, B=.03, so alt colors doesn't change it; we check for that now 3 OCT 08 JH 
				NSColor *fontColor = [theColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
				float darkness;
				darkness = ( (222 * [fontColor redComponent]) 
							+ (707 * [fontColor greenComponent]) 
							+ (71 * [fontColor blueComponent]) ) / 1000;
				//	if black or if MS Word 'Auto' color (RGB =.03 ?!) ...
				if ([theColor isEqualTo:[NSColor blackColor]] || theColor==NULL || darkness < 0.04)
				{
					//NSLog(@"colorRange: %@", NSStringFromRange(colorRange));
					
					//	...add alternate colors
					[[[self layoutManagers] objectAtIndex:0] addTemporaryAttributes:[self theTempAttributes] forCharacterRange:colorRange];
				}
				//	else, not black...
				else
				{
					//	so look for color + temp attr, a conflict that can happen when font color is added to black text which already has temporary attributes
					NSRange problemRange;
					//	the layoutManager
					id lm = [[self layoutManagers] objectAtIndex:0];
					[lm temporaryAttributesAtCharacterIndex:loc effectiveRange:&problemRange];
					//	found colors + temp colors, so remove the temp colors
					if (problemRange.length > 0)
					[lm removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:colorRange];
				}
				loc = loc + colorRange.length;
			}
		}
	}
}


//	accessor set at init time to remember user preference
//	indicates all text should be colored by Alt Colors (old behavior) instead of just black text (new behavior)
-(BOOL)shouldHideFontColorsWithAltColors
{
	return shouldHideFontColorsWithAltColors; 
}

-(void)setShouldHideFontColorsWithAltColors:(BOOL)flag
{
	shouldHideFontColorsWithAltColors = flag;
}

@end

