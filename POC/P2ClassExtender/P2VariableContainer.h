//
//  P2VariableContainer.h
//  P2GUIImporter
//
//  Created by Dario Segura on 2013-04-28.
//
//

#import <Foundation/Foundation.h>

@interface P2VariableContainer : NSObject
{
    NSString *m_type;
    NSString *m_name;
    id m_value;
    size_t m_size;
}

@property (nonatomic, retain) NSString *type;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) id value;
@property (readonly)          size_t size;

+(id) containerWithType:(NSString*)type name:(NSString*)name andValue:(id)value;
-(id) initWithType:(NSString*)type name:(NSString*)name andValue:(id)value;

@end
