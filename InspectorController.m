/*
 InspectorController.h
 Bean
 
 revised 27 JUNE 08 JH
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

#import "InspectorController.h"
#import "JHDocument.h"

static InspectorController *sharedInspectorController = nil;

//private and/or forward declaration
@interface InspectorController (PrivateMethods)

-(BOOL)shouldForceInspectorUpdate;
-(void)setShouldForceInspectorUpdate:(BOOL)flag;
-(float)pointsPerUnitAccessor;
-(void)setPointsPerUnitAccessor:(float)points;
-(IBAction)refreshFontNameMenu:(id)sender;
-(IBAction)grayOutInspector:(id)sender;
-(void)updateInspector:(NSDictionary *)theAttributes theRightMarginValueToIndentFrom:(float)theRightMarginValue isReadOnly:(BOOL)isReadOnly;

@end

@implementation InspectorController

#pragma mark -
#pragma mark ---- Shared Instance, Init, Dealloc, etc. ----

+ (id)sharedInspectorController
{
	if (!sharedInspectorController)
	{
		sharedInspectorController = [[InspectorController alloc] init];
	}
	return sharedInspectorController;
}

- (id)init
{
	self = [self initWithWindowNibName:@"Inspector"];
	if (self)
	{
		shouldForceInspectorUpdate = NO;
		textFieldDidChange = NO;
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(grayOutInspector:) name:@"JHDocumentControllerHasNoDocumentsNotification" object:NULL];
		[nc addObserver:self selector:@selector(prepareInspectorUpdate:) name:NSTextViewDidChangeTypingAttributesNotification object:NULL];
		[nc addObserver:self selector: @selector(prepareInspectorUpdate:) name:NSWindowDidBecomeMainNotification object:NULL];
		[nc addObserver:self selector: @selector(prepareInspectorUpdate:) name:NSWindowDidBecomeKeyNotification object:NULL];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

#pragma mark -
#pragma mark ---- Window Controller Methods ----

- (void)windowDidLoad
{
	//does nothing?
	[super windowDidLoad];
	//so inspector won't disappear behind main window
	[(NSPanel *)[self window] setFloatingPanel:YES];
	//so inspector won't steal focus from main window
	[(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];
	//saves the inspector panel's position for positioning at startup
	[self setWindowFrameAutosaveName:@"SpacingInspector"];
	// refresh font menu
	[self refreshFontNameMenu:self];
	[self showSpacingControls:self];
	
	//load localized control labels
	[previewFontsButton setTitle:NSLocalizedString(@"button: Preview Fonts in Menu", @"")];
	[previewFontsButton sizeToFit];
	[charSpacingDefaultButton setTitle:NSLocalizedString(@"button: Default", @"")];
	[lineSpacingDefaultButton setTitle:NSLocalizedString(@"button: Default", @"")];
	[forceLineSpacingDefaultButton setTitle:NSLocalizedString(@"button: Default", @"")];
	[fontLabel setObjectValue:NSLocalizedString(@"label: Font", @"")];
	[styleLabel setObjectValue:NSLocalizedString(@"label: Style", @"")];
	[sizeLabel setObjectValue:NSLocalizedString(@"label: Size", @"")];
	[alignmentLabel setObjectValue:NSLocalizedString(@"label: Alignment", @"")];
	[highlightLabel setObjectValue:NSLocalizedString(@"label: Highlight", @"")];
	[spacingDisclosureLabel setObjectValue:NSLocalizedString(@"label: Spacing", @"")];
	[charSpacingLabel setObjectValue:NSLocalizedString(@"label: Character", @"")];
	[lineSpacingLabel setObjectValue:NSLocalizedString(@"label: Line", @"")];
	[interLineSpacingLabel setObjectValue:NSLocalizedString(@"label: Inter-line", @"")];
	[beforeParaSpacingLabel setObjectValue:NSLocalizedString(@"label: Before Paragraph", @"")];
	[afterParaSpacingLabel setObjectValue:NSLocalizedString(@"label: After Paragraph", @"")];
	[indentLabel setObjectValue:NSLocalizedString(@"label: Indent", @"")];
	[indentFirstLineLabel setObjectValue:NSLocalizedString(@"label: First Line", @"")];
	[indentLeftLabel setObjectValue:NSLocalizedString(@"label: Left", @"")];
	[indentRightLabel setObjectValue:NSLocalizedString(@"label: Right", @"")];
	[forceLineSpacingLabel setObjectValue:NSLocalizedString(@"label: Force Line Height", @"")];
	[forceLineSpacingAtLeastLabel setObjectValue:NSLocalizedString(@"label: At Least", @"")];
	[forceLineSpacingAtMostLabel setObjectValue:NSLocalizedString(@"label: At Most", @"")];
}

#pragma mark -
#pragma mark ---- Update Inspector ----

// ******************* prepare to update inspector *******************

//	responds to notifications:
//	NSTextViewDidChangeTypingAttributesNotification, NSWindowDidBecomeMainNotification, NSWindowDidBecomeKeyNotification
//	CHANGE: used to respond to notification: NSApplicationDidUpdateNotification (too frequent and vague) 25 JUNE 08 JH
//	Causes update of settings in Inspector to reflect typing attributes
- (void) prepareInspectorUpdate:(NSNotification *)notification
{
	//	pointers
	id textView;
	id theWindow;
	id document;
	id textStorage;
	
	//NSLog(@"notification:%@", [notification name]);
	
	//notification object is textView
	if ([[notification object] isKindOfClass:[NSTextView class]])
	{
		textView = [notification object];
		theWindow = [textView window];
		document = [[theWindow windowController] document];
		textStorage = [textView textStorage];
	}
	//notification object is window
	else
	{
		theWindow = [notification object];
		document = [[theWindow windowController] document];
		textView = [document firstTextView];
		textStorage = [textView textStorage];

		if (![theWindow isMainWindow] 
					&& ![theWindow isEqualTo:[self window]]
					&& ![[theWindow windowController] isKindOfClass:[InspectorController class]])
		{
			//if notification window is not the doc window, then it's a panel or sheet, so gray out inspector
			if (![theWindow isEqualTo:[textView window]])
			{
				[self grayOutInspector:self];
			}
			return;
		}
		//new window, so force update
		[self setShouldForceInspectorUpdate:YES];
	}
		
	//	prevent non-main windows from taking over the inspector
	if (![theWindow isMainWindow])
	{
		return;
	}
	
	//	update inspector in case documents switched focus and one was American while the other was metric
	[self setPointsPerUnitAccessor:[document pointsPerUnitAccessor]];
	
	//	if NOT plain text, get the attributes
	NSDictionary *theAttributes;
	if ([textView isRichText])
	{
		//	get insertion point attributes (typingAttributes), which are 'potential' attributes for text at insertion point
		if ([textStorage length] > 0 && [textView selectedRange].location == 0)
		{
			theAttributes = [textView typingAttributes];
		}
		//	get typing attributes at index
		else if ([textView selectedRange].length==0)
		{
			theAttributes = [textView typingAttributes];
		}
		//	get the attributes of the first character of the first selection
		else
		{
			theAttributes = [textStorage attributesAtIndex:[textView selectedRange].location effectiveRange:NULL];
		}
	} 
	//if plain text, avoid nil attributes by using addAttribute without actually changing anything
	else
	{
		if ([textStorage length]==0)
		{
			theAttributes = [textView typingAttributes];
		}
		else
		{
			int attributeLocation = 0;
			int textLength = [textStorage length];
			//	prevent out-of-bounds exception for attribute:atIndex: below
			if ([textView selectedRange].location==textLength && textLength > 0)
			{
				attributeLocation = [textView selectedRange].location - 1;
			}
			else
			{
				attributeLocation = [textView selectedRange].location;				
			}
			theAttributes = [textStorage attributesAtIndex:attributeLocation effectiveRange:NULL];
		}
	}
	
	//	if there is a sheet displayed or something like that, we disable the inspector controls, since they wouldn't work anyway
	/*
	if (![[NSApp keyWindow] isEqualTo:[[document theScrollView] window]] && ![[NSApp keyWindow] isEqualTo:docWindow] && ([[textView window] isMainWindow]) )
	{
		theAttributes = nil;
	}
	*/
		
	//if attributes have changed since previous call or 'force flag' is up, update inspector
	if (![theAttributes isEqual:[document oldAttributes]] || [self shouldForceInspectorUpdate])
	{
		//inspector needs right margin info to calculate and show settings in the way users expect
		float rightMarginToIndentFrom = [[document printInfo] paperSize].width - [[document printInfo] leftMargin] - [[document printInfo] rightMargin];
		[self updateInspector:theAttributes theRightMarginValueToIndentFrom:rightMarginToIndentFrom isReadOnly:[document readOnlyDoc]];
	}
	
	//	bookkeeping
	[self setShouldForceInspectorUpdate:NO];
	[document setOldAttributes:theAttributes];
}

