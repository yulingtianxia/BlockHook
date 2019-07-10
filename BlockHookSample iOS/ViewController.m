//
//  ViewController.m
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/26.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import <BlockHook/BlockHook.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    NSObject *ret = [NSObject new];
//    NSObject *testArg = [NSObject new];
//    NSObject *testArg1 = [NSObject new];
//    
//    NSObject *(^testblock)(NSObject *) = ^(NSObject *a) {
//        return ret;
//    };
//    __block BHInvocation *inv = nil;
//    
//    [(id)testblock block_interceptor:^(BHInvocation *invocation, IntercepterCompletion  _Nonnull completion) {
//        //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        inv = invocation;
//        NSObject *arg = (__bridge NSObject *)*(void **)(invocation.args[1]);
//        *(void **)(invocation.args[1]) = (__bridge void *)(testArg1);
//        completion();
//        *(void **)(invocation.retValue) = (__bridge void *)([NSObject new]);
//        //        });
//    }];
//    
//    NSObject *result = testblock(testArg);
//    NSLog(@"result:%@", result);
}

@end
