/*
	ApplicationDelegate.m
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
#import "ApplicationDelegate.h"
#import "ServicesObject.h"
#import "PrefWindowController.h"
#import "InspectorController.h"
#import "TemplateNameValueTransformer.h" //for Tiger -- must register transformer for IB
#import "JHAttributedStringToDataTransformer.h"
//#import </usr/include/objc/objc-class.h> //for swizzle code
//20111025-1 bad hardcoded path above, use below instead
#import <objc/runtime.h>

@interface NSObject(SwizzledMethodSignatures)
- (void)setBackgroundColorSwizzle:aColor;
- (void)changeColorSwizzle:sender;
- (void)insertTextSwizzle:sender;
- (BOOL)trackMouseSwizzle:event adding:(BOOL)isAdding;
- (NSTypesetterControlCharacterAction)actionForControlCharacterAtIndexSwizzle:(NSInteger)index;
- (void)drawBackgroundForBlockSwizzle:block
                            withFrame:(NSRect)rect
                               inView:aView
                       characterRange:(NSRange)range
                        layoutManager:layoutManager;
- (NSRect)lineFragmentRectForProposedRectSwizzle:(NSRect)rect
                                  sweepDirection:(NSLineSweepDirection)dir
                               movementDirection:(NSLineMovementDirection)movementDir
                                   remainingRect:(NSRect)remaining;
- (void)orderFrontListPanelSwizzle:sender;
- (BOOL)validateMenuItemSwizzle:menuItem;
@end

// silence compiler warning
@interface NSObject(Swizzle)

+ (void)swizzleMethod:(SEL)orig_sel withMethod:(SEL)alt_sel;

@end

@implementation NSObject(Swizzle)

//	this switches two methods' selectors, allowing a method swizzle
//	it's used to add something to a function where you don't have the method's code and don't wish to subclass
//	in effect, you can call the method's implementation from within the method
//	should be called ONLY once, or else undoes swizzle (eg, don't put in +initialize in a category)
//	taken straight from www.cocoadev.com/index.pl?MethodSwizzling; thanks RobinHP
+ (void)swizzleMethod:(SEL)orig_sel withMethod:(SEL)alt_sel
{
	Method orig_method = nil, alt_method = nil;
	id c = [self class];
	// First, look for the methods
	orig_method = class_getInstanceMethod(c, orig_sel);
	alt_method = class_getInstanceMethod(c, alt_sel);
	
	// If both are found, swizzle them
	if ((orig_method != nil) && (alt_method != nil))
	{
		//=Tiger?
#if !__OBJC2__
		{
			//NSLog(@"TIGER SWIZZLE");
			//Tiger only code -- method_types and method_imp are deprecated on Leopard
			char *temp1;
			IMP temp2;
			temp1 = orig_method->method_types;
			orig_method->method_types = alt_method->method_types;
			alt_method->method_types = temp1;
			
			temp2 = orig_method->method_imp;
			orig_method->method_imp = alt_method->method_imp;
			alt_method->method_imp = temp2;
		}
#else
		{
			//NSLog(@"LEOPARD SWIZZLE");
			//these obj-c 2.0 runtime msg's work on Leopard only -- see CocoaDev: Swizzle
			if(class_addMethod(c, orig_sel, method_getImplementation(alt_method), method_getTypeEncoding(alt_method)))
				class_replaceMethod(c, alt_sel, method_getImplementation(orig_method), method_getTypeEncoding(orig_method));
			else
				method_exchangeImplementations(orig_method, alt_method);
		}
#endif
	} else NSLog(@"Could not swizzle nonexistent methods!");
}

@end

//	this delegate of NSApplication was formerly called 'Controller.m' 24 JUNE 08 JH 
//	the app delegate is connected in IB (in MainMenu.nib: connect File'sOwner ---> ApplicationDelegate as 'Delegate')
@implementation ApplicationDelegate

+ (void)initialize
{
	//for Tiger, must register transformer (not nec. for Leopard, where we can just use the class name)
	TemplateNameValueTransformer *templateNameTransformer = [[[TemplateNameValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:templateNameTransformer forName:@"templateNameTransformer"];

	JHAttributedStringToDataTransformer *AttributedStringToDataTransformer = [[[JHAttributedStringToDataTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:AttributedStringToDataTransformer forName:@"AttributedStringToDataTransformer"];
}

//	perform initialization of Services here
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	//	Services won't work unless setServicesProvider is called from the application's delegate
	[NSApp setServicesProvider: [ServicesObject sharedInstance]];
	//swizzle in effect allows call to super without subclassing!
	[NSTextView swizzleMethod:@selector(setBackgroundColor:) withMethod:@selector(setBackgroundColorSwizzle:)];
	[NSTextView swizzleMethod:@selector(changeColor:) withMethod:@selector(changeColorSwizzle:)];
	[NSTextView swizzleMethod:@selector(insertText:) withMethod:@selector(insertTextSwizzle:)];
	[NSRulerMarker swizzleMethod:@selector(trackMouse:adding:) withMethod:@selector(trackMouseSwizzle:adding:)];
	[NSTypesetter swizzleMethod:@selector(actionForControlCharacterAtIndex:) withMethod:@selector(actionForControlCharacterAtIndexSwizzle:)];
	[NSTextTable swizzleMethod:@selector(drawBackgroundForBlock:withFrame:inView:characterRange:layoutManager:) withMethod:@selector(drawBackgroundForBlockSwizzle:withFrame:inView:characterRange:layoutManager:)];
	[NSTextContainer swizzleMethod:@selector(lineFragmentRectForProposedRectSwizzle:sweepDirection:movementDirection:remainingRect:) withMethod:@selector(lineFragmentRectForProposedRect:sweepDirection:movementDirection:remainingRect:)];
	//fix bug where list panel can appear on text fields
	[NSTextView swizzleMethod:@selector(orderFrontListPanel:) withMethod:@selector(orderFrontListPanelSwizzle:)];
	//allow proper validation (state of substitution > menu items isn't reported unless object's imp is called)
	[NSTextView swizzleMethod:@selector(validateMenuItem:) withMethod:@selector(validateMenuItemSwizzle:)];
	
    [self createMyiCloudDocumentFolder];
}

- (void)createMyiCloudDocumentFolder {
    /* if this is the first time the user launched Bean since we added iCloud support, they
     * don't have a Bean folder in their ubiquity container. We add it here.
     */
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *iCloudDocumentsFolder = [[fm URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:@"Documents"];
    if (iCloudDocumentsFolder != nil) {
        if (![fm fileExistsAtPath:[iCloudDocumentsFolder path]]) {
            NSError *error = nil;
            BOOL madeDir = [fm createDirectoryAtURL:iCloudDocumentsFolder withIntermediateDirectories:YES attributes:nil error:&error];
            if (!madeDir) {
                [NSApp presentError:error];
            }
        }
    }
}

