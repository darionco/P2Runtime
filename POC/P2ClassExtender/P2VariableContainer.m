//
//  P2VariableContainer.m
//  P2GUIImporter
//
//  Created by Dario Segura on 2013-04-28.
//
//

#import "P2VariableContainer.h"

@interface P2VariableContainer (Internal)
-(size_t) getVariableSize;
@end

@implementation P2VariableContainer

@synthesize type = m_type;
@synthesize name = m_name;
@synthesize value = m_value;
@synthesize size = m_size;

+(id) containerWithType:(NSString*)type name:(NSString*)name andValue:(id)value
{
    return [[[P2VariableContainer alloc] initWithType:type name:name andValue:value] autorelease];
}
-(id) initWithType:(NSString*)type name:(NSString*)name andValue:(id)value
{
    self = [super init];
    if (self)
    {
        self.type = type;
        self.name = name;
        self.value = value;
        m_size = [self getVariableSize];
    }
    return self;
}

-(size_t) getVariableSize
{
    if ([m_type isEqualToString:@"int"])
    {
        return sizeof(int);
    }
    else if ([m_type isEqualToString:@"id"] || [m_type hasSuffix:@"*"])
    {
        return sizeof(id*);
    }
    else if ([m_type isEqualToString:@"double"])
    {
        return sizeof(double);
    }
    return 0;
}

@end
