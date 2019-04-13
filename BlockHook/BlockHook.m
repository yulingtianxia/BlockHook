//
//  BlockHook.m
//  BlockHookSample
//
//  Created by 杨萧玉 on 2018/2/27.
//  Copyright © 2018年 杨萧玉. All rights reserved.
//  Thanks to MABlockClosure : https://github.com/mikeash/MABlockClosure

#import "BlockHook.h"
#import <ffi.h>
#import <assert.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/nlist.h>
#import <pthread.h>

#if TARGET_OS_IPHONE
#import <CoreGraphics/CoreGraphics.h>
#endif

#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct nlist_64 nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct nlist nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

enum {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30),
};

struct _BHBlockDescriptor
{
    unsigned long reserved;
    unsigned long size;
    void *rest[1];
};

struct _BHBlock
{
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    struct _BHBlockDescriptor *descriptor;
};

static NSMapTable *block_invoke_mangle_cache;
static pthread_mutex_t block_invoke_mangle_cache_mutex;

static void _hunt_blocks_for_image(const struct mach_header *header, intptr_t slide) {
    Dl_info info;
    if (dladdr(header, &info) == 0) {
        return;
    }
    segment_command_t *cur_seg_cmd;
    segment_command_t *linkedit_segment = NULL;
    segment_command_t *pagezero_segment = NULL;
    struct symtab_command* symtab_cmd = NULL;
    
    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_LINKEDIT) == 0) {
                linkedit_segment = cur_seg_cmd;
            }
            else if (strcmp(SEG_PAGEZERO, cur_seg_cmd->segname) == 0) {
                pagezero_segment = (segment_command_t*)cur_seg_cmd;
            }
        } else if (cur_seg_cmd->cmd == LC_SYMTAB) {
            symtab_cmd = (struct symtab_command*)cur_seg_cmd;
        }
    }
    
    if (!symtab_cmd || !linkedit_segment ) {
        return;
    }
    
    uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
    
    pthread_mutex_lock(&block_invoke_mangle_cache_mutex);
    
    if (!block_invoke_mangle_cache) {
        block_invoke_mangle_cache = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality valueOptions:NSPointerFunctionsCopyIn];
    }
    
    for (uint i = 0; i < symtab_cmd->nsyms; i++) {
        uint32_t strtab_offset = symtab[i].n_un.n_strx;
        char *symbol_name = strtab + strtab_offset;
        bool symbol_name_longer_than_1 = symbol_name[0] && symbol_name[1];
        if (!symbol_name_longer_than_1) {
            continue;
        }
        uintptr_t block_addr = (uintptr_t)info.dli_fbase + symtab[i].n_value - (pagezero_segment ? pagezero_segment->vmsize : 0);
        NSString *symbolName = [NSString stringWithUTF8String:&symbol_name[1]];
        NSRange range = [symbolName rangeOfString:@"_block_invoke"];
        if (range.location != NSNotFound && range.location > 0) {
            [block_invoke_mangle_cache setObject:symbolName forKey:(__bridge id)(void *)block_addr];
        }
    }
    
    pthread_mutex_unlock(&block_invoke_mangle_cache_mutex);
}

@interface BHDealloc : NSObject

@property (nonatomic, strong) BHToken *token;
@property (nonatomic, nullable) BHDeadBlock deadBlock;

@end

@implementation BHDealloc

- (void)dealloc
{
    if (self.deadBlock) {
        self.deadBlock(self.token);
    }
}

@end

@interface BHToken ()
{
    ffi_cif _cif;
    void *_originInvoke;
    void *_replacementInvoke;
    ffi_closure *_closure;
}
@property (nonatomic) NSMutableArray *allocations;
@property (nonatomic, weak) id block;
@property (nonatomic) NSUInteger numberOfArguments;
@property (nonatomic) id hookBlock;
@property (nonatomic, nullable, readwrite) NSString *mangleName;
@property (nonatomic) NSMethodSignature *originalBlockSignature;
/**
 if block is kind of `__NSStackBlock__` class.
 */
@property (nonatomic, getter=isStackBlock) BOOL stackBlock;

- (id)initWithBlock:(id)block;

@end

@implementation BHToken

- (id)initWithBlock:(id)block
{
    if((self = [self init]))
    {
        _allocations = [[NSMutableArray alloc] init];
        _block = block;
        _originalBlockSignature = [NSMethodSignature signatureWithObjCTypes:BHBlockTypeEncodeString(block)];
        _closure = ffi_closure_alloc(sizeof(ffi_closure), &_replacementInvoke);
        _numberOfArguments = [self _prepCIF:&_cif withEncodeString:BHBlockTypeEncodeString(_block)];
        BHDealloc *bhDealloc = [BHDealloc new];
        bhDealloc.token = self;
        objc_setAssociatedObject(block, NSSelectorFromString([NSString stringWithFormat:@"%p", self]), bhDealloc, OBJC_ASSOCIATION_RETAIN);
        [self _prepClosure];
    }
    return self;
}

