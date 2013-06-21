//
//  P2MethodContainer.h
//  P2GUIImporter
//
//  Created by Dario Segura on 2013-04-28.
//
//

#import <Foundation/Foundation.h>

@interface P2MethodContainer : NSObject
{
    NSArray *m_argTypes;
    NSArray *m_argNames;
    NSString *m_selString;
    NSString *m_source;
    NSData *m_compiledCode; // TODO: Implement compiler //
}

@property (readonly) NSArray *argumentTypes;
@property (readonly) NSArray *argumentNames;
@property (readonly) NSString *selectorString;
@property (nonatomic, copy) NSString *source;

-(id) initWithSelectorString:(NSString*)selString argumentTypes:(NSArray*)argTypes argumentNames:(NSArray*)argNames andSource:(NSString*)source;

@end
