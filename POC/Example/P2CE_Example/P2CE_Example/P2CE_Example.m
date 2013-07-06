//
//  P2CE_Example.m
//  P2CE_Example
//
//  Created by Dario Segura on 2013-06-19.
//  Copyright (c) 2013 Dario Segura. All rights reserved.
//

#import "P2CE_Example.h"
#import "P2ClassExtender.h"

@implementation P2CE_Example

-(void) runExample
{
    [[P2ClassExtender sharedInstance] createClassWithSource:@"\
     @interface Greeter : NSObject\
     -(void) sayHelloWithString:(NSString*)string numberOfTimes:(int)times andDelegate:(id)delegate;\
     -(void) sayHelloAgain;\
     @end\
     \
     @implementation Greeter\
     -(void) sayHelloWithString:(NSString*)string numberOfTimes:(int)times andDelegate:(id)delegate\
     {\
         NSLog(@\"Hello %@!!! %d times over!\", string, times);\
         [delegate sayHello];\
     }\
     -(void) sayHelloAgain\
     {\
         NSLog(@\"Hello again!\");\
     }\
     @end\
     "];
    
    [[P2ClassExtender sharedInstance] createClassWithSource:@"\
     @interface Caller : NSObject\
     -(void) callSayHelloAgainFrom:(id)target;\
     @end\
     \
     @implementation Caller\
     -(void) callSayHelloAgainFrom:(id)target\
     {\
         [target sayHelloAgain];\
     }\
     @end\
     "];
    
    [[P2ClassExtender sharedInstance] createClassWithSource:@"\
     @interface CallerChild : Caller\
     @end\
     @implementation CallerChild\
     @end\
     "];
    
    [[P2ClassExtender sharedInstance] createClassWithSource:@"\
     @interface ExampleChild : P2CE_Example\
     -(void) sayGoodbye;\
     @end\
     @implementation ExampleChild\
     -(void) sayGoodbye\
     {\
         NSLog(@\"Goodbye?! NOT YET!\");\
     }\
     @end\
     "];
    
    [[P2ClassExtender sharedInstance] createClassWithSource:@"\
     @interface ExamplePureChild : P2CE_Example\
     @end\
     @implementation ExamplePureChild\
     @end\
     "];
    
    Class greeterClass = NSClassFromString(@"Greeter");
    id greeterInstance = [[greeterClass alloc] init];
    [greeterInstance sayHelloWithString:@"Dario" numberOfTimes:60 andDelegate:self];
    
    Class callerClass = NSClassFromString(@"Caller");
    id callerInstance = [[callerClass alloc] init];
    [callerInstance callSayHelloAgainFrom:greeterInstance];
    
    Class callerChildClass = NSClassFromString(@"CallerChild");
    id callerChildInstance = [[callerChildClass alloc] init];
    [callerChildInstance callSayHelloAgainFrom:greeterInstance];
    
    Class exampleChildClass = NSClassFromString(@"ExampleChild");
    id exampleChildInstance = [[exampleChildClass alloc] init];
    [exampleChildInstance sayGoodbye];
    
    Class examplePureChildClass = NSClassFromString(@"ExamplePureChild");
    id examplePureChildInstance = [[examplePureChildClass alloc] init];
    [examplePureChildInstance sayGoodbye];
}

-(void) sayHello
{
    NSLog(@"Hello you!");
}

-(void) sayGoodbye
{
    NSLog(@"Have a nice day... you!");
}

@end
