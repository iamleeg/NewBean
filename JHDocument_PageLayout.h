/*
  JHDocument_PageLayout.h
  Bean

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

#import <Cocoa/Cocoa.h>
#import "JHDocument.h"

@interface JHDocument (JHDocument_PageLayout)

//	add and remove pages 
-(void)addPage:(id)sender;
-(void)removePage:(id)sender;

//	change paper size and orientation 
-(void)doPageLayout:(id)sender;
-(void)didEndPageLayout:(NSPageLayout *)pageLayout returnCode:(int)result contextInfo:(void *)contextInfo;

//	force layout to complete 
-(void)doForegroundLayoutToCharacterIndex:(unsigned)loc;

//	helper for LayoutView
-(NSRect)textRectForContainerIndex:(unsigned)containerIndex;
//	return page number of page containing container at index
-(int)pageNumberForContainerAtIndex:(int)containerIndex;

@end