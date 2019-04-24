//
//  ViewController.m
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/26.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import "ViewController.h"
#import <BlockHook/BlockHook.h>

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

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    struct Block_layout (^testblock3)(void) = ^()
    {
        NSLog(@"This is a Global block for stret");
        
        return (struct Block_layout){0,1,2,0,0};
    };
    [testblock3 block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token){
        [token invokeOriginalBlock];
        struct Block_layout lala = **(struct Block_layout **)(token.args[0]);
        NSLog(@"lala flag:%d", lala.reserved);
    }];
    struct Block_layout result = testblock3();
    result.flags;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
