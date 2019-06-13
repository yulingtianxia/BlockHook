//
//  BlockHook.m
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/27.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//  Thanks to MABlockClosure : https://github.com/mikeash/MABlockClosure

#import "BlockHook.h"
#import <ffi.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <os/lock.h>

#if !__has_feature(objc_arc)
#error
#endif

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

struct _BHBlockDescriptor1
{
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

struct _BHBlock
{
    void *isa;
    volatile int32_t flags; // contains ref count
    int32_t reserved;
    BHBlockInvokeFunction invoke;
    struct _BHBlockDescriptor1 *descriptor;
};

#pragma mark - Helper Function

__unused static struct _BHBlockDescriptor1 * _bh_Block_descriptor_1(struct _BHBlock *aBlock)
{
    return aBlock->descriptor;
}

__unused static struct _BHBlockDescriptor2 * _bh_Block_descriptor_2(struct _BHBlock *aBlock)
{
    if (! (aBlock->flags & BLOCK_HAS_COPY_DISPOSE)) return nil;
    uint8_t *desc = (uint8_t *)aBlock->descriptor;
    desc += sizeof(struct _BHBlockDescriptor1);
    return (struct _BHBlockDescriptor2 *)desc;
}

static struct _BHBlockDescriptor3 * _bh_Block_descriptor_3(struct _BHBlock *aBlock)
{
    if (! (aBlock->flags & BLOCK_HAS_SIGNATURE)) return nil;
    uint8_t *desc = (uint8_t *)aBlock->descriptor;
    desc += sizeof(struct _BHBlockDescriptor1);
    if (aBlock->flags & BLOCK_HAS_COPY_DISPOSE) {
        desc += sizeof(struct _BHBlockDescriptor2);
    }
    return (struct _BHBlockDescriptor3 *)desc;
}

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

#define DISPATCH_BLOCK_PRIVATE_DATA_MAGIC 0xD159B10C // 0xDISPatch_BLOCk

DISPATCH_ALWAYS_INLINE
static inline bool
bh_dispatch_block_has_private_data(struct _BHBlock *block)
{
    Dl_info dlinfo;
    memset(&dlinfo, 0, sizeof(dlinfo));
    if (dladdr(block->invoke, &dlinfo) && dlinfo.dli_sname)
    {
#ifdef __linux__
        char *functionName = "__dispatch_block_create_block_invoke";
#else
        char *functionName = "___dispatch_block_create_block_invoke";
#endif
        if (strcmp(functionName, dlinfo.dli_sname) == 0) {
            return true;
        }
    }
    return false;
}

DISPATCH_ALWAYS_INLINE
static inline dispatch_block_private_data_t
bh_dispatch_block_get_private_data(struct _BHBlock *block)
{
    if (!bh_dispatch_block_has_private_data(block)) {
        return nil;
    }
    // Keep in sync with _dispatch_block_create implementation
    uint8_t *x = (uint8_t *)block;
    // x points to base of struct Block_layout
    x += sizeof(struct _BHBlock);
    // x points to base of captured dispatch_block_private_data_s object
    dispatch_block_private_data_t dbpd = (dispatch_block_private_data_t)x;
    if (dbpd->dbpd_magic != DISPATCH_BLOCK_PRIVATE_DATA_MAGIC) {
        return nil;
    }
    return dbpd;
}

static const char *BHSizeAndAlignment(const char *str, NSUInteger *sizep, NSUInteger *alignp, long *lenp)
{
    const char *out = NSGetSizeAndAlignment(str, sizep, alignp);
    if (lenp) {
        *lenp = out - str;
    }
    while(*out == '}') {
        out++;
    }
    while(isdigit(*out)) {
        out++;
    }
    return out;
}

static int BHTypeCount(const char *str)
{
    int typeCount = 0;
    while(str && *str)
    {
        str = BHSizeAndAlignment(str, NULL, NULL, NULL);
        typeCount++;
    }
    return typeCount;
}

static const char *BHBlockTypeEncodeString(id blockObj)
{
    struct _BHBlock *block = (__bridge void *)blockObj;
    return _bh_Block_descriptor_3(block)->signature;
}

static void BHFFIClosureFunc(ffi_cif *cif, void *ret, void **args, void *userdata);

@interface BHLock : NSObject<NSLocking>

@property (nonatomic) dispatch_semaphore_t semaphore;

@end

@implementation BHLock

- (instancetype)init
{
    self = [super init];
    if (self) {
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)lock
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock
{
    dispatch_semaphore_signal(self.semaphore);
}

@end

@interface NSObject (BHLock)

- (BHLock *)bh_lockForKey:(const void * _Nonnull)key;

@end

@implementation NSObject (BHLock)

- (BHLock *)bh_lockForKey:(const void * _Nonnull)key
{
    BHLock *lock = objc_getAssociatedObject(self, key);
    if (!lock) {
        lock = [BHLock new];
        objc_setAssociatedObject(self, key, lock, OBJC_ASSOCIATION_RETAIN);
    }
    return lock;
}

@end

@interface BHToken ()
{
    ffi_cif _cif;
    void *_replacementInvoke;
    ffi_closure *_closure;
}
@property (nonatomic, readwrite) BlockHookMode mode;
@property (nonatomic) NSMutableArray *allocations;
@property (nonatomic, weak, readwrite) id block;
@property (nonatomic, readwrite) id aspectBlock;
@property (nonatomic, nullable, readwrite) NSString *mangleName;
@property (nonatomic) NSMethodSignature *originalBlockSignature;
@property (nonatomic) NSMethodSignature *aspectBlockSignature;
@property (atomic) void *originInvoke;
@property (nonatomic, readwrite) NSMutableDictionary *userInfo;

/**
 if block is kind of `__NSStackBlock__` class.
 */
@property (nonatomic, getter=isStackBlock) BOOL stackBlock;
@property (nonatomic, getter=hasStret) BOOL stret;
@property (nonatomic, nullable, readwrite) BHToken *next;

- (void)invokeOriginalBlockWithArgs:(void **)args retValue:(void *)retValue;

@end

@interface BHInvocation ()

@property (nonatomic, readwrite) BHToken *token;
@property (nonatomic, readwrite) void *_Nullable *_Null_unspecified args;
@property (nonatomic, nullable, readwrite) void *retValue;

@end
@implementation BHInvocation

- (void)invokeOriginalBlock
{
    [self.token invokeOriginalBlockWithArgs:self.args retValue:self.retValue];
}

@end

@implementation BHToken

@synthesize next = _next;

- (instancetype)initWithBlock:(id)block mode:(BlockHookMode)mode aspectBlockBlock:(id)aspectBlock
{
    self = [super init];
    if (self) {
        _allocations = [[NSMutableArray alloc] init];
        _block = block;
        const char *encode = BHBlockTypeEncodeString(block);
        // Check block encoding types valid.
        NSUInteger numberOfArguments = [self _prepCIF:&_cif withEncodeString:encode];
        if (numberOfArguments == -1) { // Unknown encode.
            return nil;
        }
        // Check aspectBlock valid.
        _aspectBlockSignature = [NSMethodSignature signatureWithObjCTypes:BHBlockTypeEncodeString(aspectBlock)];
        
        // origin block invoke func arguments: block(self), ...
        // origin block invoke func arguments (x86 struct return): struct*, block(self), ...
        // hook block signature arguments: block(self), invocation, ...
        if ((mode == BlockHookModeDead && _aspectBlockSignature.numberOfArguments > 2)
            || _aspectBlockSignature.numberOfArguments > numberOfArguments + 1) {
            NSLog(@"Block has too many arguments. Not calling %@", self);
            return nil;
        }
        _userInfo = [NSMutableDictionary dictionary];
        _originalBlockSignature = [NSMethodSignature signatureWithObjCTypes:encode];
        _closure = ffi_closure_alloc(sizeof(ffi_closure), &_replacementInvoke);
        
        // __NSStackBlock__ -> __NSStackBlock -> NSBlock
        if ([block isKindOfClass:NSClassFromString(@"__NSStackBlock")]) {
            NSLog(@"Hooking StackBlock causes a memory leak! I suggest you copy it first!");
            self.stackBlock = YES;
        }

        [self _prepClosure];
        objc_setAssociatedObject(block, _replacementInvoke, self, OBJC_ASSOCIATION_RETAIN);
        _mode = mode;
        _aspectBlock = aspectBlock;
    }
    return self;
}

- (void)dealloc
{
    if (BlockHookModeDead == self.mode) {
        BHInvocation *invocation = nil;
        NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:self.aspectBlockSignature];
        if (self.aspectBlockSignature.numberOfArguments == 2) {
            invocation = [BHInvocation new];
            invocation.token = self;
            [blockInvocation setArgument:(void *)&invocation atIndex:1];
        }
        [blockInvocation invokeWithTarget:self.aspectBlock];
    }
    [self remove];
    if (_closure) {
        ffi_closure_free(_closure);
        _closure = NULL;
    }
}

- (BHToken *)next
{
    BHLock *lock = [self.block bh_lockForKey:@selector(next)];
    [lock lock];
    if (!_next) {
        _next = objc_getAssociatedObject(self.block, self.originInvoke);
    }
    BHToken *result = _next;
    [lock unlock];
    return result;
}

- (void)setNext:(BHToken *)next
{
    BHLock *lock = [self.block bh_lockForKey:@selector(next)];
    [lock lock];
    _next = next;
    [lock unlock];
}

- (BOOL)remove
{
    if (self.isStackBlock) {
        NSLog(@"Can't remove token for StackBlock!");
        return NO;
    }
    if (self.originInvoke) {
        if (self.block) {
            BHToken *current = [self.block block_currentHookToken];
            BHToken *last = nil;
            while (current) {
                if (current == self) {
                    if (last) { // remove middle token
                        last.originInvoke = self.originInvoke;
                        last.next = nil;
                    }
                    else { // remove head(current) token
                        BHLock *lock = [self.block bh_lockForKey:@selector(block_currentInvokeFunction)];
                        [lock lock];
                        ((__bridge struct _BHBlock *)self.block)->invoke = self.originInvoke;
                        [lock unlock];
                    }
                    break;
                }
                last = current;
                current = [current next];
            }
        }
        self.originInvoke = NULL;
        objc_setAssociatedObject(self.block, _replacementInvoke, nil, OBJC_ASSOCIATION_RETAIN);
        return YES;
    }
    return NO;
}

- (NSString *)mangleName
{
    if (!_mangleName) {
        NSString *mangleName = self.next.mangleName;
        if (mangleName.length > 0) {
            _mangleName = mangleName;
        }
        else {
            Dl_info dlinfo;
            memset(&dlinfo, 0, sizeof(dlinfo));
            if (dladdr(self.originInvoke, &dlinfo) && dlinfo.dli_sname)
            {
                _mangleName = [NSString stringWithUTF8String:dlinfo.dli_sname];
            }
        }
    }
    return _mangleName;
}

- (void)invokeOriginalBlockWithArgs:(void **)args retValue:(void *)retValue
{
    if (self.originInvoke) {
        ffi_call(&_cif, self.originInvoke, retValue, args);
    }
    else {
        NSLog(@"You had lost your originInvoke! Please check the order of removing tokens!");
    }
}

#pragma mark - Private Method

- (void *)_allocate:(size_t)howmuch
{
    NSMutableData *data = [NSMutableData dataWithLength:howmuch];
    [_allocations addObject: data];
    return [data mutableBytes];
}

- (ffi_type *)_ffiTypeForStructEncode:(const char *)str
{
    NSUInteger size, align;
    long length;
    BHSizeAndAlignment(str, &size, &align, &length);
    ffi_type *structType = [self _allocate:size];
    structType->type = FFI_TYPE_STRUCT;
    structType->size = size;
    structType->alignment = align;
    
    const char *temp = [[[NSString stringWithUTF8String:str] substringWithRange:NSMakeRange(0, length)] UTF8String];
    
    // cut "struct="
    while (temp && *temp && *temp != '=') {
        temp++;
    }
    ffi_type **elements = [self _typesWithEncodeString:temp + 1];
    if (!elements) {
        return nil;
    }
    structType->elements = elements;
    
    return structType;
}

- (ffi_type *)_ffiTypeForEncode:(const char *)str
{
    #define SINT(type) do { \
        if(str[0] == @encode(type)[0]) \
        { \
            if(sizeof(type) == 1) \
                return &ffi_type_sint8; \
            else if(sizeof(type) == 2) \
                return &ffi_type_sint16; \
            else if(sizeof(type) == 4) \
                return &ffi_type_sint32; \
            else if(sizeof(type) == 8) \
                return &ffi_type_sint64; \
            else \
            { \
                NSLog(@"Unknown size for type %s", #type); \
                abort(); \
            } \
        } \
    } while(0)
    
    #define UINT(type) do { \
        if(str[0] == @encode(type)[0]) \
        { \
            if(sizeof(type) == 1) \
                return &ffi_type_uint8; \
            else if(sizeof(type) == 2) \
                return &ffi_type_uint16; \
            else if(sizeof(type) == 4) \
                return &ffi_type_uint32; \
            else if(sizeof(type) == 8) \
                return &ffi_type_uint64; \
            else \
            { \
                NSLog(@"Unknown size for type %s", #type); \
                abort(); \
            } \
        } \
    } while(0)
    
    #define INT(type) do { \
        SINT(type); \
        UINT(unsigned type); \
    } while(0)
    
