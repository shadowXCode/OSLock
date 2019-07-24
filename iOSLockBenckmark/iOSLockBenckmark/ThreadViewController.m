//
//  ThreadViewController.m
//  iOSLockBenckmark
//
//  Created by Walker on 2019/5/29.
//  Copyright © 2019 ibireme. All rights reserved.
//

#import "ThreadViewController.h"

@interface ThreadViewController ()
@property (strong) NSThread *thread;
@end

@implementation ThreadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(run1) object:nil];
    [self.thread start];
    
}

- (void)run1 {
    NSLog(@"--- %@ ---",NSStringFromSelector(_cmd));
    
    [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] run];
//    [NSRunLoop currentRunLoop] 
    NSLog(@"未开启RunLoop");
    [[NSNotificationCenter defaultCenter] addObserverForName:nil object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        
    }];
}

- (IBAction)addTimer:(id)sender {
    
    [self performSelector:@selector(run2) onThread:self.thread withObject:nil waitUntilDone:NO];
    
}

- (void)run2 {
    NSTimer *timer = [NSTimer timerWithTimeInterval:3 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"%@ ---",[NSThread currentThread]);
    }];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
