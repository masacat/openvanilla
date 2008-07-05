//
//  OVPreferenceController.m
//  OpenVanilla
//
//  Created by zonble on 2008/7/4.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OVPreferenceController.h"


@implementation OVPreferenceController

- (void)setExcludeList
{
	NSEnumerator *enumerator;
	
	NSMutableDictionary *moduleLibraries = [NSMutableDictionary dictionary];
    NSDictionary *history = [_loader loadHistory];
	enumerator = [[history allKeys] objectEnumerator];
    NSString *loaderKey;
    while (loaderKey = [enumerator nextObject]) {
        NSArray *loaderNode = [history valueForKey:loaderKey];
        NSMutableDictionary *newnode = [NSMutableDictionary dictionary];
        NSEnumerator *loaderEnumerator = [loaderNode objectEnumerator];
        NSString *s;
        while (s = [loaderEnumerator nextObject])  {
			[newnode setValue:[NSNumber numberWithBool:TRUE] forKey:s];
		}
        [moduleLibraries setValue:newnode forKey:[loaderKey lastPathComponent]];        
    }
	
	NSArray *loaderConfig = [_config valueForKey:@"OVLoader"];		
	
    _excludeModuleList = [NSMutableArray arrayWithArray:[loaderConfig valueForKey:@"excludeModuleList"]];
	[_excludeModuleList retain];
    enumerator = [[loaderConfig valueForKey:@"excludeLibraryList"] objectEnumerator];
    NSString *s;
    while (s = [enumerator nextObject]) {
        NSDictionary *moduleLibrary = [moduleLibraries valueForKey:s];
        if (moduleLibrary) 
			[_excludeModuleList addObjectsFromArray:[moduleLibrary allKeys]];
    }
//    NSLog(@"exclude list=%@", [_excludeModuleList description]);	
}

- (void)setUpModules
{
	NSArray *moduleLists = [_loader moduleList];
	if (!moduleLists) {
		moduleLists = [NSArray array];
	}
		
	const char *locale = [_loader service]->locale();	
	NSEnumerator *e = [moduleLists objectEnumerator];
	CVModuleWrapper *w;
	
	while (w = [e nextObject]) {
        OVModule *ovm = [w module];
		NSString *identifier = [w identifier];
        NSString *localizedName = [NSString stringWithUTF8String:ovm->localizedName(locale)];
		NSDictionary *dictionary = [_config valueForKey:identifier];
		BOOL enabled = ![_excludeModuleList containsObject:identifier];
		
		if (!dictionary) {
			dictionary = [NSDictionary dictionary];
		}
		//      NSString *shortcut=[menucfg valueForKey:mid default:@""];	
		
		if ([[w moduleType] isEqualToString:@"OVInputMethod"]) {
			if ([[w identifier] hasPrefix:@"OVIMGeneric-"]) {
				OVIMGenericController *moduleCotroller = [[OVIMGenericController alloc] initWithIdentifier:identifier localizedName:localizedName dictionary:dictionary enabled:enabled delegate:self];
				[m_moduleListController addInputMethod:moduleCotroller];				
			}
			else if ([dictionary count]) {
				OVTableModuleController *moduleCotroller = [[OVTableModuleController alloc] initWithIdentifier:identifier localizedName:localizedName dictionary:dictionary enabled:enabled delegate:self];
				[m_moduleListController addInputMethod:moduleCotroller];
			}
			else {
				OVModuleController *moduleCotroller = [[OVModuleController alloc] initWithIdentifier:identifier localizedName:localizedName dictionary:dictionary enabled:enabled delegate:self];
				[m_moduleListController addInputMethod:moduleCotroller];
			}
		}
		else if ([[w moduleType] isEqualToString:@"OVOutputFilter"]) {
			OVModuleController *moduleCotroller = [[OVModuleController alloc] initWithIdentifier:identifier localizedName:localizedName dictionary:nil enabled:enabled delegate:self];
			[m_moduleListController addOutputFilter:moduleCotroller];
		}
		
	}
//	[m_moduleListController reload];
	[m_moduleListController expandAll];
}

- (void)awakeFromNib
{	
	[[self window] setDelegate:self];
			
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@""];
	[toolbar setDelegate:self];
	[toolbar autorelease];
	[[self window] setToolbar:toolbar];
	[[self window] center];	
	
	_loader = [CVEmbeddedLoader new];
    _config = [[NSMutableDictionary dictionaryWithDictionary:[[_loader config] dictionary]] retain];
	
	[self setExcludeList];
	[self setUpModules];	
	[self setActiveView:[m_moduleListController view] animate:NO];
}

- (void) dealloc
{
	[_loader release];
	[_config release];
	[_excludeModuleList release];
	[super dealloc];
}

- (BOOL)updateConfigWithIdentifer:(NSString *)identifier dictionary:(NSDictionary *)dictionary
{
	if (!identifier || ![identifier length])
		return NO;
	if (!dictionary)
		return NO;
	
	[_config setValue:dictionary forKey:identifier];
	
	return YES;
}
- (void)writeConfigWithIdentifer:(NSString *)identifier dictionary:(NSDictionary *)dictionary
{
	if ([self updateConfigWithIdentifer:identifier dictionary:dictionary])
		[self writeConfig];
}
- (void)addToExcludeList:(NSString *)identifier
{
	NSLog(@"i");
	[_excludeModuleList addObject:identifier];
	NSMutableDictionary *loaderConfig = [NSMutableDictionary dictionaryWithDictionary:[_config valueForKey:@"OVLoader"]];
	[loaderConfig setValue:_excludeModuleList forKey:@"excludeModuleList"];
	[self writeConfigWithIdentifer:@"OVLoader" dictionary:loaderConfig];	
}
- (void)removeFromExcludeList:(NSString *)identifier
{
	NSLog(@"i");	
	[_excludeModuleList removeObject:identifier];
	NSMutableDictionary *loaderConfig = [NSMutableDictionary dictionaryWithDictionary:[_config valueForKey:@"OVLoader"]];
	[loaderConfig setValue:_excludeModuleList forKey:@"excludeModuleList"];
	[self writeConfigWithIdentifer:@"OVLoader" dictionary:loaderConfig];		
}

- (void)writeConfig
{
	[[_loader config] sync];
	[[[_loader config] dictionary] removeAllObjects];
	[[[_loader config] dictionary] addEntriesFromDictionary:_config];
	[[_loader config] sync];
}
- (void)setActiveView:(NSView *)view animate:(BOOL)flag
{	
	NSRect windowFrame = [[self window] frame];
	windowFrame.size.height = [view frame].size.height + WINDOW_TITLE_HEIGHT;
	windowFrame.size.width = [view frame].size.width;
	windowFrame.origin.y = NSMaxY([[self window] frame]) - ([view frame].size.height + WINDOW_TITLE_HEIGHT);

	if ([[u_mainView subviews] count] != 0)
		[[[u_mainView subviews] objectAtIndex:0] removeFromSuperview];
	
	[[self window] setFrame:windowFrame display:YES animate:flag];		
	[u_mainView setFrame:[view frame]];
	[u_mainView addSubview:view];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[NSApp terminate:self];
}

@end