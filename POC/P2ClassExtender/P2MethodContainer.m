//
//  P2MethodContainer.m
//  P2GUIImporter
//
//  Created by Dario Segura on 2013-04-28.
//
//

#import "P2MethodContainer.h"

@implementation P2MethodContainer

@synthesize argumentNames = m_argNames;
@synthesize argumentTypes = m_argTypes;
@synthesize selectorString = m_selString;
@synthesize source = m_source;

-(id) initWithSelectorString:(NSString*)selString argumentTypes:(NSArray*)argTypes argumentNames:(NSArray*)argNames andSource:(NSString*)source
{
    self = [super init];
    if (self)
    {
        m_selString = [[NSString alloc] initWithString:selString];
        m_argTypes = [[NSArray alloc] initWithArray:argTypes];
        m_argNames = [[NSArray alloc] initWithArray:argNames];
        if (source)
        {
            m_source = [[NSString alloc] initWithString:source];
        }
        // TODO: Precompile the source //
    }
    return self;
}

-(void) dealloc
{
    [m_selString release];
    [m_argTypes release];
    [m_argNames release];
    [m_source release];
    [super dealloc];
}

@end
