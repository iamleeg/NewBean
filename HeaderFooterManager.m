/*
	HeaderFooterManager.m
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
 
#import "HeaderFooterManager.h"
#import "JHDocument.h"
#import "PrefWindowController.h" //show header/footer controls in Preferences

//	show header/footer sheet, set header/footer action and prepare undo
@implementation HeaderFooterManager

#pragma mark -
#pragma mark ---- Init, Dealloc ----

- (void)dealloc
{
	if (document) [document release];
	[super dealloc];
}

//	call header/footer sheet and insert current values
- (IBAction)showSheet:(id)sender
{
	if(headerFooterSheet == nil) { [NSBundle loadNibNamed:@"HeaderFooter" owner:self]; }
	if(headerFooterSheet == nil)
	{
		//marginsSheet behavior in nib = [x] release self when closed, so we don't need: [marginsSheet release];
		NSLog(@"Could not load HeaderFooter.nib");
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}

	//load localized control labels
	[closeButton setTitle:NSLocalizedString(@"button: Close", @"button: Close")];
	[lockSettingsButton setTitle:NSLocalizedString(@"button: Lock header/footer style", @"button: Lock header/footer style")];
	[lockSettingsButton sizeToFit];
	[showSettingsButton setTitle:NSLocalizedString(@"button: Show Header/Footer Preferences…", @"button: Show Header/Footer Preferences…")];
	[showSettingsButton sizeToFit];
		
	//instance of JHDocument is sender
	[self setDocument:sender];
	id doc = [self document];
	
	//if using pref for header/footer (default)
	if ([doc headerFooterSetting]==0)
	{
		[lockSettingsButton setState:NSOffState];
	}
	else
	{
		[lockSettingsButton setState:NSOnState];
	}
	
	//show panel
	[NSApp beginSheet:headerFooterSheet 
	   modalForWindow:[NSApp mainWindow]
		modalDelegate:nil
	   didEndSelector:nil
		  contextInfo:nil];
}

//
-(IBAction)headerFooterAction:(id)sender
{
	id doc = [self document];

	//	use Preference settings for header/footer
	if ([sender state]==NSOffState)
	{
		//only headerFooterSetting accessor matters here, since 0 causes app to look to prefs for settings
		[doc setHeaderFooterSetting:0];
	}
	//	doc saves current settings for header/footer
	else
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		// 0 = use prefs, 1 = no header/footer, 2 = header/footer
		[doc setHeaderFooterSetting:[defaults boolForKey:@"prefPrintHeaderFooter"] + 1];
		[doc setHeaderFooterStyle:[[defaults objectForKey:@"prefStyleHeaderFooterTag"] intValue]];
		[doc setHeaderFooterStartPage:[[defaults objectForKey:@"prefHeaderFooterPagesToSkip"] intValue]];
	}

	//	refresh view to reflect changes
	PageView *pageView = [[doc theScrollView] documentView];
	//	if layout view is on
	if ([pageView isKindOfClass:[PageView class]])
	{
		//	refresh view
		[pageView setForceRedraw:YES];
		[pageView setNeedsDisplay:YES];
	}
}

//	close panel
-(IBAction)closeHeaderFooterSheet:(id)sender
{	
	//	dismiss sheet 
	[NSApp stopModal];
	[NSApp endSheet: headerFooterSheet];
	[headerFooterSheet orderOut:self];
	//fixed leak 14 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[headerFooterSheet close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
}

// show header/footer controls pane in Preferences 
-(IBAction)showHeaderFooterControls:(id)sender
{
	id pWC = [PrefWindowController sharedInstance]; 
	if ([pWC window])
	{
		[pWC showWindow:nil];
		[[pWC window] orderFront:nil];
		[pWC showPrintTabView:self];
	}
}

#pragma mark -
#pragma mark ---- Accessors ----

// ******************* Accessors ********************

-(JHDocument *)document
{
	return document;
}

-(void)setDocument:(JHDocument *)newDoc
{
	[newDoc retain];
	[document release];
	document = newDoc;
}

@end