/*
	MarginsManager.m
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
 
#import "MarginsManager.h"
#import "JHDocument.h"
#import "JHDocument_Misc.h" //undo method
#import "JHDocument_Print.h" //applyUpdatedPrintInfo
#import "JHDocument_PageLayout.h" //doForegroundLayout
#import "JHDocument_View.h" //rememberVisibleTextRange, restoreVisibleTextRange

//	show Margins sheet, set margins action and prepare undo
@implementation MarginsManager

#pragma mark -
#pragma mark ---- Init, Dealloc  ----

- (void)dealloc
{
	if (document) [document release];
	[super dealloc];
}

//	call margin sheet and insert current values
- (IBAction)showSheet:(id)sender
{
	//if so, then sheet is already shown
	//TODO: find a more gracefull way of handing this, perhaps involving menu item validation
	if ([sender isKindOfClass:[NSMenuItem class]]) return;
	//marginsSheet behavior in nib = [x] release self when closed, so we don't need: [marginsSheet release];
	if(marginsSheet == nil) { [NSBundle loadNibNamed:@"MarginSheet" owner:self]; }
	if(marginsSheet == nil)
	{
		NSLog(@"Could not load MarginSheet");
		[[NSNotificationCenter defaultCenter] postNotificationName:@"JHBeanSheetDidEndNotification" object:self];
		return;
	}
	
	[applyButton setTitle:NSLocalizedString(@"button: Apply", @"button: Apply")];
	[cancelButton setTitle:NSLocalizedString(@"button: Cancel", @"button: Cancel")];
	[leftLabel setObjectValue:NSLocalizedString(@"label: Left", @"")];
	[rightLabel setObjectValue:NSLocalizedString(@"label: Right", @"")];
	[bottomLabel setObjectValue:NSLocalizedString(@"label: Bottom", @"")];
	[topLabel setObjectValue:NSLocalizedString(@"label: Top", @"")];
	[rangeLabel setObjectValue:NSLocalizedString(@"label: Acceptable range: 0.1 - 6.0 units", @"")];
	
	//instance of JHDocument is sender
	[self setDocument:sender];
	id doc = [self document];
	id pInfo = [doc printInfo];
	
	float pointsPerUnit;
	pointsPerUnit = [doc pointsPerUnitAccessor];
	//	determine cm vs. inches; 28.35 points per cm (rounded up to avoid float error) and 72 per inche
	if (pointsPerUnit < 30.0)
	{
		[measurementUnitTextField setObjectValue:NSLocalizedString(@"Margins (in Centimeters)", @"label in margins sheet: Margins (in Centimeters)")];
	}
	else
	{
		[measurementUnitTextField setObjectValue:NSLocalizedString(@"Margins (in Inches)", @"label in margins sheet: Margins (in Inches)")];	
	}
	//get margins from print info (could use docAttributes as well?)
	[tfLeftMargin setFloatValue:[pInfo leftMargin]/pointsPerUnit];
	[tfRightMargin setFloatValue:[pInfo rightMargin]/pointsPerUnit]; 
	[tfTopMargin setFloatValue:[pInfo topMargin]/pointsPerUnit];
	[tfBottomMargin setFloatValue:[pInfo bottomMargin]/pointsPerUnit];

	[NSApp beginSheet:marginsSheet 
	   modalForWindow:[NSApp mainWindow]
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}
//wired to Change and Cancel buttons on sheet - rewritten 19 AUG 08 for better field validation JH
-(IBAction)applyMargins:(id)sender
{
	id doc = [self document];
	id pInfo = [doc printInfo];
	float pointsPerUnit;
	pointsPerUnit = [doc pointsPerUnitAccessor]; 

	//	this causes text fields with uncommited edits to try to validate themselves before focus leaves them
	[marginsSheet makeFirstResponder:marginsSheet];

	//if textFields fail to validate after Apply is pressed, don't dismiss sheet
	if (![[marginsSheet firstResponder] isEqualTo:marginsSheet] && ![[sender cell] tag]==0)
	{
		//a margin settings was < 0.1 or > 6.0 units (inches or cms); show 'helper' label
		[rangeLabel setHidden:NO];
		return;
	}
	
	//cancel pressed
	else if ([[sender cell] tag]==0)
	{
		//	stop editing any fields (otherwise won't be reset to current margins)
		[tfLeftMargin abortEditing];
		[tfRightMargin abortEditing];
		[tfTopMargin abortEditing];
		[tfBottomMargin abortEditing];
		//	reset the fields to match printInfo
		[tfLeftMargin setFloatValue:[pInfo leftMargin]/pointsPerUnit];
		[tfRightMargin setFloatValue:[pInfo rightMargin]/pointsPerUnit];  
		[tfTopMargin setFloatValue:[pInfo topMargin]/pointsPerUnit];
		[tfBottomMargin setFloatValue:[pInfo bottomMargin]/pointsPerUnit];
	}
	
	[NSApp stopModal];
	//	dismiss the sheet after margin changes appear on screen 
	[NSApp endSheet: marginsSheet];
	[marginsSheet orderOut:self];
	
	//	Change button was pressed, so change the margins
	if (![[sender cell] tag]==0)
	{
		[doc rememberVisibleTextRange];
		//	input in text fields was validated, apply the margins
		if ([marginsSheet firstResponder] == marginsSheet)
		{
			//	record old margin settings in case undo margin change is called
			[ [[doc undoManager] prepareWithInvocationTarget:doc] 
					undoChangeLeftMargin:[pInfo leftMargin]
							 rightMargin:[pInfo rightMargin] 
							   topMargin:[pInfo topMargin]
							bottomMargin:[pInfo bottomMargin] ];
			[[doc undoManager] setActionName:NSLocalizedString(@"Change Margins", @"undo action: Change Margins")];
			//	set printInfo properties
			[pInfo setLeftMargin:[tfLeftMargin floatValue]*pointsPerUnit];
			[pInfo setRightMargin:[tfRightMargin floatValue]*pointsPerUnit];
			[pInfo setTopMargin:[tfTopMargin floatValue]*pointsPerUnit];
			[pInfo setBottomMargin:[tfBottomMargin floatValue]*pointsPerUnit];
			//	also set in pageView for display
			PageView *pageView = [[doc theScrollView] documentView];
			//	means Layout View
			if ([pageView isKindOfClass:[PageView class]])
			{
				//	show Please Wait... sheet
				if ([[doc textStorage] length] > 20000)
				{
					[NSApp beginSheet:messageSheet modalForWindow:[doc docWindow] modalDelegate:doc didEndSelector:NULL contextInfo:nil];
					[messageSheet orderFront:sender];
				}
				//	must refresh view
				[pageView setForceRedraw:YES];
				[pageView setNeedsDisplay:YES];
			}
			[doc applyUpdatedPrintInfo];
			[doc doForegroundLayoutToCharacterIndex:INT_MAX]; //must be INT_MAX
			
			if ([pageView isKindOfClass:[PageView class]] && [messageSheet isVisible])
			{
				[NSApp endSheet:messageSheet];
				[messageSheet orderOut:sender];
			}
			//	restore visible text range after changing margins 6 AUG 08 JH
			[doc restoreVisibleTextRange];
		}
	}
	//fixed leak 14 JUL 09 closing sheet releases nib; also, the creating object now releases this object
	[marginsSheet close];
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