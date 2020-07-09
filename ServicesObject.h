/*
 ServicesObject.h
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

#import <AppKit/AppKit.h> // no Foundation.h needed

@class JHDocument;

@interface ServicesObject : NSObject {

}

+ (ServicesObject *)sharedInstance;

//	services
-(void)openSelectionInBean:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
-(void)recoverTextFromSelectedFile:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
//-(void)insertLoremIpsum:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
-(void)pasteSelectionIntoCurrentBeanDocument:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
-(void)htmlSnippit:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
-(void)htmlSnippitWithStyles:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
-(void)recoverTextAlert;

@end