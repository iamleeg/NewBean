/*
	NSAttributedString-EncodeRTFwithPictures.m
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

//	Category on NSAttributedString that encodes pictures in exported RTF
//	detective work by Keith Blount and actual code snippit by BW
//	see: RTFOrWordDocsWithImages on CocoaDev.com, http: //www.cocoadev.com/index.pl?RTFOrWordDocsWithImages

#import "NSAttributedString-EncodeRTFwithPictures.h"

@implementation NSAttributedString ( EncodeRTFwithPictures )

- (NSString *)encodeRTFwithPictures
{
	NSMutableDictionary *attachmentDictionary = [NSMutableDictionary dictionaryWithCapacity:5];
	NSMutableAttributedString *stringToEncode = [[NSMutableAttributedString alloc] initWithAttributedString:self];
	
	NSRange strRange = NSMakeRange(0, [stringToEncode length]);
	while (strRange.length > 0)
	{
		NSRange effectiveRange;
		id attr = [stringToEncode attribute:NSAttachmentAttributeName atIndex:strRange.location effectiveRange:&effectiveRange];
		strRange = NSMakeRange(NSMaxRange(effectiveRange), NSMaxRange(strRange) - NSMaxRange(effectiveRange));
		
		if(attr)
		{
			//	if we find a text attachment, check to see if it's one of ours
			NSTextAttachment *attachment = (NSTextAttachment *)attr;
			NSFileWrapper *fileWrapper = [attachment fileWrapper];
			NSImage *image = [[[NSImage alloc] initWithData:[fileWrapper regularFileContents]] autorelease];
			
			NSString *imageKey = [NSString stringWithFormat:@"Image#%i",[image hash]];
			[attachmentDictionary setObject:image forKey:imageKey];
			[stringToEncode removeAttribute:NSAttachmentAttributeName range:effectiveRange];
			[stringToEncode replaceCharactersInRange:effectiveRange withString:imageKey];
			strRange.length+=[imageKey length]-1;
		}
	}
	
	NSData *rtfData = [stringToEncode RTFFromRange:NSMakeRange(0,[stringToEncode length]) documentAttributes:nil];
	NSMutableString *rtfString = [[NSMutableString alloc] initWithData:rtfData encoding:NSASCIIStringEncoding];
	
	NSEnumerator *imageKeyEnum = [attachmentDictionary keyEnumerator];
	NSString *key;
	while(key = [imageKeyEnum nextObject])
	{
		NSRange keyRange = [rtfString rangeOfString:key];
		if(keyRange.location!=NSNotFound)
		{
			NSImage *img = [attachmentDictionary objectForKey:key];
			NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithData:[img TIFFRepresentation]] autorelease];
			//	was...NSPNGFileType
			NSString *hexString = [self hexadecimalRepresentation:[bitmap representationUsingType:NSJPEGFileType properties:nil]];
			//	pngblip or jpegblip depending
			NSString *encodedImage = [NSString stringWithFormat:@"{\\*\\shppict {\\pict \\jpegblip %@}}", hexString];
			[rtfString replaceCharactersInRange:keyRange withString:encodedImage];
		}
	}	
	[stringToEncode release];
	return (rtfString) ? [rtfString autorelease] : rtfString;
}

static const char *const digits = "0123456789abcdef";

- (NSString*)hexadecimalRepresentation:(NSData *)data
{
	NSString *result = nil;
	size_t length = [data length];
	if (0 != length)
	{
		NSMutableData *temp = [NSMutableData dataWithLength:(length << 1)];
		if (temp)
		{
			const unsigned char *src = [data bytes];
			unsigned char *dst = [temp mutableBytes];
			if (src && dst)
			{
				while (length-- > 0)
				{
					*dst++ = digits[(*src >> 4) & 0x0f];
					*dst++ = digits[(*src++ & 0x0f)];
				}
				result = [[NSString alloc] initWithData:temp encoding:NSASCIIStringEncoding];
			}
		}
	}
	return (result) ? [result autorelease] : result;
}

@end

