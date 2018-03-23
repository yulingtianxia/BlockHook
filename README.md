<p align="center">
<a href="https://github.com/yulingtianxia/BlockHook">
<img src="Assets/logo.png" alt="BlockHook" />
</a>
</p>

# BlockHook

Hook Objective-C block with libffi.
Thanks to MABlockClosure and Aspects!

## 📚 Article

- [Hook Objective-C Block with Libffi](http://yulingtianxia.com/blog/2018/02/28/Hook-Objective-C-Block-with-Libffi/)

## 🌟 Features

- [x] Easy to use.
- [x] Keep your code clear
- [x] Reserve the whole arguments.
- [x] Support 4 modes: Before, Instead, After and Dead.
- [x] Centralized management of rules.
- [x] Self-managed rules.

## 🐒 How to use

You can hook a block using 4 modes (before/instead/after/dead). This method returns a `BHToken` instance for more control. You can `remove` a `BHToken`, or set custom return value to its `retValue` property.

```
- (BHToken *)block_hookWithMode:(BlockHookMode)mode
                     usingBlock:(id)block
```

BlockHook is easy to use. Its APIs take example by Aspects. Here is a full set of usage of BlockHook.

```
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
```

Here is the log:

```
hooked block
hook before block! token:<BHToken: 0x1d00e0f80>
hook instead
hook after block! x:3 y:5 ret:15
hooked result:15
original block
I'm here! result: 8, z is a NSObject: 0x1c0011ec0
original result:8
block dead! token:<BHToken: 0x1c40e8480>
```

## 📲 Installation

BlockHook needs libffi, which is a submodule in this project. You should use `--recursive` when clone this sample, or you can use these commands get the submodule.

```
cd libffi
git submodule init
git submodule update
```

before running target in Xcode, you need do these in libffi:

- run `./autogen.sh`
- run `./configure`
- run `python generate-darwin-source-and-headers.py`

You must build libffi for every architecture you need.
The sample project "BlockHookSample" just only support iOS platform. 

After importing libffi, just add the two files BlockHook.h/m to your project.


## ❤️ Contributed

- If you **need help** or you'd like to **ask a general question**, open an issue.
- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.

## 👨🏻‍💻 Author

yulingtianxia, yulingtianxia@gmail.com

## 👮🏻 License

MessageThrottle is available under the MIT license. See the LICENSE file for more info.

