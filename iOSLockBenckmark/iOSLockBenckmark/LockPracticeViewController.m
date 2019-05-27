//
//  LockPracticeViewController.m
//  iOSLockBenckmark
//
//  Created by Walker on 2019/5/16.
//  Copyright © 2019 ibireme. All rights reserved.
//

#import "LockPracticeViewController.h"
#import <libkern/OSAtomic.h>
#import <pthread.h>

/**
 有关锁的各种理解：https://bestswifter.com/ios-lock/
 */
@interface LockPracticeViewController ()

@end

@implementation LockPracticeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)close:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

/**
 自旋锁
 特点：自旋锁不会让等待的进入睡眠状态
 基于此特点自旋锁不在安全，主要原因发生在低优先级线程拿到锁时，高优先级线程进入忙等(busy-wait)状态，消耗大量 CPU 时间，从而导致低优先级线程拿不到CPU时间，也就无法完成任务并释放锁。这种问题被称为优先级反转。
 为什么忙等会导致低优先级线程拿不到时间片？这还得从操作系统的线程调度说起。
 
 现代操作系统在管理普通线程时，通常采用时间片轮转算法(RoundRobin，简称RR)。每个线程会被分配一段时间片(quantum)，通常在10-100毫秒左右。当线程用完属于自己的时间片以后，就会被操作系统挂起，放入等待队列中，直到下一次被分配时间片。
 
 
 OS_SPINLOCK_INIT： 默认值为 0,在 locked 状态时就会大于 0，unlocked状态下为 0
 OSSpinLockTry ：尝试加锁，可以加锁则立即加锁并返回 YES,反之返回 NO
 OSSpinLockLock ：上锁，参数为 OSSpinLock 地址
 OSSpinLockUnlock ：解锁，参数为 OSSpinLock 地址
 
 trylock和lock的使用场景：当前线程锁失败，也可以继续其它任务，用 trylock 合适
 当前线程只有锁成功后，才会做一些有意义的工作，那就 lock，没必要轮询 trylock
 */
- (IBAction)OSSpinLock:(id)sender {
    __block OSSpinLock lock = OS_SPINLOCK_INIT;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1 准备上锁");
        OSSpinLockLock(&lock);
        sleep(4);
        NSLog(@"线程1");
        OSSpinLockUnlock(&lock);
        NSLog(@"线程1 解锁成功");
        NSLog(@"--------------------------------------------------------");
    });
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2 准备上锁");
        OSSpinLockLock(&lock);
        NSLog(@"线程2");
        OSSpinLockUnlock(&lock);
        NSLog(@"线程2 解锁成功");
    });
}

/**
 dispatch_time_t一般在dispatch_after和dispatch_group_wait等方法里作为参数使用。这里最需要注意的是一些宏的含义。
 NSEC_PER_SEC，每秒有多少纳秒。1秒 == 10的9次方纳秒
 USEC_PER_SEC，每秒有多少毫秒。
 NSEC_PER_USEC，每毫秒有多少纳秒。
 DISPATCH_TIME_NOW 从现在开始
 DISPATCH_TIME_FOREVE 永久
 
 dispatch_semaphore_create 创建信号量大小
 dispatch_semaphore_wait 信号量：判断是否大于零，如果大于零，说明不用等待，并且信号量-1；如果等于零，等待超时时间。
 dispatch_semaphore_signal 信号量+1
 */
- (IBAction)dispatch_semaphore:(id)sender {
    dispatch_semaphore_t signal = dispatch_semaphore_create(1);
    dispatch_time_t overTime = dispatch_time(DISPATCH_TIME_NOW, 10.0f * NSEC_PER_SEC);
//    overTime = DISPATCH_TIME_FOREVER;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1 等待ing");
        dispatch_semaphore_wait(signal, overTime); //signal值 -1
        NSLog(@"线程1");
        dispatch_semaphore_signal(signal);
        NSLog(@"线程1 发送信号");
        NSLog(@"-------------------------------");
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2 等待ing");
        dispatch_semaphore_wait(signal, overTime);
        NSLog(@"线程2");
        dispatch_semaphore_signal(signal);
        NSLog(@"线程2 发送信号");
    });
}

/**
 互斥锁，实现原理同信号量，不是使用忙等，而是阻塞线程并睡眠，需要进行上下文切换。内部实现同信号量，效率低是因为申请加锁时需要对锁的类型加以判断。
 
 互斥锁类型：
 PTHREAD_MUTEX_NORMAL 0  默认
 PTHREAD_MUTEX_ERRORCHECK 1 检错锁，防止在同一线程下多次加锁出现死锁
 PTHREAD_MUTEX_RECURSIVE 2 递归锁
 */
- (IBAction)pthread_mutex:(id)sender {
    
    //定义锁的属性
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
    
    static pthread_mutex_t plock;
    pthread_mutex_init(&plock, NULL);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1 准备上锁");
        pthread_mutex_lock(&plock);
        sleep(3);
        NSLog(@"线程1");
        pthread_mutex_unlock(&plock);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSLog(@"线程2 准备上锁");
        pthread_mutex_lock(&plock);
        NSLog(@"线程2");
        pthread_mutex_unlock(&plock);
    });
}

