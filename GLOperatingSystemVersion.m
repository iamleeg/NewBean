/*
GLOperatingSystemVersion.h
Bean

Copyright (c) 2020 Graham Lee

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

#import "GLOperatingSystemVersion.h"

BOOL IsOperatingSystemBelowTenDotMinorRelease(int minorVersion)
{
    NSProcessInfo *info = [NSProcessInfo processInfo];
    if ([info respondsToSelector:@selector(isOperatingSystemAtLeastVersion:)]) {
        NSOperatingSystemVersion version = {
            .majorVersion = 10,
            .minorVersion = minorVersion,
            .patchVersion = 0
        };
        return !([info isOperatingSystemAtLeastVersion:version]);
    } else {
        SInt32 systemVersion;
        OSErr err = Gestalt(gestaltSystemVersionMajor, &systemVersion);
        if (err != noErr) {
            // we don't know, so play safe and say we're on something early
            return YES;
        }
        if (systemVersion < 10) {
            // how are you even here
            return YES;
        }
        if (systemVersion >= 11) {
            // why hello, big sir
            return NO;
        }
        err = Gestalt(gestaltSystemVersionMinor, &systemVersion);
        if (err != noErr) {
            // again, the safe option is to say that we're on an early version
            return YES;
        }
        return systemVersion < minorVersion;
    }
}

typedef enum : NSUInteger {
    Tiger = 4,
    Leopard = 5,
    SnowLeopard = 6,
} TenDotMinorVersion;

@implementation GLOperatingSystemVersion

+ (BOOL)isBeforeSnowLeopard
{
    return IsOperatingSystemBelowTenDotMinorRelease(SnowLeopard);
}

+ (BOOL)isBeforeLeopard
{
    return IsOperatingSystemBelowTenDotMinorRelease(Leopard);
}

+ (BOOL)isBeforeTiger
{
    return IsOperatingSystemBelowTenDotMinorRelease(Tiger);
}

+ (BOOL)isAtLeastLeopard
{
    return ![self isBeforeLeopard];
}

+ (BOOL)isAtLeastSnowLeopard
{
    return ![self isBeforeSnowLeopard];
}
@end
