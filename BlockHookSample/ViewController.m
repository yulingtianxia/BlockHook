//
//  ViewController.m
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/26.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import "BlockHook.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSObject *z = NSObject.new;
    int (^block)(int, int) = ^(int x, int y) {
        int result = x + y;
        NSLog(@"I'm here! result: %d, z is a NSObject: %p", result, z);
        return result;
    };
    
    
    BHToken *tokenInstead = [block block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token, int x, int y){
        // change the block imp and result
        *(int *)(token.retValue) = x * y;
        NSLog(@"hook instead");
    }];

    BHToken *tokenAfter = [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHToken *token, int x, int y){
        // print args and result
        NSLog(@"hook after block! x:%d y:%d ret:%d", x, y, *(int *)(token.retValue));
    }];

    BHToken *tokenBefore = [block block_hookWithMode:BlockHookModeBefore usingBlock:^(id token){
        // BHToken has to be the first arg.
        NSLog(@"hook before block! token:%@", token);
    }];
    
    BHToken *tokenDead = [block block_hookWithMode:BlockHookModeDead usingBlock:^(id token){
        // BHToken is the only arg.
        NSLog(@"block dead! token:%@", token);
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"hooked block");
        int ret = block(3, 5);
        NSLog(@"hooked result:%d", ret);
        // remove all tokens when you don't need.
        // reversed order of hook.
        [tokenBefore remove];
        [tokenAfter remove];
        [tokenInstead remove];
        NSLog(@"original block");
        ret = block(3, 5);
        NSLog(@"original result:%d", ret);
//        [tokenDead remove];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
