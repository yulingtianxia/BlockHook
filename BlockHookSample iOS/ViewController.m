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
    NSObject *ret = [NSObject new];
    NSObject *(^testblock)(NSObject *) = ^(NSObject *a) {
        NSLog(@"I'm a block:%@", a);
        return ret;
    };
    __block BHInvocation *inv = nil;
    
    BHToken *token = [(id)testblock block_interceptor:^(BHInvocation *invocation, IntercepterCompletion  _Nonnull completion) {
        id block = ^{
            NSLog(@"Intercept!");
            inv = invocation;
            NSObject *a = (__bridge NSObject *)*(void **)(invocation.args[1]);
            NSObject *p = [NSObject new];
            NSObject *r = [NSObject new];
            *(void **)(invocation.args[1]) = (__bridge void *)(p);
            completion();
            *(void **)(invocation.retValue) = (__bridge void *)(r);
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
    }];
    NSObject *a = [NSObject new];
    NSObject *result = testblock(a);
    NSLog(@"result:%@", result);
    
}

@end
