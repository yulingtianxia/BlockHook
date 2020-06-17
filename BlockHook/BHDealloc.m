//
//  BHDealloc.m
//  BlockHook
//
//  Created by 杨萧玉 on 2020/6/17.
//  Copyright © 2020 杨萧玉. All rights reserved.
//

#import "BHDealloc.h"
#import "BHHelper.h"
#import "BHToken+Private.h"
#import "BHInvocation+Private.h"

@implementation BHDealloc

- (void)dealloc {
    if (BlockHookModeContainsMode(self.token.mode, BlockHookModeDead)) {
        BHInvocation *invocation = nil;
        NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:self.token.aspectBlockSignature];
        if (self.token.aspectBlockSignature.numberOfArguments >= 2) {
            invocation = [[BHInvocation alloc] initWithToken:self.token];
            invocation.mode = BlockHookModeDead;
            [blockInvocation setArgument:(void *)&invocation atIndex:1];
        }
        [blockInvocation invokeWithTarget:self.token.aspectBlock];
    }
    [self.token remove];
}

@end
