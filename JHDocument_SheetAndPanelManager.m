/*
	JHDocument_SheetAndPanelManager.m
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
 
#import "JHDocument_SheetAndPanelManager.h"
#import "GetPropertiesManager.h"
#import "EncodingManager.h"
#import "GetInfoManager.h"
#import "MarginsManager.h"
#import "ImageManager.h"
#import "TabStopManager.h"
#import "LinkManager.h"
#import "InspectorController.h"
#import "HeaderFooterManager.h"
#import "ColumnsManager.h"

@implementation JHDocument ( JHDocument_SheetAndPanelManager )

#pragma mark -
#pragma mark ---- Inspector Panel ----

// ******************* Inspector Panel *******************

//	toggle Inspector window in and out
- (IBAction)showInspectorPanelAction:(id)sender
{
	id ic = [InspectorController sharedInspectorController]; 
	if ([[ic window] isVisible])
	{
		[[ic window] orderOut:sender];
	}
	else
	{
		//	show inspector panel 
		[ic showWindow:sender];
		[[ic window] orderFront:sender];
		NSNotification *aNotification = [NSNotification notificationWithName:@"ForceUpdateInspectorControllerNotification" object:[self firstTextView]];
		[ic prepareInspectorUpdate:aNotification];
	}
}

// controllerObjects should really be NSWindowControllers, then should [[[sheet new] window] autorelease] and beginSheet, or else emply
//			didEndSelector to release object; or perhaps use loadNibNamed:owner:

#pragma mark -
#pragma mark ---- Bean Sheet Manager ----

// ******************* Bean Sheet Manager ********************

-(IBAction)showBeanSheet:(id)sender
{
	id sheet = nil;
	// == inits various sheet controller objects here, release at releaseBeanSheet
	switch ([sender tag])
	{
		//Get Info sheet
		case 0:
			sheet = [GetInfoManager new]; //<== all inits here are released in releaseBeanSheet:
			break;
		//propertiesSheet
		case 1:
			sheet = [GetPropertiesManager new]; 
			break;
		//encodingSheet
		case 2:
			sheet = [EncodingManager new];  
			break;
		//marginsSheet
		case 3:
			sheet = [MarginsManager new]; 
			break;
		//resizeImageSheet
		case 4:
			sheet = [ImageManager new]; 
			[sheet setSender:sender];
			break;
		//tabStopSheet
		case 5:
			sheet = [TabStopManager new]; 
			break;
		//linkSheet
		case 6:
			sheet = [LinkManager new]; 
			break;
		//headerFooterSheet
		case 7:
			sheet = [HeaderFooterManager new]; 
			break;
		//columnsSheet
		case 8:
			sheet = [ColumnsManager new]; 
			break;
		//default
		default:
			break;
	}
	[[NSNotificationCenter defaultCenter]
				addObserver:self
				selector:@selector(releaseBeanSheet:)
				name:@"JHBeanSheetDidEndNotification"
				object:sheet];
	if (sheet) [sheet showSheet:self];
}

-(void)releaseBeanSheet:(NSNotification *)notification
{
	id sheet = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"JHBeanSheetDidEndNotification" object:sheet];
	[sheet release]; //	<== release
	sheet = nil;
}

#pragma mark -
#pragma mark ---- Image/Size Actions ----

// ******************* Image/Size Actions ********************

-(IBAction)insertImageAction:(id)sender
{
	ImageManager *iM = [ImageManager new]; // <== init will release in releaseBeanSheet via notification
	[[NSNotificationCenter defaultCenter]
				addObserver:self
				selector:@selector(releaseBeanSheet:)
				name:@"JHBeanSheetDidEndNotification"
				object:iM];
	if (iM) [iM insertImageAction:self];
}

@end