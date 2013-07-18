//
//  DLLAppDelegate.h
//  MemoryFiller
//
//  Created by Rasmus Sten on 2013-07-16.
//  Copyright (c) 2013 Rasmus Sten. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DLLAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

@property (assign) IBOutlet NSWindow *window;
- (IBAction)buttonPressed:(id)sender;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextFieldCell *sizeTextField;
@property (weak) IBOutlet NSTextField *bytesWrittenLabel;
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSTextField *totalBytesLabel;
@property (weak) IBOutlet NSTextField *chunkSizeTextField;

@property (strong) NSPointerArray *mallocs;
@property ssize_t totalBytesWritten;
@end