    #define COND(type, name) do { \
        if(str[0] == @encode(type)[0]) \
        return &ffi_type_ ## name; \
    } while(0)
    
    #define PTR(type) COND(type, pointer)
    
    SINT(_Bool);
    SINT(signed char);
    UINT(unsigned char);
    INT(short);
    INT(int);
    INT(long);
    INT(long long);
    
    PTR(id);
    PTR(Class);
    PTR(SEL);
    PTR(void *);
    PTR(char *);
    
    COND(float, float);
    COND(double, double);
    
    COND(void, void);
    
    // Ignore Method Encodings
    switch (*str) {
        case 'r':
        case 'R':
        case 'n':
        case 'N':
        case 'o':
        case 'O':
        case 'V':
            return [self _ffiTypeForEncode:str + 1];
    }
    
    // Struct Type Encodings
    if (*str == '{') {
        ffi_type *structType = [self _ffiTypeForStructEncode:str];
        return structType;
    }
    
    NSLog(@"Unknown encode string %s", str);
    return nil;
}

- (ffi_type **)_argsWithEncodeString:(const char *)str getCount:(int *)outCount
{
    // 第一个是返回值，需要排除
    return [self _typesWithEncodeString:str getCount:outCount startIndex:1];
}

- (ffi_type **)_typesWithEncodeString:(const char *)str
{
    return [self _typesWithEncodeString:str getCount:NULL startIndex:0];
}

