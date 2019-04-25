//
//  BlockHookSample_iOSTests.m
//  BlockHookSample iOSTests
//
//  Created by 杨萧玉 on 2019/4/19.
//  Copyright © 2019 杨萧玉. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <BlockHook/BlockHook.h>

struct TestStruct {
    int32_t a;
    double b;
    float c;
    char d;
    int *e;
    CGRect *f;
};

struct Block_descriptor {
    void *reserved;
    uintptr_t size;
};

struct Block_layout {
    void *isa;
    int32_t flags; // contains ref count
    int32_t reserved;
    void  *invoke;
    struct Block_descriptor *descriptor;
};

@interface BlockHookSample_iOSTests : XCTestCase

@end

@implementation BlockHookSample_iOSTests

struct TestStruct _testRect;

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    int e = 5;
    _testRect = (struct TestStruct){1, 2.0, 3.0, 4, &e, NULL};
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)performBlock:(void(^)(void))block
{
    BHToken *tokenInstead = [block block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token){
        [token invokeOriginalBlock];
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
    struct TestStruct (^StructReturnBlock)(void) = ^()
    {
        struct TestStruct result = _testRect;
        return result;
    };
    
    [StructReturnBlock block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token){
        [token invokeOriginalBlock];
        (**(struct TestStruct **)(token.args[0])).a = 100;
    }];
    
    struct TestStruct result = StructReturnBlock();
    NSAssert(result.a == 100, @"Modify return struct failed!");
}

- (void)testStructPointerReturn {
    struct TestStruct * (^StructReturnBlock)(void) = ^()
    {
        struct TestStruct *result = &_testRect;
        return result;
    };
    
    [StructReturnBlock block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token){
        [token invokeOriginalBlock];
        (**(struct TestStruct **)(token.retValue)).a = 100;
    }];
    
    struct TestStruct *result = StructReturnBlock();
    NSAssert(result->a == 100, @"Modify return struct failed!");
}

- (void)testStructArg {
    void (^StructReturnBlock)(struct TestStruct) = ^(struct TestStruct test)
    {
        NSAssert(test.a == 100, @"Modify struct member failed!");
    };
    
    [StructReturnBlock block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token, struct TestStruct test){
        // Hook 改参数
        (*(struct TestStruct *)(token.args[1])).a = 100;
        [token invokeOriginalBlock];
    }];
    StructReturnBlock(_testRect);
}

- (void)testStructPointerArg {
    void (^StructReturnBlock)(struct TestStruct *) = ^(struct TestStruct *test)
    {
        NSAssert(test->a == 100, @"Modify struct member failed!");
    };
    
    [StructReturnBlock block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token, struct TestStruct test){
        // Hook 改参数
        (**(struct TestStruct **)(token.args[1])).a = 100;
        [token invokeOriginalBlock];
    }];
    StructReturnBlock(&_testRect);
}

- (void)testStackBlock {
    NSObject *z = NSObject.new;
    [self performBlock:^{
        NSLog(@"stack block:%@", z);
    }];
}

- (void)testHookBlock {
    
    NSObject *z = NSObject.new;
    int(^block)(int x, int y) = ^int(int x, int y) {
        int result = x + y;
        NSLog(@"%d + %d = %d, z is a NSObject: %@", x, y, result, z);
        return result;
    };
    
    BHToken *tokenInstead = [block block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token, int x, int y){
        [token invokeOriginalBlock];
        NSLog(@"let me see original result: %d", *(int *)(token.retValue));
        // change the block imp and result
        *(int *)(token.retValue) = x * y;
        NSLog(@"hook instead: '+' -> '*'");
    }];
    
    NSAssert([tokenInstead.mangleName isEqualToString:@"__41-[BlockHookSample_iOSTests testHookBlock]_block_invoke"], @"Wrong mangle name!");
    
    BHToken *tokenAfter = [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHToken *token, int x, int y){
        // print args and result
        NSLog(@"hook after block! %d * %d = %d", x, y, *(int *)(token.retValue));
    }];
    
    BHToken *tokenBefore = [block block_hookWithMode:BlockHookModeBefore usingBlock:^(id token){
        // BHToken has to be the first arg.
        NSLog(@"hook before block! token:%@", token);
    }];
    
    __unused BHToken *tokenDead = [block block_hookWithMode:BlockHookModeDead usingBlock:^(id token){
        // BHToken is the only arg.
        NSLog(@"block dead! token:%@", token);
    }];
    
    NSLog(@"hooked block");
    int ret = block(3, 5);
    NSAssert(ret == 15, @"hook failed!");
    NSLog(@"hooked result:%d", ret);
    // remove all tokens when you don't need.
    // reversed order of hook.
    [block block_removeHook:tokenBefore];
    [tokenAfter remove];
    [block block_removeHook:tokenInstead];
    NSLog(@"remove tokens, original block");
    ret = block(3, 5);
    NSAssert(ret == 8, @"remove hook failed!");
    NSLog(@"original result:%d", ret);
    //        [tokenDead remove];
}

@end
