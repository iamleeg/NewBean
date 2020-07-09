/*
	JHDocument_CloseGracefully.m
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
 
#import "JHDocument_CloseGracefully.h"
#import "JHDocument_ReadWrite.h" //checkBeforeSaveWithContextInfo
#import "JHDocument_Backup.h" //backupDocument

//	category with NSDocument helper methods
@implementation JHDocument ( JHDocument_CloseGracefully )

#pragma mark -
#pragma mark --- JHDocument's 'Close Gracefully' Methods ---

// ******************* JHDocument's 'Close Gracefully' Methods ********************

- (void)canCloseDocumentWithDelegate:(id)inDelegate 
				 shouldCloseSelector:(SEL)inShouldCloseSelector
						 contextInfo:(void *)inContextInfo
{
	//	if shouldCreateDatedBackup (user prefs) AND doc not empty AND doc saved AND saved recently with changes, then back it up
	if ([self shouldCreateDatedBackup] && ![self isTransientDocument] && [self fileName] && [self needsDatedBackup])
	{
		//	do backup
		BOOL success = [self backupDocument]; 
		if (success)
		{
			//	prevents multiple backups because of different notifications which might occur at close
			[self setShouldCreateDatedBackup:NO];
		}
		else
		{
			//	don't try again; otherwise, user won't be able to close window
			[self setShouldCreateDatedBackup:NO];
			
			NSString *titleString = [NSString stringWithFormat:NSLocalizedString(@"Automatic backup of the document \\U201C%@\\U201D was not successful.", @"alert title: Automatic backup of the document (document name inserted at runtime) was not successful."), [self displayName]];
			NSString *infoString = NSLocalizedString(@"Try using the Finder to make a backup copy of this file. Deselect \\U2018Backup at close\\U2019 under \\U2018Get Info\\U2019 to disable automatic backup.", @"alert text: Try using the Finder to make a backup copy of this file. Deselect 'Backup at close' under 'Get Info' to disable automatic backup.");
			(void)NSRunAlertPanel(titleString, infoString, NSLocalizedString(@"OK", @"OK"), nil, nil);
		}
	}
	
	if (![self isDocumentEdited])
	{	
		//	if not edited, no need to save, so tell selector to close document
		[super canCloseDocumentWithDelegate:inDelegate 
						shouldCloseSelector:inShouldCloseSelector
								contextInfo:inContextInfo];
	}
	else
	{	
		//	typeDef to convey needed info as object to selector of canCloseWithDelegate via callback
		SelectorContextInfo *selectorContextInfo = malloc(sizeof(SelectorContextInfo));
		selectorContextInfo -> delegate = inDelegate;
		selectorContextInfo -> shouldCloseSelector = inShouldCloseSelector;
		selectorContextInfo -> contextInfo = inContextInfo;
		//	alert that doc has changed, save?
		NSString *title = nil;
		NSString *infoText = nil;
		infoText = NSLocalizedString(@"Your changes will be lost if you don\\U2019t save them.", @"alert text: Your changes will be lost if you don't save them.");
		NSString *docName = [NSString stringWithFormat:@"%@%@%@", NSLocalizedString(@"firstLevelOpenQuote", nil), [self displayName], NSLocalizedString(@"firstLevelCloseQuote", nil)]; 
		if ([self fileName])
		{
			title = [NSString stringWithFormat:NSLocalizedString(@"Do you want to save the changes you made in the document %@?", @"alert title: Do you want to save the changes you made in the document (name of document inserted at runtime -- nothing inserted if not named yet)?"), docName];
		}
		else
		{
			title = NSLocalizedString(@"Do you want to save the changes you made in this document?", @"alert title: Do you want to save the changes you made in this document?");
		}
		NSBeginAlertSheet(title, NSLocalizedString(@"Save", @"button: Save"), NSLocalizedString(@"Don\\U2019t Save", @"button: Don't Save"), NSLocalizedString(@"Cancel", @"button: Cancel"), docWindow, self, NULL, 
						  @selector(canCloseAlertDidEnd:returnCode:contextInfo:), selectorContextInfo, infoText); 
	}
}

- (void)canCloseAlertDidEnd:(NSAlert *)alert 
				 returnCode:(int)returnCode
				contextInfo:(void *)callBackInfo;
{
	
#define Save		NSAlertDefaultReturn
#define DontSave	NSAlertAlternateReturn
#define Cancel		NSAlertOtherReturn
	
	SelectorContextInfo *selectorContextInfo = callBackInfo; //	this is freed after the switch
	switch (returnCode)
	{
		case Save:
		{
			if ([self checkBeforeSaveWithContextInfo:callBackInfo isClosing:YES])
			{	
				//	success on save = can close; failure = cannot close
				[self saveDocumentWithDelegate:selectorContextInfo->delegate
							   didSaveSelector:selectorContextInfo->shouldCloseSelector 
								   contextInfo:selectorContextInfo->contextInfo];
			}
			else
			{
				//	return here to avoid freeing selectorContextInfo, which will be freed in checkBeforeSave...
				return;
			}
			break;
		}
		case Cancel:
		{
			//	send 'NO' callback to selector for canCloseWithDelegate (= don't close)
			void (*meth)(id, SEL, JHDocument *, BOOL, void*);
			meth = (void (*)(id, SEL, JHDocument *, BOOL, void*))[selectorContextInfo->delegate methodForSelector:selectorContextInfo->shouldCloseSelector];
			if (meth) { meth(selectorContextInfo->delegate, selectorContextInfo->shouldCloseSelector, self, NO, selectorContextInfo->contextInfo); }
			//	tell app to stop termination
			[NSApp replyToApplicationShouldTerminate:NSTerminateCancel];
			break;
		}
		case DontSave:
		{
			//	send 'YES' callback to selector for canCloseWithDelegate (= close without save)
			void (*meth)(id, SEL, JHDocument *, BOOL, void*);
			meth = (void (*)(id, SEL, JHDocument *, BOOL, void*))[selectorContextInfo->delegate methodForSelector:selectorContextInfo->shouldCloseSelector];
			if (meth)
				meth(selectorContextInfo->delegate, selectorContextInfo->shouldCloseSelector, self, YES, selectorContextInfo->contextInfo);
			break;
		}	
	}
	//	free memory
	free(selectorContextInfo);
}

- (BOOL)windowShouldClose:(id)sender
{
	//	indicates to repeating actions (such as word count) that they need to end immediately
	[self setIsTerminatingGracefully:YES];
	return YES;
}

-(void)windowWillClose:(NSNotification *)theNotification
{
	//	we invalidate timer here, or else dealloc doesn't get called (because the target of the timer
	//	is self (JHDocument), and so self is retained and never gets released (got that?)
	if (autosaveTimer)
	{
		[autosaveTimer invalidate];
		[autosaveTimer release];
		autosaveTimer = NULL;
	}
}

@end