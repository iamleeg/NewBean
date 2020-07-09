/*
	NSAttributedString-EncodeRTFwithPictures.h
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


//	Category on NSAttributedString that encodes pictures in exported RTF
//	detective work by Keith Blount and actual code snippit by BW
//	see: RTFOrWordDocsWithImages on CocoaDev.com, http: //www.cocoadev.com/index.pl?RTFOrWordDocsWithImages

#import <Cocoa/Cocoa.h>

@interface NSAttributedString ( EncodeRTFwithPictures )

// method declarations
- (NSString *)encodeRTFwithPictures;
- (NSString*)hexadecimalRepresentation:(NSData *)data;

@end
