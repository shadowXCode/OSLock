//
//  GCDViewController.m
//  iOSLockBenckmark
//
//  Created by Walker on 2019/5/29.
//  Copyright © 2019 ibireme. All rights reserved.
//

#import "GCDViewController.h"

void swap(int* i1,int* i2){
    int temp;
    temp = *i1;
    *i1 = *i2;
    *i2 = temp;
}

@interface GCDViewController ()

@end

@implementation GCDViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    int a = 1;
    int b = 2;
    swap(&a, &b);
    
    dispatch_queue_t queueA = dispatch_queue_create("com.lyk.queueA", NULL);
    dispatch_queue_t queueB = dispatch_queue_create("com.lyk.queueB", NULL);
    
    static int kQueueSpecific;
    CFStringRef queueSpecificValue = CFSTR("queueA");
    dispatch_queue_set_specific(queueA, &kQueueSpecific, (void *)queueSpecificValue, (dispatch_function_t)CFRelease);
    
    dispatch_sync(queueA, ^{
        dispatch_block_t block = ^{
            NSLog(@"NO deadlock!");
        };
        
        CFStringRef retrievedValue = dispatch_get_specific(&kQueueSpecific);
                
        if (retrievedValue) {
            block();
        } else {
            dispatch_sync(queueA, block);
        }
    });
    
    
    
    static void *queueKey1 = "queueKey1";
    dispatch_queue_t queue1 = dispatch_queue_create(queueKey1, DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(queue1, queueKey1, &queueKey1, NULL);
    if (dispatch_get_specific(queueKey1)) {
        //说明当前的队列就是queue1
        NSLog(@"当前的队列就是queue1");
    }else{
        //说明当前的队列不是是queue1
        NSLog(@"当前的队列不是是queue1");
    }
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
