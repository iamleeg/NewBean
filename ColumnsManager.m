/*
	ColumnsManager.m
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
 
#import "ColumnsManager.h"
#import "JHDocument.h"
#import "JHDocument_Print.h" //applyUpdatedPrintInfo
#import "JHDocument_PageLayout.h" //doForegroundLayout...
#import "JHDocument_View.h" //updateZoomSlider
#import "JHDocument_Misc.h" //undo method
#import "NSTextViewExtension.h"
#import "GLOperatingSystemVersion.h"


//	show header/footer sheet, set header/footer action and prepare undo
@implementation ColumnsManager

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
	if(columnsSheet == nil) { [NSBundle loadNibNamed:@"Columns" owner:self]; }
	if(columnsSheet == nil)
	{
		//columnsSheet behavior in nib = [x] release self when closed, so we don't need: [columnsSheet release];
		NSLog(@"Could not load Columns.nib");
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}
	
	//load localized control labels
	[applyButton setTitle:NSLocalizedString(@"button: Apply", @"")];
	[cancelButton setTitle:NSLocalizedString(@"button: Cancel", @"")];
	[columnsLabel setObjectValue:NSLocalizedString(@"label: Columns",@"")];
	[columnsLabel sizeToFit];
	[gutterLabel setObjectValue:NSLocalizedString(@"label: Gutter (pts)",@"")];
	[gutterLabel sizeToFit];
	
	//instance of JHDocument is sender
	[self setDocument:sender];
	id doc = [self document];
	
	//load settings
	int columns = [doc numberColumns];
	[columnsStepper setIntValue:columns];
	[columnsValueLabel setIntValue:[columnsStepper intValue]];
	int gutter = [doc columnsGutter];
	if (gutter==0)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		unsigned gutterSize = [[defaults objectForKey:@"prefDefaultColumnGutter"] intValue];
		//error check
		if (gutterSize < 0 || gutterSize > 40) gutterSize = 15;
		[gutterStepper setIntValue:gutterSize];
		[gutterValueLabel setIntValue:[gutterStepper intValue]];
	}
	else
	{
		[gutterStepper setIntValue:gutter];
		[gutterValueLabel setIntValue:[gutterStepper intValue]];
	}
	if (columns==1)
		[gutterValueLabel setTextColor:[NSColor lightGrayColor]];
	else
		[gutterValueLabel setTextColor:[NSColor blackColor]];
	
	//show sheet
	[NSApp beginSheet:columnsSheet 
	   modalForWindow:[NSApp mainWindow]
		modalDelegate:nil
	   didEndSelector:nil
		  contextInfo:nil];
}

//
-(IBAction)columnsAndGutterAction:(id)sender
{
	//	update columns label
	if ([sender tag]==0)
	{
		int numColumns = [sender intValue];
		[columnsValueLabel setIntValue:numColumns];
		if (numColumns == 1)
		{
			[gutterValueLabel setTextColor:[NSColor lightGrayColor]];
		}
		else if (numColumns > 1)
		{
			[gutterValueLabel setTextColor:[NSColor blackColor]];
		}
	}
	//	update gutter label
	else
	{
		[gutterValueLabel setIntValue:[sender intValue]];
	}
}

//	close panel
-(IBAction)applyOrCancelAction:(id)sender
{
	//BUGFIX 5 JAN 09 JH on tiger, dismissing the sheet at the end of the method did not work for some reason; but responds better the Leopard compatible way, so use alternate method behavior for Leopard +
	BOOL isTiger = NO;
	if ([GLOperatingSystemVersion isBeforeLeopard])
		isTiger = YES;
	//dismiss sheet
	if (isTiger)
	{
		[columnsSheet orderOut:self];
		[NSApp endSheet: columnsSheet];
	}
	//apply button
	if ([sender tag]==1)
	{
		id doc = [self document];
		int newColumns = [columnsStepper intValue];
		int newGutter = [gutterStepper intValue];
		if ([doc numberColumns] != newColumns || [doc columnsGutter] != newGutter)
		{
			//	record old margin settings in case undo margin change is called
			[ [[doc undoManager] prepareWithInvocationTarget:doc] 
					undoChangeColumns:[doc numberColumns]
					gutter:[doc columnsGutter] ];
			[[doc undoManager] setActionName:NSLocalizedString(@"Change Columns", @"undo action: Change Margins")];
	
			[doc rememberVisibleTextRange];
			//	set number columns
			[doc setNumberColumns:newColumns];
			//	set gutter width in pts
			[doc setColumnsGutter:newGutter];
			PageView *pageView = [[doc theScrollView] documentView];
			//	means Layout View
			if ([pageView isKindOfClass:[PageView class]])
			{
				//	must refresh view
				[pageView setForceRedraw:YES];
				//[pageView setNeedsDisplay:YES];
				[pageView display];
			}
			[doc applyUpdatedPrintInfo];
			[doc restoreVisibleTextRange];
		}
	}
	//dismiss sheet (see note a start of method)
	if (!isTiger)
	{
		//	dismiss sheet
		[columnsSheet orderOut:self];
		[NSApp endSheet: columnsSheet];
	}
	//fixed leak 14 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[columnsSheet close];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
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
