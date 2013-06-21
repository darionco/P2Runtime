//
//  P2ClassExtender.m
//  P2GUIImporter
//
//  Created by Dario Segura on 2013-04-27.
//
//

#import "P2ClassExtender.h"
#import "P2MethodContainer.h"
#import <objc/runtime.h>


#pragma mark - P2ClassExtender
@implementation P2ClassExtender

@synthesize runtimeClasses = m_runtimeClasses;

+(P2ClassExtender*) sharedInstance
{
    static P2ClassExtender *__P2ClassExtender_sharedInstance__ = nil;
    if (!__P2ClassExtender_sharedInstance__)
    {
        __P2ClassExtender_sharedInstance__ = [[P2ClassExtender alloc] init];
    }
    return __P2ClassExtender_sharedInstance__;
}

-(id) init
{
    self = [super init];
    if (self)
    {
        m_runtimeClasses = [[NSMutableDictionary alloc] init];
        
        NSMutableCharacterSet *validVarName = [[NSCharacterSet letterCharacterSet] mutableCopy];
        [validVarName addCharactersInString:@"_"]; // $ // ?? //
        m_validVarName = [validVarName retain];
        
        NSMutableCharacterSet *trimParentesisAndWhiteSpace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [trimParentesisAndWhiteSpace addCharactersInString:@"()"];
        m_trimParentesisAndWhiteSpace = [trimParentesisAndWhiteSpace retain];
        
        m_endAndBegining = [[NSCharacterSet characterSetWithCharactersInString:@" []{};\n\r"] retain];
        m_validMessageStart = [[NSCharacterSet characterSetWithCharactersInString:@"+-"] retain];
        m_curlyBraces = [[NSCharacterSet characterSetWithCharactersInString:@"{}"] retain];
        
        m_voidIMP = &P2ClassExtension_default_return_void;
        m_idIMP = &P2ClassExtension_default_return_id;
        m_intIMP = &P2ClassExtension_default_return_int;
        m_doubleIMP = &P2ClassExtension_default_return_double;
        
        m_typeEncodings = [[NSMutableDictionary alloc] init];
        
        // we only support void, double, int and id //
        [m_typeEncodings setObject:[NSString stringWithFormat:@"%s", @encode(void)] forKey:@"void"];
        [m_typeEncodings setObject:[NSString stringWithFormat:@"%s", @encode(int)] forKey:@"int"];
        [m_typeEncodings setObject:[NSString stringWithFormat:@"%s", @encode(double)] forKey:@"double"];
        [m_typeEncodings setObject:[NSString stringWithFormat:@"%s", @encode(id)] forKey:@"id"];
    }
    
    return self;
}

-(void) dealloc
{
    [m_runtimeClasses release];
    
    [m_validVarName release];
    [m_trimParentesisAndWhiteSpace release];
    [m_endAndBegining release];
    [m_validMessageStart release];
    [m_typeEncodings release];
    [m_curlyBraces release];
    
    [super dealloc];
}

-(P2MethodContainer*) getMethod:(SEL)method forClass:(Class)cls
{
    if ([cls instancesRespondToSelector:method])
    {
        Class currentClass = cls;
        NSString *methodName = NSStringFromSelector(method);
        NSDictionary *methods;
        while ((methods = [m_runtimeClasses objectForKey:currentClass]))
        {
            P2MethodContainer *ret = [methods objectForKey:methodName];
            if (ret)
            {
                return ret;
            }
            currentClass = [currentClass superclass];
        }
    }
    return nil;
}

