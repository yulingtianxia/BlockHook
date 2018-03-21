//
//  BlockHook.h
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/27.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ffi.h>

typedef NS_ENUM(NSUInteger, BlockHookMode) {
    BlockHookModeAfter,
    BlockHookModeInstead,
    BlockHookModeBefore,
};

@class BHToken;
typedef void(^BHDeadBlock)(BHToken * _Nullable token);

NS_ASSUME_NONNULL_BEGIN

@interface BHToken : NSObject

@property (nonatomic) BlockHookMode mode;
@property (nonatomic, nullable) void *retValue;

- (BOOL)remove;

- (void)setBlockDeadCallback:(BHDeadBlock)deadBlock;

@end

@interface NSObject (BlockHook)

- (nullable BHToken *)block_hookWithMode:(BlockHookMode)mode
                     usingBlock:(id)block;
- (BOOL)block_removeHook:(BHToken *)token;

@end

NS_ASSUME_NONNULL_END