/*
//test code
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if ([[InspectorController sharedInspectorController] inspectorPanelIsVisible])
	{
		//save pref here so when Bean is restarted, panel returns to previous visible-or-not state
		//NSLog(@"inspector panel is visible");
	}
}
*/

//since Application is, so to speak, a singleton, I dont think this is ever called, but it cant hurt
- (void)dealloc {
    if (twoToneIBeamCursor) [twoToneIBeamCursor release];
    [super dealloc];
}

//	check for a newer version of Bean (available for download on the web at www.bean-osx.com)
//	by comparing Bean's x.x.x style version number to the one stored in an xml file on the web.
//	based on UpdateCheckTest code created by Karl Moskowski on 08/01/07
//	NOTE: this ties us down to the x.x.x version style numbering, which isn't a bad thing
-(IBAction) checkForUpdate:(id) sender
{
#define versionIsCurrent 0
#define versionIsNotCurrent 1
#define versionIsNewerThanLatestAvailable 2
	
	int resultOfCheckForUpdate = 0;
	BOOL shouldKeepChecking = YES;
	NSError *theError = nil;
	NSXMLDocument *xmlDoc = nil;
	NSData *versionData;
	
	//	NOTE: NSURL was reading an on-disk cache of the URL and would never indicate when an update was needed, so we use NSURLRequest instead so we can control the cache policy
	// theURL = [[NSURL alloc] initWithScheme:@"http" host:@"www.bean-osx.com" path:@"/releases/availableVersion.xml"];
	
	//	for testing using on-disk XML file
	//	NSURL *theURL = [NSURL fileURLWithPath:@"//Users/JH/Documents/Cocoa/BeanWeb/BeanMirror/releases/availableVersion.xml"];
	
	//	set up request
	NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.bean-osx.com/releases/availableVersion.xml"]
											  cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];
	
	versionData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:nil error:nil];
	
	//	was failing silently on Leopard if no internet connection; we now check for versionData 18 MAR 08 JH
	if (versionData)
	{
		//	retrieve XML version doc over web
		xmlDoc = [[[NSXMLDocument alloc] 
				  initWithData: versionData
				  options:(NSXMLNodePreserveWhitespace|NSXMLNodePreserveCDATA) 
				  error:&theError] autorelease];
	}
	
	//	couldn't get latest version number
	if ((theError != nil && [theError code] == -1014) || !xmlDoc || !versionData)
	{
		NSString *vaTitle = NSLocalizedString(@"Sorry, Bean was unable to check for a newer version.", @"alert title: Sorry, Bean was unable to check for a newer version.");
		NSString *vaText = NSLocalizedString(@"Perhaps you are not connected to the internet?\rYou can check for a newer version at this address in your web browser: www.bean-osx.com", @"alert text: Perhaps you are not connected to the internet?\rYou can check for a newer version at this address in your web browser: www.bean-osx.com");
		NSRunAlertPanel(vaTitle, vaText, NSLocalizedString(@"OK", @"OK"), nil, nil);
	}
	
	//	compare the latest version number to the version number of the one we have here
	else
	{
		//	get the version numbers as strings
		NSString *availableVersion = [[[xmlDoc nodesForXPath:@"./data/availableVersion" error:&theError] objectAtIndex:0] stringValue];
		NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
		
		//	for testing
		//NSLog([NSString stringWithFormat:@"a:%@, c:%@", availableVersion, currentVersion]);
		
		//turn the version numbers into arrays
		NSMutableArray *availableVersionArray = [NSMutableArray arrayWithCapacity:3];
		NSMutableArray *currentVersionArray = [NSMutableArray arrayWithCapacity:3];
		
		//	build the array for (newest) availableVersion
		NSScanner *scanner = [NSScanner scannerWithString:availableVersion];
		while (![scanner isAtEnd])
		{
			NSString *tempString = nil;
			[scanner scanUpToString:@"." intoString:&tempString];
			if (tempString)
			{
				[availableVersionArray addObject:[NSNumber numberWithInt:[tempString intValue]]];
				unsigned scanLoc = 0;
				scanLoc = [scanner scanLocation];
				if ((scanLoc + 1) < [availableVersion length])
				{
					[scanner setScanLocation:(scanLoc + 1)];
				}
			}
			tempString = nil;
		}
		scanner = nil;
		
		//	build the array for currentVersion (the one we have)
		scanner = [NSScanner scannerWithString:currentVersion];
		while (![scanner isAtEnd])
		{
			NSString *tempString = nil;
			[scanner scanUpToString:@"." intoString:&tempString];
			if (tempString)
			{
				[currentVersionArray addObject:[NSNumber numberWithInt:[tempString intValue]]];
				unsigned scanLoc = 0;
				scanLoc = [scanner scanLocation];		
				if ((scanLoc + 1) < [currentVersion length])
				{
					[scanner setScanLocation:(scanLoc + 1)];
				}
			}
			tempString = nil;
		}
		
		//	step through arrays, comparing numbers; higher 'availableVersion' numbers means update available
		int i = 0;
		for (i = 0; i < [availableVersionArray count]; i++)
		{
			if (shouldKeepChecking==YES)
			{
				int avNum = [[availableVersionArray objectAtIndex:i] intValue];
				int cvNum = [[currentVersionArray objectAtIndex:i] intValue];
				
				//for testing
				//NSLog([NSString stringWithFormat:@"a:%i c:%i", avNum, cvNum]);
				
				if (avNum > cvNum)
				{
					resultOfCheckForUpdate = versionIsNotCurrent;
					shouldKeepChecking = NO;
				}
				else if (avNum < cvNum)
				{
					resultOfCheckForUpdate = versionIsNewerThanLatestAvailable;
					shouldKeepChecking = NO;
				}
				else //	are equal
				{
					resultOfCheckForUpdate = versionIsCurrent;
				}
			}
		}
		
		//	inform user
		if (resultOfCheckForUpdate == versionIsNotCurrent)
		{
			
			if (NSRunInformationalAlertPanel (NSLocalizedString(@"An updated version of Bean is available.", @"alert title: An updated version of Bean is available."),
											  [NSString stringWithFormat:NSLocalizedString(@"Version %@ is available (you have %@). Do you want to visit the download web page?", @"alert text: Version %@ is available (you have %@). Do you want to visit the download web page? (translator: retain the order of the version numbers)"), availableVersion, currentVersion],
											  NSLocalizedString(@"Yes", @"Yes"),
											  NSLocalizedString(@"No", @"No"),
											  nil ) 
				== NSAlertDefaultReturn)
			{
				NSURL *beanURL = [[NSURL alloc] initWithScheme:@"http" host:@"www.bean-osx.com" path:@"/index.html"];
				[[NSWorkspace sharedWorkspace] openURL:beanURL];
				[beanURL release];
			}	
			return;
		}
		else if (resultOfCheckForUpdate == versionIsNewerThanLatestAvailable)
		{
			NSRunAlertPanel(NSLocalizedString(@"You appear to have a preview of the next version of Bean.", @"alert title: You appear to have a preview of the next version of Bean."), @"", NSLocalizedString(@"OK", @"OK"), nil, nil);
		}
		else
		{
			NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"This version of Bean (%@) is current.", @"alert title: This version of Bean (version number inserted at runtime) is current."), currentVersion], @"", NSLocalizedString(@"OK", @"OK"), nil, nil);
		}
	}
	theError = nil;
}

