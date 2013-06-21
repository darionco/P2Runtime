//
//  P2ClassExtension.m
//  P2GUIImporter
//
//  Created by Dario Segura on 2013-04-27.
//
//

#import "P2ClassExtension.h"
#import "P2ClassExtender.h"
#import "P2MethodContainer.h"
#import "P2VariableContainer.h"
#import <objc/runtime.h>

#pragma mark - P2CE utility defines
/* P2CE_initVarStack
 *
 * This macro creates and configures two new variables:
 * P2MethodContainer *method
 * NSMutableArray *varStack
 *
 * method - contains the gsg method definition which should be used to run the method
 *
 * varStack - contains an NSMutableArray that should be used as a variable stack. Upon creation this stack contains
 * one dictionary holding the method's arguments and their values if any.
 *
 * vars - A pointer to the current top of the stack
 */
#define P2CE_initVarStack()\
    P2MethodContainer *method = [[P2ClassExtender sharedInstance] getMethod:_cmd forClass:[self class]];\
    NSMutableArray *varStack __attribute__((cleanup(__P2_Var_Stack_Release_Object__))) = [[NSMutableArray alloc] init];\
    va_list args;\
    va_start(args, _cmd);\
    NSDictionary *argDict = P2CE_createArgumentsDictionary(method, args);\
    [varStack addObject:argDict];\
    [argDict release];\
    NSDictionary *vars = [varStack lastObject];\
    va_end(args);

#define P2CE_pushVarBlock()\
    do\
    {\
        vars = [[NSDictionary alloc] init];\
        [varStack addObject:vars];\
        [vars release];\
    } while (0);

#define P2CE_popVarBlock()\
    do\
    {\
        [varStack removeLastObject];\
        vars = [varStack lastObject];\
    } while(0);

#pragma mark - P2CE utility functions
NSDictionary* P2CE_createArgumentsDictionary(P2MethodContainer *method, va_list args);
BOOL P2CE_isCommandSupprtedCStyleCommand(NSString *command);
id P2CE_runCStyleCommand(NSString *command, NSArray *varStack);
P2VariableContainer* P2CE_getVariableFromStack(NSString *name, NSArray *stack);
void* P2CE_runObjCCommand(NSString *command, NSArray *stack);

static void __P2_Var_Stack_Release_Object__(NSArray **obj);

#pragma mark - P2CE C-Style function wrappers
id P2CE_NSLog_wrapper(NSString *command, NSArray *varStack);