// udpates Inspector to reflect typingAttributes or else first selected character
- (void)updateInspector:(NSDictionary *)theAttributes theRightMarginValueToIndentFrom:(float)theRightMarginValue isReadOnly:(BOOL)isReadOnly
{
	//if no values for text, reflect that
	if (!theAttributes)
	{
		[fontStylesMenu setEnabled:NO];
		[fontNameMenu setEnabled:NO];
		[fontSizeTextField setEnabled:NO];
		[fontSizeStepper setEnabled:NO];
		[fontSizeSlider setEnabled:NO];
		[characterSpacingSlider setEnabled:NO];
		[characterSpacingTextField setEnabled:NO];
		[characterSpacingStepper setEnabled:NO];
		[characterSpacingSlider setIntValue:0];
		[characterSpacingStepper setIntValue:0];
		[characterSpacingTextField setStringValue:@" "];
		[characterSpacingDefaultButton setEnabled:NO];
		[multipleSpacingSlider setEnabled:NO];
		[multipleSpacingStepper setEnabled:NO];
		[multipleSpacingTextField setEnabled:NO];
		[multipleSpacingSlider setIntValue:0];
		[multipleSpacingStepper setIntValue:0];
		[multipleSpacingTextField setObjectValue:@" "];
		[multipleSpacingDefaultButton setEnabled:NO];
		[interlineSpacingSlider setIntValue:0];
		[interlineSpacingSlider setEnabled:NO];
		[interlineSpacingStepper setEnabled:NO];
		[interlineSpacingTextField setObjectValue:@" "];
		[interlineSpacingTextField setEnabled:NO];
		[afterParagraphSpacingStepper setIntValue:0];
		[afterParagraphSpacingTextField setObjectValue:@" "];
		[afterParagraphSpacingSlider setEnabled:NO];
		[afterParagraphSpacingStepper setEnabled:NO];
		[afterParagraphSpacingTextField setEnabled:NO];
		[afterParagraphSpacingSlider setIntValue:0];
		[afterParagraphSpacingStepper setIntValue:0];
		[afterParagraphSpacingTextField setObjectValue:@" "];
		[beforeParagraphSpacingSlider setEnabled:NO];
		[beforeParagraphSpacingStepper setEnabled:NO];
		[beforeParagraphSpacingTextField setEnabled:NO];
		[beforeParagraphSpacingSlider setIntValue:0];
		[beforeParagraphSpacingStepper setIntValue:0];
		[beforeParagraphSpacingTextField setObjectValue:@" "];
		[firstLineIndentTextField setEnabled:NO];
		[firstLineIndentStepper setEnabled:NO];
		[firstLineIndentTextField setObjectValue:@" "];
		[firstLineIndentStepper setIntValue:0];
		[headIndentTextField setEnabled:NO];
		[headIndentStepper setEnabled:NO];
		[headIndentTextField setObjectValue:@" "];
		[headIndentStepper setIntValue:0];
		[tailIndentTextField setEnabled:NO];
		[tailIndentStepper setEnabled:NO];
		[tailIndentTextField setObjectValue:@" "];
		[tailIndentStepper setIntValue:0];
		[alignmentLeftButton setEnabled:NO];
		[alignmentRightButton setEnabled:NO];
		[alignmentCenterButton setEnabled:NO];
		[alignmentJustifyButton setEnabled:NO];
		[minLineHeightTextField setEnabled:NO];
		[maxLineHeightTextField setEnabled:NO];
		[minLineHeightStepper setEnabled:NO];
		[maxLineHeightStepper setEnabled:NO];
		[highlightYellowButton setEnabled:NO];
		[highlightOrangeButton setEnabled:NO];
		[highlightPinkButton setEnabled:NO];
		[highlightBlueButton setEnabled:NO];
		[highlightGreenButton setEnabled:NO];
		[highlightRemoveButton setEnabled:NO];
		[forceLineHeightDefaultButton setEnabled:NO];
		[fontNameMenu setTitle:NSLocalizedString(@"None", @"None")]; //1 JUL 08 JH
		[fontStylesMenu setTitle:NSLocalizedString(@"None", @"None")];
		[fontSizeTextField setFloatValue:0.0];
		[fontSizeStepper setFloatValue:0.0];
		[fontSizeSlider setFloatValue:0.0];		
	}
	//get paragraph attribute values from dictionary passed from JHDocument
	else
	{
		//NSParagraphStyle stores all 'attributes' dealing with paragraph 
		NSParagraphStyle *theCurrentStyle = [theAttributes objectForKey:NSParagraphStyleAttributeName];
		
		//for MULTIPLE LINE HEIGHTS
		NSNumber *theMultipleValue;
		theMultipleValue = [NSNumber numberWithFloat:[theCurrentStyle lineHeightMultiple]];
		//avoid errors caused by float 0 != 0
		if ([theCurrentStyle lineHeightMultiple]==0) theMultipleValue = [NSNumber numberWithInt:0];
		[multipleSpacingSlider setEnabled:YES];
		[multipleSpacingStepper setEnabled:YES];
		[multipleSpacingTextField setEnabled:YES];
		[multipleSpacingDefaultButton setEnabled:YES];
		//set control values
		[multipleSpacingSlider setObjectValue:theMultipleValue];
		[multipleSpacingStepper setObjectValue:theMultipleValue];
		[multipleSpacingTextField setObjectValue:theMultipleValue];
		
		//for LEADING (inter-line spacing)
		NSNumber *theInterlineValue;
		theInterlineValue = [NSNumber numberWithFloat:[theCurrentStyle lineSpacing]];
		//avoid float and it's 'errors'
		if ([theCurrentStyle lineSpacing]==0) theInterlineValue = [NSNumber numberWithInt:0]; 
		[interlineSpacingSlider  setEnabled:YES];
		[interlineSpacingStepper  setEnabled:YES];
		[interlineSpacingTextField  setEnabled:YES];
		[interlineSpacingSlider setObjectValue:theInterlineValue];
		[interlineSpacingStepper setObjectValue:theInterlineValue];
		[interlineSpacingTextField setObjectValue:theInterlineValue];
	
		//for AFTER PARAGRAPH SPACING
		//this is totally separate from the MULTIPLE LINE HEIGHT attribute
		NSNumber *theAfterParagraphSpacingValue;
		theAfterParagraphSpacingValue = [NSNumber numberWithFloat:[theCurrentStyle paragraphSpacing]];
		//avoid float and it's 'errors'
		if ([theCurrentStyle paragraphSpacing]==0) theAfterParagraphSpacingValue = [NSNumber numberWithInt:0];
		[afterParagraphSpacingSlider  setEnabled:YES];
		[afterParagraphSpacingStepper  setEnabled:YES];
		[afterParagraphSpacingTextField  setEnabled:YES];
		[afterParagraphSpacingSlider setObjectValue:theAfterParagraphSpacingValue];
		[afterParagraphSpacingStepper setObjectValue:theAfterParagraphSpacingValue];
		[afterParagraphSpacingTextField setObjectValue:theAfterParagraphSpacingValue];
		
		//for BEFORE PARAGRAPH SPACING
		//this is totally separate from the MULTIPLE LINE HEIGHT attribute
		NSNumber *theBeforeParagraphSpacingValue;
		theBeforeParagraphSpacingValue = [NSNumber numberWithFloat:[theCurrentStyle paragraphSpacingBefore]];
		//avoid float and it's 'errors'
		if ([theCurrentStyle paragraphSpacingBefore]==0) theBeforeParagraphSpacingValue = [NSNumber numberWithInt:0]; 
		[beforeParagraphSpacingSlider  setEnabled:YES];
		[beforeParagraphSpacingStepper  setEnabled:YES];
		[beforeParagraphSpacingTextField  setEnabled:YES];
		[beforeParagraphSpacingSlider setObjectValue:theBeforeParagraphSpacingValue];
		[beforeParagraphSpacingStepper setObjectValue:theBeforeParagraphSpacingValue];
		[beforeParagraphSpacingTextField setObjectValue:theBeforeParagraphSpacingValue];												

		//indent is in points, so adjust to cm or inches for the controls
		float pointsPerUnit;
		pointsPerUnit = [self pointsPerUnitAccessor];
		
		//for FIRST LINE INDENT for paragraph
		float theFirstLineIndentValue;
		theFirstLineIndentValue = [theCurrentStyle firstLineHeadIndent];
		//avoid float and it's problems
		if ([theCurrentStyle firstLineHeadIndent]==0) theFirstLineIndentValue = 0.0;
		[firstLineIndentTextField setEnabled:YES];
		[firstLineIndentStepper setEnabled:YES];
		[firstLineIndentTextField setFloatValue:theFirstLineIndentValue/pointsPerUnit];
		[firstLineIndentStepper setFloatValue:theFirstLineIndentValue/pointsPerUnit];

		//for HEAD (LEFT) INDENT for paragraph
		float theHeadIndentValue;
		theHeadIndentValue = [theCurrentStyle headIndent];
		//avoid float and it's problems
		if ([theCurrentStyle headIndent]==0) theHeadIndentValue = 0.0;
		[headIndentTextField setEnabled:YES];
		[headIndentStepper setEnabled:YES];
		[headIndentTextField setFloatValue:theHeadIndentValue/pointsPerUnit];
		[headIndentStepper setFloatValue:theHeadIndentValue/pointsPerUnit];

		//for TAIL (RIGHT) INDENT for paragraph
		float theTailIndentValue;
		theTailIndentValue = [theCurrentStyle tailIndent];
		//avoid float and it's problems
		if ([theCurrentStyle tailIndent]==0) theTailIndentValue = 0.0;
		[tailIndentTextField setEnabled:YES];
		[tailIndentStepper setEnabled:YES];
		//	the tail, or right, value is actually the measure in pts that the text extends past the left indent,
		//but our controls show how far from the right margin in inches/cms the text is, so we do some math to 
		//adjust the values to display on the controls
		if (theTailIndentValue==0.0) theTailIndentValue = theRightMarginValue;
		[tailIndentTextField setFloatValue:(theRightMarginValue - theTailIndentValue)/pointsPerUnit];
		[tailIndentStepper setFloatValue:(theRightMarginValue - theTailIndentValue)/pointsPerUnit];

		//for MIN LINE SPACING for paragraph; 0 = no line height limits
		float theMinLineSpacingValue;
		theMinLineSpacingValue = [theCurrentStyle minimumLineHeight];
		//avoid float and it's problems
		if ([theCurrentStyle minimumLineHeight]==0) theMinLineSpacingValue = 0.0;
		[minLineHeightTextField setEnabled:YES];
		[minLineHeightStepper setEnabled:YES];
		[minLineHeightTextField setFloatValue:theMinLineSpacingValue/pointsPerUnit];
		[minLineHeightStepper setFloatValue:theMinLineSpacingValue/pointsPerUnit];
		
		//for MAX LINE SPACING for paragraph; 0 = no line height limits
		float theMaxLineSpacingValue;
		theMaxLineSpacingValue = [theCurrentStyle maximumLineHeight];
		//avoid float and it's problems
		if ([theCurrentStyle maximumLineHeight]==0) theMaxLineSpacingValue = 0.0;
		[maxLineHeightTextField setEnabled:YES];
		[maxLineHeightStepper setEnabled:YES];
		[forceLineHeightDefaultButton setEnabled:YES];
		[maxLineHeightTextField setFloatValue:theMaxLineSpacingValue/pointsPerUnit];
		[maxLineHeightStepper setFloatValue:theMaxLineSpacingValue/pointsPerUnit];
		
		//for paragraph alignment
		[alignmentLeftButton setEnabled:YES];
		[alignmentRightButton setEnabled:YES];
		[alignmentCenterButton setEnabled:YES];
		[alignmentJustifyButton setEnabled:YES];
		int theAlignment = [theCurrentStyle alignment];
		if (theAlignment==0 || theAlignment==4) { //left alignment
			[alignmentLeftButton setBordered:YES];
			[alignmentRightButton setBordered:NO];
			[alignmentCenterButton setBordered:NO];
			[alignmentJustifyButton setBordered:NO];
		} else if (theAlignment==1) { //right alignment
			[alignmentLeftButton setBordered:NO];
			[alignmentRightButton setBordered:YES];
			[alignmentCenterButton setBordered:NO];
			[alignmentJustifyButton setBordered:NO];
		} else if (theAlignment==2) { //centered alignment
			[alignmentLeftButton setBordered:NO];
			[alignmentRightButton setBordered:NO];
			[alignmentCenterButton setBordered:YES];
			[alignmentJustifyButton setBordered:NO];
		} else if (theAlignment==3) { //justified alignment
			[alignmentLeftButton setBordered:NO];
			[alignmentRightButton setBordered:NO];
			[alignmentCenterButton setBordered:NO];
			[alignmentJustifyButton setBordered:YES];
		}
		
		//	for KERNING (character spacing)
		NSNumber *theKernValue = [theAttributes objectForKey:NSKernAttributeName];
		//	adjust to match JHDocument action
		if ([theKernValue floatValue] < 0)
		{
			theKernValue = [NSNumber numberWithFloat:[theKernValue floatValue] * 2];
		}
		
		//adjust kerning value to reflect scale of control settings (0 to 400%; 100% is default)
		[characterSpacingSlider setEnabled:YES];
		[characterSpacingTextField setEnabled:YES];
		[characterSpacingStepper setEnabled:YES];
		[characterSpacingDefaultButton setEnabled:YES];
		//set values for controls from attributes from textView
		[characterSpacingSlider setObjectValue:theKernValue];
		[characterSpacingStepper setObjectValue:theKernValue];
		[characterSpacingTextField setFloatValue:[characterSpacingSlider floatValue]];
		
		//for FONT FAMILY TRAITS (font:styles NSPopupMenu) 
		[fontStylesMenu setEnabled:YES];
		[fontNameMenu setEnabled:YES];
		[fontSizeTextField setEnabled:YES];
		[fontSizeStepper setEnabled:YES];
		[fontSizeSlider setEnabled:YES];

		//get the name of the selected font or the font at the insertion point
		NSFont *theFont = [theAttributes objectForKey:NSFontAttributeName];
		//get the name of that font's font family
		NSString *theFamilyName = [theFont familyName];
		//get available fonts within family as 'traits'
		NSArray *theFamilyTraits = [[NSFontManager sharedFontManager] availableMembersOfFontFamily:theFamilyName];
		//	font size
		float currentPointSize = [theFont pointSize];
		//each item is a subArray containing displayName, traitName, and two other things
		NSArray *singleTraitArray; 
		//clear the styles menu
		[fontStylesMenu removeAllItems];
		//load the styles menu with available styles
		int index = 0;
		/*
		How this works: we set the attributedTitle of the NSMenuItem to an attributed string representing the name of the NSFont with the NSFontNameAttribute set to the NSFont, so that we can graphically represent the font trait item as well as to pass it through to the action in JHDocument, since [[sender cell] attributedTitle] will identify the font selected
		*/
		//	set title of fontNameMenu with name of current font at insertion point
		if ([theFont displayName])
		{
			//	set title of fontNameMenu to family name of font
			[fontNameMenu setTitle:[theFont familyName]];
			//	attempt to subtract family name from display name (leaving 'traits description') to set title of fontStylesMenu button 
			NSString *theDisplayName = [theFont displayName];
			NSString *theTraits = nil;
			int i = [theFamilyName length];
			//	traits description is extracted from display name and used as title for fontStylesMenu button
			if (i < [theDisplayName length])
			{
				//	if we can substract the family name from the start of the display name and end up with traits of specific font, do it 
				if ([[theDisplayName substringWithRange:NSMakeRange(0, i)] isEqualToString:theFamilyName] && [theDisplayName length] >= i + 1)
				{
					theTraits = [theDisplayName substringFromIndex:i + 1];
				}
				//	else, use the display name as it is (it might be something oddball)
				else
				{
					theTraits = theDisplayName;
				}
			}
			//	catch-all for blank display names, etc. 
			else
			{
					theTraits = @"Regular";
			}

			//	NOTE: for some reason, you have to add an extra character (here, a space), or else you get a weird out-of-bounds index error that doesn't make sense to me
			[fontStylesMenu addItemWithTitle:[NSString stringWithFormat:@"%@ ", theTraits]];			
		}
		else
		{
			//shouldn't happen
			[fontNameMenu addItemWithTitle:@"Font Name"];
			[fontStylesMenu addItemWithTitle:@"Font Style"];
		}
		//	load fontStyleMenu with attributed strings visually and textually describing font style varients
		NSEnumerator *e = [theFamilyTraits objectEnumerator];
		while (singleTraitArray = [e nextObject])
		{
			//	second item of availableMemberOfFontFamily is 'trait' name, ex: Italic Bold
			[fontStylesMenu addItemWithTitle:[singleTraitArray objectAtIndex:1]];
			
			//	create an attributed string with name of font and font applied to the string
			NSAttributedString*	fontTraitAttrString = [[[NSAttributedString alloc] initWithString:[singleTraitArray objectAtIndex:1] attributes: [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:[singleTraitArray objectAtIndex:0] size:12], NSFontAttributeName, nil]] autorelease];
			//	set the attributed title to the attributed string
			[[fontStylesMenu itemAtIndex:index + 1] setAttributedTitle:fontTraitAttrString];
			//	the title is overridden by the attributed title; we use it to pass the fontName along to JHDocument
			[[fontStylesMenu itemAtIndex:index + 1] setTitle:[singleTraitArray objectAtIndex:0]];
			index = index + 1;
		}
		if (currentPointSize > 0)
		{
			[fontSizeTextField setFloatValue:currentPointSize];
			[fontSizeStepper setFloatValue:currentPointSize];
			[fontSizeSlider setFloatValue:currentPointSize];
		}
		else
		{
			//error
			//[fontSizeTextField setFloatValue:currentPointSize];
		}
		
		[highlightYellowButton setEnabled:YES];
		[highlightOrangeButton setEnabled:YES];
		[highlightPinkButton setEnabled:YES];
		[highlightBlueButton setEnabled:YES];
		[highlightGreenButton setEnabled:YES];
		[highlightRemoveButton setEnabled:YES];		
	}
	//if document isReadOnly then un-enable controls, while still showing settings
	if (isReadOnly)
	{
		[fontStylesMenu setEnabled:NO];
		[fontNameMenu setEnabled:NO];
		[fontSizeTextField setEnabled:NO];
		[fontSizeStepper setEnabled:NO];
		[fontSizeSlider setEnabled:NO];
		
		[characterSpacingSlider setEnabled:NO];
		[characterSpacingTextField setEnabled:NO];
		[characterSpacingStepper setEnabled:NO];
		[characterSpacingDefaultButton setEnabled:NO];
		[multipleSpacingSlider setEnabled:NO];
		[multipleSpacingStepper setEnabled:NO];
		[multipleSpacingTextField setEnabled:NO];
		[multipleSpacingDefaultButton setEnabled:NO];
		[interlineSpacingSlider setEnabled:NO];
		[interlineSpacingStepper setEnabled:NO];
		[interlineSpacingTextField setEnabled:NO];
		[afterParagraphSpacingSlider setEnabled:NO];
		[afterParagraphSpacingStepper setEnabled:NO];
		[afterParagraphSpacingTextField setEnabled:NO];
		[beforeParagraphSpacingSlider setEnabled:NO];
		[beforeParagraphSpacingStepper setEnabled:NO];
		[beforeParagraphSpacingTextField setEnabled:NO];
		[firstLineIndentTextField setEnabled:NO];
		[firstLineIndentStepper setEnabled:NO];
		[headIndentTextField setEnabled:NO];
		[headIndentStepper setEnabled:NO];
		[tailIndentTextField setEnabled:NO];
		[tailIndentStepper setEnabled:NO];
		[alignmentLeftButton setEnabled:NO];
		[alignmentRightButton setEnabled:NO];
		[alignmentCenterButton setEnabled:NO];
		[alignmentJustifyButton setEnabled:NO];
		[minLineHeightTextField setEnabled:NO];
		[maxLineHeightTextField setEnabled:NO];
		[minLineHeightStepper setEnabled:NO];
		[maxLineHeightStepper setEnabled:NO];
		[highlightYellowButton setEnabled:NO];
		[highlightOrangeButton setEnabled:NO];
		[highlightPinkButton setEnabled:NO];
		[highlightBlueButton setEnabled:NO];
		[highlightGreenButton setEnabled:NO];
		[highlightRemoveButton setEnabled:NO];
		[forceLineHeightDefaultButton setEnabled:NO];
	}
}

