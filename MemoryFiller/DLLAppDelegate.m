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
    self.window.delegate = self;
    [self.fillTypeBox selectItemAtIndex:0];
    [self.window setAlphaValue:0.0];
    [self fadeInWindow];

}

- (void) windowWillClose:(NSNotification *)notification
{
    [[NSApplication sharedApplication] terminate:self];
}

- (void) fadeInWindow
{
    [self.window.animator setAlphaValue:1.0];
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
    if ([self.progressIndicator.layer.animationKeys containsObject:fadeIn ? @"fadeIn" : @"fadeOut"]) {
        return;
    }
    if (self.progressIndicator.layer.opacity == fadeIn ? 1.0 : 0.0) {
        return;
    }
    CABasicAnimation* a = [CABasicAnimation animation];
    
    a.keyPath = @"opacity";
    if (fadeIn) {
        a.fromValue = [NSNumber numberWithFloat:0];
        a.toValue = [NSNumber numberWithFloat:1];
    } else {
        a.fromValue = [NSNumber numberWithFloat:1];
        a.toValue = [NSNumber numberWithFloat:0];
    }
    a.duration = 2.0;
    a.timingFunction = [CAMediaTimingFunction
                        functionWithName:kCAMediaTimingFunctionLinear];
    
    [self.progressIndicator.layer addAnimation:a forKey:fadeIn ? @"fadeIn" : @"fadeOut"];
    self.progressIndicator.layer.opacity = fadeIn ? 1.0 : 0.0;
}

- (IBAction)buttonPressed:(id)sender {
    size_t megabytes = (size_t) self.sizeTextField.intValue;
    size_t target = megabytes * 1024 * 1024;
    int blocksize_kb = self.chunkSizeTextField.intValue;
    NSLog(@"block size in KiB: %d", blocksize_kb);
    size_t maxblocksize = blocksize_kb * 1024;
    NSLog(@"Chunk size: %zd bytes", maxblocksize);
    [self.progressIndicator setDoubleValue:0];
    self.progressIndicator.maxValue = target;
    [self startFade:YES];
    self.startButton.enabled = NO;
    long fillMethod = self.fillTypeBox.indexOfSelectedItem;
    NSLog(@"Fill method: %ld", fillMethod);
    NSLog(@"Button pressed: megabytes: %zd; target: %zd", megabytes, target);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        size_t written = 0;
        void* buffer = malloc(target);
        if (buffer == NULL) {
            [NSAlert alertWithMessageText:@"Failed to allocate memory" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"strerror says: %@", [NSString stringWithCString:strerror(errno) encoding:NSUTF8StringEncoding]];
            goto cleanup;
        }
        [self.mallocs addPointer:buffer];
        int urandom = -1;
        if (fillMethod == 0 || fillMethod == 1) {
            char* file = fillMethod == 0 ? "/dev/urandom" : "/dev/zero";
            urandom = open(file, O_RDONLY);
            if (urandom == -1) {
                NSLog(@"failed to open %s (errno: %d)", file, errno);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSAlert alertWithMessageText:@"Failed to open /dev/urandom" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"strerror says: %@", [NSString stringWithCString:strerror(errno) encoding:NSUTF8StringEncoding]];
                });
                goto cleanup;
            }
            NSLog(@"Opened %s with fd %d", file, urandom);
        }
        double starttime_global = [NSDate timeIntervalSinceReferenceDate];
        while (written < target) {
            size_t blocksize;
            if (target - written > maxblocksize) {
                blocksize = maxblocksize;
            } else {
                blocksize = target - written;
            }
            double starttime = [NSDate timeIntervalSinceReferenceDate];
            size_t c;
            if (urandom > -1) {
                c = read(urandom, buffer+written, blocksize);
            } else {
                memset(buffer+written, 0, blocksize);
                c = blocksize;
            }

            double stoptime = [NSDate timeIntervalSinceReferenceDate];
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
                    double secondsSinceStart = (stoptime - starttime_global);
                    double bytesPerSecondChunk = c / (stoptime - starttime);
                    double bytesPerSecondTotal = written / (stoptime - starttime_global);
                    double estimatedTimeTotal = target / bytesPerSecondTotal;
                    double estimatedTimeRemaining = estimatedTimeTotal - secondsSinceStart;
                    if (estimatedTimeRemaining < 1.5) {
                        [self startFade:NO];
                    }
                    //NSLog(@"%.2f seconds remaining (out of %.2f)", estimatedTimeRemaining, estimatedTimeTotal);
                    if (written == target) {
                        // average for whole buffer
                        NSLog(@"Done writing (target bytes: %zd, %f MiB per second)", written, (bytesPerSecondTotal/1024/1024));
                        self.bandwidthLabel.stringValue = [NSString stringWithFormat:@"%.2f MiB/sec", (bytesPerSecondTotal/1024/1024)];
                    } else {
                        // average for this chunk
                        self.bandwidthLabel.stringValue = [NSString stringWithFormat:@"%.3f MiB/sec (%.1f seconds remain)", (((double)bytesPerSecondChunk)/1024.0/1024.0), estimatedTimeRemaining];
                    }
                });
            }
        }
        if (urandom > -1) {
            close(urandom);
        }
    cleanup:
        NSLog(@"Cleanup");
        dispatch_async(dispatch_get_main_queue(), ^{
            self.startButton.enabled = YES;
            [self startFade:NO];
        });
    });
}
@end
