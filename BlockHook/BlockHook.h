//
//  BlockHook.h
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/27.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, BlockHookMode) {
    BlockHookModeBefore = 1 << 0,
    BlockHookModeInstead = 1 << 1,
    BlockHookModeAfter = 1 << 2,
    BlockHookModeDead = 1 << 3,
};

@class BHToken;

NS_ASSUME_NONNULL_BEGIN

@interface BHInvocation : NSObject

/**
 Token for hook.
 */
@property (nonatomic, readonly, assign) BHToken *token;
/**
 Arguments of invoking the block. Need type casting.
 */
@property (nonatomic, readonly) void *_Nullable *_Null_unspecified args;
/**
 Return value of invoking the block. Need type casting.
 */
@property (nonatomic, nullable, readonly) void *retValue;
/**
 Mode you want to insert your custom logic: Before, Instead, After OR Dead.
 This is NOT a bit mask. Just check equality.
 */
@property (nonatomic, readonly) BlockHookMode mode;

/**
 Invoke original implementation of the block.
 */
- (void)invokeOriginalBlock;

/**
 Retain arguments and set return value to nil or zero.
 */
- (void)retainArguments;

@end

@interface BHToken : NSObject

/**
 Mode you want to insert your custom logic: Before, Instead, After AND Dead.
 This is NS_OPTIONS, so you can use bitmask.
 */
@property (nonatomic, readonly) BlockHookMode mode;

/**
 Block be hooked.
 */
@property (nonatomic, weak, readonly) id block;

/**
 Next token in hook list.
 */
@property (nonatomic, nullable, readonly) BHToken *next;

/**
 Mangle name of the invoke function.
 */
@property (nonatomic, nullable, readonly) NSString *mangleName;

/**
 Aspect Block.
 */
@property (nonatomic, readonly) id aspectBlock;

/**
 A dictionary containing user-defined information relating to the token.
 */
@property (nonatomic, readonly) NSMutableDictionary *userInfo;

/**
 Remove token will revert the hook.

 @return If it is successful.
 */
- (BOOL)remove;

@end

/**
 BlockHook Category.
 Method receiver must be a block.
 */
@interface NSObject (BlockHook)

/**
 Hook this block.

 @param mode BlockHookMode
 @param aspectBlock Implement your custom logic here. Argument list: BHInvocation comes in first, followed by other arguments when block invoking.
 @return Token for hook.
 */
- (nullable BHToken *)block_hookWithMode:(BlockHookMode)mode
                              usingBlock:(id)aspectBlock;

/**
 Remove all hook.
 */
- (void)block_removeAllHook;

/**
 Block may be hooked more than once. The current token represents the last time.

 @return BHToken instance.
 */
- (nullable BHToken *)block_currentHookToken;

/**
 Current invoke function of block.

 @return Pointer to invoke function.
 */
- (void *)block_currentInvokeFunction;

typedef void(^IntercepterCompletion)(void);
- (void)interceptBlock:(void (^)(BHInvocation *invocation, IntercepterCompletion completion))block;

@end

NS_ASSUME_NONNULL_END