//there are no documents to inspect, so gray-out inspector controls 24 JUNE 08 JH
-(IBAction)grayOutInspector:(id)sender
{
	[self updateInspector:nil theRightMarginValueToIndentFrom:0.0 isReadOnly:NO];
}

#pragma mark -
#pragma mark ---- Interface stuff ----

//	*must* precede refreshFontNamesMenu in class code
int fontSort(id font1, id font2, void *context)
{
	NSString *fontName1 = font1;
	NSString *fontName2 = font2;
	NSComparisonResult sortOrder = [fontName1 caseInsensitiveCompare:fontName2];
	return sortOrder;
}

-(IBAction)refreshFontNameMenu:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[fontNameMenu removeAllItems];
	NSArray *theFontFamilies;
	//	only Leopard returns a sorted list of fonts, so if Tiger then we sort them
	SInt32 systemVersion;
	if (Gestalt(gestaltSystemVersion, &systemVersion) == noErr && systemVersion < 0x1050)
	{			
		NSArray *theUnsortedFontFamilies = [[NSFontManager sharedFontManager] availableFontFamilies];
		//	sort the array
		theFontFamilies = [theUnsortedFontFamilies sortedArrayUsingFunction:fontSort context:NULL]; //fixed double release 4 Aug 07 JH
	}
	else
	{
		theFontFamilies = [[NSFontManager sharedFontManager] availableFontFamilies];
	}
	//show current font in text selection in NSPopupButton's cell
	[fontNameMenu addItemWithTitle:@"None"]; // necessary, but why?
	[fontNameMenu setTitle:NSLocalizedString(@"None", @"None")]; //necessary?
	int index = 0;
	NSString *aFontFamily;
	NSEnumerator *e = [theFontFamilies objectEnumerator];
	while (aFontFamily = [e nextObject])
	{
		//	second item of availableMemberOfFontFamily is 'trait' name, ex: Italic Bold
		[fontNameMenu addItemWithTitle:aFontFamily];
		if ([defaults boolForKey:@"prefShowFontPreview"])
		{
			//	create an attributed string with name of font and font applied to the string
			NSAttributedString*	fontFamilyAttrString = [[[NSAttributedString alloc] initWithString:aFontFamily attributes: [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:aFontFamily size:12], NSFontAttributeName, nil]] autorelease];
			//	set the attributed title to the attributed string
			[[fontNameMenu itemAtIndex:index + 1] setAttributedTitle:fontFamilyAttrString];
		}
		//	the title is overridden by the attributed title; we use it to pass the fontName along to JHDocument
		[[fontNameMenu itemAtIndex:index + 1] setTitle:aFontFamily];
		index = index + 1;
	}
	//	force update of font name displayed in inspector controls
	if ([[NSDocumentController sharedDocumentController] currentDocument])
	{
		NSNotification *aNotification = [NSNotification notificationWithName:@"ForceUpdateInspectorControllerNotification" object:[[[NSDocumentController sharedDocumentController] currentDocument] firstTextView]];
		//BUGFIX - font name button title would say "None" after this method, so force update
		[self setShouldForceInspectorUpdate:YES];
		[self prepareInspectorUpdate:aNotification];
	}
}

