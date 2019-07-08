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
@property (nonatomic, strong) NSObject *test;
@property (nonatomic, strong) NSObject *result;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.test = [NSObject new];
    self.result = [NSObject new];
    NSObject *(^testblock)(NSObject *) = ^(NSObject *a) {
        NSLog(@"I'm a block:%@", a);
        return self.result;
    };
    __block BHInvocation *inv = nil;
//    [(id)testblock block_hookWithMode:BlockHookModeAfter usingBlock:^(BHInvocation *invocation) {
////        [invocation invokeOriginalBlock];
//        inv = invocation;
//    }];
    
    [(id)testblock interceptBlock:^(BHInvocation *invocation, IntercepterCompletion  _Nonnull completion) {
        id block = ^{
            NSLog(@"Intercept!");
            inv = invocation;
            NSObject *a = (__bridge NSObject *)*(void **)(invocation.args[1]);
            NSObject *p = [NSObject new];
            *(void **)(invocation.args[1]) = (__bridge void *)(p);
            completion();
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
    }];
    NSObject *result = testblock(self.test);
    NSLog(@"result:%@", result);
}

@end
