/*
  JHFindPanel.h
  Copyright (c) 2007-2011 James Hoover
 */

#import <Cocoa/Cocoa.h>

@interface JHFindPanel : NSPanel
{
	//for findTextField field editor (to show invisibles) 
	NSTextView *findFieldEditor;
	
	//for localized menu items in search history menus
	NSMenu *fieldHistory;

//	for loading localized strings into nib
	id findLabel;
	id replaceWithLabel;
	id findTextField;
	id replaceTextField;
//
	id ignoreCaseButton;
	id useRegExButton;
	id patternPopupButton;
	id statusField;	//loads status messages, like: 'Not Found' '7 Replaced' etc.
//
	id findNextButton;
	id findPreviousButton;
	id findAndReplaceButton;
	id replaceButton;
//	
	id selectAllButton;
	id replaceAllButton;
	id rangePopupButton; //for Option key behavior
	id optionKeyLabel;
}

@end