//	based on some example code by Andrew Stone
//	causes spacing controls section (bottom half) of inspector to be hidden or shown 9 APR 08 JH
- (IBAction)showSpacingControls:(id)sender {

	NSWindow *win = [self window];
	NSRect winFrame = [win frame];
	
	// we'll need to know the size of both boxes in this case:
	NSRect topFrame = [topBox frame];
	NSRect bottomFrame = [bottomBox frame];
	
	// get the original settings for reestablishing later:
	int topMask = [topBox autoresizingMask];
	int bottomMask = [bottomBox autoresizingMask];
	
	// set the boxes to not automatically resize when the window resizes:
	[topBox setAutoresizingMask:NSViewNotSizable];
	[bottomBox setAutoresizingMask:NSViewNotSizable];
	
	//hide spacing controls -- dependent on binding of control, which remembers last settings
	if ([showSpacingControlsButton state] == 0)
	{
		// adjust the desired height and origin of the window:
		winFrame.size.height -= NSHeight(bottomFrame);
		winFrame.origin.y += NSHeight(bottomFrame);
		// adjust the origin of the bottom box well below the window:
		bottomFrame.origin.y = -NSHeight(bottomFrame);
		// begin the top box at the bottom of the window
		topFrame.origin.y = 0.0;
		//if we resize window before it is shown, its placement will be off due to remembered origin
		if (![win isVisible])
		{
			winFrame.origin.y = winFrame.origin.y - NSHeight(bottomFrame);
		}
	}
	//show spacing controls
	else
	{
			// stack the boxes one on top of the other:
			bottomFrame.origin.y = 0.0;
			topFrame.origin.y = NSHeight(bottomFrame);
			// adjust the desired height and origin of the window, unless not yet visible (will be sized and positioned when shown)
			if ([win isVisible])
			{
				winFrame.size.height += NSHeight(bottomFrame);
				winFrame.origin.y -= NSHeight(bottomFrame);
			}
	}
	
	// adjust locations of the boxes:
	[topBox setFrame:topFrame];
	[bottomBox setFrame:bottomFrame];
	
	// resize the window and display:
	[win setFrame:winFrame display:YES];
	
	// reset the boxes to their original autosize masks:
	[topBox setAutoresizingMask:topMask];
	[bottomBox setAutoresizingMask:bottomMask];
}

