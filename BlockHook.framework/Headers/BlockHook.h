//
//  BlockHook.h
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/27.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BlockHookMode) {
    BlockHookModeAfter,
    BlockHookModeInstead,
    BlockHookModeBefore,
    BlockHookModeDead,
};

@class BHToken;
typedef void(^BHDeadBlock)(BHToken * _Nullable token);

NS_ASSUME_NONNULL_BEGIN

@interface BHToken : NSObject

@property (nonatomic) BlockHookMode mode;
/**
 Arguments of invoking the block. Need type casting.
 */
@property (nonatomic) void *_Nullable *_Null_unspecified args;
/**
 Return value of invoking the block. Need type casting.
 */
@property (nonatomic, nullable) void *retValue;
/**
 Mangle name of the invoke function.
 */
@property (nonatomic, nullable, readonly) NSString *mangleName;

/**
 Remove token will revert the hook.

 @return remove successfully
 */
- (BOOL)remove;

/**
 Invoke original implementation of the block.
 */
- (void)invokeOriginalBlock;

@end

@interface NSObject (BlockHook)

- (nullable BHToken *)block_hookWithMode:(BlockHookMode)mode
                     usingBlock:(id)block;
- (BOOL)block_removeHook:(BHToken *)token;

@end

NS_ASSUME_NONNULL_END