- (ffi_type **)_typesWithEncodeString:(const char *)str getCount:(int *)outCount startIndex:(int)start
{
    int argCount = BHTypeCount(str) - start;
    ffi_type **argTypes = [self _allocate:argCount * sizeof(*argTypes)];
    
    int i = -start;
    while(str && *str)
    {
        const char *next = BHSizeAndAlignment(str, NULL, NULL, NULL);
        if (i >= 0 && i < argCount) {
            ffi_type *argType = [self _ffiTypeForEncode:str];
            if (argType) {
                argTypes[i] = argType;
            }
            else {
                if (outCount) {
                    *outCount = -1;
                }
                return nil;
            }
        }
        i++;
        str = next;
    }
    
    if (outCount) {
        *outCount = argCount;
    }
    
    return argTypes;
}

- (int)_prepCIF:(ffi_cif *)cif withEncodeString:(const char *)str
{
    int argCount;
    ffi_type **argTypes;
    ffi_type *returnType;
    struct _BHBlock *bh_block = (__bridge void *)self.block;
    if ((bh_block->flags & BLOCK_HAS_STRET)) {
        argTypes = [self _typesWithEncodeString:str getCount:&argCount startIndex:0];
        if (!argTypes) { // Error!
            return -1;
        }
        argTypes[0] = &ffi_type_pointer;
        returnType = &ffi_type_void;
        self.stret = YES;
    }
    else {
        argTypes = [self _argsWithEncodeString:str getCount:&argCount];
        if (!argTypes) { // Error!
            return -1;
        }
        returnType = [self _ffiTypeForEncode:str];
    }
    if (!returnType) { // Error!
        return -1;
    }
    ffi_status status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, argCount, returnType, argTypes);
    if (status != FFI_OK) {
        NSLog(@"Got result %ld from ffi_prep_cif", (long)status);
        abort();
    }
    return argCount;
}