- (void)dealloc
{
    [self remove];
    if(_closure) {
        ffi_closure_free(_closure);
        _closure = NULL;
    }
}

+ (void)load
{
    pthread_mutex_init(&block_invoke_mangle_cache_mutex, NULL);
    _dyld_register_func_for_add_image(_hunt_blocks_for_image);
}

- (BOOL)remove
{
    [self setBlockDeadCallback:nil];
    if (_originInvoke) {
        if (self.isStackBlock) {
            NSLog(@"Can't remove token for StackBlock!");
            return NO;
        }
        if (self.block) {
            ((__bridge struct _BHBlock *)self.block)->invoke = _originInvoke;
        }
#if DEBUG
        _originInvoke = NULL;
#endif
        return YES;
    }
    return NO;
}

- (void)setMode:(BlockHookMode)mode
{
    _mode = mode;
    if (BlockHookModeDead == mode) {
        [self setBlockDeadCallback:self.hookBlock];
    }
}

- (void)setHookBlock:(id)hookBlock
{
    _hookBlock = hookBlock;
    if (BlockHookModeDead == self.mode) {
        [self setBlockDeadCallback:hookBlock];
    }
}

- (void)setBlockDeadCallback:(BHDeadBlock)deadBlock
{
    if (self.isStackBlock) {
        NSLog(@"Can't set BlockDeadCallback for StackBlock!");
        return;
    }
    BHDealloc *bhDealloc = objc_getAssociatedObject(self.block, NSSelectorFromString([NSString stringWithFormat:@"%p", self]));
    bhDealloc.deadBlock = deadBlock;
}

- (NSString *)mangleName
{
    if (!_mangleName) {
        pthread_mutex_lock(&block_invoke_mangle_cache_mutex);
        if (_originInvoke) {
            _mangleName = [block_invoke_mangle_cache objectForKey:(__bridge id)_originInvoke];
        }
        pthread_mutex_unlock(&block_invoke_mangle_cache_mutex);
    }
    return _mangleName;
}

- (void)invokeOriginalBlock
{
    if (_originInvoke) {
        ffi_call(&_cif, _originInvoke, self.retValue, self.args);
    }
    else {
        NSLog(@"You had lost your originInvoke! Please check the order of removing tokens!");
    }
}

#pragma mark - Help Function

static const char *BHBlockTypeEncodeString(id blockObj)
{
    struct _BHBlock *block = (__bridge void *)blockObj;
    struct _BHBlockDescriptor *descriptor = block->descriptor;
    
    assert(block->flags & BLOCK_HAS_SIGNATURE);
    
    int index = 0;
    if(block->flags & BLOCK_HAS_COPY_DISPOSE)
        index += 2;
    
    return descriptor->rest[index];
}

static void BHFFIClosureFunc(ffi_cif *cif, void *ret, void **args, void *userdata)
{
    BHToken *token = (__bridge BHToken *)(userdata);
    token.retValue = ret;
    token.args = args;
    if (BlockHookModeBefore == token.mode) {
        [token invokeHookBlockWithArgs:args];
    }
    if (!(BlockHookModeInstead == token.mode && [token invokeHookBlockWithArgs:args])) {
        [token invokeOriginalBlock];
    }
    if (BlockHookModeAfter == token.mode) {
        [token invokeHookBlockWithArgs:args];
    }
    token.retValue = NULL;
    token.args = NULL;
}

static const char *BHSizeAndAlignment(const char *str, NSUInteger *sizep, NSUInteger *alignp, long *len)
{
    const char *out = NSGetSizeAndAlignment(str, sizep, alignp);
    if(len)
        *len = out - str;
    while(isdigit(*out))
        out++;
    return out;
}

static int BHArgCount(const char *str)
{
    int argcount = -1; // return type is the first one
    while(str && *str)
    {
        str = BHSizeAndAlignment(str, NULL, NULL, NULL);
        argcount++;
    }
    return argcount;
}

#pragma mark - Private Method

- (void *)_allocate:(size_t)howmuch
{
    NSMutableData *data = [NSMutableData dataWithLength:howmuch];
    [_allocations addObject: data];
    return [data mutableBytes];
}