#pragma mark -
#pragma mark ---- Control Actions ----

// ******************* setFontAction *******************

//called by Inspector's font family popup button
//BUGFIX: could make Bean unresponsive when changing font of large, complex documents (I forgot to bracket changes); based a little more closely now on the Gnustep method setFont 28 JUNE 08 JH
-(IBAction)fontNameAction:(id)sender
{
	//	if 1) app is active and 2) there are documents (so Inspector controls are enabled) and
	//	3) we are using the Inspector controls to call the action methods, then currentDocument should return something useful
	id doc = [[NSDocumentController sharedDocumentController] currentDocument];
	id textView = [doc firstTextView];
	id textStorage = [textView textStorage];
	NSFontManager *fontManager = [NSFontManager sharedFontManager];

	//	get current selection's attributes (for setting typing attributes)
	NSDictionary *theAttributes;
	if ([textView selectedRange].length==0)
	{
		//	get insertion point attributes (typingAttributes), which are 'potential' attributes
		theAttributes = [textView typingAttributes];
	}
	else
	{
		//	get the attributes of the first character of the first selection
		theAttributes = [textStorage attributesAtIndex:[textView selectedRange].location effectiveRange:NULL];		
	}
	//	get current font
	NSFont *theCurrentFont = [theAttributes objectForKey: NSFontAttributeName];
	//	get current font's point size
	float currentPointSize = [theCurrentFont pointSize];
	//	get newly selected font name from popup button 
	NSString *theFontName = [[sender selectedItem] title];
	//	create new font with newly selected font name and old selection's font size
	NSFont *theFont = [NSFont fontWithName:theFontName size:currentPointSize];
	
	//	setup undo
	if ([textView isRichText])
	{
		if (![textView shouldChangeTextInRanges:[textView selectedRanges] replacementStrings:nil]) { return; }
	}
	else
	{
		if (![textView shouldChangeTextInRange:NSMakeRange(0, [textStorage length]) replacementString:nil]) { return; }
	}
	//bracket changes!
	[textStorage beginEditing];
	
	//	go through selected ranges and make changes
	if ([textView isRichText])
	{
		//	change selected ranges to use the new NSFontAttributeName
		NSEnumerator *e = [[textView selectedRanges] objectEnumerator];
		NSValue *theRange;
				
		//	for selected ranges...		
		while (theRange = [e nextObject])
		{
			NSRange rangeToChange = [theRange rangeValue];
			NSRange runRange;
			//	APPLY a converted version of the FONT STYLE to rangeToChange 
			int index = rangeToChange.location;
			while (index < NSMaxRange(rangeToChange))
			{
				NSFont *font = [textStorage attribute:NSFontAttributeName atIndex:index effectiveRange:&runRange];
				//	make font == default but save traits (bold, ital) if possible
				NSFont *newFont = [fontManager convertFont:font toFamily:[theFont familyName]];
				//	intersecton of range to change and found attribute range so change doesn't overstep selection
				NSRange revisedRange = NSIntersectionRange(runRange, rangeToChange);
				//	attachments won't return a font, so make sure there is one
				if (newFont)
				{
					//for undo
					[textStorage addAttribute:NSFontAttributeName value:newFont range:revisedRange];
				}
				index = runRange.location + runRange.length;
			}
		}
	}
	//	plain text, so change all text
	else
	{
		//	add selected NSFont attribute to range
		[textStorage addAttribute:NSFontAttributeName value:theFont range:NSMakeRange(0, [textStorage length])];
	}
	//close bracket changes
	[textStorage endEditing];
	//finalize undo
	[textView didChangeText];
	[[doc undoManager] setActionName:NSLocalizedString(@"undo action Set Font", @"undo action: Set Font")];	
	
	NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
	[theTypingAttributes setObject:theFont forKey:NSFontAttributeName];
	[textView setTypingAttributes:theTypingAttributes];
}

// ******************* fontStylesAction *******************

//	inspector's font styles popup button allows user to choose font family varients, thus allowing more options than the traditional italic, bold, underline buttons (or less, sometimes)
//	NOTE: all selected ranges are converted to the choosen font; user can combine 'select by...' with this action to change diverse types of ranges, e.g., headers, etc.
//	TODO: Font Panel converts those fonts that have a bold varient, without changing the font family; should we do that here?
-(IBAction) fontStyleAction:(id)sender
{
	id doc = [[NSDocumentController sharedDocumentController] currentDocument];
	id textView = [doc firstTextView];
	id textStorage = [textView textStorage];
	NSFontManager *fontManager = [NSFontManager sharedFontManager];

	//	get current selection's attributes
	NSDictionary *theAttributes;
	if ([textView selectedRange].length==0)
	{
		//	get insertion point attributes (typingAttributes), which are 'potential' attributes
		theAttributes = [textView typingAttributes];
	}
	else
	{
		//	get the attributes of the first character of the first selection
		theAttributes = [textStorage attributesAtIndex:[textView selectedRange].location effectiveRange:NULL];
	}
	//	get current font
	NSFont *theCurrentFont = [theAttributes objectForKey: NSFontAttributeName];
	//	get current font's point size
	float currentPointSize = [theCurrentFont pointSize];
	//	get newly selected font name from popup button 
	NSString *theFontStyleName = [[sender selectedItem] title];
	//	create new font with newly selected font name and old selection's font size
	NSFont *theNewFont = [NSFont fontWithName:theFontStyleName size:currentPointSize];
	
	//	setup undo
	if ([textView isRichText])
	{
		if (![textView shouldChangeTextInRanges:[textView selectedRanges] replacementStrings:nil]) { return; }
	}
	else
	{
		if (![textView shouldChangeTextInRange:NSMakeRange(0, [textStorage length]) replacementString:nil]) { return; }
	}
	//bracket changes!
	[textStorage beginEditing];
	
	//	go through selected ranges and make changes
	if ([textView isRichText])
	{
		//	change selected ranges to use the new NSFontAttributeName
		NSEnumerator *e = [[textView selectedRanges] objectEnumerator];
		NSValue *theRange;
		//	for selected ranges...
		//	CHANGE: set font for attribute runs, but retain font sizes in runs 01 FEB 08 JH 
		while (theRange = [e nextObject])
		{		
			NSRange rangeToChange = [theRange rangeValue];
			NSRange runRange;
			//	APPLY a converted version of the FONT STYLE to rangeToChange 
			int index = rangeToChange.location;
			while (index < NSMaxRange(rangeToChange))
			{
				// get font from range
				NSFont *someFont = [textStorage attribute:NSFontAttributeName atIndex:index effectiveRange:&runRange];
				//	make font == default but save traits (bold, ital) if possible
				NSFont *newFont = [fontManager convertFont:someFont toFace:theFontStyleName];
				//	intersecton of range to change and found attribute range so change doesn't overstep selection
				NSRange revisedRange = NSIntersectionRange(runRange, rangeToChange);
				//	attachments won't return a font, so make sure there is one
				if (newFont)
				{
					[textStorage addAttribute:NSFontAttributeName value:newFont range:revisedRange];
				}
				index = runRange.location + runRange.length;
			}
		}
		
	}
	//	plain text, so change all text
	else
	{
		//	add selected NSFont attribute to range
		[textStorage addAttribute:NSFontAttributeName value:theNewFont range:NSMakeRange(0, [textStorage length])];
	}
	//close bracket changes
	[textStorage endEditing];
	//finalize undo
	[textView didChangeText];
	[[doc undoManager] setActionName:NSLocalizedString(@"Font Style", @"undo action: Font Style")];
	
	//	also set the typing attributes, in case no text yet, or end of string text
	NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
	[theTypingAttributes setObject:theNewFont forKey:NSFontAttributeName];
	[textView setTypingAttributes:theTypingAttributes];
}

