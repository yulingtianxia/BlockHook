//
//  BlockHookSampleTests.m
//  BlockHookSample iOSTests
//
//  Created by 杨萧玉 on 2019/4/19.
//  Copyright © 2019 杨萧玉. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <BlockHook/BlockHook.h>

struct TestStruct {
    int64_t a;
    double b;
    float c;
    char d;
    int *e;
    CGRect *f;
    uint64_t g;
};

@interface BlockHookSampleTests : XCTestCase

@end

@implementation BlockHookSampleTests

struct TestStruct _testRect;

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    int e = 5;
    _testRect = (struct TestStruct){1, 2.0, 3.0, 4, &e, NULL, 7};
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)performBlock:(void(^)(void))block
{
    BHToken *tokenInstead = [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHInvocation *invocation){
        NSLog(@"hook stack block succeed!");
    }];
    
    __unused BHToken *tokenDead = [block block_hookWithMode:BlockHookModeDead usingBlock:^(BHToken *token){
        NSLog(@"stack block dead!");
    }];
    
    if (block) {
        block();
    }
    [tokenInstead remove];
}

- (void)testStructReturn {
    struct TestStruct (^StructReturnBlock)(int) = ^(int x)
    {
        struct TestStruct result = _testRect;
        return result;
    };
    
    [StructReturnBlock block_hookWithMode:BlockHookModeAfter usingBlock:^(BHInvocation *invocation, int x){
        (*(struct TestStruct *)(invocation.retValue)).a = 100;
        NSAssert(x == 8, @"Wrong arg!");
    }];
    
    struct TestStruct result = StructReturnBlock(8);
    NSAssert(result.a == 100, @"Modify return struct failed!");
}

- (void)testStructPointerReturn {
    struct TestStruct * (^StructReturnBlock)(void) = ^()
    {
        struct TestStruct *result = &_testRect;
        return result;
    };
    
    [StructReturnBlock block_hookWithMode:BlockHookModeAfter usingBlock:^(BHInvocation *invocation){
        (**(struct TestStruct **)(invocation.retValue)).a = 100;
    }];
    
    struct TestStruct *result = StructReturnBlock();
    NSAssert(result->a == 100, @"Modify return struct failed!");
}

- (void)testStructArg {
    void (^StructReturnBlock)(struct TestStruct) = ^(struct TestStruct test)
    {
        NSAssert(test.a == 100, @"Modify struct member failed!");
    };
    
    [StructReturnBlock block_hookWithMode:BlockHookModeBefore usingBlock:^(BHInvocation *invocation, struct TestStruct test){
        // Hook 改参数
        (*(struct TestStruct *)(invocation.args[1])).a = 100;
    }];
    StructReturnBlock(_testRect);
}

- (void)testStructPointerArg {
    void (^StructReturnBlock)(struct TestStruct *) = ^(struct TestStruct *test)
    {
        NSAssert(test->a == 100, @"Modify struct member failed!");
    };
    
    [StructReturnBlock block_hookWithMode:BlockHookModeBefore usingBlock:^(BHInvocation *invocation, struct TestStruct test){
        // Hook 改参数
        (**(struct TestStruct **)(invocation.args[1])).a = 100;
    }];
    StructReturnBlock(&_testRect);
}

- (void)testStackBlock {
    NSObject *z = NSObject.new;
    [self performBlock:^{
        NSLog(@"stack block:%@", z);
    }];
}

- (void)testProtocol {
    int(^block)(int x, int y) = ^int(int x, int y) {
        int result = x + y;
        NSLog(@"%d + %d = %d", x, y, result);
        return result;
    };
    const char *(^protocolBlock)(id<CALayerDelegate>, int(^)(int, int)) = ^(id<CALayerDelegate> delegate, int(^block)(int, int)) {
        return (const char *)"test protocol";
    };
    BHToken *token = [protocolBlock block_hookWithMode:BlockHookModeBefore usingBlock:^(BHInvocation *invocation, id<CALayerDelegate> delegate, int(^block)(int x, int y)){
        NSLog(@"%@ %@ %@", invocation, delegate, block);
    }];
    id z = [NSObject new];
    protocolBlock(z, block);
}

