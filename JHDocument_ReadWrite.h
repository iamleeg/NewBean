/*
  JHDocument_ReadWrite.h
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

// methods to read and write files (open, save, export, backup)
@interface JHDocument (JHDocument_ReadWrite)

// CopyPaste begin
/* the following four are for use with CopyPaste 
 called in 
 -(IBAction)saveTheDocument:(id)sender
 -(BOOL)checkBeforeSaveWithContextInfo:(void *)contextInfo isClosing:(BOOL)isClosing
 */
- (void) setWasPasteboard:(BOOL)was;
- (BOOL) wasPasteboard;
- (void) setPbname:(NSString*)pb;
-(BOOL) wasServiceRequest;

// CopyPaste end

//publicize
-(BOOL)checkBeforeSaveWithContextInfo:(void *)contextInfo isClosing:(BOOL)flag;
-(BOOL)textLengthIsZero;

//forward declare
-(int)failedDocType;
-(void)setFailedDocType:(int)error;
-(void)setTextLengthIsZero:(BOOL)flag;

@end