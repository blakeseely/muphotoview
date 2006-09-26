//
//  AppController.m
//  MUPhotoView Demo
//
//  Created by Blake Seely on 4/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"
#import "MUPhotoView.h"

@implementation AppController

- (id)init
{
    if (self = [super init]) {
        //photosArray = [[NSMutableArray alloc] init];
        //selectionIndexes = [[NSMutableIndexSet alloc] init];
        
        return self;
    }
    
    return nil;
}

- (void)dealloc
{
    [selectionIndexes release];
    [photosArray release];
    [super dealloc];
}

- (void)awakeFromNib
{
    NSArray *photoPaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"jpg" inDirectory:nil];
    int i;
    int max = [photoPaths count] * 10;
    
    for (i = 0; i < max; i++) {
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:[photoPaths objectAtIndex:(i % [photoPaths count])]];
        [photosArrayController addObject:image];
        [image release];
    }
    
    // bindings
    [photoView bind:@"photosArray" toObject:photosArrayController withKeyPath:@"arrangedObjects" options:nil];
    [photoView bind:@"selectedPhotoIndexes" toObject:photosArrayController withKeyPath:@"selectionIndexes" options:nil];
    
    [photoSizeSlider bind:@"value" toObject:photoView withKeyPath:@"photoSize" options:nil];
    [backgroundColorWell bind:@"value" toObject:photoView withKeyPath:@"backgroundColor" options:nil];
    
    //[outlineSelectionColor bind:@"enabled" toObject:outlineSelection withKeyPath:@"value" options:nil];
    [outlineSelectionColor bind:@"value" toObject:photoView withKeyPath:@"selectionBorderColor" options:nil];
    [outlineSelection bind:@"value" toObject:photoView withKeyPath:@"useBorderSelection" options:nil];
    [shadowSelection bind:@"value" toObject:photoView withKeyPath:@"useShadowSelection" options:nil];
    [shadowBorder bind:@"value" toObject:photoView withKeyPath:@"useShadowBorder" options:nil];
    [outlineBorder bind:@"value" toObject:photoView withKeyPath:@"useOutlineBorder" options:nil];
}

#pragma mark -
// MUPhotoViewDelegate methods
#pragma mark MUPhotoViewDelegate methods

- (unsigned)photoCountForPhotoView:(MUPhotoView *)view
{
    return [photosArray count];
}

- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)index
{
    return [photosArray objectAtIndex:index];
}

// Selection
- (NSIndexSet *)selectionIndexesForPhotoView:(MUPhotoView *)view;
{
    return selectionIndexes;
}


- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
    [selectionIndexes removeAllIndexes];
    [selectionIndexes addIndexes:indexes];
}

// double-click
- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)index
{
    NSLog(@"User double-clicked on a photo");
}



@end
