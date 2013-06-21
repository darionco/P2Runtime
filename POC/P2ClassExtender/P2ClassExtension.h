//
//  P2ClassExtension.h
//  P2GUIImporter
//
//  Created by Dario Segura on 2013-04-27.
//
//

#import <Foundation/Foundation.h>

#pragma mark - P2ClassExtension function declarations
typedef void(*voidMessageIMP)(id self, SEL _cmd, ...);
typedef id(*idMessageIMP)(id self, SEL _cmd, ...);
typedef int(*intMessageIMP)(id self, SEL _cmd, ...);
typedef double(*doubleMessageIMP)(id self, SEL _cmd, ...);

typedef void(*deallocIMP)(id self, SEL _cmd);

void    P2ClassExtension_default_return_void   (id self, SEL _cmd, ...);
id      P2ClassExtension_default_return_id     (id self, SEL _cmd, ...);
int     P2ClassExtension_default_return_int    (id self, SEL _cmd, ...);
double  P2ClassExtension_default_return_double (id self, SEL _cmd, ...);