-(IBAction)fontSizeAction:(id)sender;
{
	//ignore steppers/sliders here
	if ([sender isKindOfClass:[NSTextField class]])
	{
		//do action and reset flag
		if (textFieldDidChange)
		{
			[self setTextFieldDidChange:NO];
		}
		//no change to text field, just tabbed in and out or something, so no action/undo
		else
		{
			return;
		}
	}

	id doc = [[NSDocumentController sharedDocumentController] currentDocument];
	id textView = [doc firstTextView];
	id textStorage = [textView textStorage];
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
	//	get current selection's attributes
	NSDictionary *theAttributes;
	if ([textView selectedRange].length==0)
	{
		//	get insertion point attributes (typingAttributes), which are 'potential' attributes
		theAttributes = [textView typingAttributes];
	}
	else
	{
		//	get the attributes of the first character of the first selection
		theAttributes = [textStorage attributesAtIndex:[textView selectedRange].location effectiveRange:NULL];
	}
	//	get new font point size from sender control
	float newPointSize = [[sender cell] floatValue];
	//	get current font
	NSFont *theCurrentFont = [theAttributes objectForKey: NSFontAttributeName];
	//	get newly selected font name from popup button 
	NSString *theCurrentFontName = [theCurrentFont fontName];
	//	create new font with newly selected font name and old selection's font size
	NSFont *theNewFont;
	theNewFont = [NSFont fontWithName:theCurrentFontName size:newPointSize];
	
	//	if !richText and no font has been applied yet, there is no font attribute, so create a font based on user defaults
	if (!theNewFont)
	{
		//	retrieve the preferred plain text font from user prefs
		NSString *textFontName = [defaults valueForKey:@"prefPlainTextFontName"];
		//	create the font with new size NSFont
 		theNewFont = nil;
		theNewFont = [NSFont fontWithName:textFontName size:newPointSize];
	}
	
	//	setup undo
	if ([textView isRichText])
	{
		if (![textView shouldChangeTextInRanges:[textView selectedRanges] replacementStrings:nil]) { return; }
	}
	else
	{
		if (![textView shouldChangeTextInRange:NSMakeRange(0, [textStorage length]) replacementString:nil]) { return; }
	}
	//bracket changes!
	[textStorage beginEditing];
	
	
	//	go through selected ranges and make changes
	if ([textView isRichText])
	{
		//	change selected ranges to use the new NSFontAttributeName (which contains font size)
		NSEnumerator *e = [[textView selectedRanges] objectEnumerator];
		NSValue *theRange;
		//	for selected ranges...
		//	CHANGE: set font for attribute runs, changing font sizes but keeping original fonts 6 FEB 08 JH 
		while (theRange = [e nextObject])
		{
			//	we do this 'undo' couplet so that insertion point index will restore after undo
			[textView shouldChangeTextInRanges:[textView selectedRanges] replacementStrings:nil];
			[textView didChangeText];
			
			NSRange rangeToChange = [theRange rangeValue];
			NSRange runRange;
			//	APPLY a converted version of theNewFont to rangeToChange 
			int index = rangeToChange.location;
			while (index < rangeToChange.location + rangeToChange.length)
			{
				// get font from range
				NSFont *someFont = [textStorage attribute:NSFontAttributeName atIndex:index effectiveRange:&runRange];
				//	make font == default but save traits (bold, ital) if possible
				NSFont *newFont = [fontManager convertFont:someFont toSize:newPointSize];
				//	intersecton of range to change and found attribute range so change doesn't overstep selection
				NSRange revisedRange = NSIntersectionRange(runRange, rangeToChange);
				//	attachments won't return a font, so make sure there is one
				if (newFont)
				{
					[textStorage addAttribute:NSFontAttributeName value:newFont range:revisedRange];
				}
				index = runRange.location + runRange.length;
			}
		}
	}
	//	plain text, so change all text
	else
	{
		//	apply new size
		[textStorage addAttribute:NSFontAttributeName value:theNewFont range:NSMakeRange(0, [textStorage length])];
	}
	//close bracket changes
	[textStorage endEditing];
	//finalize undo
	[textView didChangeText];
	[[doc undoManager] setActionName:NSLocalizedString(@"undo action: Change Font Size", @"undo action: Change Font Size")];
	
	//	also set the typing attributes, in case no text yet, or end of string text
	//	NOTE: Apple docs say to do this - see 'setTypingAttributes' entry
	NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
	[theTypingAttributes setObject:theNewFont forKey:NSFontAttributeName];
	[textView setTypingAttributes:theTypingAttributes];
	//set focus to docWindow only after ENTER in changed text field (not tab, etc.)
	if (returnFocusToDocWindow)
		[[doc docWindow] performSelector:@selector(makeKeyAndOrderFront:) withObject:self afterDelay:0.0f];
}


