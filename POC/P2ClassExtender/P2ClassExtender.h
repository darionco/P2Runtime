//
//  P2ClassExtender.h
//  P2GUIImporter
//
//  Created by Dario Segura on 2013-04-27.
//
//

#import <Foundation/Foundation.h>
#import "P2ClassExtension.h"
#import "P2MethodContainer.h"

@interface P2ClassExtender : NSObject
{
    NSMutableDictionary *m_runtimeClasses;
    
    NSCharacterSet *m_validVarName;
    NSCharacterSet *m_trimParentesisAndWhiteSpace;
    NSCharacterSet *m_endAndBegining;
    NSCharacterSet *m_validMessageStart;
    NSCharacterSet *m_curlyBraces;
    
    voidMessageIMP m_voidIMP;
    idMessageIMP m_idIMP;
    intMessageIMP m_intIMP;
    doubleMessageIMP m_doubleIMP;
    
    NSMutableDictionary *m_typeEncodings;
}

@property (readonly) NSDictionary *runtimeClasses;

+(P2ClassExtender*) sharedInstance;

-(P2MethodContainer*) getMethod:(SEL)method forClass:(Class)cls;

-(void) createClassWithSource:(NSString*)src;
-(void) addIvarWithType:(NSString*)ivarType andName:(NSString*)ivarName toClass:(Class)cls;
-(void) addMessageWithReturnType:(NSString*)type andDeclaration:(NSString*)signature toClass:(Class)cls;
-(NSString*) getSELStringFromDeclaration:(NSString*)declaration;
-(NSDictionary*) getMethodCallDescription:(NSString*)methodCall;

@end