/**
 互斥锁之递归锁
 允许一个线程递归的申请锁
 */
- (IBAction)pthread_mutex_recursive:(id)sender {
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    
    static pthread_mutex_t mutex;
    pthread_mutex_init(&mutex, &attr);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^RecursiveBlock)(int);
        RecursiveBlock = ^(int value) {
            pthread_mutex_lock(&mutex);
            if (value > 0) {
                NSLog(@"线程: %d", value);
                RecursiveBlock(value-1);
            }
        };
        pthread_mutex_unlock(&mutex);
    });
}

/**
 NSLock
 trylock：能加锁返回 YES 并执行加锁操作，相当于 lock，反之返回 NO
 lockBeforeDate：这个方法表示会在传入的时间内尝试加锁，若能加锁则执行加锁操作并返回 YES，反之返回 NO
 */
- (IBAction)NSLock:(id)sender {
    
    NSLock *lock = [[NSLock alloc] init];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1 尝试加速ing...");
        [lock lock];
        NSLog(@"线程1 加锁");
        sleep(4);
        [lock unlock];
        NSLog(@"线程1解锁成功");
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2 尝试加速ing...");
        BOOL x = [lock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:3]];
        if (x) {
            NSLog(@"线程2 加锁");
            sleep(3);
            [lock unlock];
            NSLog(@"线程2解锁成功");
        } else {
            NSLog(@"失败");
        }
    });
    
}

/**
 条件锁，condition可以理解为条件标示
 NSConditionLock 借助 NSCondition 来实现，它的本质就是一个生产者-消费者模型。“条件被满足”可以理解为生产者提供了新的内容。
 */
- (IBAction)NSConditionLock:(id)sender {
    NSConditionLock *clock = [[NSConditionLock alloc] initWithCondition:0];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1");
        if ([clock tryLockWhenCondition:0]) {
            NSLog(@"线程1 加锁");
            sleep(3);
            [clock unlockWithCondition:1];
            NSLog(@"线程1 解锁");
        } else {
            NSLog(@"失败");
        }
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程2");
        [clock lockWhenCondition:3];
        NSLog(@"线程2 加锁");
        sleep(3);
        [clock unlockWithCondition:2];
        NSLog(@"线程2 解锁");
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程3");
        [clock lockWhenCondition:1];
        NSLog(@"线程3 加锁");
        sleep(3);
        [clock unlockWithCondition:3];
        NSLog(@"线程3 解锁");
    });
    
}

/**
 归锁也是通过 pthread_mutex_lock 函数来实现，在函数内部会判断锁的类型，如果显示是递归锁，就允许递归调用，仅仅将一个计数器加一，锁的释放过程也是同理。
 NSRecursiveLock 与 NSLock 的区别在于内部封装的 pthread_mutex_t 对象的类型不同，前者的类型为 PTHREAD_MUTEX_RECURSIVE。
 */
- (IBAction)NSRecursiveLock:(id)sender {
//    NSLock *lock = [NSLock new];  //会造成死锁
    NSRecursiveLock *lock = [NSRecursiveLock new];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^RecursiveBlock)(int);
        RecursiveBlock = ^(int value) {
            [lock lock];
            if (value > 0) {
                NSLog(@"线程：%d",value);
                RecursiveBlock(value - 1);
            }
            [lock unlock];
        };
    });
}

/**
 NSCondition其实是封装了一个互斥锁和条件变量
 
 wait：进入等待状态
 waitUntilDate:：让一个线程等待一定的时间
 signal：唤醒一个等待的线程
 broadcast：唤醒所有等待的线程
 */
- (IBAction)NSCondition:(id)sender {
    NSCondition *condition = [[NSCondition alloc] init];
    
    //线程等待2s后解锁
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        NSLog(@"线程1 start");
//        [condition lock];
//        [condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
//        [condition unlock];
//        NSLog(@"线程1 解锁");
//    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [condition lock];
        NSLog(@"线程1加锁成功");
        [condition wait];
        NSLog(@"线程1");
        [condition unlock];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [condition lock];
        NSLog(@"线程2加锁成功");
        [condition wait];
        NSLog(@"线程2");
        [condition unlock];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(2);
        NSLog(@"唤醒一个等待线程");
        [condition signal];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(5);
        NSLog(@"唤醒所有等待线程");
        [condition broadcast];
    });
}

/**
 相关文档：
    http://ios.jobbole.com/82826/
    https://stackoverflow.com/questions/1215330/how-does-synchronized-lock-unlock-in-objective-c/6047218#6047218
 
 */
- (IBAction)synchronized:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized (self) {
            sleep(2);
            NSLog(@"线程1");
        }
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized (self) {
            NSLog(@"线程2");
        }
    });
}


- (void)testOperationQueue {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 3;
    
}

@end
