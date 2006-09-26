//
//  AppController.h
//  MUPhotoView Demo
//
//  Created by Blake Seely on 4/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MUPhotoView.h"

@interface AppController : NSObject {
    NSMutableArray *photosArray; // unused in this demo now
    NSMutableIndexSet *selectionIndexes; // unused in this demo now
    
    IBOutlet NSArrayController *photosArrayController;
    
    IBOutlet MUPhotoView *photoView;
    IBOutlet NSSlider *photoSizeSlider;
    IBOutlet NSColorWell *backgroundColorWell;
    
    IBOutlet NSButton *outlineBorder;
    IBOutlet NSButton *shadowBorder;
    
    IBOutlet NSButton *outlineSelection;
    IBOutlet NSColorWell *outlineSelectionColor;
    IBOutlet NSButton *shadowSelection;
}

@end
