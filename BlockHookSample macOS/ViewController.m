//
//  ViewController.m
//  BlockHookSampleMac
//
//  Created by 杨萧玉 on 2019/4/14.
//  Copyright © 2019 杨萧玉. All rights reserved.
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
    struct Block_layout (^testblock3)(int) = ^(int a)
    {
        NSLog(@"This is a Global block for stret");
        return (struct Block_layout){0,1,2,0,0};
    };
    [testblock3 block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token, int a){
        [token invokeOriginalBlock];
        struct Block_layout lala = **(struct Block_layout **)(token.retValue);
        NSLog(@"lala flag:%d", lala.reserved);
        NSLog(@"arg a:%d", a);
    }];
    struct Block_layout result = testblock3(100);
    result.flags;
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
