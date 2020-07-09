/*
	JHDocument_MenuValidation.m
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

//validates document's menu items 
#import "JHDocument_MenuValidation.h"
#import "JHDocumentController.h" // for _openRecentDocument method (see note)

@implementation JHDocument ( JHDocument_MenuValidation )

#pragma mark -
#pragma mark ---- Menu Validation ----

// ******************* Menu Validation ********************
//	arbitrary numbers to determine state of menu items whose titles change. Speeds up the validation...cos not zero. (trick from Text Edit)

#define TagForFirst 42
#define TagForSecond 43

void validateToggleItem(NSMenuItem *aCell, BOOL useFirst, NSString *first, NSString *second)
{
	if (useFirst)
	{
		if ([aCell tag] != TagForFirst)
		{
			[aCell setTitle:first];
			[aCell setTag:TagForFirst];
		}
	} 
	else
	{
		if ([aCell tag] != TagForSecond)
		{
			[aCell setTitle:second];
			[aCell setTag:TagForSecond];
		}
	}
}

//	menu validation
- (BOOL)validateMenuItem:(NSMenuItem *)userInterfaceItem
{
	PageView *pageView = [theScrollView documentView];
	NSTextView *tv = [self firstTextView];
	SEL action = [userInterfaceItem action];
	/*
				Use this method to add images to menu items: e.g. paragraph alignment icons
				Note that doesn't work with std first responders, just IB actions
				if (action == @selector(getInfoSheet:)) {
					[userInterfaceItem setImage:[NSImage imageNamed:@"lilbean"]];
				}
	*/
	//	validate floatWindow
	if (action == @selector(floatWindow:))
	{
		([self isFloating]) ? [userInterfaceItem setState:1] : [userInterfaceItem setState:0];
	}
	//	validate setViewType
	else if (action == @selector(setTheViewType:))
	{
		validateToggleItem(userInterfaceItem, [self hasMultiplePages], 
			NSLocalizedString(@"Hide Layout", @"menu item: Hide page layout view."),
			NSLocalizedString(@"Show Layout", @"menu item: Show page layout view"));
		
		//	prevent NSMutableAttributedString out-of-bounds due to unfinished layout
		//	note: setTheViewType now forces layout to INTMAX if unfinished layout, so this is not needed here
		//if ([docWindow isVisible] && [layoutManager firstUnlaidCharacterIndex] < [textStorage length]) { return NO; }
		
	}
	//	validate toggleBothRulers
	else if (action == @selector(toggleBothRulers:))
	{
		validateToggleItem(userInterfaceItem, [theScrollView rulersVisible], 
			NSLocalizedString(@"Hide Ruler", @"menu item: Hide the ruler"), 
			NSLocalizedString(@"Show Ruler", @"menu item: Show the ruler"));
	}
	//	validate showInspectorAction
	//	TODO: would be nice to have this control always active, even with no documents, since the inspector might still need to be hidden, but even placing this in ApplicationDelegate doesn't do this :-(
	else if (action == @selector(showInspectorPanelAction:))
	{
		return YES;
	}
	//	validate showBeanSheet (getInfo)
	else if (action == @selector(showBeanSheet:) && [userInterfaceItem tag]==0)
	{
		if (![[NSApp keyWindow] isEqualTo:[theScrollView window]]) //another sheet is up
			return NO;
		else
			return YES;
	}
	//	validate defineWord
	else if (action == @selector(defineWord:))
	{
		if (![[textStorage string] length]) return NO;
		else return YES;
	}
	//	validate autocompleteAction
	else if (action == @selector(autocompleteAction:))
	{
		if (![[textStorage string] length]) return NO;
		else return YES;
	}
	//	validate toggleInvisiblesAction
	else if (action == @selector(toggleInvisiblesAction:))
	{
		validateToggleItem(userInterfaceItem, [layoutManager showInvisibleCharacters],
			NSLocalizedString(@"Hide Invisibles", @"menu item: Hide Invisible Characters"), 
			NSLocalizedString(@"Show Invisibles", @"menu item: Show Invisible Characters"));
	}
	//	validate toggleMarginsAction
	else if (action == @selector(toggleMarginsAction:))
	{
		if (![self hasMultiplePages])
		{
			return NO;
		}
		else
		{
			validateToggleItem(userInterfaceItem, [pageView showMarginsGuide], 
					NSLocalizedString(@"Hide Margins", @"menu item: Show the margin guide"),
					NSLocalizedString(@"Show Margins", @"menu item: Hide the margin guide"));
			return YES;
		}
	}
	//	validate zoomSelect
	else if (action == @selector(zoomSelect:))
	{
		if ([userInterfaceItem tag]==1)
		{
			[theScrollView isFitWidth] ? [userInterfaceItem setState:1] : [userInterfaceItem setState:0]; 
		}
		if ([userInterfaceItem tag]==2)
		{
			[theScrollView isFitPage] ? [userInterfaceItem setState:1] : [userInterfaceItem setState:0]; 
		}
	}
	//	validate switchTextColors
	else if (action == @selector(switchTextColors:))
	{
		([self shouldUseAltTextColors]) ? [userInterfaceItem setState:1] : [userInterfaceItem setState:0];
	}
	//	backup enabled only if not empty and has name
	else if (action == @selector(backupDocumentAction:))
	{
		if (![self isTransientDocument] && [self isDocumentSaved])
			{ return YES; }
		else
			{ return NO; }
	}
	//tab sheet
	else if (action == @selector(showBeanSheet:) && [userInterfaceItem tag]==5)
	{
		if (![[textStorage string] length] 
				|| ![[NSApp keyWindow] isEqualTo:[theScrollView window]] //another sheet is up
				|| [self readOnlyDoc]) 
		{
			return NO;
		}
		else
		{
			return YES;
		}
	}
	else if (action == @selector(listItemIndent:) || action == @selector(listItemUnindent:))
	{
		//	bounds check requirements for listItemIndent method
		if ([tv selectedRange].location==0 || [tv selectedRange].location==[textStorage length] || [self readOnlyDoc])
			return NO;
		NSParagraphStyle *pStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:[tv selectedRange].location effectiveRange:NULL];
		int listCount = 0;
		if (!pStyle)
			return NO;
		//	textLists exist, so enable
		else
			if (pStyle)
				listCount = [[pStyle textLists] count];
		return (listCount) ? YES : NO;
	}
	//	validate only if previous paragraph is a list item 28 DEC 07 JH; revised 18 MAR 09 JH
	else if (action == @selector(moveListItemNorth:))
	{
		//	check bounds
		if ([tv selectedRange].location==0 || [self readOnlyDoc]) return NO;
		
		//	is current paragraph a list item?
		int listCount = 0;
		NSRange paragraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange([tv selectedRange].location, 0)];
		NSParagraphStyle *pStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:paragraphRange.location effectiveRange:NULL];
		if (pStyle)
			listCount = [[pStyle textLists] count];

		//	if prev paragraph contains NO textList, can't move list item north in list
		int prevListCount = 0;
		int prevItemLoc = paragraphRange.location - 1;
		pStyle = nil;
		if (prevItemLoc > 0) //check bounds
		{
			pStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:prevItemLoc effectiveRange:NULL];
			if (pStyle)
				prevListCount = [[pStyle textLists] count];
		}
		
		if (!listCount || !prevListCount) return NO;
	}
	//	validate only if next paragraph is a list item 28 DEC 07 JH; revised 18 MAR 09 JH
	else if (action == @selector(moveListItemSouth:))
	{
		//	check bounds
		if ([tv selectedRange].location==[textStorage length] || [self readOnlyDoc]) return NO;
			
		//	is current paragraph a list item?
		int listCount = 0;
		NSRange paragraphRange = [[textStorage string] paragraphRangeForRange:NSMakeRange([tv selectedRange].location, 0)];
		NSParagraphStyle *pStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:paragraphRange.location effectiveRange:NULL];
		if (pStyle)
			listCount = [[pStyle textLists] count];
		
		//	if following paragraph contains NO textList, can't move list item south in list
		int followingListCount = 0;
		int followingItemLoc = NSMaxRange(paragraphRange);
		if (followingItemLoc < [textStorage length]) //check bounds
		{
			pStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:followingItemLoc effectiveRange:NULL];
			if (pStyle) 
				followingListCount = [[pStyle textLists] count];
		}
		
		if (!listCount || !followingListCount) return NO;
	}
	//creates text lists ex nihilo
	else if (action == @selector(specialTextListAction:))
	{
		//note: no bounds check needed for this routine
		return ([tv isRichText] && ![self readOnlyDoc]) ? YES : NO;
	}
	//	validate selectLiveWordCounting
	else if (action == @selector(selectLiveWordCounting:))
	{
		[self shouldDoLiveWordCount] ? [userInterfaceItem setState:1] : [userInterfaceItem setState:0];
	}
	//	determines if item on pboard is char or para style to paste and if so, enables menu and changes title
	else if (action == @selector(copyAndPasteFontOrRulerAction:))
	{
		NSPasteboard *fontPasteboard = [NSPasteboard pasteboardWithName:NSFontPboard];
		NSPasteboard *rulerPasteboard = [NSPasteboard pasteboardWithName:NSRulerPboard];
		//	paste font
		if ([userInterfaceItem tag]==2 && [fontPasteboard changeCount] > 0) 
		{
			return YES;
		}
		//	paste ruler
		else if ([userInterfaceItem tag]==3 && [rulerPasteboard changeCount] > 0)
		{
			return YES;
		}
		//	copy font; copy ruler; copy font/ruler
		else if ([userInterfaceItem tag]==0 
					 || [userInterfaceItem tag]==1 
					 || [userInterfaceItem tag]==4)
		{
			//avoid addAttribute:nil when isRichText==NO (27 May 2007 BH)
			if ([tv isRichText]) { return YES; }
			else { return NO; }
		}
		//	paste font/ruler
		else if ([userInterfaceItem tag]==5 && [rulerPasteboard changeCount] > 0 && [fontPasteboard changeCount] > 0)
		{
			return YES;
		}
		//	select by...various // tag > 5 (18 MAY 08 JH)
		else if ( ( [textStorage length] == 0
					|| [tv selectedRange].location==[textStorage length] )
					&& ( [userInterfaceItem tag] > 5 ) )
		{
			return NO;
		}
		else
		{
			return YES;
		}
	}
	//	change convertSmartQuotes menu action title depending on if there is a text selection (7 April 2007)
	else if (action == @selector(convertQuotesAction:))
	{
		//	active only if text length > 0
		if ([textStorage length] > 0 && ![self readOnlyDoc])
		{
			//	to Smart Quotes menu item
			if ([userInterfaceItem tag]==0)
			{
				//	disable Smart Quotes option if HTML (27 May 2007 BH)
				if ([[self fileType] isEqualToString:HTMLDoc]) 
				{
					return NO;
				}
				else
				{
					if ([tv selectedRange].length == 0)
					{
						//	convert whole text to Smart Quotes
						//	changed all setTitleWithMnemonic to setTitle
						//		setTitleWithMnemonic was probably for Yellow Box, use here was just a mistake
						[userInterfaceItem setTitle:NSLocalizedString(@"Text to Smart Quotes", @"menu item: Text to Smart Quotes (Convert all text in document to use Smart Quotes)")];
					}
					else
					{
						//	convert just selection to Smart Quotes
						[userInterfaceItem setTitle:NSLocalizedString(@"Selection to Smart Quotes", @"menu item: (Convert selected text in document to use Smart Quotes)")];
					}
				}
			}
			//	to Straight Quotes
			else
			{
				if ([tv selectedRange].length == 0)
				{
					//	convert whole text to Straight Quotes
					[userInterfaceItem setTitle:NSLocalizedString(@"Text to Straight Quotes", @"menu item: Text to Straight Quotes (Convert all text in document to use Straight Quotes)")];
				}
				else
				{
					//	convert selected text to Straight Quotes
					[userInterfaceItem setTitle:NSLocalizedString(@"Selection to Straight Quotes", @"menu item: Selection to Straight Quotes (Convert selected text in document to use Straight Quotes)")];
				}
			return YES;
			}
		}
		else return NO;
	}	
	//	Smart Quotes menu action
	else if (action == @selector(useSmartQuotesAction:))
	{
		//for .txt, we enable in case needed (Gutenberg, etc.)
		if ([[self currentFileType] isEqualToString:HTMLDoc] 
					|| [[self currentFileType] isEqualToString:TXTwExtDoc])
		{
			return NO;
		}
		else
		{
			//if Bean Smart Quotes or Leopard Smart Quotes is active
			if ([self shouldUseSmartQuotes] 
						|| ([[self firstTextView] respondsToSelector:@selector(isAutomaticQuoteSubstitutionEnabled)]
						&& [[self firstTextView] isAutomaticQuoteSubstitutionEnabled]))
			{
				//show active with checkmark
				[userInterfaceItem setState:1];
			}
			else
			{
				//show inactive with no checkmark
				[userInterfaceItem setState:0];
			}
			return YES;
		}
	}
	else if (action == @selector(insertDateTimeStamp:))
	{
		if (![self readOnlyDoc])
			return YES;
		else
			return NO;
	}
	//	don't allow export if file was never saved (no filename)
	else if (action == @selector(exportToHTML:))
	{
		if ([[self fileType] isEqualToString:HTMLDoc] || [self fileName]==nil) return NO;
	}
	//	don't allow export to PDF if file was never saved (no filename)
	else if (action == @selector(printDocument:) && [userInterfaceItem tag]==100)
	{
		if ([self fileName]==nil) return NO;
	}
	//	don't allow export if file was never saved (no filename)
	else if (action == @selector(saveRTFwithPictures:))
	{
		//	we now allow export even if there are no images, to facilitate people wanting to share rtf as .doc! 20 MAY 08 JH
		//if ([self fileName]==nil || ![textStorage containsAttachments]) return NO;
		if ([self fileName]==nil) return NO;
	}
	else if (action == @selector(revertDocumentToSaved:))
	{
		if (![self isTransientDocument] && [self isDocumentSaved] && [self isDocumentEdited])
			return YES;
		else
			return NO;
	}
	//	no hyperlink possible for plain text
	else if (action == @selector(showBeanSheet:) && [userInterfaceItem  tag]==6)
	{
		//added check for readOnly 11 Oct 2007
		return ([tv isRichText] && ![self readOnlyDoc]) ? YES : NO;
	}
	else if (action == @selector(restoreCursorLocationAction:))
	{
		if (!([self savedEditLocation]) || ([self savedEditLocation] == ([tv selectedRange].location + [tv selectedRange].length)))
			{ return NO; }
	}
	else if (action == @selector(textControlAction:))
	{
		switch ([userInterfaceItem tag])
		{
			case 30:
				[userInterfaceItem setImage:[NSImage imageNamed:@"swatchX"]];
				break;
			case 31:
				[userInterfaceItem setImage:[NSImage imageNamed:@"swatchYellow"]];
				break;
			case 32:
				[userInterfaceItem setImage:[NSImage imageNamed:@"swatchOrange"]];
				break;
			case 33:
				[userInterfaceItem setImage:[NSImage imageNamed:@"swatchPink"]];
				break;
			case 34:
				[userInterfaceItem setImage:[NSImage imageNamed:@"swatchBlue"]];
				break;
			case 35:
				[userInterfaceItem setImage:[NSImage imageNamed:@"swatchGreen"]];
				break;
		}
		//	if highlight buttons in inspector
		if ([userInterfaceItem tag] > 29)
		{
			// bugfix: change so typing attributes are effected when selRange.length is zero 16 OCT 08 JH
			if (![self readOnlyDoc])
				return YES;
			else
				return NO;
		}
		//	everything else
		else
		{
			if ([textStorage length] && ![self readOnlyDoc]) 
				return YES;
			else
				return NO;
		}
	}
	else if (action == @selector(sendToMail:))
	{
		if ([self fileName]) 
			return YES;
		else
			return NO;
	}
	//margins, header/footer, and columns sheets inactive when doc is read only
	else if (action == @selector(showBeanSheet:) && 
				([userInterfaceItem tag]==3 
				|| [userInterfaceItem tag]==7
				|| [userInterfaceItem tag]==8))
	{
		if ([self readOnlyDoc]) 
			return NO;
		else
			return YES;
	}
	else if (action == @selector(insertBreakAction:))
	{
		if ([self readOnlyDoc]) 
			return NO;
		else
			return YES;
	}
	//insert image sheet
	else if (action == @selector(insertImageAction:))
	{
		if ([tv importsGraphics] && ![self readOnlyDoc]) 
			return YES;
		else
			return NO;
	}
	//resize image sheet
	else if (action == @selector(showBeanSheet:) && [userInterfaceItem  tag]==4)
	{
		if	(	[tv importsGraphics]
				&& [[textStorage attributedSubstringFromRange:[tv selectedRange]] containsAttachments]
				&& [[NSApp keyWindow] isEqualTo:[theScrollView window]] //another sheet is up
				&& ![self readOnlyDoc]
			) 
			return YES;
		else
			return NO;
	}
	//	propertiesSheetAction
	else if (action == @selector(showBeanSheet:) && [userInterfaceItem  tag]==1)
	{
		 //not rich text, or another sheet is up
		if (![tv isRichText] || ![[NSApp keyWindow] isEqualTo:[theScrollView window]])
			 { return NO; }
		else
			 { return YES; }
	}
	//	'extend style of selection' is menu item title in nib
	else if (action == @selector(matchToSelectionAction:))
	{
		if ([tv selectedRange].location==[textStorage length] || ![tv isRichText]) { return NO; }
		if (![textStorage length]==0 && ![self readOnlyDoc])
		{
			if ([tv selectedRange].length == 0)
			{
				//	apply defaults to whole doc
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: All to Style at Text Cursor", @"menu item: Match > All to Style at Text Cursor")];
			}
			else
			{
				//	apply defaults to selection
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: Selection to Style at Text Cursor", @"menu item: Match > Selection to Style at Text Cursor")];
			}
			return YES;
		}
		else
		{
			return NO;		
		}
	}
	else if (action == @selector(simplifyStylesAction:))
	{
		if (![textStorage length]==0 && ![self readOnlyDoc] && [tv isRichText])
		{
			if ([tv selectedRange].length == 0)
			{
				//	apply defaults to whole doc
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: All to Most Common Style", @"menu item: Match > All to Most Common Style (apply most common Font and Ruler in document across entire text)")];
			}
			else
			{
				//	apply defaults to selection
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: Selection to Most Common Style", @"menu item: Match > Selection to Most Common Style (extend most common Font and Ruler in selection to entire selection)")];
			}
			return YES;
		}
		else
		{
			return NO;		
		}
	}
	else if (action == @selector(removeAllStylesAction:))
	{
		if (![textStorage length]==0 && ![self readOnlyDoc] && [tv isRichText])
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}	
	else if (action == @selector(applyDefaultStyleAction:))
	{
		if (![textStorage length]==0 && ![self readOnlyDoc])
		{
			if ([tv selectedRange].length == 0)
			{
				//	apply defaults to whole doc
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: All to Default Style", @"menu item: Match > All to Default Style (applies Font and Ruler from Preferences to entire text)")];
			}
			else
			{
				//	apply defaults to selection
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: Selection to Default Style", @"menu item: Match > Selection to Default Style (applies Font and Ruler from Preferences to selection)")];
			}
			return YES;
		}
		else
		{
			return NO;		
		}
	}
	//we don't validate these 'remove actions' ; perhaps we should?
	else if (action == @selector(removeAttachmentsAction:))
	{
		if (![textStorage length]==0 && ![self readOnlyDoc])
		{
			if ([tv selectedRange].length == 0)
			{
				//	apply defaults to whole doc
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: All Attachments", @"menu item: Edit > Remove > All Attachments")];
			}
			else
			{
				//	apply defaults to selection
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: Selected Attachments", @"menu item: Selected Attachments")];
			}
			return YES;
		}
		else
		{
			return NO;		
		}
	}
	else if (action == @selector(removeTextListsAction:))
	{
		if (![textStorage length]==0 && ![self readOnlyDoc])
		{
			if ([tv selectedRange].length == 0)
			{
				//	apply defaults to whole doc
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: All List Markers", @"menu item: Edit > Remove > All List Markers")];
			}
			else
			{
				//	apply defaults to selection
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: Selected List Markers", @"menu item: Edit > Remove > Selected List Markers")];
			}
			return YES;
		}
		else
		{
			return NO;		
		}
	}
	else if (action == @selector(removeTextTablesAction:))
	{
		if (![textStorage length]==0 && ![self readOnlyDoc])
		{
			if ([tv selectedRange].length == 0)
			{
				//	apply defaults to whole doc
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: All Text Tables", @"menu item: Edit > Remove > All Text Tables")];
			}
			else
			{
				//	apply defaults to selection
				[userInterfaceItem setTitle:NSLocalizedString(@"menu item: Selected Text Tables", @"menu item: Edit > Remove > Selected Text Tables")];
			}
			return YES;
		}
		else
		{
			return NO;		
		}
	}
	else if (action == @selector(strikethroughAction:))
	{
		if (![self readOnlyDoc] && [tv isRichText])
		{
			NSDictionary *theAttributes;
			NSObject *theStrikethrough;
			if ([tv selectedRange].length > 0)
				theAttributes = [textStorage attributesAtIndex:[tv selectedRange].location effectiveRange:NULL];
			// if no selection, check typing attributes
			else
				theAttributes = [tv typingAttributes];
			theStrikethrough = [theAttributes objectForKey:NSStrikethroughStyleAttributeName];
			(theStrikethrough) ? [userInterfaceItem setState:1] : [userInterfaceItem setState:0];
			return YES;
		}
		else
		{
			return NO;
		}
	}
	else if (action == @selector(allowHyphenationAction:))
	{
		if ([textStorage length] > 0 && ![self readOnlyDoc] && [tv selectedRange].location!=[textStorage length])
		{
			NSParagraphStyle *theStyle;
			theStyle = [textStorage attribute:NSParagraphStyleAttributeName atIndex:[tv selectedRange].location effectiveRange:NULL];
			float theHyphenationFactor = [theStyle hyphenationFactor];
			if (theHyphenationFactor > 0.1)
				[userInterfaceItem setState:1];
			else
				[userInterfaceItem setState:0];
			return YES;
		}
		else
		{
			return NO;
		}
	}
	else if (action == @selector(bean_toggleFullScreen:))
	{
		if (fullScreen)
			[userInterfaceItem setState:1];
		else
			[userInterfaceItem setState:0];
		return YES;
	}
	//	validate toggleInvisiblesAction
	else if (action == @selector(toggleToolbarShownAction:))
	{
		validateToggleItem(userInterfaceItem, [[docWindow toolbar] isVisible],
			NSLocalizedString(@"menu item: Hide Toolbar", @"menu item: Hide Toolbar"), 
			NSLocalizedString(@"menu item: Show Toolbar", @"menu item: Show Toolbar"));
	}
	//the open recent menu items don't work in full screen (systemUISuppressed) mode, so disable - bug filed with Apple rdar://problem/5748616 
	//NOTE: _openRecentDocument: is private, but if it becomes truely private, no problem; this 'if' clause will never be used then
	else if (action == @selector(_openRecentDocument:))
	{
		if (fullScreen) return NO;
		else return YES;
	}
	else if (action == @selector(makeTemplateAction:))
	{
		NSString *filePath = [self fileName];
		//can't make an unsaved file a template
		if (!filePath) return NO;
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL isLocked = NO;
		NSDictionary *theFileAttrs = [fm fileAttributesAtPath:filePath traverseLink:YES];
		//is file locked (a template)?
		isLocked = [[theFileAttrs objectForKey:NSFileImmutable] boolValue];
		//enable for unlocked files
		if (!isLocked) return YES;
		else return NO;
	}
	else if (action == @selector(toggleAlternateFont:))
	{
		if (_alternateFontActive) [userInterfaceItem setState:1];
		else [userInterfaceItem setState:0];
		return ([tv isRichText] && ![self readOnlyDoc]) ? YES : NO;
	}
	else if (action == @selector(beginNote:) || action == @selector(insertSignatureLineAction:))
	{	
		return ([tv isRichText] && ![self readOnlyDoc]) ? YES : NO;
	}
	/*
	 else if (action == @selector(alignLeft:)) {
		 [userInterfaceItem setImage:[NSImage imageNamed:@"TBCopyItemImage"]];
	}
	*/
	else
	{
	   return [super validateUserInterfaceItem: userInterfaceItem];
	}
	return YES;
}

@end