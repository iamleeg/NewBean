/*
	JHDocument_Backup.m
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

// methods to read and write files (open, save, export, backup)
#import "JHDocument_ReadWrite.h"
#import "GetInfoManager.h" //for autosave controls

@implementation JHDocument ( JHDocument_Backup )

#pragma mark -
#pragma mark ---- Backup ----

// ******************* Backup *******************

//called by backupDocumentAction and backupDocumentAtQuitAction
-(BOOL)backupDocument
{
	//	if file has been saved (changed) since opening, make a backup of this 'version' of the document
	BOOL success = NO;
	//	using 10.1-3 style for NSDateFormatter
	int backupFileNumber = 1;
	//	create date string for date-stamp to add to backup filename
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] 
									   initWithDateFormat:@"%1Y-%m-%d" allowNaturalLanguage:NO] autorelease];
	NSDate *today = [NSDate date];
	NSString *formattedDateString = [dateFormatter stringFromDate:today];
	//	what if file has no extension?
	NSString *theExtension = [[self fileName] pathExtension];
	NSString *thePathMinusExtension = [[self fileName] stringByDeletingPathExtension];
	NSString *theBackupFilePath = [NSString stringWithFormat:@"%@%@%@%@%i%@%@", 
								   thePathMinusExtension, @".", formattedDateString, @" ", backupFileNumber, @".", theExtension];
	//NSURL *theBackupURL = [NSURL fileURLWithPath:theBackupFilePath]; //dead code
	NSFileManager *fileManager = [NSFileManager defaultManager];
	//add sequential numbers to distinguish between backups done on the same date, so none are overwritten
	while ([fileManager fileExistsAtPath:theBackupFilePath] && backupFileNumber < 1000)
	{
		backupFileNumber = backupFileNumber + 1;
		theBackupFilePath = [NSString stringWithFormat:@"%@%@%@%@%i%@%@", 
							 thePathMinusExtension, @".", formattedDateString, @" ", backupFileNumber, @".", theExtension];
		//theBackupURL = [NSURL fileURLWithPath:theBackupFilePath]; //dead code
	}
	NSString *theSource = [self fileName];
	if ([fileManager fileExistsAtPath:theSource])
	{
		//	duplicate the written-out representation and give it the backup filename
		success = [fileManager copyPath:theSource toPath:theBackupFilePath handler:nil];
	}
	//	unsuccessful backup is handled elsewhere
	return success;
}

//	done automatically at document close according to Preference setting, or else as action of menu item
-(IBAction)backupDocumentAction:(id)sender
{
	BOOL success = [self backupDocument];
	//	message that backup was not succcessful
	if (!success)
	{
		NSString *title = NSLocalizedString(@"The backup was not successful.", @"alert title: The backup was not successful. (alert shown upon failure of backup file save)");
		NSString *infoText = NSLocalizedString(@"A date-stamped backup copy of this document could not be created due to an unknown problem.", @"alert text: A date-stamped backup copy of this document could not be created due to an unknown problem.");
		NSBeginAlertSheet(title, NSLocalizedString(@"OK", @"OK"), nil, nil, [[self firstTextView] window], self, nil, nil, NULL, infoText, NULL);
	}
}

-(IBAction)backupDocumentAtQuitAction:(id)sender
{
	//if shouldCreateDatedBackup (prefs) AND not empty doc AND not unsaved doc AND doc was saved with changes, then back it up
	if ( [self shouldCreateDatedBackup] 
		 && ![self isTransientDocument]
		 && [self fileName]
		 && [self needsDatedBackup] )
	{
		//	do backup
		BOOL success = [self backupDocument]; 
		if (success)
		{
			//	prevents multiple backups due to different notifications which occur at quit
			[self setShouldCreateDatedBackup:NO];
		}
		else
		{
			//	prevents multiple backups due to different notifications which occur at quit
			[self setShouldCreateDatedBackup:NO];
			NSString *titleString = [NSString stringWithFormat:NSLocalizedString(@"Automatic backup of the document \\U201C%@\\U201D was not successful.", @"alert title: Automatic backup of the document (document name inserted at runtime) was not successful."), [self displayName]];
			NSString *infoString = NSLocalizedString(@"Try using the Finder to make a backup copy of this file. Deselect \\U2018Backup at close\\U2019 under \\U2018Get Info\\U2019 to disable automatic backup.", @"alert text: Try using the Finder to make a backup copy of this file. Deselect 'Backup at close' under 'Get Info' to disable automatic backup.");
			(void)NSRunAlertPanel(titleString, infoString, NSLocalizedString(@"OK", @"OK"), nil, nil);
		}
	}
}

#pragma mark -
#pragma mark ---- Backup ----

//	I M P O R T A N T: Autosave code (in Get Info...) was repurposed as 'Backup' after Cocoa autosave started being used in Bean
//	---------- only difference is instead of (Autosaved) filename addition before suffix, it's (Backup)

// ******************* Autosave ********************

//	I M P O R T A N T: Autosave (in Get Info...) was repurposed as 'Backup' after Cocoa autosave started being used in Bean
- (void)beginAutosavingDocumentWithInterval:(int)interval
{
	int theAutosaveInterval = interval * 60; 
	//	autosaveTimer is declared in the header file
	if (!autosaveTimer)
	{
		[self setAutosaveTime:interval];
		autosaveTimer = [[NSTimer scheduledTimerWithTimeInterval:theAutosaveInterval target:self selector:@selector(autosaveDocument:) userInfo:nil repeats:YES] retain];
	}
}

//	I M P O R T A N T: Autosave (in Get Info...) was repurposed as 'Backup' after Cocoa autosave started being used in Bean
- (void)autosaveDocument: (NSTimer *)theTimer
{
	//Autosaves the document, with (Autosave) appended to fileName before the extension, at interval specified. Only writes out if changes exist since last autosave (via needsAutosave), irrespective of isDirty accessor. Autosaved documents are never overwritten directly; there is no danger then of lossy docs being overwritten and information being lost, and there is no need to interrupt the user with warning dialogs. Also, this way, changes the user might not want to save in the original document are not saved without asking user. Note that subsequent autosaves overwrite this '(Autosaved)' file.
	
	//	docs that are transient can't autosave (control should be un-enabled anyway)
	if (isTransientDocument) { return; }
	
	//	if autosave is on (that's how we got here) and doc is edited (whether saved or not), do autosave
	if ([self fileName] && [self needsAutosave]) {
		//	we add '(Autosave)' to filename before extension and save to the same folder as the original file 
		//	what is there is no extension?
		NSString *theExtension = [[self fileName] pathExtension];
		NSString *thePathMinusExtension = [[self fileName] stringByDeletingPathExtension];
		NSString *autosaveFilenameSuffix = [NSString stringWithFormat:@"%@%@", @" ", NSLocalizedString(@"(Backup)", @"Suffix added to end of filename before extension indicating that file was automatically backed-up.")];
		NSString *theAutosavePath = [NSString stringWithFormat:@"%@%@%@%@", thePathMinusExtension, autosaveFilenameSuffix, @".", theExtension];
		NSURL *theURL = [NSURL fileURLWithPath:theAutosavePath];
		NSError *theError = nil;
		[self writeToURL:theURL ofType:[self fileType] error:&theError];
		[self setNeedsAutosave:NO];
		
		//	error alert dialog
		if (theError) {
			//	turn autosave off so the problem does not repeat, then alert the user
			[autosaveTimer invalidate];
			[autosaveTimer release];
			autosaveTimer = NULL;
			[self setDoAutosave:NO];
			NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Backup failed: %@", @"alert title: Backup failed: (localized reason inserted here at runtime)."), [theError localizedDescription]];
			NSString *infoText = [NSString stringWithFormat:NSLocalizedString(@"Automatic backup of the document \\U201C%@\\U201D failed. Automatic backup is now deactivated for this document so the problem does not repeat.", @"alert text: Automatic backup of the document (document name inserted at runtime) failed. Automatic backup is now deactivated for this document so the problem does not repeat."), [theAutosavePath lastPathComponent]];
			NSBeginAlertSheet(title, NSLocalizedString(@"OK", @"OK"), nil, nil, [[self firstTextView] window], self, nil, nil, NULL, infoText, NULL);
		}
	}
}

//	I M P O R T A N T: Autosave (in Get Info...) was repurposed as 'Backup' after Cocoa autosave started being used in Bean
-(void)toggleAutosave
{
	//note: toggleAutosave (that is, clicking the button in Get Info...) dirties document; there is no 'undo' action
	//can make undoable, but uncertain whether user would understand without alert that they were undoing a checkbox (so to speak) on the not-currently-visible Get Info... sheet.
	
	//	is autosaving, so stop autosave
	if (autosaveTimer)
	{
		[autosaveTimer invalidate];
		[autosaveTimer release];
		autosaveTimer = NULL;
		[self setDoAutosave:NO];
		[self updateChangeCount:NSChangeDone];
	}
	//	start autosaving
	else
	{
		[self setDoAutosave:YES];
		[self updateChangeCount:NSChangeDone];
		[self beginAutosavingDocumentWithInterval:[self autosaveTime]];
	}
}

//	I M P O R T A N T: Autosave (in Get Info...) was repurposed as 'Backup' after Cocoa autosave started being used in Bean
-(IBAction)setAutosaveInterval:(int)interval
{
	//timed backup is active...
	if (autosaveTimer)
	{
		//get rid of old timer
		[autosaveTimer invalidate];
		[autosaveTimer release];
		autosaveTimer = NULL;
		//create new timer
		[self updateChangeCount:NSChangeDone]; //dirties doc; no undo
		[self beginAutosavingDocumentWithInterval:interval];
	}
}


@end