//	controls on the 'Inspector' adjust ruler (NSParagraphStyle) attributes and kerning (and now font attributes)
- (IBAction)textControlAction:(id)sender
{
	//ignore steppers/sliders here
	if ([sender isKindOfClass:[NSTextField class]])
	{
		//do action and reset flag
		if (textFieldDidChange)
		{
			[self setTextFieldDidChange:NO];
		}
		//no change to text field, just tabbed in and out or something, so no action/undo
		else
		{
			return;
		}
	}
	
	id doc = [[NSDocumentController sharedDocumentController] currentDocument];
	id textView = [doc firstTextView];
	id textStorage = [textView textStorage];
		
	NSNumber *theValue = [NSNumber numberWithInt:0];;
	//in case modifierFlags (option key, etc.) are used 20 MAY 08 JH
	NSEvent *theEvent = [NSApp currentEvent];
	
	//	can't take floatValue of menuItem (which just triggers an action) so test for menuItem to avoid bad selector 
	if ([sender tag] < 20)
	{
		theValue = [NSNumber numberWithFloat:[[sender cell] floatValue]];
	}
	
	//	KERNING is a character attribute (NSKernAttributeName); we handle it separately from paragraph attribtutes below
	
	//BUG: for selected ranges encompassing partial paragraphs, when the font attribute is homogenous and the font face is 'Regular,' the kern attribute is applied by the layout manager as if it's a paragraph attribute, not a chartacter attribute...this happens as far back as 10.4 Tiger, and occurs in a simple test app as well (rdr://7367161)
		
	//tag = 11 belongs to 'default' kerning button
	if ([sender tag]==0 || [sender tag]==11)
	{
		NSEnumerator *e = [[textView selectedRanges] objectEnumerator];
		NSValue *theRangeValue;
		//setup undo
		if ([textView shouldChangeTextInRanges:[textView selectedRanges] replacementStrings:nil])
		{
			//bracket for efficiency
			[textStorage beginEditing];
			//	for selected ranges...
			while (theRangeValue = [e nextObject])
			{
				//fixed a bug where different ranges could receive different values because we reused theValue each loop 6 Sept 08 JH
				NSNumber *newValue;
				//tag=11 means 'default' button was pressed - set kerning attribute to 0.0 (= 100% on slider)
				if ([sender tag]==11) 
				{
					newValue = [NSNumber numberWithInt:0];
				}
				else if ([theValue floatValue] > 0)
				{
					newValue = [NSNumber numberWithFloat:[theValue floatValue]];
				}
				else if ([theValue floatValue] < 0)
				{
					newValue = [NSNumber numberWithFloat:[theValue floatValue] * .5];
				}
				//else, 0
				else
				{  
					newValue = [NSNumber numberWithInt:[theValue intValue]];
				}
				//	adjust text KERNING based on value from slider
				//	bug his here: kerning attributes displayed by paragraph by layoutmanager
				[textStorage addAttribute:NSKernAttributeName value:newValue range:[theRangeValue rangeValue]];
			}
			//	bracket for efficiency
			[textStorage endEditing];
			//	also set the typing attributes, in case no text yet, or end of string text
			NSDictionary *theAttributes = [textView typingAttributes];
			NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
			[theTypingAttributes setObject:theValue forKey:NSKernAttributeName];
			[textView setTypingAttributes:theTypingAttributes];
			//	end undo
			[textView didChangeText];
			//	name undo for menu
			[[doc undoManager] setActionName:NSLocalizedString(@"Character Spacing", @"undo action: (change) Character Spacing")];
		}
	}
	
	//	PARAGRAPH (RULER) ATTRIBUTES are all handled here
	
	else if ([sender tag] < 30)
	{
		//	pointers n things
		unsigned paragraphNumber;
		//	an array of NSRanges containing applicable (possibly grouped) whole paragraph boundaries
		NSArray *theRangesForUserParagraphAttributeChange = [textView rangesForUserParagraphAttributeChange];
		//	a range containing one or more paragraphs
		NSRange theCurrentRange;
		//	a range containing the paragraph of interest 
		NSRange theCurrentParagraphRange;
		//	since the values are hard-coded in menu items (as opposed to Inspector controls like sliders which change), we test for menu items here to avoid 'bad selector' (menu items have a tag of > 19)
		if ([sender tag] < 20) theValue = [NSNumber numberWithFloat:[[sender cell] floatValue]];		
		//	tag==12 mean default button for line spacing was pressed, set to 0.0
		if ([sender tag]==12)
			theValue = [NSNumber numberWithInt:0];
		//	figure effected range for undo
		int undoRangeIndex = [textView rangeForUserParagraphAttributeChange].location;
		int undoRangeLength = [[theRangesForUserParagraphAttributeChange 
								objectAtIndex:([theRangesForUserParagraphAttributeChange count] - 1)] rangeValue].location
								+ [[theRangesForUserParagraphAttributeChange 
								objectAtIndex:([theRangesForUserParagraphAttributeChange count] - 1)] rangeValue].length
								- undoRangeIndex;
		[[doc undoManager] beginUndoGrouping];
			//	start undo setup
		if ([textView shouldChangeTextInRange:NSMakeRange(undoRangeIndex,undoRangeLength) replacementString:nil])
		{
			[textStorage beginEditing]; //bracket for efficiency
			//iterate through ranges of paragraph groupings
			for (paragraphNumber = 0; paragraphNumber < [theRangesForUserParagraphAttributeChange count]; paragraphNumber++)
			{
				//set range for first (or only) paragraph; index is needed to locate paragraph; length is not important
				//note: function rangesForUserPargraphAttributeChange returns NSValues (objects), so we use rangeValue to get NSRange value
				theCurrentParagraphRange = [[theRangesForUserParagraphAttributeChange objectAtIndex:paragraphNumber] rangeValue];
				theCurrentRange = [[theRangesForUserParagraphAttributeChange objectAtIndex:paragraphNumber] rangeValue];
				//now, step thru theCurrentRange paragraph by paragraph
				while (theCurrentParagraphRange.location < (theCurrentRange.location + theCurrentRange.length))
				{
					NSMutableParagraphStyle *theParagraphStyle;
					//get the actual paragraph range including length
					theCurrentParagraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange(theCurrentParagraphRange.location, 1)];
					//BH: don't really understand the next two lines, but it works in this order. Why wouldn't you allocate it, THEN set an attribute?
					theParagraphStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:theCurrentParagraphRange.location effectiveRange:NULL];
					if (theParagraphStyle==nil)
					{
						theParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
					}
					else
					{
						theParagraphStyle = [[theParagraphStyle mutableCopyWithZone:[textView zone]]autorelease];
					}
					//pointsPerUnit is used for paragraph indents (inches/cms > points)
					float pointsPerUnit;
					pointsPerUnit = [doc pointsPerUnitAccessor];
					//change the attribute associated with the inspector control
					if ([sender tag]==1 || [sender tag]==12)
					{
						//	if line spacing, set setMinimumLineSpacing to 0.0 to allow spacing < default minimum (often = 1.5)
						[theParagraphStyle setMinimumLineHeight:0];
						//default line spacing button has tag=12; pulls default from user prefs 13 Aug 2007
						if ([sender tag]==12)
						{
							NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
							switch ([defaults integerForKey:@"prefDefaultLineSpacing"]) //selectedTag binding
							{
								case 0: //single space
									theValue = [NSNumber numberWithFloat:1.0];
									break;
								case 2: //double space
									theValue = [NSNumber numberWithFloat:2.0];
									break;
								case 3: //1.2 space
									theValue = [NSNumber numberWithFloat:1.2];
									break;
								default: //1.5 space
									theValue = [NSNumber numberWithFloat:1.5];
									break;
							}
						}
						[theParagraphStyle setLineHeightMultiple:([theValue floatValue])]; 
					} else if ([sender tag]==2) {
						[theParagraphStyle setLineSpacing:([theValue floatValue])];
					} else if ([sender tag]==3) {
						[theParagraphStyle setParagraphSpacingBefore:([theValue floatValue])];
					} else if ([sender tag]==4) {
						[theParagraphStyle setParagraphSpacing:([theValue floatValue])];
					} else if ([sender tag]==5) {
						[theParagraphStyle setFirstLineHeadIndent:([theValue floatValue] * pointsPerUnit)];
						//	holding down option key will change head indent as well 20 MAY 08 JH
						if ([theEvent modifierFlags] & NSAlternateKeyMask) 
						{
							[theParagraphStyle setHeadIndent:([theValue floatValue] * pointsPerUnit)];
						}					
					} else if ([sender tag]==6) {
						[theParagraphStyle setHeadIndent:([theValue floatValue] * pointsPerUnit)];
						//	holding down option key will change first line head indent as well 20 MAY 08 JH
						if ([theEvent modifierFlags] & NSAlternateKeyMask) 
						{
							[theParagraphStyle setFirstLineHeadIndent:([theValue floatValue] * pointsPerUnit)];
						}					
					} else if ([sender tag]==7) {
						float rightMarginToIndentFrom = [[doc printInfo] paperSize].width - [[doc printInfo] leftMargin] - [[doc printInfo] rightMargin];
						[theParagraphStyle setTailIndent:(rightMarginToIndentFrom - ([theValue floatValue] * pointsPerUnit))];
					} else if ([sender tag]==8) {
						[theParagraphStyle setMinimumLineHeight:([theValue floatValue] * pointsPerUnit)];
					} else if ([sender tag]==9) {
						[theParagraphStyle setMaximumLineHeight:([theValue floatValue] * pointsPerUnit)];
					} else if ([sender tag]==10) {
						[theParagraphStyle setMaximumLineHeight:0.0];
						[theParagraphStyle setMinimumLineHeight:0.0];
					} else if ([sender tag]==20) { //line spacing menuItem actions
						[theParagraphStyle setLineHeightMultiple:1.0];
					} else if ([sender tag]==21) {
						[theParagraphStyle setLineHeightMultiple:1.5];
					} else if ([sender tag]==22) {
						[theParagraphStyle setLineHeightMultiple:2.0];
					} else if ([sender tag]==23) {
						[theParagraphStyle setLineHeightMultiple:1.2];
					}
							
					//	add the attributes to the current paragraph
					[textStorage addAttribute:NSParagraphStyleAttributeName value:theParagraphStyle range:theCurrentParagraphRange];
					
					//	make index (=location) the first letter of the next paragraph
					theCurrentParagraphRange = NSMakeRange((theCurrentParagraphRange.location + theCurrentParagraphRange.length),1);
					//	oops, forgot this; added 20 MAY 08 JH
					//	get typingAttributes
					NSDictionary *theAttributes = [textView typingAttributes];
					NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
					[theTypingAttributes setObject:theParagraphStyle forKey:NSParagraphStyleAttributeName];
					[textView setTypingAttributes:theTypingAttributes];
					
				}
				//	FIX for problem where paragraph attributes were not changed by inspector controls when text length is zero 9 APR 08 JH
				//	also set typingAttributes for textView with zero text
				//	note: some code in the below block and the above block is duplicated; couldn't think of a graceful way to combine them 
				if ([textStorage length]==0)
				{
					//	get typingAttributes
					NSDictionary *theAttributes = [textView typingAttributes];
					//	get paragraphStyle from typingAttributes
					NSParagraphStyle *paragraphStyle = [theAttributes objectForKey:NSParagraphStyleAttributeName];
					//	make mutable copy
					NSMutableParagraphStyle *theParagraphStyle = [[paragraphStyle mutableCopy] autorelease];
					//pointsPerUnit is used for paragraph indents (inches/cms > points)
					float pointsPerUnit;
					pointsPerUnit = [doc pointsPerUnitAccessor];
					//change the attribute associated with the inspector control
					if ([sender tag]==1 || [sender tag]==12)
					{
						//	if line spacing, set setMinimumLineSpacing to 0.0 to allow spacing < default minimum (often = 1.5)
						[theParagraphStyle setMinimumLineHeight:0];
						//default line spacing button has tag=12; pulls default from user prefs 13 Aug 2007
						if ([sender tag]==12)
						{
							NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
							switch ([defaults integerForKey:@"prefDefaultLineSpacing"]) //selectedTag binding
							{
								case 0: //single space
									theValue = [NSNumber numberWithFloat:1.0];
									break;
								case 2: //double space
									theValue = [NSNumber numberWithFloat:2.0];
									break;
								case 3: //1.2 space
									theValue = [NSNumber numberWithFloat:1.2];
									break;
								default: //1.5 space
									theValue = [NSNumber numberWithFloat:1.5];
									break;
							}
						}
						[theParagraphStyle setLineHeightMultiple:([theValue floatValue])]; 
					} else if ([sender tag]==2) {
						[theParagraphStyle setLineSpacing:([theValue floatValue])];
					} else if ([sender tag]==3) {
						[theParagraphStyle setParagraphSpacingBefore:([theValue floatValue])];
					} else if ([sender tag]==4) {
						[theParagraphStyle setParagraphSpacing:([theValue floatValue])];
					} else if ([sender tag]==5) {
						[theParagraphStyle setFirstLineHeadIndent:([theValue floatValue] * pointsPerUnit)];
						//	holding down option key will change head indent as well 20 MAY 08 JH
						if ([theEvent modifierFlags] & NSAlternateKeyMask) 
						{
							[theParagraphStyle setHeadIndent:([theValue floatValue] * pointsPerUnit)];
						}					
					} else if ([sender tag]==6) {
						[theParagraphStyle setHeadIndent:([theValue floatValue] * pointsPerUnit)];
						//	holding down option key will change head indent as well 20 MAY 08 JH
						if ([theEvent modifierFlags] & NSAlternateKeyMask) 
						{
							[theParagraphStyle setFirstLineHeadIndent:([theValue floatValue] * pointsPerUnit)];
						}					
					} else if ([sender tag]==7) {
						float rightMarginToIndentFrom = [[doc printInfo] paperSize].width - [[doc printInfo] leftMargin] - [[doc printInfo] rightMargin];
						[theParagraphStyle setTailIndent:(rightMarginToIndentFrom - ([theValue floatValue] * pointsPerUnit))];
					} else if ([sender tag]==8) {
						[theParagraphStyle setMinimumLineHeight:([theValue floatValue] * pointsPerUnit)];
					} else if ([sender tag]==9) {
						[theParagraphStyle setMaximumLineHeight:([theValue floatValue] * pointsPerUnit)];
					} else if ([sender tag]==10) {
						[theParagraphStyle setMaximumLineHeight:0.0];
						[theParagraphStyle setMinimumLineHeight:0.0];
					} else if ([sender tag]==20) { //line spacing menuItem actions
						[theParagraphStyle setLineHeightMultiple:1.0];
					} else if ([sender tag]==21) {
						[theParagraphStyle setLineHeightMultiple:1.5];
					} else if ([sender tag]==22) {
						[theParagraphStyle setLineHeightMultiple:2.0];
					} else if ([sender tag]==23) {
						[theParagraphStyle setLineHeightMultiple:1.2];
					}
					NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
					[theTypingAttributes setObject:theParagraphStyle forKey:NSParagraphStyleAttributeName];
					[textView setTypingAttributes:theTypingAttributes];
				}
			}
			//	close bracket
			[textStorage endEditing];
			//	end undo setup
			[textView didChangeText];
			//	name undo action, based on tag of control
			if ([sender tag]==1 || [sender tag]==12 || [sender tag]==10 || [sender tag]==20 
				|| [sender tag]==21 || [sender tag]==22 || [sender tag]==23 ) {
				[[doc undoManager] setActionName:NSLocalizedString(@"Line Spacing", @"undo action: Line Spacing")];
			} else if ([sender tag]==2) {
				[[doc undoManager] setActionName:NSLocalizedString(@"Inter-line Spacing", @"undo action: Inter-line Spacing")];
			} else if ([sender tag]==3) {
				[[doc undoManager] setActionName:NSLocalizedString(@"Before Paragraph Spacing", @"undo action: Before Paragraph Spacing")];
			} else if ([sender tag]==4) {
				[[doc undoManager] setActionName:NSLocalizedString(@"Paragraph Spacing", @"undo action: Paragraph Spacing")];
			} else if ([sender tag]==5 || [sender tag]==6 || [sender tag]==7) {
				[[doc undoManager] setActionName:NSLocalizedString(@"Indent", @"undo action: Indent")];
			} else if ([sender tag]==8) {
				[[doc undoManager] setActionName:NSLocalizedString(@"Minimum Line Spacing", @"undo action: Minimum Line Spacing")];
			} else if ([sender tag]==9) {
				[[doc undoManager] setActionName:NSLocalizedString(@"Maximum Line Spacing", @"undo action: Maximum Line Spacing")];
			}	
		}
		[[doc undoManager] endUndoGrouping];
	}
	
	//	HIGHLIGHTING is a character attribute (NSBackgroundAttributeName); we handle it separately from paragraph attribtutes
	
	//tag = 30 to 39 for highlighting and remove highlighting
	else if ([sender tag] > 29 && [sender tag] < 40) 
	{ 
		NSEnumerator *e = [[textView selectedRanges] objectEnumerator];
		NSColor *theColor = nil;
		NSValue *theRangeValue;
		int tag = [sender tag];
		//	for selected ranges...
		while (theRangeValue = [e nextObject])
		{
			//setup undo
			[textView shouldChangeTextInRange:[theRangeValue rangeValue] replacementString:nil];
			//NOTE: move this outside while (shouldChangeTextInRanges)?
			//bracket for efficiency
			[textStorage beginEditing];
			switch (tag)
			{
				case 30: //remove background highlight color
					//nothing to do here
					break;
				case 31: //yellow
					theColor = [NSColor yellowColor];
					break;
				case 32: //orange
					theColor = [NSColor colorWithCalibratedRed:0.95 green:0.61 blue:0.13 alpha:1.0];
					break;
				case 33: //pink
					theColor = [NSColor colorWithCalibratedRed:0.92 green:0.58 blue:0.81 alpha:1.0];
					break;
				case 34: //blue
					theColor = [NSColor colorWithCalibratedRed:0.59 green:0.83 blue:0.95 alpha:1.0];
					break;
				case 35: //green
					theColor = [NSColor greenColor];
					break;
			}
			if (tag==30)
			{
				//	remove text HIGHLIGHTING
				[textStorage removeAttribute:NSBackgroundColorAttributeName range:[theRangeValue rangeValue]];
			}
			else
			{
				//	adjust text HIGHLIGHTING based on tag of menuItem
				[textStorage addAttribute:NSBackgroundColorAttributeName value:theColor range:[theRangeValue rangeValue]];
			}
			if (tag >= 30)
			{
				//	also set the typing attributes, in case no text yet, or end of string text
				NSDictionary *theAttributes = [textView typingAttributes];
				NSMutableDictionary *theTypingAttributes = [[theAttributes mutableCopy] autorelease];
				if (tag==30)
				{
					[theTypingAttributes removeObjectForKey:NSBackgroundColorAttributeName];
				}
				else
				{
					[theTypingAttributes setObject:theColor forKey:NSBackgroundColorAttributeName];
				}
				[textView setTypingAttributes:theTypingAttributes];
			}
			//	bracket for efficiency
			[textStorage endEditing];
			//	end undo
			[textView didChangeText];
			//	name undo for menu
			if ([sender tag] > 30)	{ [[doc undoManager] setActionName:NSLocalizedString(@"Highlighting", @"undo action: Highlighting")]; } 
			else { [[doc undoManager] setActionName:NSLocalizedString(@"Remove Highlighting", @"undo action: Remove highlighting")]; }
			theColor = nil;
		}
	}
	//set focus to docWindow only after ENTER in changed text field (not tab, etc.)
	if (returnFocusToDocWindow)
		[[doc docWindow] performSelector:@selector(makeKeyAndOrderFront:) withObject:self afterDelay:0.0f];
}

