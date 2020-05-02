//
//  MRCTests.m
//  BlockHookSample iOSTests
//
//  Created by 杨萧玉 on 2020/5/2.
//  Copyright © 2020 杨萧玉. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <BlockHook/BlockHook.h>

@interface MRCTests : XCTestCase

@end

@implementation MRCTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testAsyncInvokeMallocBlock {
    NSObject *test = [[NSObject new] autorelease];
    [self hookBlock:^{
        NSLog(@"This is a block, %@", test);
    }];
}

- (void)hookBlock:(void(^)(void))block {
    id b = [[block copy] autorelease];
    NSObject *obj = [[NSObject new] autorelease];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Wait for block invoke."];
    
    [b block_hookWithMode:BlockHookModeAfter usingBlock:^{
        NSLog(@"catch obj:%@", obj);
        [expectation fulfill];
    }];
    
    [self performBlock:b];
    
    [self waitForExpectations:@[expectation] timeout:30];
    [expectation release];
}

- (void)performBlock:(void(^)(void))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (block) {
            block();
        }
    });
}

@end
