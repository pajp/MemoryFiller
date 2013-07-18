//
//  DLLAppDelegate.m
//  MemoryFiller
//
//  Created by Rasmus Sten on 2013-07-16.
//  Copyright (c) 2013 Rasmus Sten. All rights reserved.
//

#import "DLLAppDelegate.h"
#import <QuartzCore/QuartzCore.h>

@implementation DLLAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.mallocs = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory];
    self.chunkSizeTextField.stringValue = @"1024";
    self.sizeTextField.stringValue = @"100";
    self.totalBytesWritten = 0;
    self.progressIndicator.layer.opacity = 0;
}
- (IBAction)freeAllButtonPressed:(id)sender {
    NSLog(@"mallocs size before free: %ld", (unsigned long)[self.mallocs count]);
    for (int i=0; i < [self.mallocs count]; i++)
    {
        void* buffer = [self.mallocs pointerAtIndex:i];
        NSLog(@"Freeing memory at location %p", buffer);
        free(buffer);
        [self.mallocs replacePointerAtIndex:i withPointer:NULL];
    }
    [self.mallocs compact];
    NSLog(@"mallocs size after compact: %ld", (unsigned long)[self.mallocs count]);
    self.bytesWrittenLabel.stringValue = @"0";
    self.totalBytesLabel.stringValue = @"0";
    self.totalBytesWritten = 0;
}

- (void)startFade:(BOOL) fadeIn {
    CABasicAnimation* a = [CABasicAnimation animation];
    
    a.keyPath = @"opacity";
    if (fadeIn) {
        a.fromValue = [NSNumber numberWithFloat:0];
        a.toValue = [NSNumber numberWithFloat:1];
    } else {
        a.fromValue = [NSNumber numberWithFloat:1];
        a.toValue = [NSNumber numberWithFloat:0];
    }
    a.duration = fadeIn ? 2.0 : 0.5;
    a.repeatCount = 0;
    a.autoreverses = NO;
    a.timingFunction = [CAMediaTimingFunction
                        functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [self.progressIndicator.layer addAnimation:a forKey:fadeIn ? @"fadeIn" : @"fadeOut"];
    self.progressIndicator.layer.opacity = fadeIn ? 1.0 : 0.0;
}

- (IBAction)buttonPressed:(id)sender {
    int megabytes = self.sizeTextField.intValue;
    ssize_t target = megabytes * 1024 * 1024;
    int blocksize_kb = self.chunkSizeTextField.intValue;
    NSLog(@"block size in KiB: %d", blocksize_kb);
    ssize_t maxblocksize = blocksize_kb * 1024;
    NSLog(@"Chunk size: %zd bytes", maxblocksize);
    [self.progressIndicator setDoubleValue:0];
    self.progressIndicator.maxValue = target;
    [self startFade:YES];
    self.startButton.enabled = NO;
    NSLog(@"Button pressed: megabytes: %d; target: %zd", megabytes, target);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ssize_t written = 0;
        void* buffer = malloc(target);
        if (buffer == NULL) {
            [NSAlert alertWithMessageText:@"Failed to allocate memory" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"strerror says: %@", [NSString stringWithCString:strerror(errno) encoding:NSUTF8StringEncoding]];
            goto cleanup;
        }
        [self.mallocs addPointer:buffer];
        int urandom = open("/dev/urandom", O_RDONLY);
        if (urandom == -1) {
            NSLog(@"failed to open /dev/urandom (errno: %d", errno);
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSAlert alertWithMessageText:@"Failed to open /dev/urandom" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"strerror says: %@", [NSString stringWithCString:strerror(errno) encoding:NSUTF8StringEncoding]];
            });
            goto cleanup;
        }
        NSLog(@"Open /dev/urandom with fd %d", urandom);
        while (written < target) {
            ssize_t blocksize;
            if (target - written > maxblocksize) {
                blocksize = maxblocksize;
            } else {
                blocksize = target - written;
            }
            ssize_t c = read(urandom, buffer+written, blocksize);
            //NSLog(@"Read %zd bytes", blocksize);
            if (c == -1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSAlert alertWithMessageText:@"Failed to read /dev/urandom" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"strerror says: %@", [NSString stringWithCString:strerror(errno) encoding:NSUTF8StringEncoding]];
                });
                break;
            } else {
                written += c;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.progressIndicator incrementBy:c];
                    self.totalBytesWritten += c;
                    self.bytesWrittenLabel.stringValue = [NSString stringWithFormat:@"%zd", written];
                    self.totalBytesLabel.stringValue = [NSString stringWithFormat:@"%zd", self.totalBytesWritten];
                });
            }
        }
        NSLog(@"Done writing (target bytes: %zd)", written);
        close(urandom);
    cleanup:
        NSLog(@"Cleanup");
        dispatch_async(dispatch_get_main_queue(), ^{
            self.startButton.enabled = YES;
            [self startFade:NO];            
        });
    });
}
@end