#pragma mark - P2ClassExtension implementations
void P2ClassExtension_default_return_void(id self, SEL _cmd, ...)
{
    //NSLog(@"%s called by class %@ with SEL: %@", __PRETTY_FUNCTION__, [self class], NSStringFromSelector(_cmd));
    P2CE_initVarStack(); // this results on three new variables (autoreleased) in the scope: P2MethodContainer *method, NSMutableArray *varStack and NSDictionary *vars //
    // find the method's source //
    //NSString *src = method.source;
    // get all the blocks //
    //NSArray *blocks = [method.source componentsSeparatedByString:@"{"]; // TODO
    // iterate through the blocks and find nested blocks //
    // TODO
    // find the different commands, TODO: add support for "for" loops //
    NSArray *commands = [method.source componentsSeparatedByString:@";"];
    // iterate through the commands and process them secuentially //
    for (int i = 0; i < commands.count; ++i)
    {
        NSString *command = [commands objectAtIndex:i];
        // trim the command //
        command = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // if the command starts with curly braces start/end a var stack block and remove the string //
        if ([command hasPrefix:@"{"])
        {
            P2CE_pushVarBlock();
            if ([command isEqualToString:@"{"])
            {
                continue;
            }
            command = [command stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
            command = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; // maybe we should use a mutable string instead? //
        }
        else if ([command hasPrefix:@"}"])
        {
            P2CE_popVarBlock();
            if ([command isEqualToString:@"}"])
            {
                continue;
            }
            command = [command stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
            command = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; // maybe we should use a mutable string instead? //

        }
        
        // recognize the type of command //
        if ([command rangeOfString:@"="].location != NSNotFound) // assignment operation
        {
            // TODO
        }
        else if ([command hasPrefix:@"["]) // objective-c function call
        {
            P2CE_runObjCCommand(command, varStack);
        }
        else if (P2CE_isCommandSupprtedCStyleCommand(command)) // C style command
        {
            P2CE_runCStyleCommand(command, varStack);
        }
        else // unsuported comamnd //
        {
            NSLog(@"P2ClassExtension WARNING: Unsupported command: %@", command);
        }
    }
}

id P2ClassExtension_default_return_id(id self, SEL _cmd, ...)
{
    //NSLog(@"%s called by class %@ with SEL: %@", __PRETTY_FUNCTION__, [self class], NSStringFromSelector(_cmd));
    P2CE_initVarStack(); // this results on two new variables (autoreleased) in the scope: P2MethodContainer *method and NSMutableArray *varStack //
    
    for (NSString *key in [[varStack objectAtIndex:0] allKeys])
    {
        P2VariableContainer *var = [[varStack objectAtIndex:0] objectForKey:key];
        NSLog(@"Variable: %@\tType: %@\tValue:%@", var.name, var.type, var.value);
    }
    
    return nil;
}

int P2ClassExtension_default_return_int(id self, SEL _cmd, ...)
{
    //NSLog(@"%s called by class %@ with SEL: %@", __PRETTY_FUNCTION__, [self class], NSStringFromSelector(_cmd));
    P2CE_initVarStack(); // this results on two new variables (autoreleased) in the scope: P2MethodContainer *method and NSMutableArray *varStack //
    return 0;
}

double P2ClassExtension_default_return_double(id self, SEL _cmd, ...)
{
    //NSLog(@"%s called by class %@ with SEL: %@", __PRETTY_FUNCTION__, [self class], NSStringFromSelector(_cmd));
    P2CE_initVarStack(); // this results on two new variables (autoreleased) in the scope: P2MethodContainer *method and NSMutableArray *varStack //
    return 0.0;
}


#pragma mark - P2CE utility functions implementation
NSDictionary* P2CE_createArgumentsDictionary(P2MethodContainer *method, va_list args)
{
    NSMutableDictionary *retDict = [[NSMutableDictionary alloc] init];
    P2VariableContainer *container = nil;
    for (int i = 0; i < method.argumentTypes.count; ++i)
    {
        if ([[method.argumentTypes objectAtIndex:i] isEqualToString:@"id"] || [[method.argumentTypes objectAtIndex:i] hasSuffix:@"*"])
        {
            container = [P2VariableContainer containerWithType:[method.argumentTypes objectAtIndex:i]
                                                           name:[method.argumentNames objectAtIndex:i]
                                                       andValue:va_arg(args, id)];
        }
        else if ([[method.argumentTypes objectAtIndex:i] isEqualToString:@"int"])
        {
            container = [P2VariableContainer containerWithType:[method.argumentTypes objectAtIndex:i]
                                                           name:[method.argumentNames objectAtIndex:i]
                                                       andValue:[NSNumber numberWithInt:va_arg(args, int)]];
        }
        else if ([[method.argumentTypes objectAtIndex:i] isEqualToString:@"double"])
        {
            container = [P2VariableContainer containerWithType:[method.argumentTypes objectAtIndex:i]
                                                           name:[method.argumentNames objectAtIndex:i]
                                                       andValue:[NSNumber numberWithDouble:va_arg(args, double)]];
        }
        [retDict setObject:container forKey:[method.argumentNames objectAtIndex:i]];
    }
    return retDict;
}

BOOL P2CE_isCommandSupprtedCStyleCommand(NSString *command)
{
    // just a long list of supported command for now //
    // if the string doesn't contain parentesis we can safely assume it's not a C-Style command (supported by this function) //
    if ([command rangeOfString:@"("].location == NSNotFound)
    {
        return NO;
    }
    else if ([command hasPrefix:@"NSLog"])
    {
        return YES;
    }
    
    return NO;
}

id P2CE_runCStyleCommand(NSString *command, NSArray *varStack)
{
    if ([command hasPrefix:@"NSLog"])
    {
        return P2CE_NSLog_wrapper(command, varStack);
    }
    
    return nil;
}

void* P2CE_runObjCCommand(NSString *command, NSArray *stack)
{
    // TODO: Incomplete, modify to account for arguments in the function call //
    NSDictionary *description = [[P2ClassExtender sharedInstance] getMethodCallDescription:command];
    SEL sel = NSSelectorFromString([description objectForKey:@"selector"]);
    id target = P2CE_getVariableFromStack([description objectForKey:@"target"], stack).value;
    [target performSelector:sel];
    return nil;
}

P2VariableContainer* P2CE_getVariableFromStack(NSString *name, NSArray *stack)
{
    P2VariableContainer *ret = nil;
    for (int i = stack.count - 1; i >= 0; --i)
    {
        NSDictionary *context = [stack objectAtIndex:i];
        ret = [context objectForKey:name];
        if (ret) break;
    }
    return ret;
}

void __P2_Var_Stack_Release_Object__(NSArray **obj)
{
    [(*obj) release];
    (*obj) = nil;
}

#pragma mark - P2CE C-Style function wrappers implementation
id P2CE_NSLog_wrapper(NSString *command, NSArray *varStack)
{
    NSScanner *scanner = [NSScanner scannerWithString:command];
    // advance the scanner to the begining of the arguments //
    [scanner scanUpToString:@"@\"" intoString:nil];
    [scanner scanString:@"@\"" intoString:nil];
    NSString *formatString = nil;
    [scanner scanUpToString:@"\"" intoString:&formatString]; // TODO: Add support for nested quotes //
    // move past the quotes //
    [scanner scanString:@"\"" intoString:nil];
    // skip any white space //
    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
    // if the next character is a comma then there are arguments //
    if ([scanner scanString:@"," intoString:nil])
    {
        NSString *argumentString = nil;
        [scanner scanUpToString:@")" intoString:&argumentString];
        if (argumentString)
        {
            // TODO: Add support for constants //
            NSArray *arguments = [argumentString componentsSeparatedByString:@","];
            NSMutableArray *vars = [[NSMutableArray alloc] initWithCapacity:arguments.count];
            size_t varsSize = 0;
            for (int i = 0; i < arguments.count; ++i)
            {
                NSString *argument = [[arguments objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                P2VariableContainer *var = P2CE_getVariableFromStack(argument, varStack);
                varsSize += var.size;
                [vars addObject:var];
            }
            char *va_args = (char*)malloc(varsSize);
            char *va_args_ptr = va_args;
            
            for (int i = 0; i < vars.count; ++i)
            {
                P2VariableContainer *var = [vars objectAtIndex:i];
                if ([var.type isEqualToString:@"id"] || [var.type hasSuffix:@"*"])
                {
                    id *tmp = (id*)va_args;
                    (*tmp) = var.value;
                }
                else if ([var.type isEqualToString:@"int"])
                {
                    int *tmp = (int*)va_args;
                    (*tmp) = [var.value integerValue];
                }
                else if ([var.type isEqualToString:@"double"])
                {
                    double *tmp = (double*)va_args;
                    (*tmp) = [var.value doubleValue];
                }
                va_args += var.size;
            }
            NSLogv(formatString, (va_list)va_args_ptr);
            free(va_args_ptr);
        }
    }
    else
    {
        NSLog(@"%@", formatString);
    }
    return nil;
}


