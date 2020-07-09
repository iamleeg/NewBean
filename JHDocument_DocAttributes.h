/*
  JHDocument_DocAttributes.h
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

//	create, return, apply documentAttributes dictionary and default settings
@interface JHDocument (JHDocument_DocAttributes)

-(NSDictionary *)docAttributes;
-(void)setDocAttributes:(NSDictionary *)docAttrsDict;
-(NSMutableDictionary *)createDocumentAttributesDictionary;
-(void)applyDocumentAttributes;
-(void)applyDefaultDocumentAttributes;
//publicize...became necessary to call this before adding first page
-(void)applyDefaultMargins;

@end