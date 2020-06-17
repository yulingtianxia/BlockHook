//
//  BHHelper.h
//  BlockHook
//
//  Created by 杨萧玉 on 2020/6/17.
//  Copyright © 2020 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BHToken+Private.h"
#import <ffi.h>

#ifdef __cplusplus
#define BH_EXTERN        extern "C" __attribute__((visibility("default"))) __attribute((used))
#else
#define BH_EXTERN            extern __attribute__((visibility("default"))) __attribute((used))
#endif

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Block Layout

enum {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30),
};

typedef void(*BHBlockCopyFunction)(void *, const void *);
typedef void(*BHBlockDisposeFunction)(const void *);
typedef void(*BHBlockInvokeFunction)(void *, ...);

struct _BHBlockDescriptor1 {
    uintptr_t reserved;
    uintptr_t size;
};

struct _BHBlockDescriptor2 {
    // requires BLOCK_HAS_COPY_DISPOSE
    BHBlockCopyFunction copy;
    BHBlockDisposeFunction dispose;
};

struct _BHBlockDescriptor3 {
    // requires BLOCK_HAS_SIGNATURE
    const char *signature;
    const char *layout;     // contents depend on BLOCK_HAS_EXTENDED_LAYOUT
};

struct _BHBlock {
    void *isa;
    volatile int32_t flags; // contains ref count
    int32_t reserved;
    BHBlockInvokeFunction invoke;
    struct _BHBlockDescriptor1 *descriptor;
};

OS_OBJECT_DECL_CLASS(voucher);

struct dispatch_block_private_data_s {
    unsigned long dbpd_magic;
    dispatch_block_flags_t dbpd_flags;
    unsigned int volatile dbpd_atomic_flags;
    int volatile dbpd_performed;
    unsigned long dbpd_priority;
    voucher_t dbpd_voucher;
    dispatch_block_t dbpd_block;
    dispatch_group_t dbpd_group;
    dispatch_queue_t dbpd_queue;
    mach_port_t dbpd_thread;
};

typedef struct dispatch_block_private_data_s *dispatch_block_private_data_t;

BH_EXTERN bool BlockHookModeContainsMode(BlockHookMode m1, BlockHookMode m2);
BH_EXTERN __unused struct _BHBlockDescriptor1 * _bh_Block_descriptor_1(struct _BHBlock *aBlock);
BH_EXTERN __unused struct _BHBlockDescriptor2 *_Nullable _bh_Block_descriptor_2(struct _BHBlock *aBlock);
BH_EXTERN struct _BHBlockDescriptor3 *_Nullable _bh_Block_descriptor_3(struct _BHBlock *aBlock);

BH_EXTERN dispatch_block_private_data_t _Nullable bh_dispatch_block_get_private_data(struct _BHBlock *block);

BH_EXTERN const char *BHSizeAndAlignment(const char *str, NSUInteger *_Nullable sizep, NSUInteger *_Nullable alignp, long *_Nullable lenp);
BH_EXTERN int BHTypeCount(const char *str);
BH_EXTERN const char *BHBlockTypeEncodeString(id blockObj);
BH_EXTERN BOOL ReplaceBlockInvoke(struct _BHBlock *block, void *replacement);
BH_EXTERN void BHFFIClosureFunc(ffi_cif *cif, void *ret, void *_Nullable *_Null_unspecified args, void *userdata);

NS_ASSUME_NONNULL_END
