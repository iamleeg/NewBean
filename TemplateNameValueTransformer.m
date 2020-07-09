/*	
TemplateNameValueTransformer.m
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

//based on a value transformer class from Smultron by Peter Borg
//value transformers can be used in Interface Builder bindings but do not automatically show up in the IB UI

#import <Foundation/Foundation.h>
#import "TemplateNameValueTransformer.h"

@implementation TemplateNameValueTransformer
+ (Class)transformedValueClass
{
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation
{
	return NO;   
}

//receives a filepath as a string, returns the last path component (which should be the filename without the path, in quotes)
- (id)transformedValue:(id)value
{	
	/*
	if (![value respondsToSelector: @selector(lastPathComponent)])
			NSLog(@"Value passed to value transformer does not respond to -lastPathComponent. (Value is an instance of %@).", [value class]);
	*/
	if (value == nil) return NSLocalizedString(@"pref label: None selected", @"pref label: None selected (no custom new document template has been selected yet)");
	
	NSString *fileName = [NSString stringWithFormat:NSLocalizedString(@"pref label: Template: \\U201C%@\\U201D", @"pref label: Template: \\U201C%@\\U201D (name of file that is template for new documents)"), [value lastPathComponent]];
	
	if (!fileName) return NSLocalizedString(@"pref label: None selected", @"pref label: None selected (no custom new document template has been selected yet)");

	return fileName;
}

@end
