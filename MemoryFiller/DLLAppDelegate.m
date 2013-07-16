//
//  DLLAppDelegate.m
//  MemoryFiller
//
//  Created by Rasmus Sten on 2013-07-16.
//  Copyright (c) 2013 Rasmus Sten. All rights reserved.
//

#import "DLLAppDelegate.h"

@implementation DLLAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}
- (IBAction)freeAllButtonPressed:(id)sender {
    for (int i=0; i < [self.mallocs count]; i++)
    {
        free([self.mallocs pointerAtIndex:i]);
        [self.mallocs replacePointerAtIndex:i withPointer:NULL];
    }
    [self.mallocs compact];
    NSLog(@"mallocs size after compact: %ld", (unsigned long)[self.mallocs count]);
    self.bytesWrittenLabel.stringValue = @"0";
    self.totalBytesLabel.stringValue = @"0";
}

- (IBAction)buttonPressed:(id)sender {
    int megabytes = [self.sizeTextField.title intValue];
    ssize_t target = megabytes * 1024 * 1024;
    [self.progressIndicator setDoubleValue:0];
    self.progressIndicator.hidden = NO;
    self.progressIndicator.maxValue = target;
    self.startButton.enabled = NO;
    NSLog(@"Button pressed: megabytes: %d; target: %zd", megabytes, target);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ssize_t written = 0;
        ssize_t maxblocksize = 128*1024;
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
            //NSLog(@"Wrote %zd bytes", written);
            if (c == -1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSAlert alertWithMessageText:@"Failed to read /dev/urandom" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"strerror says: %@", [NSString stringWithCString:strerror(errno) encoding:NSUTF8StringEncoding]];
                });
                break;
            } else {
                written += c;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.progressIndicator incrementBy:c];
                    self.bytesWrittenLabel.stringValue = [NSString stringWithFormat:@"%zd", written];
                    self.totalBytesLabel.stringValue = [NSString stringWithFormat:@"%ld", self.totalBytesLabel.intValue + c];
                });
            }
        }
        NSLog(@"Done writing (target bytes: %zd", written);
        close(urandom);
    cleanup:
        NSLog(@"Cleanup");
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressIndicator.hidden = YES;
            self.startButton.enabled = YES;
            
        });
    });
}
@end