- (void)_prepClosure
{
    ffi_status status = ffi_prep_closure_loc(_closure, &_cif, BHFFIClosureFunc, (__bridge void *)(self), _replacementInvoke);
    if (status != FFI_OK) {
        NSLog(@"ffi_prep_closure returned %d", (int)status);
        abort();
    }
    // exchange invoke func imp
    struct _BHBlock *block = (__bridge struct _BHBlock *)self.block;
    BHLock *lock = [self.block bh_lockForKey:@selector(block_currentInvokeFunction)];
    [lock lock];
    self.originInvoke = block->invoke;
    block->invoke = _replacementInvoke;
    [lock unlock];
}

- (BOOL)invokeAspectBlockWithArgs:(void **)args retValue:(void *)retValue
{
    if (!self.isStackBlock && !self.block) {
        return NO;
    }
    
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:self.aspectBlockSignature];
    BHInvocation *invocation = nil;
    if (self.aspectBlockSignature.numberOfArguments > 1) {
        invocation = [BHInvocation new];
        invocation.args = args;
        invocation.retValue = retValue;
        invocation.token = self;
        [blockInvocation setArgument:(void *)&invocation atIndex:1];
    }
    
    void *argBuf = NULL;
    for (NSUInteger idx = 2; idx < self.aspectBlockSignature.numberOfArguments; idx++) {
        const char *type = [self.originalBlockSignature getArgumentTypeAtIndex:idx - 1];
        NSUInteger argSize;
        NSGetSizeAndAlignment(type, &argSize, NULL);
        
        if (!(argBuf = reallocf(argBuf, argSize))) {
            NSLog(@"Failed to allocate memory for block invocation.");
            return NO;
        }
        memcpy(argBuf, args[idx - 1], argSize);
        [blockInvocation setArgument:argBuf atIndex:idx];
    }
    
    [blockInvocation invokeWithTarget:self.aspectBlock];
    
    if (argBuf != NULL) {
        free(argBuf);
    }
    return YES;
}