- (void)controlTextDidBeginEditing:(NSNotification *)aNotification
{
	[self setTextFieldDidChange:YES];
}

//so tabbing out of text fields don't cause (non-)changes to be committed (with unwanted undo actions) 
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	if ([[[aNotification userInfo] objectForKey:@"NSTextMovement"] intValue] == NSReturnTextMovement)
	{
		[self setReturnFocusToDocWindow:YES];
	}
	else
	{
		[self setReturnFocusToDocWindow:NO];	
	}
}

#pragma mark -
#pragma mark ---- Accessors ----

//	JHDocument notifies inspector upon updateInspector whether document which gained focus uses American measurement units or metric

- (float)pointsPerUnitAccessor { return pointsPerUnitAccessor; }
- (void)setPointsPerUnitAccessor:(float)points { pointsPerUnitAccessor = points; }

- (BOOL)shouldForceInspectorUpdate { return shouldForceInspectorUpdate; }
- (void)setShouldForceInspectorUpdate:(BOOL)flag { shouldForceInspectorUpdate = flag; }

-(BOOL)textFieldDidChange { return textFieldDidChange; }
-(void)setTextFieldDidChange:(BOOL)flag { textFieldDidChange = flag; }

-(BOOL)returnFocusToDocWindow { return returnFocusToDocWindow; }
-(void)setReturnFocusToDocWindow:(BOOL)flag { returnFocusToDocWindow = flag; }

/*
//test code
//	reports to appDelegate whether panel is instantiated 
- (BOOL )inspectorPanelIsVisible
{
	if (inspectorPanel) { return [inspectorPanel isVisible]; }
	else { return NO; }
}
*/

@end