//	application menu validation
- (BOOL)validateMenuItem:(NSMenuItem *)userInterfaceItem
{
	SEL action = [userInterfaceItem action];
	if (action == @selector(checkForUpdate:))
	{
		return YES;
	}
	if (action == @selector(revealFileInFinder:))
	{
		id doc = [[NSDocumentController sharedDocumentController] currentDocument];
		if (!doc || ![doc fileName])
			return NO;
	}
	return YES;
}

-(IBAction)showPreferences:(id)sender
{
	id pWC = [PrefWindowController sharedInstance]; 
	if ([pWC window])
	{
		//	show Preferences window
		[pWC showWindow:sender];
		[[pWC window] orderFront:sender];
	}
}

- (IBAction)displayHelp:(id)sender
{
	int t = [sender tag];
	NSString *topic = nil;

	switch (t)
	{
		case 0:
		{
			//specifically display help page on File Formats, for Help button in Save panel and Get Info sheet
			topic = @"FORMATS";
			break;
		}
		case 1:
		{
			//display help for Preferences > ADVANCED tab controls
			topic = @"ADVANCED";
			break;
		}
		case 2:
		{
			//display help for Preferences > GENERAL tab controls
			topic = @"GENERAL";
			break;
		}
		case 3:
		{
			//display help for Preferences > DOCUMENTS tab controls
			topic = @"DOCUMENTS";
			break;
		}
		case 4:
		{
			//display help for Preferences > PRINTING tab controls
			topic = @"PRINTING";
			break;
		}
		case 5:
		{
			//display help for Preferences > VIEW tab controls
			topic = @"VIEW";
			break;
		}
		case 6:
		{
			//display help for Preferences > FONT tab controls
			topic = @"FONT";
			break;
		}
		case 7:
		{
			//display help for Preferences > STYLE tab controls
			topic = @"STYLE";
			break;
		}
		case 8:
		{
			//display help for Preferences > WINDOW tab controls
			topic = @"WINDOW";
			break;
		}
		case 9:
		{
			//display help for Preferences > FULLSCREEN tab controls
			topic = @"FULLSCREEN";
			break;
		}
		case 10:
		{
			//display help for Preferences > ADVANCED-INTERFACE tab controls
			topic = @"ADVANCED-INTERFACE";
			break;
		}
		case 11:
		{
			//display help for Preferences > ADVANCED-FIND/REPLACE tab controls
			topic = @"ADVANCED-FIND/REPLACE";
			break;
		}
		case 12:
		{
			//display help for FIND PANEL controls
			topic = @"FIND";
			break;
		}
		case 13:
		{
			//display help for PREF > ADVANCED > NOTES MODE tab controls
			topic = @"ADVANCED-NOTESMODE";
			break;
		}
		case 14:
		{
			//display help for PREF > GENERAL > TEXT CURSOR tab controls
			topic = @"TEXTCURSOR";
			break;
		}
		case 15:
		{
			//call index page for help
			topic = @"BEANHELPTOC";
			break;
		}
		default:
		{
			//nothing else yet
		}
	}
	
	if (topic)
		//open help page for 'topic'
		[[NSHelpManager sharedHelpManager] openHelpAnchor:topic inBook:[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"]];
}

-(IBAction)revealFileInFinder:(id)sender;
{
	id doc = [[NSDocumentController sharedDocumentController] currentDocument];
	if (doc)
	{
		NSString *thePath = [doc fileName];
		if (thePath) { [[NSWorkspace sharedWorkspace] selectFile:thePath inFileViewerRootedAtPath:nil]; }
	}
}


-(NSCursor *)twoToneIBeamCursor
{
	if (!twoToneIBeamCursor)
	{
		//NSLog(@"APPDEL TWOTONE_IBEAM_CURSOR INIT");
		NSImage *whiteCursorImage = [[NSImage alloc] 
					initWithContentsOfFile:[
					[NSBundle mainBundle] 
					pathForResource:@"BIbeam"
					ofType:@"tiff"
					inDirectory:nil]];
		[whiteCursorImage autorelease];
		twoToneIBeamCursor = [[NSCursor alloc] initWithImage:whiteCursorImage hotSpot:NSMakePoint(4.0, 8.0)];
	}
	return twoToneIBeamCursor;
}

@end