@end

@implementation NSObject (BlockHook)

- (BOOL)block_checkValid
{
    BOOL valid = [self isKindOfClass:NSClassFromString(@"NSBlock")];
    if (!valid) {
        NSLog(@"Not Block! %@", self);
    }
    return valid;
}

- (BHToken *)block_hookWithMode:(BlockHookMode)mode
                     usingBlock:(id)aspectBlock
{
    if (!aspectBlock || ![self block_checkValid]) {
        return nil;
    }
    struct _BHBlock *bh_block = (__bridge void *)self;
    if (!_bh_Block_descriptor_3(bh_block)) {
        NSLog(@"Block has no signature! Required ABI.2010.3.16. %@", self);
        return nil;
    }
    // Handle blocks have private data.
    dispatch_block_private_data_t dbpd = bh_dispatch_block_get_private_data(bh_block);
    if (dbpd && dbpd->dbpd_block) {
        return [dbpd->dbpd_block block_hookWithMode:mode usingBlock:aspectBlock];
    }
    return [[BHToken alloc] initWithBlock:self mode:mode aspectBlockBlock:aspectBlock];
}

- (void)block_removeAllHook
{
    if (![self block_checkValid]) {
        return;
    }
    BHToken *token = nil;
    while ((token = [self block_currentHookToken])) {
        [token remove];
    }
}

- (BHToken *)block_currentHookToken
{
    if (![self block_checkValid]) {
        return nil;
    }
    dispatch_block_private_data_t dbpd = bh_dispatch_block_get_private_data((__bridge struct _BHBlock *)(self));
    if (dbpd && dbpd->dbpd_block) {
        return [dbpd->dbpd_block block_currentHookToken];
    }
    void *invoke = [self block_currentInvokeFunction];
    return objc_getAssociatedObject(self, invoke);
}

- (void *)block_currentInvokeFunction
{
    struct _BHBlock *bh_block = (__bridge void *)self;
    BHLock *lock = [self bh_lockForKey:_cmd];
    [lock lock];
    void *invoke = bh_block->invoke;
    [lock unlock];
    return invoke;
}

@end

#pragma mark - Hook Function

static void BHFFIClosureFunc(ffi_cif *cif, void *ret, void **args, void *userdata)
{
    BHToken *token = (__bridge BHToken *)(userdata);
    void *userRet = ret;
    void **userArgs = args;
    if (token.hasStret) {
        // The first arg contains address of a pointer of returned struct.
        userRet = *((void **)args[0]);
        // Other args move backwards.
        userArgs = args + 1;
    }
    if (BlockHookModeBefore == token.mode) {
        [token invokeAspectBlockWithArgs:userArgs retValue:userRet];
    }
    if (!(BlockHookModeInstead == token.mode && [token invokeAspectBlockWithArgs:userArgs retValue:userRet])) {
        [token invokeOriginalBlockWithArgs:args retValue:ret];
    }
    if (BlockHookModeAfter == token.mode) {
        [token invokeAspectBlockWithArgs:userArgs retValue:userRet];
    }
}