- (ffi_type *)_ffiArgForEncode: (const char *)str
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
    
    #define STRUCT(structType, ...) do { \
        if(strncmp(str, @encode(structType), strlen(@encode(structType))) == 0) \
        { \
            ffi_type *elementsLocal[] = { __VA_ARGS__, NULL }; \
            ffi_type **elements = [self _allocate: sizeof(elementsLocal)]; \
            memcpy(elements, elementsLocal, sizeof(elementsLocal)); \
            \
            ffi_type *structType = [self _allocate: sizeof(*structType)]; \
            structType->type = FFI_TYPE_STRUCT; \
            structType->elements = elements; \
            return structType; \
        } \
    } while(0)
    
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
    PTR(void (*)(void));
    
    COND(float, float);
    COND(double, double);
    
    COND(void, void);
    
    ffi_type *CGFloatFFI = sizeof(CGFloat) == sizeof(float) ? &ffi_type_float : &ffi_type_double;
    STRUCT(CGRect, CGFloatFFI, CGFloatFFI, CGFloatFFI, CGFloatFFI);
    STRUCT(CGPoint, CGFloatFFI, CGFloatFFI);
    STRUCT(CGSize, CGFloatFFI, CGFloatFFI);
    
#if !TARGET_OS_IPHONE
    STRUCT(NSRect, CGFloatFFI, CGFloatFFI, CGFloatFFI, CGFloatFFI);
    STRUCT(NSPoint, CGFloatFFI, CGFloatFFI);
    STRUCT(NSSize, CGFloatFFI, CGFloatFFI);
#endif
    
    NSLog(@"Unknown encode string %s", str);
    abort();
}

- (ffi_type **)_argsWithEncodeString:(const char *)str getCount:(int *)outCount
{
    int argCount = BHArgCount(str);
    ffi_type **argTypes = [self _allocate: argCount * sizeof(*argTypes)];
    
    int i = -1; // 第一个是返回值，需要排除
    while(str && *str)
    {
        const char *next = BHSizeAndAlignment(str, NULL, NULL, NULL);
        if(i >= 0)
            argTypes[i] = [self _ffiArgForEncode: str];
        i++;
        str = next;
    }
    
    *outCount = argCount;
    
    return argTypes;
}

- (int)_prepCIF:(ffi_cif *)cif withEncodeString:(const char *)str
{
    int argCount;
    ffi_type **argTypes = [self _argsWithEncodeString:str getCount:&argCount];
    
    ffi_status status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, argCount, [self _ffiArgForEncode: str], argTypes);
    if(status != FFI_OK)
    {
        NSLog(@"Got result %ld from ffi_prep_cif", (long)status);
        abort();
    }
    return argCount;
}

- (void)_prepClosure
{
    ffi_status status = ffi_prep_closure_loc(_closure, &_cif, BHFFIClosureFunc, (__bridge void *)(self), _replacementInvoke);
    if(status != FFI_OK)
    {
        NSLog(@"ffi_prep_closure returned %d", (int)status);
        abort();
    }
    // exchange invoke func imp
    _originInvoke = ((__bridge struct _BHBlock *)self.block)->invoke;
    ((__bridge struct _BHBlock *)self.block)->invoke = _replacementInvoke;
}

- (BOOL)invokeHookBlockWithArgs:(void **)args
{
    if ((!self.isStackBlock && !self.block) || !self.hookBlock) {
        return NO;
    }
    NSMethodSignature *hookBlockSignature = [NSMethodSignature signatureWithObjCTypes:BHBlockTypeEncodeString(self.hookBlock)];
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:hookBlockSignature];
    
    // origin block invoke func arguments: block(self), ...
    // hook block signature arguments: block(self), token, ...
    
    if (hookBlockSignature.numberOfArguments > self.numberOfArguments + 1) {
        NSLog(@"Block has too many arguments. Not calling %@", self);
        return NO;
    }
    
    if (hookBlockSignature.numberOfArguments > 1) {
        [blockInvocation setArgument:(void *)&self atIndex:1];
    }

    void *argBuf = NULL;
    for (NSUInteger idx = 2; idx < hookBlockSignature.numberOfArguments; idx++) {
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
    
    [blockInvocation invokeWithTarget:self.hookBlock];
    
    if (argBuf != NULL) {
        free(argBuf);
    }
    return YES;
}

@end

@implementation NSObject (BlockHook)

- (BHToken *)block_hookWithMode:(BlockHookMode)mode
                     usingBlock:(id)block
{
    // __NSStackBlock__ -> __NSStackBlock -> NSBlock
    if (!block || ![self isKindOfClass:NSClassFromString(@"NSBlock")]) {
        NSLog(@"Not Block!");
        return nil;
    }
    struct _BHBlock *bh_block = (__bridge void *)block;
    if (!(bh_block->flags & BLOCK_HAS_SIGNATURE)) {
        NSLog(@"Block has no signature! Required ABI.2010.3.16");
        return nil;
    }
    BHToken *token = [[BHToken alloc] initWithBlock:self];
    token.mode = mode;
    token.hookBlock = block;
    if ([self isKindOfClass:NSClassFromString(@"__NSStackBlock")]) {
        NSLog(@"Stack Block! I suggest you copy it first!");
        token.stackBlock = YES;
    }
    return token;
}

- (BOOL)block_removeHook:(BHToken *)token
{
    return [token remove];
}

@end