- (void)testHookBlock {
    
    NSObject *z = NSObject.new;
    int(^block)(int x, int y) = ^int(int x, int y) {
        int result = x + y;
        NSLog(@"%d + %d = %d, z is a NSObject: %@", x, y, result, z);
        return result;
    };
    
    __unused BHToken *tokenDead = [block block_hookWithMode:BlockHookModeDead usingBlock:^(BHToken *token){
        // BHToken is the only arg.
        NSLog(@"block dead! token:%@", token);
    }];
    
    BHToken *tokenInstead = [block block_hookWithMode:BlockHookModeInstead usingBlock:^(BHInvocation *invocation, int x, int y){
        [invocation invokeOriginalBlock];
        NSLog(@"let me see original result: %d", *(int *)(invocation.retValue));
        // change the block imp and result
        *(int *)(invocation.retValue) = x * y;
        NSLog(@"hook instead: '+' -> '*'");
    }];
    
    NSAssert([tokenInstead.mangleName isEqualToString:@"__37-[BlockHookSampleTests testHookBlock]_block_invoke"], @"Wrong mangle name!");
    
    __unused BHToken *tokenAfter = [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHInvocation *invocation, int x, int y){
        // print args and result
        NSLog(@"hook after block! %d * %d = %d", x, y, *(int *)(invocation.retValue));
    }];
    
    __unused BHToken *tokenBefore = [block block_hookWithMode:BlockHookModeBefore usingBlock:^(BHInvocation *invocation){
        // BHToken has to be the first arg.
        NSLog(@"hook before block! invocation:%@", invocation);
    }];
    
    NSLog(@"hooked block");
    int ret = block(3, 5);
    NSAssert(ret == 15, @"hook failed!");
    NSLog(@"hooked result:%d", ret);
    // remove token.
    [tokenInstead remove];
    NSLog(@"remove tokens, original block");
    ret = block(3, 5);
    NSAssert(ret == 8, @"remove hook failed!");
    NSLog(@"original result:%d", ret);
    //        [tokenDead remove];
}

- (void)testRemoveAll {
    
    NSObject *z = NSObject.new;
    int(^block)(int x, int y) = ^int(int x, int y) {
        int result = x + y;
        NSLog(@"%d + %d = %d, z is a NSObject: %@", x, y, result, z);
        return result;
    };
    
    [block block_hookWithMode:BlockHookModeDead usingBlock:^(BHToken *token){
        // BHToken is the only arg.
        NSLog(@"block dead! token:%@", token);
    }];
    
    [block block_hookWithMode:BlockHookModeInstead usingBlock:^(BHInvocation *invocation, int x, int y){
        [invocation invokeOriginalBlock];
        NSLog(@"let me see original result: %d", *(int *)(invocation.retValue));
        // change the block imp and result
        *(int *)(invocation.retValue) = x * y;
        NSLog(@"hook instead: '+' -> '*'");
    }];
    
    [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHInvocation *invocation, int x, int y){
        // print args and result
        NSLog(@"hook after block! %d * %d = %d", x, y, *(int *)(invocation.retValue));
    }];
    
    [block block_hookWithMode:BlockHookModeBefore usingBlock:^(BHInvocation *invocation){
        // BHToken has to be the first arg.
        NSLog(@"hook before block! invocation:%@", invocation);
    }];
    
    NSLog(@"hooked block");
    int ret = block(3, 5);
    NSAssert(ret == 15, @"hook failed!");
    NSLog(@"hooked result:%d", ret);
    // remove all tokens when you don't need.
    [block block_removeAllHook];
    NSLog(@"remove tokens, original block");
    ret = block(3, 5);
    NSLog(@"original result:%d", ret);
    NSAssert(ret == 8, @"remove hook failed!");
    NSAssert([block block_currentHookToken] == nil, @"remove all hook failed!");
}

@end