-(void) createClassWithSource:(NSString*)src
{
    // find classes interfaces //
    NSRange searchingRange = NSMakeRange(0, src.length);
    NSRange interfaceRange;
    while ((interfaceRange = [src rangeOfString:@"(?<=@interface).*?(?=@end)" options:NSRegularExpressionSearch range:searchingRange]).location != NSNotFound)
    {
        searchingRange = NSMakeRange(interfaceRange.location + interfaceRange.length, src.length - (interfaceRange.location + interfaceRange.length));
        // get the @interface declaration //
        NSString *interface = [src substringWithRange:interfaceRange];
        // get a scanner to find the declaration //
        NSScanner *interfaceScanner = [NSScanner scannerWithString:interface];
        // skip the @interface string //
        //[interfaceScanner scanString:@"@interface" intoString:nil]; // no need // -Dario //
        // find the new class name //
        NSString *newClassName = nil;
        [interfaceScanner scanUpToString:@":" intoString:&newClassName];
        // trim white spaces and new lines from the string //
        newClassName = [newClassName stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
        if (NSClassFromString(newClassName))
        {
            // the class already exists, skip it //
            continue;
        }
        // advance until we find the next class name //
        [interfaceScanner scanUpToCharactersFromSet:m_validVarName intoString:nil];
        NSString *superClassName = nil;
        while (![interfaceScanner scanUpToCharactersFromSet:m_endAndBegining intoString:&superClassName]){}
        superClassName = [superClassName stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
        Class superClass = NSClassFromString(superClassName);
        if (!superClass)
        {
            // the super class doesn't exist, skip it //
            continue;
        }
        Class newClass = objc_allocateClassPair(superClass, [newClassName UTF8String], 0);
        if (!newClass)
        {
            // there was an error creating the new class skip it //
            continue;
        }
        
        // register the class in the runtime classes and create a message table //
        [m_runtimeClasses setObject:[NSMutableDictionary dictionary] forKey:(id<NSCopying>)newClass]; // this is valid and documented //
        
        // continue parsing the file // find if there are instance variables to add //
        NSRange ivarRange;
        if ((ivarRange = [interface rangeOfString:@"\\{([^}]+)\\}" options:NSRegularExpressionSearch]).location != NSNotFound)
        {
            // advance the interface scanner until the end of the string //
            [interfaceScanner scanUpToString:@"}" intoString:nil];
            NSString *ivarDeclaration = [interface substringWithRange:ivarRange];
            NSScanner *ivarScanner = [NSScanner scannerWithString:ivarDeclaration];
            // scan until the first valid var type //
            [ivarScanner scanUpToCharactersFromSet:m_validVarName intoString:nil];
            // enter a loop to read all the variables //
            while (![ivarScanner isAtEnd])
            {
                NSString *ivarType = nil;
                NSString *ivarName = nil;
                // scan until the next space, line break, delimiter //
                [ivarScanner scanUpToCharactersFromSet:m_endAndBegining intoString:&ivarType];
                ivarType = [ivarType stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
                // scan until the next valid var name //
                [ivarScanner scanUpToCharactersFromSet:m_validVarName intoString:nil];
                // scan until the next space, line break, delimiter //
                [ivarScanner scanUpToCharactersFromSet:m_endAndBegining intoString:&ivarName];
                ivarName = [ivarName stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
                [self addIvarWithType:ivarType andName:ivarName toClass:newClass];
            }
        }
        
        // parse the massage declarations //
        while (![interfaceScanner isAtEnd])
        {
            // move to the next function start //
            [interfaceScanner scanUpToCharactersFromSet:m_validMessageStart intoString:nil];
            // read the message type (+/-) //
            NSString *messageType = nil;
            [interfaceScanner scanCharactersFromSet:m_validMessageStart intoString:&messageType];
            // we don't support class (static) massages yet (+) //
            if ([messageType isEqualToString:@"+"])
            {
                // (+) MESSAGE TYPE NOT SUPPORTED YET, SKIPPING //
                continue;
            }
            // read the return type //
            NSString *returnType = nil;
            [interfaceScanner scanUpToString:@")" intoString:&returnType];
            returnType = [returnType stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
            // read the message signature //
            NSString *messageDeclaration = nil;
            [interfaceScanner scanUpToString:@";" intoString:&messageDeclaration];
            if (messageDeclaration)
            {
                messageDeclaration = [messageDeclaration stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
                [self addMessageWithReturnType:returnType andDeclaration:messageDeclaration toClass:newClass];
            }
        }
        // finally register the class pair for use by the runtime //
        objc_registerClassPair(newClass);
    }
    
    // find classes implementations //
    searchingRange = NSMakeRange(0, src.length);
    NSRange impRange;
    while ((impRange = [src rangeOfString:@"(?<=@implementation).*?(?=@end)" options:NSRegularExpressionSearch range:searchingRange]).location != NSNotFound)
    {
        searchingRange = NSMakeRange(impRange.location + impRange.length, src.length - (impRange.location + impRange.length));
        // get the @interface declaration //
        NSString *imp = [src substringWithRange:impRange];
        // get a scanner to find the declaration //
        NSScanner *impScanner = [NSScanner scannerWithString:imp];
        // find the class name //
        NSString *className = nil;
        [impScanner scanUpToCharactersFromSet:m_validVarName intoString:nil];
        [impScanner scanUpToCharactersFromSet:m_trimParentesisAndWhiteSpace intoString:&className];
        className = [className stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
        Class cls = NSClassFromString(className);
        if (!cls)
        {
            // class was not registered, skippping //
            continue;
        }
        NSMutableDictionary *classMethods = [m_runtimeClasses objectForKey:cls];
        if (!classMethods)
        {
            // class is not in the runtime classes, skipping //
            continue;
        }
        
        // advance to the first method //
        [impScanner scanUpToCharactersFromSet:m_validMessageStart intoString:nil];
        // process all messages //
        while (![impScanner isAtEnd])
        {
            // skip the message type (+/-) //
            [impScanner scanCharactersFromSet:m_validMessageStart intoString:nil];
            // skip the return type //
            [impScanner scanUpToString:@")" intoString:nil];
            // read the method declaration //
            NSString *methodDeclaration = nil;
            [impScanner scanUpToCharactersFromSet:m_curlyBraces intoString:&methodDeclaration];
            // process declaration to get selector name //
            if (methodDeclaration)
            {
                methodDeclaration = [methodDeclaration stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
                NSString *SELString = [NSString stringWithString:[self getSELStringFromDeclaration:methodDeclaration]];
                P2MethodContainer *container = [classMethods objectForKey:SELString];
                if (!container)
                {
                    // add a default container to the dictionary, just in case // all missing funtions default to id return type //
                    container = [[[P2MethodContainer alloc] initWithSelectorString:SELString
                                                                      argumentTypes:[NSArray array]
                                                                      argumentNames:[NSArray array]
                                                                          andSource:nil] autorelease];
                    [classMethods setObject:container forKey:SELString];
                }
                int blockCount = 0;
                NSString *messageComponent = nil;
                [impScanner scanCharactersFromSet:m_curlyBraces intoString:&messageComponent];
                NSMutableString *messageSrc = [NSMutableString stringWithString:messageComponent];
                if ([messageComponent isEqualToString:@"{"])
                {
                    blockCount++;
                }
                else if ([messageComponent isEqualToString:@"}"])
                {
                    blockCount--;
                }
                while (blockCount > 0)
                {
                    [impScanner scanUpToCharactersFromSet:m_curlyBraces intoString:&messageComponent];
                    [messageSrc appendString:messageComponent];
                    [impScanner scanCharactersFromSet:m_curlyBraces intoString:&messageComponent];
                    if ([messageComponent isEqualToString:@"{"])
                    {
                        blockCount++;
                    }
                    else if ([messageComponent isEqualToString:@"}"])
                    {
                        blockCount--;
                    }
                    [messageSrc appendString:messageComponent];
                }
                container.source = messageSrc;
            }
            // advance to the next method if any //
            [impScanner scanUpToCharactersFromSet:m_validMessageStart intoString:nil];
        }
    }
}

-(void) addIvarWithType:(NSString*)ivarType andName:(NSString*)ivarName toClass:(Class)cls
{
    // TODO //
}

-(void) addMessageWithReturnType:(NSString*)type andDeclaration:(NSString*)declaration toClass:(Class)cls
{
    
    // initialize an array to hold the parameters //
    NSMutableArray *messageParamTypes = [NSMutableArray array];
    NSMutableArray *messageParamNames = [NSMutableArray array];
    NSScanner *messageScanner = [NSScanner scannerWithString:declaration];
    NSString *messageComponent = nil;
    [messageScanner scanUpToString:@":" intoString:&messageComponent];
    NSMutableString *messageSEL = [NSMutableString stringWithFormat:@"%@", messageComponent];
    if (([declaration rangeOfString:@":"]).location != NSNotFound)
    {
        [messageSEL appendString:@":"];
    }
    while (![messageScanner isAtEnd])
    {
        // skip the ":" //
        [messageScanner scanString:@":" intoString:nil];
        [messageScanner scanUpToString:@")" intoString:&messageComponent];
        messageComponent = [messageComponent stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
        [messageParamTypes addObject:messageComponent];
        // scan to the paramater name //
        [messageScanner scanUpToCharactersFromSet:m_validVarName intoString:nil];
        // read the name //
        [messageScanner scanUpToCharactersFromSet:m_endAndBegining intoString:&messageComponent];
        messageComponent = [messageComponent stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
        [messageParamNames addObject:messageComponent];
        // advance the scanner to the next component //
        if ([messageScanner scanUpToString:@":" intoString:&messageComponent])
        {
            messageComponent = [messageComponent stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
            [messageSEL appendString:messageComponent];
            if (![messageScanner isAtEnd])
            {
                [messageSEL appendString:@":"];
            }
        }
    }
    
    P2MethodContainer *method = [[[P2MethodContainer alloc] initWithSelectorString:messageSEL argumentTypes:messageParamTypes argumentNames:messageParamNames andSource:nil] autorelease];
    [[m_runtimeClasses objectForKey:cls] setObject:method forKey:method.selectorString];
    
    // build the method type encoding //
    NSString *retTypeEncoding = nil;
    if ([type hasSuffix:@"*"])
    {
        retTypeEncoding = [m_typeEncodings objectForKey:@"id"];
    }
    else
    {
        retTypeEncoding = [m_typeEncodings objectForKey:type];
    }
    NSMutableString *typeEncodings = [NSMutableString stringWithFormat:@"%@@:", retTypeEncoding];
    for (int i = 0; i < method.argumentTypes.count; ++i)
    {
        if ([[method.argumentTypes objectAtIndex:i] hasSuffix:@"*"])
        {
            [typeEncodings appendFormat:@"%@", [m_typeEncodings objectForKey:@"id"]];
        }
        else
        {
            [typeEncodings appendFormat:@"%@", [m_typeEncodings objectForKey:[method.argumentTypes objectAtIndex:i]]];
        }
    }
    
    if ([type isEqualToString:@"void"])
    {
        assert(class_addMethod(cls, NSSelectorFromString(method.selectorString), (IMP)m_voidIMP, [typeEncodings UTF8String]));
    }
    else if ([type isEqualToString:@"id"] || [type hasSuffix:@"*"])
    {
        assert(class_addMethod(cls, NSSelectorFromString(method.selectorString), (IMP)m_idIMP, [typeEncodings UTF8String]));
    }
    else if ([type isEqualToString:@"int"])
    {
        assert(class_addMethod(cls, NSSelectorFromString(method.selectorString), (IMP)m_intIMP, [typeEncodings UTF8String]));
    }
    else if ([type isEqualToString:@"double"])
    {
        assert(class_addMethod(cls, NSSelectorFromString(method.selectorString), (IMP)m_doubleIMP, [typeEncodings UTF8String]));
    }
}

-(NSString*) getSELStringFromDeclaration:(NSString*)declaration
{
    NSScanner *messageScanner = [NSScanner scannerWithString:declaration];
    NSString *messageComponent = nil;
    [messageScanner scanUpToString:@":" intoString:&messageComponent];
    NSMutableString *messageSEL = [NSMutableString stringWithFormat:@"%@", messageComponent];
    if (([declaration rangeOfString:@":"]).location != NSNotFound)
    {
        [messageSEL appendString:@":"];
    }
    while (![messageScanner isAtEnd])
    {
        // skip the ":" //
        [messageScanner scanString:@":" intoString:nil];
        [messageScanner scanUpToString:@")" intoString:nil];
        // scan to the paramater name //
        [messageScanner scanUpToCharactersFromSet:m_validVarName intoString:nil];
        // read the name //
        [messageScanner scanUpToCharactersFromSet:m_endAndBegining intoString:nil];
        // advance the scanner to the next component //
        if ([messageScanner scanUpToString:@":" intoString:&messageComponent])
        {
            messageComponent = [messageComponent stringByTrimmingCharactersInSet:m_trimParentesisAndWhiteSpace];
            [messageSEL appendString:messageComponent];
            if (![messageScanner isAtEnd])
            {
                [messageSEL appendString:@":"];
            }
        }
    }
    return messageSEL;
}

-(NSDictionary*) getMethodCallDescription:(NSString*)methodCall
{
    NSMutableArray *args = [NSMutableArray array];
    NSMutableString *selString = [NSMutableString stringWithString:@""];
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithCapacity:3];
    [ret setObject:args forKey:@"args"];
    NSScanner *scanner = [NSScanner scannerWithString:methodCall];
    NSString *component = nil;
    [scanner scanUpToCharactersFromSet:m_validVarName intoString:nil];
    [scanner scanUpToCharactersFromSet:m_endAndBegining intoString:&component];
    [ret setObject:component forKey:@"target"];
    [scanner scanUpToCharactersFromSet:m_validVarName intoString:nil];
    if (([methodCall rangeOfString:@":"]).location == NSNotFound)
    {
        [scanner scanUpToCharactersFromSet:m_endAndBegining intoString:&component];
        [ret setObject:component forKey:@"selector"];
    }
    else
    {
        // TODO //
//        while (![scanner isAtEnd])
//        {
//            //
//        }
    }
    return ret;
    
}

@end


#pragma mark - P2ClassExtension function implementations

