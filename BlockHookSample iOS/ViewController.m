//
//  ViewController.m
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/26.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
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

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSObject *testArg = [NSObject new];
    NSObject *testArg1 = [NSObject new];
    int e = 5;
    struct TestStruct testRect = (struct TestStruct){1, 2.0, 3.0, 4, &e, NULL, 7};
    struct TestStruct (^StructReturnBlock)(NSObject *) = ^(NSObject *a)
    {
        NSAssert(a == testArg1, @"Sync Struct Return Interceptor change argument failed!");
        struct TestStruct result = testRect;
        return result;
    };
    
    [StructReturnBlock block_interceptor:^(BHInvocation *invocation, IntercepterCompletion  _Nonnull completion) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __unused NSObject *arg = (__bridge NSObject *)*(void **)(invocation.args[1]);
            NSAssert(arg == testArg, @"Sync Interceptor wrong argument!");
            *(void **)(invocation.args[1]) = (__bridge void *)(testArg1);
            completion();
            (*(struct TestStruct *)(invocation.retValue)).a = 100;
        });
    }];
    
    __unused struct TestStruct result = StructReturnBlock(testArg);
}

@end
