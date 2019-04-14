//
//  ViewController.m
//  BlockHookSampleMac
//
//  Created by 杨萧玉 on 2019/4/14.
//  Copyright © 2019 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import <BlockHook/BlockHook.h>

@implementation ViewController

- (void)performBlock:(void(^)(void))block
{
    BHToken *tokenInstead = [block block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token){
        [token invokeOriginalBlock];
        NSLog(@"hook stack block succeed!");
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (block) {
            block();
        }
        [tokenInstead remove];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSObject *z = NSObject.new;
    int (^block)(int, int) = ^(int x, int y) {
        int result = x + y;
        NSLog(@"%d + %d = %d, z is a NSObject: %@", x, y, result, z);
        return result;
    };
    [self performBlock:^{
        NSLog(@"stack block:%@", z);
    }];
    
    BHToken *tokenInstead = [block block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token, int x, int y){
        [token invokeOriginalBlock];
        NSLog(@"let me see original result: %d", *(int *)(token.retValue));
        // change the block imp and result
        *(int *)(token.retValue) = x * y;
        NSLog(@"hook instead: '+' -> '*'");
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"hooked block");
        int ret = block(3, 5);
        NSLog(@"hooked result:%d", ret);
        NSLog(@"remove tokens, original block");
        ret = block(3, 5);
        NSLog(@"original result:%d", ret);
    });
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
