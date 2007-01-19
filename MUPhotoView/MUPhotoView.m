//
//  MUPhotoView
//
// Copyright (c) 2006 Blake Seely
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//  * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//  * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
//    OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//  * You include a link to http://www.blakeseely.com in your final product.
//
// Version History:
//
// Version 1.0 - April 17, 2006 - Initial Release
// Version 1.1 - April 29, 2006 - Photo removal support, Added support for reduced-size drawing during live resize
// Version 1.2 - September 24, 2006 - Updated selection behavior, Changed to MIT license, Fixed issue where no images would show, fixed autoscroll

#import "MUPhotoView.h"

@implementation MUPhotoView

#pragma mark -
// Initializers and Dealloc
#pragma mark Initializers and Dealloc

+ (void)initialize
{
    [self exposeBinding:@"photosArray"];
    [self exposeBinding:@"selectedPhotoIndexes"];
    [self exposeBinding:@"backgroundColor"];
    [self exposeBinding:@"photoSize"];
    [self exposeBinding:@"useShadowBorder"];
    [self exposeBinding:@"useOutlineBorder"];
    [self exposeBinding:@"useShadowSelection"];
    [self exposeBinding:@"useOutlineSelection"];
    
    [self setKeys:[NSArray arrayWithObject:@"backgroundColor"] triggerChangeNotificationsForDependentKey:@"shadowBoxColor"];
}

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
        
        delegate = nil;
        sendsLiveSelectionUpdates = NO;
        useHighQualityResize = YES;
        photosArray = nil;
        photosFastArray = nil;
        selectedPhotoIndexes = nil;
        dragSelectedPhotoIndexes = [[NSMutableIndexSet alloc] init];
        
        [self setBackgroundColor:[NSColor grayColor]];
        
        useShadowBorder = YES;
        useOutlineBorder = YES;
        borderShadow = [[NSShadow alloc] init];
        [borderShadow setShadowOffset:NSMakeSize(2.0,-3.0)];
        [borderShadow setShadowBlurRadius:5.0];
        noShadow = [[NSShadow alloc] init];
        [noShadow setShadowOffset:NSMakeSize(0,0)];
        [noShadow setShadowBlurRadius:0.0];
        [self setBorderOutlineColor:[NSColor colorWithCalibratedWhite:0.5 alpha:1.0]];
        
        
        useShadowSelection = NO;
        useBorderSelection = YES;
        [self setSelectionBorderColor:[NSColor selectedControlColor]];
        selectionBorderWidth = 3.0;
        [self setShadowBoxColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
        
        photoSize = 100.0;
        photoVerticalSpacing = 25.0;
        photoHorizontalSpacing = 25.0;
        
        photoResizeTimer = nil;
        photoResizeTime = [[NSDate date] retain];
        isDonePhotoResizing = YES;
    }
	
	return self;
}

- (void)dealloc
{
    [self setBorderOutlineColor:nil];
    [self setSelectionBorderColor:nil];
    [self setShadowBoxColor:nil];
    [self setBackgroundColor:nil];
    [self setPhotosArray:nil];
    [self setSelectedPhotoIndexes:nil];
    [photoResizeTime release];
    [dragSelectedPhotoIndexes release];
    dragSelectedPhotoIndexes = nil;
    
	[super dealloc];
}

#pragma mark -
// Drawing Methods
#pragma mark Drawing Methods

- (BOOL)isOpaque
{
	return YES;
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)drawRect:(NSRect)rect
{
    // draw the background color
	[[self backgroundColor] set];
	[NSBezierPath fillRect:rect];
	
    // get the number of photos
    unsigned photoCount = [self photoCount];
    if (0 == photoCount)
        return;

    // update internal grid size, adjust height based on the new grid size
    // because I may not find out that the photos array has changed until I draw and read the photos from the delegate, this call has to stay here
    [self updateGridAndFrame];

    // any other setup
    if (useHighQualityResize) {
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    }
	
    /**** BEGIN Drawing Photos ****/
	NSRange rangeToDraw = [self photoIndexRangeForRect:rect]; // adjusts for photoCount if the rect goes outside my range
    unsigned index;
    unsigned lastIndex = rangeToDraw.location + rangeToDraw.length;
    for (index = rangeToDraw.location; index <= lastIndex; index++) {
        
        // Get the image at the current index - a red square anywhere in the view means it asked for an image, but got nil for that index
        NSImage *photo = nil;
        if ([self inLiveResize]) {
            photo = [self fastPhotoAtIndex:index];
        }
        
        if (nil == photo) {
           photo = [self photoAtIndex:index]; 
        }
        
        if (nil == photo) {
            photo = [[[NSImage alloc] initWithSize:NSMakeSize(photoSize,photoSize)] autorelease];
            [photo lockFocus];
            [[NSColor redColor] set];
            [NSBezierPath fillRect:NSMakeRect(0,0,photoSize,photoSize)];
            [photo unlockFocus];
        }
        
        
        // set it to draw correctly in a flipped view (will restore it after drawing)
        BOOL isFlipped = [photo isFlipped];
        [photo setFlipped:YES];
        
        // scale it to the appropriate size, this method should automatically set high quality if necessary
        photo = [self scalePhoto:photo];
        
        // get all the appropriate positioning information
        NSRect gridRect = [self centerScanRect:[self gridRectForIndex:index]];
        NSSize scaledSize = [self scaledPhotoSizeForSize:[photo size]];
        NSRect photoRect = [self rectCenteredInRect:gridRect withSize:scaledSize];
        photoRect = [self centerScanRect:photoRect];
        
        //**** BEGIN Background Drawing - any drawing that technically goes under the image ****/
        // kSelectionStyleShadowBox draws a semi-transparent rounded rect behind/around the image
        if ([self isPhotoSelectedAtIndex:index] && [self useShadowSelection]) {
            NSBezierPath *shadowBoxPath = [self shadowBoxPathForRect:gridRect];
            [shadowBoxColor set];
            [shadowBoxPath fill];
        }
        
        //**** END Background Drawing ****/
        
        // kBorderStyleShadow - set the appropriate shadow
        if ([self useShadowBorder]) {
            [borderShadow set];
        }
        
        // draw the current photo
        NSRect imageRect = NSMakeRect(0, 0, [photo size].width, [photo size].height);
        [photo drawInRect:photoRect fromRect:imageRect operation:NSCompositeCopy fraction:1.0];
        
        // restore the photo's flipped status
        [photo setFlipped:isFlipped];
        
        // kBorderStyleShadow - remove the shadow after drawing the image
        [noShadow set];
        
        //**** BEGIN Foreground Drawing - includes outline borders, selection rectangles ****/
        if ([self isPhotoSelectedAtIndex:index] && [self useBorderSelection]) {
            NSBezierPath *selectionBorder = [NSBezierPath bezierPathWithRect:NSInsetRect(photoRect,-3.0,-3.0)];
            [selectionBorder setLineWidth:[self selectionBorderWidth]];
            [[self selectionBorderColor] set];
            [selectionBorder stroke];
        } else if ([self useOutlineBorder]) {
            photoRect = NSInsetRect(photoRect,0.5,0.5); // line up the 1px border so it completely fills a single row of pixels
            NSBezierPath *outline = [NSBezierPath bezierPathWithRect:photoRect];
            [outline setLineWidth:1.0];
            [borderOutlineColor set];
            [outline stroke];
        }
        
        //**** END Foreground Drawing ****//
        
        
    }

    //**** END Drawing Photos ****//
    
    //**** BEGIN Selection Rectangle ****//
	if (mouseDown) {
		[noShadow set];
		[[NSColor whiteColor] set];
		
		float minX = (mouseDownPoint.x < mouseCurrentPoint.x) ? mouseDownPoint.x : mouseCurrentPoint.x;
		float minY = (mouseDownPoint.y < mouseCurrentPoint.y) ? mouseDownPoint.y : mouseCurrentPoint.y;
		float maxX = (mouseDownPoint.x > mouseCurrentPoint.x) ? mouseDownPoint.x : mouseCurrentPoint.x;
		float maxY = (mouseDownPoint.y > mouseCurrentPoint.y) ? mouseDownPoint.y : mouseCurrentPoint.y;
		NSRect selectionRectangle = NSMakeRect(minX,minY,maxX-minX,maxY-minY);
		[NSBezierPath strokeRect:selectionRectangle];
		
		[[NSColor colorWithDeviceRed:0.8 green:0.8 blue:0.8 alpha:0.5] set];
		[NSBezierPath fillRect:selectionRectangle];
	}
    //**** END Selection Rectangle ****//
	
}

#pragma mark -
// Delegate Accessors
#pragma mark Delegate Accessors

- (id)delegate
{
    return delegate;
}

- (void)setDelegate:(id)del
{
    [self willChangeValueForKey:@"delegate"];
    delegate = del;
    [self didChangeValueForKey:@"delegate"];
}

#pragma mark -
// Photos Methods
#pragma mark Photo Methods

- (NSArray *)photosArray
{
    //NSLog(@"in -photosArray, returned photosArray = %@", photosArray);
    return [[photosArray retain] autorelease]; 
}

- (void)setPhotosArray:(NSArray *)aPhotosArray
{
    //NSLog(@"in -setPhotosArray:, old value of photosArray: %@, changed to: %@", photosArray, aPhotosArray);
    if (photosArray != aPhotosArray) {
        [photosArray release];
        [self willChangeValueForKey:@"photosArray"];
        photosArray = [aPhotosArray mutableCopy];
        [self didChangeValueForKey:@"photosArray"];
        
        // update live resize array
        if (nil != photosFastArray) {
            [photosFastArray release];
        }
        photosFastArray = [[NSMutableArray alloc] initWithCapacity:[aPhotosArray count]];
        unsigned i;
        for (i = 0; i < [photosArray count]; i++)
        {
            [photosFastArray addObject:[NSNull null]];
        }
        
        // update internal grid size, adjust height based on the new grid size
        [self scrollPoint:([self frame].origin)];
        [self setNeedsDisplayInRect:[self visibleRect]];
    }
}

#pragma mark -
// Selection Management
#pragma mark Selection Management

- (NSIndexSet *)selectedPhotoIndexes
{
    //NSLog(@"in -selectedPhotoIndexes, returned selectedPhotoIndexes = %@", selectedPhotoIndexes);
    return [[selectedPhotoIndexes retain] autorelease]; 
}

- (void)setSelectedPhotoIndexes:(NSIndexSet *)aSelectedPhotoIndexes
{
    //NSLog(@"in -setSelectedPhotoIndexes:, old value of selectedPhotoIndexes: %@, changed to: %@", selectedPhotoIndexes, aSelectedPhotoIndexes);
    if ((selectedPhotoIndexes != aSelectedPhotoIndexes) && (![selectedPhotoIndexes isEqualToIndexSet:aSelectedPhotoIndexes])) {

		// Set the selection and send KVO
        [selectedPhotoIndexes release];
        [self willChangeValueForKey:@"selectedPhotoIndexes"];
        selectedPhotoIndexes = [aSelectedPhotoIndexes copy];
        [self didChangeValueForKey:@"selectedPhotoIndexes"];

    }
}

#pragma mark -
// Selection Style
#pragma mark Selection Style

- (BOOL)useBorderSelection
{
    //NSLog(@"in -useBorderSelection, returned useBorderSelection = %@", useBorderSelection ? @"YES": @"NO");
    return useBorderSelection;
}

- (void)setUseBorderSelection:(BOOL)flag
{
    //NSLog(@"in -setUseBorderSelection, old value of useBorderSelection: %@, changed to: %@", (useBorderSelection ? @"YES": @"NO"), (flag ? @"YES": @"NO"));
    [self willChangeValueForKey:@"useBorderSelection"];
    useBorderSelection = flag;
    [self didChangeValueForKey:@"useBorderSelection"];
    
    [self setNeedsDisplayInRect:[self visibleRect]];
}

- (NSColor *)selectionBorderColor
{
    //NSLog(@"in -selectionBorderColor, returned selectionBorderColor = %@", selectionBorderColor);
    return [[selectionBorderColor retain] autorelease]; 
}

- (void)setSelectionBorderColor:(NSColor *)aSelectionBorderColor
{
    //NSLog(@"in -setSelectionBorderColor:, old value of selectionBorderColor: %@, changed to: %@", selectionBorderColor, aSelectionBorderColor);
    if (selectionBorderColor != aSelectionBorderColor) {
        [selectionBorderColor release];
        [self willChangeValueForKey:@"selectionBorderColor"];
        selectionBorderColor = [aSelectionBorderColor copy];
        [self didChangeValueForKey:@"selectionBorderColor"];
    }
}

- (BOOL)useShadowSelection
{
    //NSLog(@"in -useShadowSelection, returned useShadowSelection = %@", useShadowSelection ? @"YES": @"NO");
    return useShadowSelection;
}

- (void)setUseShadowSelection:(BOOL)flag
{
    //NSLog(@"in -setUseShadowSelection, old value of useShadowSelection: %@, changed to: %@", (useShadowSelection ? @"YES": @"NO"), (flag ? @"YES": @"NO"));
    [self willChangeValueForKey:@"useShadowSelection"];
    useShadowSelection = flag;
    [self willChangeValueForKey:@"useShadowSelection"];
    
    [self setNeedsDisplayInRect:[self visibleRect]];
}

#pragma mark -
// Appearance
#pragma mark Appearance

- (BOOL)useShadowBorder
{
    //NSLog(@"in -useShadowBorder, returned useShadowBorder = %@", useShadowBorder ? @"YES": @"NO");
    return useShadowBorder;
}

- (void)setUseShadowBorder:(BOOL)flag
{
    //NSLog(@"in -setUseShadowBorder, old value of useShadowBorder: %@, changed to: %@", (useShadowBorder ? @"YES": @"NO"), (flag ? @"YES": @"NO"));
    [self willChangeValueForKey:@"useShadowBorder"];
    useShadowBorder = flag;
    [self didChangeValueForKey:@"useShadowBorder"];
    
    [self setNeedsDisplayInRect:[self visibleRect]];
}

- (BOOL)useOutlineBorder
{
    //NSLog(@"in -useOutlineBorder, returned useOutlineBorder = %@", useOutlineBorder ? @"YES": @"NO");
    return useOutlineBorder;
}

- (void)setUseOutlineBorder:(BOOL)flag
{
    //NSLog(@"in -setUseOutlineBorder, old value of useOutlineBorder: %@, changed to: %@", (useOutlineBorder ? @"YES": @"NO"), (flag ? @"YES": @"NO"));
    [self willChangeValueForKey:@"useOutlineBorder"];
    useOutlineBorder = flag;
    [self didChangeValueForKey:@"useOutlineBorder"];
    
    [self setNeedsDisplayInRect:[self visibleRect]];
}

- (NSColor *)backgroundColor
{
    //NSLog(@"in -backgroundColor, returned backgroundColor = %@", backgroundColor);
    return [[backgroundColor retain] autorelease]; 
}

- (void)setBackgroundColor:(NSColor *)aBackgroundColor
{
    //NSLog(@"in -setBackgroundColor:, old value of backgroundColor: %@, changed to: %@", backgroundColor, aBackgroundColor);
    if (backgroundColor != aBackgroundColor) {
        [backgroundColor release];
        [self willChangeValueForKey:@"backgroundColor"];
        backgroundColor = [aBackgroundColor copy];
        [self didChangeValueForKey:@"backgroundColor"];
        
        // adjust the shadow box selection color based on the background color. values closer to white use black and vice versa
        NSColor *newShadowBoxColor;
        float whiteValue = 0.0;
        if ([backgroundColor numberOfComponents] >= 3) {
            float red, green, blue;
            [backgroundColor getRed:&red green:&green blue:&blue alpha:NULL];
            whiteValue = (red + green + blue) / 3;
        } else if ([backgroundColor numberOfComponents] >= 1) {
            [backgroundColor getWhite:&whiteValue alpha:NULL];
        }
        
        if (0.5 > whiteValue)
            newShadowBoxColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.5];
        else
            newShadowBoxColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.5];
        [self setShadowBoxColor:newShadowBoxColor];
    }
}

- (float)photoSize
{
    //NSLog(@"in -photoSize, returned photoSize = %f", photoSize);
    return photoSize;
}

- (void)setPhotoSize:(float)aPhotoSize
{
    //NSLog(@"in -setPhotoSize, old value of photoSize: %f, changed to: %f", photoSize, aPhotoSize);
    [self willChangeValueForKey:@"photoSize"];
    photoSize = aPhotoSize;
    [self didChangeValueForKey:@"photoSize"];
    
    // update internal grid size, adjust height based on the new grid size
    // to make sure the same photos stay in view, get a visible photos' index, then scroll to that photo after the update
    NSRect visibleRect = [self visibleRect];
    float heightRatio = visibleRect.origin.y / [self frame].size.height;
    visibleRect.origin.y = heightRatio * [self frame].size.height;
    [self scrollRectToVisible:visibleRect];
    
    [self setNeedsDisplayInRect:[self visibleRect]];
    
    // update time for live resizing
    if (nil != photoResizeTime) {
        [photoResizeTime release];
        photoResizeTime = nil;
    }
    isDonePhotoResizing = NO;
    photoResizeTime = [[NSDate date] retain];
    if (nil == photoResizeTimer) {
        photoResizeTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updatePhotoResizing) userInfo:nil repeats:YES];
    }
}


#pragma mark -
// Don't Mess With Texas
#pragma mark Don't Mess With Texas
// haven't tested changing these behaviors yet - there's no reason they shouldn't work... but use at your own risk.

- (float)photoVerticalSpacing
{
    //NSLog(@"in -photoVerticalSpacing, returned photoVerticalSpacing = %f", photoVerticalSpacing);
    return photoVerticalSpacing;
}

- (void)setPhotoVerticalSpacing:(float)aPhotoVerticalSpacing
{
    //NSLog(@"in -setPhotoVerticalSpacing, old value of photoVerticalSpacing: %f, changed to: %f", photoVerticalSpacing, aPhotoVerticalSpacing);
    [self willChangeValueForKey:@"photoVerticalSpacing"];
    photoVerticalSpacing = aPhotoVerticalSpacing;
    [self didChangeValueForKey:@"photoVertificalSpacing"];
    
    // update internal grid size, adjust height based on the new grid size
    NSRect visibleRect = [self visibleRect];
    float heightRatio = visibleRect.origin.y / [self frame].size.height;
    visibleRect.origin.y = heightRatio * [self frame].size.height;
    [self scrollRectToVisible:visibleRect];
    [self setNeedsDisplayInRect:[self visibleRect]]; 
    
    
    // update time for live resizing
    if (nil != photoResizeTime) {
        [photoResizeTime release];
        photoResizeTime = nil;
    }
    isDonePhotoResizing = NO;
    photoResizeTime = [[NSDate date] retain];
    if (nil == photoResizeTimer) {
        photoResizeTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(updatePhotoResizing) userInfo:nil repeats:YES];
    }
    
}

- (float)photoHorizontalSpacing
{
    //NSLog(@"in -photoHorizontalSpacing, returned photoHorizontalSpacing = %f", photoHorizontalSpacing);
    return photoHorizontalSpacing;
}

- (void)setPhotoHorizontalSpacing:(float)aPhotoHorizontalSpacing
{
    //NSLog(@"in -setPhotoHorizontalSpacing, old value of photoHorizontalSpacing: %f, changed to: %f", photoHorizontalSpacing, aPhotoHorizontalSpacing);
    [self willChangeValueForKey:@"photoHorizontalSpacing"];
    photoHorizontalSpacing = aPhotoHorizontalSpacing;
    [self didChangeValueForKey:@"photoHorizontalSpacing"];
    
    // update internal grid size, adjust height based on the new grid size
    NSRect visibleRect = [self visibleRect];
    float heightRatio = visibleRect.origin.y / [self frame].size.height;
    visibleRect.origin.y = heightRatio * [self frame].size.height;
    [self scrollRectToVisible:visibleRect];
    [self setNeedsDisplayInRect:[self visibleRect]];    
        
    // update time for live resizing
    if (nil != photoResizeTime) {
        [photoResizeTime release];
        photoResizeTime = nil;
    }
    isDonePhotoResizing = NO;
    photoResizeTime = [[NSDate date] retain];
    if (nil == photoResizeTimer) {
        photoResizeTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(updatePhotoResizing) userInfo:nil repeats:YES];
    }
    
}


- (NSColor *)borderOutlineColor
{
    //NSLog(@"in -borderOutlineColor, returned borderOutlineColor = %@", borderOutlineColor);
    return [[borderOutlineColor retain] autorelease]; 
}

- (void)setBorderOutlineColor:(NSColor *)aBorderOutlineColor
{
    //NSLog(@"in -setBorderOutlineColor:, old value of borderOutlineColor: %@, changed to: %@", borderOutlineColor, aBorderOutlineColor);
    if (borderOutlineColor != aBorderOutlineColor) {
        [borderOutlineColor release];
        [self willChangeValueForKey:@"borderOutlineColor"];
        borderOutlineColor = [aBorderOutlineColor copy];
        [self didChangeValueForKey:@"borderOutlineColor"];
        
        [self setNeedsDisplayInRect:[self visibleRect]];
    }
}

- (NSColor *)shadowBoxColor
{
    //NSLog(@"in -shadowBoxColor, returned shadowBoxColor = %@", shadowBoxColor);
    return [[shadowBoxColor retain] autorelease]; 
}

- (void)setShadowBoxColor:(NSColor *)aShadowBoxColor
{
    //NSLog(@"in -setShadowBoxColor:, old value of shadowBoxColor: %@, changed to: %@", shadowBoxColor, aShadowBoxColor);
    if (shadowBoxColor != aShadowBoxColor) {
        [shadowBoxColor release];
        shadowBoxColor = [aShadowBoxColor copy];
        
        [self setNeedsDisplayInRect:[self visibleRect]];
    }
    
}
- (float)selectionBorderWidth
{
    //NSLog(@"in -selectionBorderWidth, returned selectionBorderWidth = %f", selectionBorderWidth);
    return selectionBorderWidth;
}

- (void)setSelectionBorderWidth:(float)aSelectionBorderWidth
{
    //NSLog(@"in -setSelectionBorderWidth, old value of selectionBorderWidth: %f, changed to: %f", selectionBorderWidth, aSelectionBorderWidth);
    selectionBorderWidth = aSelectionBorderWidth;
}


#pragma mark -
// Mouse Event Methods
#pragma mark Mouse Event Methods

- (void) mouseDown:(NSEvent *) event
{
	mouseDown = YES;
	mouseDownPoint = [self convertPoint:[event locationInWindow] fromView:nil];
	mouseCurrentPoint = mouseDownPoint;

	unsigned				clickedIndex = [self photoIndexForPoint:mouseDownPoint];
	NSRect					photoRect = [self photoRectForIndex:clickedIndex];
	unsigned int			flags = [event modifierFlags];
	NSMutableIndexSet*		indexes = [[self selectionIndexes] mutableCopy];
	BOOL					imageHit = NSPointInRect(mouseDownPoint, photoRect);

	if (imageHit) {
		if (flags & NSCommandKeyMask) {
			// Flip current image selection state.
			if ([indexes containsIndex:clickedIndex]) {
                [indexes removeIndex:clickedIndex];
			} else {
                [indexes addIndex:clickedIndex];
			}
        } else {
			if (flags & NSShiftKeyMask) {
				// Add range to selection.
				if ([indexes count] == 0) {
					[indexes addIndex:clickedIndex];
				} else {
					unsigned int origin = (clickedIndex < [indexes lastIndex]) ? clickedIndex :[indexes lastIndex];
					unsigned int length = (clickedIndex < [indexes lastIndex]) ? [indexes lastIndex] - clickedIndex : clickedIndex - [indexes lastIndex];

					length++;
					[indexes addIndexesInRange:NSMakeRange(origin, length)];
				}
			} else {
				if (![self isPhotoSelectedAtIndex:clickedIndex]) {
					// Photo selection without modifiers.
					[indexes removeAllIndexes];
					[indexes addIndex:clickedIndex];
				}
			}
		}

		potentialDragDrop = YES;
	} else {
		if ((flags & NSShiftKeyMask) == 0) {
			[indexes removeAllIndexes];
		}
		potentialDragDrop = NO;
	}

	[self setSelectionIndexes:indexes];
	[indexes release];
}

- (void)mouseDragged:(NSEvent *)event
{
    mouseCurrentPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    
    // if the mouse has moved less than 5px in either direction, don't register the drag yet
    float xFromStart = fabs((mouseDownPoint.x - mouseCurrentPoint.x));
	float yFromStart = fabs((mouseDownPoint.y - mouseCurrentPoint.y));
	if ((xFromStart < 5) && (yFromStart < 5)) {
		return;
        
	} else if (potentialDragDrop && (nil != delegate)) {
        // create a drag image
		unsigned clickedIndex = [self photoIndexForPoint:mouseDownPoint];
        NSImage *clickedImage = [self photoAtIndex:clickedIndex];
        BOOL flipped = [clickedImage isFlipped];
        [clickedImage setFlipped:NO];
        NSSize scaledSize = [self scaledPhotoSizeForSize:[clickedImage size]];
		if (nil == clickedImage) { // creates a red image, which should let the user/developer know something is wrong
            clickedImage = [[[NSImage alloc] initWithSize:NSMakeSize(photoSize,photoSize)] autorelease];
            [clickedImage lockFocus];
            [[NSColor redColor] set];
            [NSBezierPath fillRect:NSMakeRect(0,0,photoSize,photoSize)];
            [clickedImage unlockFocus];
        }
		NSImage *dragImage = [[NSImage alloc] initWithSize:scaledSize];

		// draw the drag image as a semi-transparent copy of the image the user dragged, and optionally a red badge indicating the number of photos
        [dragImage lockFocus];
		[clickedImage drawInRect:NSMakeRect(0,0,scaledSize.width,scaledSize.height) fromRect:NSMakeRect(0,0,[clickedImage size].width,[clickedImage size].height)  operation:NSCompositeCopy fraction:0.5];
		[dragImage unlockFocus];
        
        [clickedImage setFlipped:flipped];

		// if there's more than one image, put a badge on the photo
		if ([[self selectionIndexes] count] > 1) {
			NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
			[attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
			[attributes setObject:[NSFont fontWithName:@"Helvetica" size:14] forKey:NSFontAttributeName];
			NSAttributedString *badgeString = [[NSAttributedString alloc] initWithString:[[NSNumber numberWithInt:[[self selectionIndexes] count]] stringValue] attributes:attributes];
			NSSize stringSize = [badgeString size];
			int diameter = stringSize.width;
			if (stringSize.height > diameter) diameter = stringSize.height;
			diameter += 5;
			
			// calculate the badge circle
			int minY = 5;
			int maxX = [dragImage size].width - 5;
			int maxY = minY + diameter;
			int minX = maxX - diameter;
			NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(minX,minY,maxX-minX,maxY-minY)];
			// draw the circle
			[dragImage lockFocus];
			[[NSColor colorWithDeviceRed:1 green:0.1 blue:0.1 alpha:0.7] set];
			[circle fill];
			[dragImage unlockFocus];
			
			// draw the string
			NSPoint point;
			point.x = maxX - ((maxX - minX) / 2) - 1;
			point.y = (maxY - minY) / 2;
			point.x = point.x - (stringSize.width / 2);
			point.y = point.y - (stringSize.height / 2) + 7;
			
			[dragImage lockFocus];
			[badgeString drawAtPoint:point];
			[dragImage unlockFocus];
			
			[badgeString release];
			[attributes release];
		}
		
		// get the supported drag data types from the delegate
        NSArray *types = [delegate pasteboardDragTypesForPhotoView:self];
        
        if (nil != types) {
            // get the pasteboard and register the returned types with delegate as the owner
            NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
            [pb declareTypes:types owner:delegate];

			unsigned int selectedIndex = [[self selectionIndexes] firstIndex];
			while (selectedIndex != NSNotFound) {
				int j;
				for (j = 0; j < [types count]; j++) {
					NSString *type = [types objectAtIndex:j];
					NSData *data = [delegate photoView:self pasteboardDataForPhotoAtIndex:selectedIndex dataType:type];
					if (nil != data) {
						[pb setData:data forType:type];
					}
				}
				selectedIndex = [[self selectionIndexes] indexGreaterThanIndex:selectedIndex];
			}

            // place the cursor in the center of the drag image
            NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
            NSSize imageSize = [dragImage size];
            p.x = p.x - imageSize.width / 2;
            p.y = p.y + imageSize.height / 2;
            
            [self dragImage:dragImage at:p offset:NSMakeSize(0,0) event:event pasteboard:pb source:self slideBack:YES];
        }

        [dragImage release];

    } else {
        // adjust the mouse current point so that it's not outside the frame
        NSRect frameRect = [self frame];
        if (mouseCurrentPoint.x < NSMinX(frameRect))
            mouseCurrentPoint.x = NSMinX(frameRect);
        if (mouseCurrentPoint.x > NSMaxX(frameRect))
            mouseCurrentPoint.x = NSMaxX(frameRect);
        if (mouseCurrentPoint.y < NSMinY(frameRect))
            mouseCurrentPoint.y = NSMinY(frameRect);
        if (mouseCurrentPoint.y > NSMaxY(frameRect))
            mouseCurrentPoint.y = NSMaxY(frameRect);
        
        // determine the rect for the current drag area
        float minX, maxX, minY, maxY;
        minX = (mouseCurrentPoint.x < mouseDownPoint.x) ? mouseCurrentPoint.x : mouseDownPoint.x;
		minY = (mouseCurrentPoint.y < mouseDownPoint.y) ? mouseCurrentPoint.y : mouseDownPoint.y;
		maxX = (mouseCurrentPoint.x > mouseDownPoint.x) ? mouseCurrentPoint.x : mouseDownPoint.x;
		maxY = (mouseCurrentPoint.y > mouseDownPoint.y) ? mouseCurrentPoint.y : mouseDownPoint.y;
        if (maxY > NSMaxY(frameRect))
            maxY = NSMaxY(frameRect);
        if (maxX > NSMaxX(frameRect))
            maxX = NSMaxX(frameRect);
            
        NSRect selectionRect = NSMakeRect(minX,minY,maxX-minX,maxY-minY);
		
		unsigned minIndex = [self photoIndexForPoint:NSMakePoint(minX, minY)];
		unsigned xRun = [self photoIndexForPoint:NSMakePoint(maxX, minY)] - minIndex + 1;
		unsigned yRun = [self photoIndexForPoint:NSMakePoint(minX, maxY)] - minIndex + 1;
		unsigned selectedRows = (yRun / columns);
        
        // Save the current selection (if any), then populate the drag indexes
		// this allows us to shift band select to add to the current selection.
		[dragSelectedPhotoIndexes removeAllIndexes];
		[dragSelectedPhotoIndexes addIndexes:[self selectionIndexes]];
        
        // add indexes in the drag rectangle
        int i;
		for (i = 0; i <= selectedRows; i++) {
			unsigned rowStartIndex = (i * columns) + minIndex;
            int j;
            for (j = rowStartIndex; j < (rowStartIndex + xRun); j++) {
                if (NSIntersectsRect([self photoRectForIndex:j],selectionRect))
                    [dragSelectedPhotoIndexes addIndex:j];
            }
		}
        
        // if requested, set the selection. this could cause a rapid series of KVO notifications, so if this is false, the view tracks
        // the selection internally, but doesn't pass it to the bindings or the delegates until the drag is over.
		// This will cause an appropriate redraw.
        if (sendsLiveSelectionUpdates)
		{
            [self setSelectionIndexes:dragSelectedPhotoIndexes];
        }
		
        // autoscrolling
        if (autoscrollTimer == nil) {
            autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(autoscroll) userInfo:nil repeats:YES];
        }

        [[self superview] autoscroll:event];
        
		[self setNeedsDisplayInRect:[self visibleRect]];
    }
    
}


- (void)mouseUp:(NSEvent *)event
{
	// Doubl-click Handling
	if ([event clickCount] == 2) {
		// There could be more than one selected photo.  In that case, call the delegates doubleClickOnPhotoAtIndex routine for
		// each selected photo.
		unsigned int			selectedIndex = [[self selectionIndexes] firstIndex];
		while (selectedIndex != NSNotFound) {
			[delegate photoView:self doubleClickOnPhotoAtIndex:selectedIndex];
			selectedIndex = [[self selectionIndexes] indexGreaterThanIndex:selectedIndex];
		}
	} else if (0 < [dragSelectedPhotoIndexes count]) { // finishing a drag selection
        // move the drag indexes into the main selection indexes - firing off KVO messages or delegate messages
        [self setSelectionIndexes:dragSelectedPhotoIndexes];
        [dragSelectedPhotoIndexes removeAllIndexes];
	}

    if (autoscrollTimer != nil) {
		[autoscrollTimer invalidate];
		autoscrollTimer = nil;
	}
    
    mouseDown = NO;

	[self setNeedsDisplayInRect:[self visibleRect]];
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	if (nil != delegate)
        return [delegate photoView:self draggingSourceOperationMaskForLocal:isLocal];
    else
        return NSDragOperationNone;
}

- (void)autoscroll
{
	mouseCurrentPoint = [self convertPoint:[[NSApp currentEvent] locationInWindow] fromView:nil];
	[[self superview] autoscroll:[NSApp currentEvent]];
	
    [self mouseDragged:[NSApp currentEvent]];
}

#pragma mark -
// Responder Method
#pragma mark Responder Methods

- (BOOL)acceptsFirstResponder
{
	return([self photoCount] > 0);
}

- (BOOL)resignFirstResponder
{
	[self setNeedsDisplay:YES];
	return YES;
}

- (BOOL)becomeFirstResponder
{
	[self setNeedsDisplay:YES];
	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString*					eventKey = [theEvent charactersIgnoringModifiers];
	unichar						keyChar = 0;

	if ([eventKey length] == 1)
	{
		keyChar = [eventKey characterAtIndex:0];
		if (keyChar == ' ')
		{
			unsigned int			selectedIndex = [[self selectionIndexes] firstIndex];

			while (selectedIndex != NSNotFound)
			{
				[delegate photoView:self doubleClickOnPhotoAtIndex:selectedIndex];
				selectedIndex = [[self selectionIndexes] indexGreaterThanIndex:selectedIndex];
			}
			return;
		}
	}

	[self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void)deleteBackward:(id)sender
{
    if (0 < [[self selectionIndexes] count]) {
        [self removePhotosAtIndexes:[self selectionIndexes]];
    }
}

- (void)selectAll:(id)sender
{
    if (0 < [self photoCount]) {
        NSIndexSet *allIndexes = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, [self photoCount])];
        [self setSelectionIndexes:allIndexes];
        [allIndexes release];
    }
}

- (void)insertTab:(id)sender
{
	[[self window] selectKeyViewFollowingView:self];
}

- (void)insertBackTab:(id)sender
{
	[[self window] selectKeyViewPrecedingView:self];
}

- (void)moveLeft:(id)sender
{
	NSIndexSet*					indexes = [self selectionIndexes];
	NSMutableIndexSet*			newIndexes = [[NSMutableIndexSet alloc] init];

	if (([indexes count] > 0) && (![indexes containsIndex:0]))
	{
		[newIndexes addIndex:[indexes firstIndex] - 1];
	}
	else
	{
		if (([indexes count] == 0) && ([self photoCount] > 0))
		{
			[newIndexes addIndex:[self photoCount] - 1];
		}
	}

	if ([newIndexes count] > 0)
	{
		[self setSelectionIndexes:newIndexes];
		[self scrollRectToVisible:[self gridRectForIndex:[newIndexes firstIndex]]];
	}

	[newIndexes release];
}

- (void)moveLeftAndModifySelection:(id)sender
{
    NSIndexSet *indexes = [self selectionIndexes];
	if (([indexes count] > 0) && (![indexes containsIndex:0])) {
		NSMutableIndexSet *newIndexes = [indexes mutableCopy];
        [newIndexes addIndex:([newIndexes firstIndex] - 1)];
        [self setSelectionIndexes:newIndexes];
		[self scrollRectToVisible:[self gridRectForIndex:[newIndexes firstIndex]]];
        [newIndexes release];
	}
}

- (void)moveRight:(id)sender
{
	NSIndexSet*					indexes = [self selectionIndexes];
	NSMutableIndexSet*			newIndexes = [[NSMutableIndexSet alloc] init];

	if (([indexes count] > 0) && (![indexes containsIndex:[self photoCount] - 1]))
	{
		[newIndexes addIndex:[indexes lastIndex] + 1];
	}
	else
	{
		if (([indexes count] == 0) && ([self photoCount] > 0))
		{
			[newIndexes addIndex:0];
		}
	}

	if ([newIndexes count] > 0)
	{
		[self setSelectionIndexes:newIndexes];
		[self scrollRectToVisible:[self gridRectForIndex:[newIndexes lastIndex]]];
	}

	[newIndexes release];
}

- (void)moveRightAndModifySelection:(id)sender
{
    NSIndexSet *indexes = [self selectionIndexes];
	if (([indexes count] > 0) && (![indexes containsIndex:([self photoCount] - 1)])) {
		NSMutableIndexSet *newIndexes = [indexes mutableCopy];
        [newIndexes addIndex:([newIndexes lastIndex] + 1)];
        [self setSelectionIndexes:newIndexes];
		[self scrollRectToVisible:[self gridRectForIndex:[newIndexes lastIndex]]];
        [newIndexes release];
	}
}

- (void)moveDown:(id)sender
{
	NSIndexSet*					indexes = [self selectionIndexes];
	NSMutableIndexSet*			newIndexes = [[NSMutableIndexSet alloc] init];
	unsigned int				destinationIndex = [indexes lastIndex] + columns;
	unsigned int				lastIndex = [self photoCount] - 1;

	if (([indexes count] > 0) && (destinationIndex <= lastIndex))
	{
		[newIndexes addIndex:destinationIndex];
	}
	else
	{
		if (([indexes count] == 0) && ([self photoCount] > 0))
		{
			[newIndexes addIndex:0];
		}
	}

	if ([newIndexes count] > 0)
	{
		[self setSelectionIndexes:newIndexes];
		[self scrollRectToVisible:[self gridRectForIndex:[newIndexes lastIndex]]];
	}

	[newIndexes release];
}

- (void)moveDownAndModifySelection:(id)sender
{
	NSIndexSet *indexes = [self selectionIndexes];
	unsigned int destinationIndex = [indexes lastIndex] + columns;
	unsigned int lastIndex = [self photoCount] - 1;
	
	if (([indexes count] > 0) && (destinationIndex <= lastIndex)) {
		NSMutableIndexSet *newIndexes = [indexes mutableCopy];
        NSRange addRange;
        addRange.location = [indexes lastIndex] + 1;
        addRange.length = columns;
        [newIndexes addIndexesInRange:addRange];
        [self setSelectionIndexes:newIndexes];
		[self scrollRectToVisible:[self gridRectForIndex:[newIndexes lastIndex]]];
        [newIndexes release];
	}
}

- (void)moveUp:(id)sender
{
	NSIndexSet*					indexes = [self selectionIndexes];
	NSMutableIndexSet*			newIndexes = [[NSMutableIndexSet alloc] init];

	if (([indexes count] > 0) && ([indexes firstIndex] >= columns))
	{
		[newIndexes addIndex:[indexes firstIndex] - columns];
	}
	else
	{
		if (([indexes count] == 0) && ([self photoCount] > 0))
		{
			[newIndexes addIndex:[self photoCount] - 1];
		}
	}

	if ([newIndexes count] > 0)
	{
		[self setSelectionIndexes:newIndexes];
		[self scrollRectToVisible:[self gridRectForIndex:[newIndexes firstIndex]]];
	}

	[newIndexes release];
}

- (void)moveUpAndModifySelection:(id)sender
{
	NSMutableIndexSet *indexes = [[self selectionIndexes] mutableCopy];
	if (([indexes count] > 0) && ([indexes firstIndex] >= columns)) {
		[indexes addIndexesInRange:NSMakeRange(([indexes firstIndex] - columns), columns + 1)];
		[self setSelectionIndexes:indexes];
		[self scrollRectToVisible:[self gridRectForIndex:[indexes firstIndex]]];
	}	
	[indexes release];
}

- (void)scrollToEndOfDocument:(id)sender
{
    [self scrollRectToVisible:[self gridRectForIndex:([self photoCount] - 1)]];
}

- (void)scrollToBeginningOfDocument:(id)sender
{
    [self scrollPoint:NSZeroPoint];
}

- (void)moveToEndOfLine:(id)sender
{
	NSIndexSet *indexes = [self selectionIndexes];
	if ([indexes count] > 0) {
		unsigned int destinationIndex = ([indexes lastIndex] + columns) - ([indexes lastIndex] % columns) - 1;
		if (destinationIndex >= [self photoCount]) {
			destinationIndex = [self photoCount] - 1;
		}
		NSIndexSet *newIndexes = [[NSIndexSet alloc] initWithIndex:destinationIndex];
        [self setSelectionIndexes:newIndexes];
		[self scrollRectToVisible:[self gridRectForIndex:destinationIndex]];
        [newIndexes release];
	}
}

- (void)moveToEndOfLineAndModifySelection:(id)sender
{
	NSMutableIndexSet *indexes = [[self selectionIndexes] mutableCopy];
	if ([indexes count] > 0) {
		unsigned int destinationIndexPlusOne = ([indexes lastIndex] + columns) - ([indexes lastIndex] % columns);
		if (destinationIndexPlusOne >= [self photoCount]) {
			destinationIndexPlusOne = [self photoCount];
		}
		[indexes addIndexesInRange:NSMakeRange(([indexes lastIndex]), (destinationIndexPlusOne - [indexes lastIndex]))];
		[self setSelectionIndexes:indexes];
		[self scrollRectToVisible:[self gridRectForIndex:[indexes lastIndex]]];
	}
	[indexes release];
}

- (void)moveToBeginningOfLine:(id)sender
{
	NSIndexSet *indexes = [self selectionIndexes];
	if ([indexes count] > 0) {
		unsigned int destinationIndex = [indexes firstIndex] - ([indexes firstIndex] % columns);
		NSIndexSet *newIndexes = [[NSIndexSet alloc] initWithIndex:destinationIndex];
        [self setSelectionIndexes:newIndexes];
		[self scrollRectToVisible:[self gridRectForIndex:destinationIndex]];
		[newIndexes release];
	}
}

- (void)moveToBeginningOfLineAndModifySelection:(id)sender
{
	NSMutableIndexSet *indexes = [[self selectionIndexes] mutableCopy];
	if ([indexes count] > 0) {
		unsigned int destinationIndex = [indexes firstIndex] - ([indexes firstIndex] % columns);
		[indexes addIndexesInRange:NSMakeRange(destinationIndex, ([indexes firstIndex] - destinationIndex))];
		[self setSelectionIndexes:indexes];
		[self scrollRectToVisible:[self gridRectForIndex:destinationIndex]];
	}
	[indexes release];
}

- (void)moveToBeginningOfDocument:(id)sender
{
    if (0 < [self photoCount]) {
        [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:0]];
        [self scrollPoint:NSZeroPoint];
    }
}

- (void)moveToBeginningOfDocumentAndModifySelection:(id)sender
{
	NSMutableIndexSet *indexes = [[self selectionIndexes] mutableCopy];
	if ([indexes count] > 0) {
		[indexes addIndexesInRange:NSMakeRange(0, [indexes firstIndex])];
		[self setSelectionIndexes:indexes];
		[self scrollRectToVisible:NSZeroRect];
	}
	[indexes release];
}

- (void)moveToEndOfDocument:(id)sender
{
    if (0 < [self photoCount]) {
        [self setSelectionIndexes:[NSIndexSet indexSetWithIndex:([self photoCount] - 1)]];
        [self scrollRectToVisible:[self gridRectForIndex:([self photoCount] - 1)]];
    }
}

- (void)moveToEndOfDocumentAndModifySelection:(id)sender
{
	NSMutableIndexSet *indexes = [[self selectionIndexes] mutableCopy];
	if ([indexes count] > 0) {
		[indexes addIndexesInRange:NSMakeRange([indexes lastIndex], ([self photoCount] - [indexes lastIndex]))];
		[self setSelectionIndexes:indexes];
		[self scrollRectToVisible:[self gridRectForIndex:[indexes lastIndex]]];
	}
}

@end


#pragma mark -
// Delegate Default Implementations
#pragma mark Delegate Default Implementations

@implementation NSObject (MUPhotoViewDelegate)

// will only get called if photoArray has not been set, or has not been bound
- (unsigned)photoCountForPhotoView:(MUPhotoView *)view
{
    return 0;
}

- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)index
{
    return nil;
}

- (NSImage *)photoView:(MUPhotoView *)view fastPhotoAtIndex:(unsigned)index
{
    return [self photoView:view photoAtIndex:index];
}

// selection
- (NSIndexSet *)selectionIndexesForPhotoView:(MUPhotoView *)view
{
    return [NSIndexSet indexSet];
}

- (NSIndexSet *)photoView:(MUPhotoView *)view willSetSelectionIndexes:(NSIndexSet *)indexes
{
    return indexes;
}

- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
    return;
}

// drag and drop
- (unsigned int)photoView:(MUPhotoView *)view draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    return NSDragOperationNone;
}

- (NSArray *)pasteboardDragTypesForPhotoView:(MUPhotoView *)view
{
    return [[[NSArray alloc] init] autorelease];
}

- (NSData *)photoView:(MUPhotoView *)view pasteboardDataForPhotoAtIndex:(unsigned)index dataType:(NSString *)type
{
    return nil;
}

// double-click
- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)index
{
    
}

// photo removal support
- (NSIndexSet *)photoView:(MUPhotoView *)view willRemovePhotosAtIndexes:(NSIndexSet *)indexes
{
    return [NSIndexSet indexSet];
}

- (void)photoView:(MUPhotoView *)view didRemovePhotosAtIndexes:(NSIndexSet *)indexes
{
    
}

@end

#pragma mark -
// Private
#pragma mark Private

@implementation MUPhotoView (PrivateAPI)

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent
{
	NSPoint mouseEventLocation;

	mouseEventLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];

	unsigned clickedIndex = [self photoIndexForPoint:mouseEventLocation];
	NSRect photoRect = [self photoRectForIndex:clickedIndex];

	return(NSPointInRect(mouseEventLocation, photoRect));
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	// CEsfahani - If acceptsFirstMouse unconditionally returns YES, then it is possible to lose the selection if
	// the user clicks in the content of the window without hitting one of the selected images.  This is
	// the Finder's behavior, and it bothers me.
	// It seems I have two options: unconditionally return YES, or only return YES if we clicked in an image.
	// But, does anyone rely on losing the selection if I bring a window forward?

	NSPoint mouseEventLocation;

	mouseEventLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];

	unsigned clickedIndex = [self photoIndexForPoint:mouseEventLocation];
	NSRect photoRect = [self photoRectForIndex:clickedIndex];

	return NSPointInRect(mouseEventLocation, photoRect);
}

- (void)viewDidEndLiveResize
{
    [self setNeedsDisplayInRect:[self visibleRect]];
}

- (void)setFrame:(NSRect)frame
{
    float width = [self frame].size.width;
    [super setFrame:frame];
    
    if (width != frame.size.width) {
        // update internal grid size, adjust height based on the new grid size
        [self setNeedsDisplayInRect:[self visibleRect]];    
    }
}

- (void)updateGridAndFrame
{
    /**** BEGIN Dimension calculations and adjustments ****/
    
    // get the number of photos
    unsigned photoCount = [self photoCount];
    
    // calculate the base grid size
    gridSize.height = [self photoSize] + [self photoVerticalSpacing];
    gridSize.width = [self photoSize] + [self photoHorizontalSpacing];
    
    // if there are no photos, return
    if (0 == photoCount) {
        columns = 0;
        rows = 0;
        float width = [self frame].size.width;
        float height = [[[self enclosingScrollView] contentView] frame].size.height;
        [self setFrameSize:NSMakeSize(width, height)];
        return;
    }
    
    // calculate the number of columns (ivar)
    float width = [self frame].size.width;
    columns = width / gridSize.width;
    
    // minimum 1 column
    if (1 > columns)
        columns = 1;
    
    // if we have fewer photos than columns, adjust downward
    if (photoCount < columns)
        columns = photoCount;
    
    // adjust the grid size width for extra space
    gridSize.width += (width - (columns * gridSize.width)) / columns;
    
    // calculate the number of rows of photos based on the total count and the number of columns (ivar)
    rows = photoCount / columns;
    if (0 < (photoCount % columns))
        rows++;
    // adjust my frame height to contain all the photos
    float height = rows * gridSize.height;
    NSScrollView *scroll = [self enclosingScrollView];
    if ((nil != scroll) && (height < [[scroll contentView] frame].size.height))
        height = [[scroll contentView] frame].size.height;
    
    // set my new frame size
    [self setFrameSize:NSMakeSize(width, height)];
    
    /**** END Dimension calculations and adjustments ****/
    
}

// will fetch from the internal array if not nil, from delegate otherwise
- (unsigned)photoCount
{
    if (nil != [self photosArray])
        return [[self photosArray] count];
    else if (nil != delegate)
        return [delegate photoCountForPhotoView:self];
    else
        return 0;
}

- (NSImage *)photoAtIndex:(unsigned)index
{
    if ((nil != [self photosArray]) && (index < [self photoCount]))
        return [[self photosArray] objectAtIndex:index];
    else if ((nil != delegate) && (index < [self photoCount]))
        return [delegate photoView:self photoAtIndex:index];
    else
        return nil;
}

- (void)updatePhotoResizing
{
    NSTimeInterval timeSinceResize = [[NSDate date] timeIntervalSinceReferenceDate] - [photoResizeTime timeIntervalSinceReferenceDate];
    if (timeSinceResize > 1) {
        isDonePhotoResizing = YES;
        [photoResizeTimer invalidate];
        photoResizeTimer = nil;
    }
    [self setNeedsDisplayInRect:[self visibleRect]];
}

- (BOOL)inLiveResize
{
    return ([super inLiveResize]) || (!isDonePhotoResizing);
}

- (NSImage *)fastPhotoAtIndex:(unsigned)index
{
    NSImage *fastPhoto;
    if ((nil != [self photosArray]) && (index < [[self photosArray] count]))
    {
        fastPhoto = [photosFastArray objectAtIndex:index];
        if ((NSNull *)fastPhoto == [NSNull null])
        {
			// Change this if you want higher/lower quality fast photos
			float fastPhotoSize = 100.0;
			
			NSImageRep *fullSizePhotoRep = [[self scalePhoto:[self photoAtIndex:index]] bestRepresentationForDevice:nil];
	        
			// Figure out what the scaled size is
			float longSide = [fullSizePhotoRep pixelsWide];
	        if (longSide < [fullSizePhotoRep pixelsHigh])
	            longSide = [fullSizePhotoRep pixelsHigh];

	        float scale = fastPhotoSize / longSide;

	        NSSize scaledSize;
	        scaledSize.width = [fullSizePhotoRep pixelsWide] * scale;
	        scaledSize.height = [fullSizePhotoRep pixelsHigh] * scale;

			// Draw the full-size image into our fast, small image.
	        fastPhoto = [[NSImage alloc] initWithSize:scaledSize];
	        [fastPhoto setFlipped:YES];
	        [fastPhoto lockFocus];
	        [fullSizePhotoRep drawInRect:NSMakeRect(0.0, 0.0, scaledSize.width, scaledSize.height)];
	        [fastPhoto unlockFocus];

			// Save it off
            [photosFastArray replaceObjectAtIndex:index withObject:fastPhoto];
			
			[fastPhoto autorelease];
        }
    } else if ((nil != delegate) && ([delegate respondsToSelector:@selector(photoView:fastPhotoAtIndex:)])) {
        fastPhoto = [delegate photoView:self fastPhotoAtIndex:index];
    }
    
    // if the above calls failed, try to just fetch the full size image
    if (nil == fastPhoto) {
        fastPhoto = [self photoAtIndex:index];
    }
    
    return fastPhoto;
}


// placement and hit detection
- (NSSize)scaledPhotoSizeForSize:(NSSize)size
{
    float longSide = size.width;
    if (longSide < size.height)
        longSide = size.height;
    
    float scale = [self photoSize] / longSide;
    
    NSSize scaledSize;
    scaledSize.width = size.width * scale;
    scaledSize.height = size.height * scale;
    
    return scaledSize;
}

- (NSImage *)scalePhoto:(NSImage *)image
{
    // calculate the new image size based on the scale
    NSSize newSize;
    NSImageRep *bestRep = [image bestRepresentationForDevice:nil];
    newSize.width = [bestRep pixelsWide];
    newSize.height = [bestRep pixelsHigh];
    
    // resize the image
    [image setScalesWhenResized:YES];
    [image setSize:newSize];
    
    return image;
}

- (unsigned)photoIndexForPoint:(NSPoint)point
{
	unsigned column = point.x / gridSize.width;
	unsigned row = point.y / gridSize.height;
	
	return ((row * columns) + column);
}

- (NSRange)photoIndexRangeForRect:(NSRect)rect
{
    unsigned start = [self photoIndexForPoint:rect.origin];
	unsigned finish = [self photoIndexForPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
	
    if (finish >= [self photoCount])
        finish = [self photoCount] - 1;
    
	return NSMakeRange(start, finish-start);
    
}

- (NSRect)gridRectForIndex:(unsigned)index
{
	unsigned row = index / columns;
	unsigned column = index % columns;
	float x = column * gridSize.width;
	float y = row * gridSize.height;
	
	return NSMakeRect(x, y, gridSize.width, gridSize.height);
}

- (NSRect)rectCenteredInRect:(NSRect)rect withSize:(NSSize)size
{
    float x = rect.origin.x + ((rect.size.width - size.width) / 2);
    float y = rect.origin.y + ((rect.size.height - size.height) / 2);
    
    return NSMakeRect(x, y, size.width, size.height);
}

- (NSRect)photoRectForIndex:(unsigned)index
{
	if ([self photoCount] == 0)
        return NSZeroRect;

    // get the grid rect for this index
    NSRect gridRect = [self gridRectForIndex:index];
    
    // get the actual image
    NSImage *photo = [self photoAtIndex:index];
    if (nil == photo)
        return NSZeroRect;
    
    // scale to the current photoSize
    photo = [self scalePhoto:photo];
    
    // scale the dimensions
    NSSize scaledSize = [self scaledPhotoSizeForSize:[photo size]];
    
    // get the photo rect centered in the grid
    NSRect photoRect = [self rectCenteredInRect:gridRect withSize:scaledSize];
    
    return photoRect;
}

// selection
- (BOOL)isPhotoSelectedAtIndex:(unsigned)index;
{
    if (0 < [dragSelectedPhotoIndexes count]) {
        if ([dragSelectedPhotoIndexes containsIndex:index])
            return YES;
    } else if ((nil != [self selectedPhotoIndexes]) && [[self selectedPhotoIndexes] containsIndex:index])
        return YES;
    else if (nil != delegate) 
        return [[delegate selectionIndexesForPhotoView:self] containsIndex:index];
    
    
    return NO;
}

- (NSIndexSet *)selectionIndexes
{
    if (nil != [self selectedPhotoIndexes])
        return [self selectedPhotoIndexes];
    else if (nil != delegate)
        return [delegate selectionIndexesForPhotoView:self];
    else
        return nil;
}

- (void)setSelectionIndexes:(NSIndexSet *)indexes
{
	NSMutableIndexSet *oldSelection = nil;
	
	// Set the new selection, but save the old selection so we know exactly what to redraw
    if (nil != [self selectedPhotoIndexes])
    {
    	oldSelection = [[self selectedPhotoIndexes] retain];
		[self setSelectedPhotoIndexes:indexes];
    } 
	else if (nil != delegate)
	{
		// We have to iterate through the photos to figure out which ones the delegate thinks are selected - that's the only way to know the old selection when in delegate mode
		oldSelection = [[NSMutableIndexSet alloc] init];
		int i, count = [self photoCount];
		for( i = 0; i < count; i += 1 )
		{
			if ([self isPhotoSelectedAtIndex:i])
			{
				[oldSelection addIndex:i];
			}
		}
		
		// Now update the selection
		indexes = [delegate photoView:self willSetSelectionIndexes:indexes];
		[delegate photoView:self didSetSelectionIndexes:indexes];
	}
	
	[self dirtyDisplayRectsForNewSelection:indexes oldSelection:oldSelection];
	[oldSelection release];
}

- (NSBezierPath *)shadowBoxPathForRect:(NSRect)rect
{
    NSRect inset = NSInsetRect(rect,5.0,5.0);
    float radius = 15.0;
    
    float minX = NSMinX(inset);
    float midX = NSMidX(inset);
    float maxX = NSMaxX(inset);
    float minY = NSMinY(inset);
    float midY = NSMidY(inset);
    float maxY = NSMaxY(inset);
    
    NSBezierPath *path = [[NSBezierPath alloc] init];
    [path moveToPoint:NSMakePoint(midX, minY)];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(maxX,minY) toPoint:NSMakePoint(maxX,midY) radius:radius];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(maxX,maxY) toPoint:NSMakePoint(midX,maxY) radius:radius];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(minX,maxY) toPoint:NSMakePoint(minX,midY) radius:radius];
    [path appendBezierPathWithArcFromPoint:NSMakePoint(minX,minY) toPoint:NSMakePoint(midX,minY) radius:radius];
    
    return [path autorelease];
    
}

// photo removal
- (void)removePhotosAtIndexes:(NSIndexSet *)indexes
{
    // let the delegate know that we're about to delete, give it a chance to modify the indexes we'll delete
    NSIndexSet *modifiedIndexes = indexes;
    if ((nil != delegate) && ([delegate respondsToSelector:@selector(photoView:willRemovePhotosAtIndexes:)])) {
        modifiedIndexes = [delegate photoView:self willRemovePhotosAtIndexes:indexes];
    }
    
    // if using bindings, do the removal
    if ((0 < [modifiedIndexes count]) && (nil != [self photosArray])) {
        [self willChangeValueForKey:@"photosArray"];
        [photosArray removeObjectsAtIndexes:modifiedIndexes];
        [self didChangeValueForKey:@"photosArray"];
    }
    
    if ((nil != delegate) && ([delegate respondsToSelector:@selector(photoView:didRemovePhotosAtIndexes:)])) {
        [delegate photoView:self didRemovePhotosAtIndexes:modifiedIndexes];
    }
    
    // update the selection
    NSMutableIndexSet *remaining = [[self selectionIndexes] mutableCopy];
    [remaining removeIndexes:modifiedIndexes];
    [self setSelectionIndexes:remaining];
    [remaining release];
}

- (NSImage *)scaleImage:(NSImage *)image toSize:(float)size
{
    NSImageRep *fullSizePhotoRep = [[self scalePhoto:image] bestRepresentationForDevice:nil];

    float longSide = [fullSizePhotoRep pixelsWide];
    if (longSide < [fullSizePhotoRep pixelsHigh])
        longSide = [fullSizePhotoRep pixelsHigh];
        
    float scale = size / longSide;
        
    NSSize scaledSize;
    scaledSize.width = [fullSizePhotoRep pixelsWide] * scale;
    scaledSize.height = [fullSizePhotoRep pixelsHigh] * scale;
        
    NSImage *fastPhoto = [[NSImage alloc] initWithSize:scaledSize];
    [fastPhoto setFlipped:YES];
    [fastPhoto lockFocus];
    [fullSizePhotoRep drawInRect:NSMakeRect(0.0, 0.0, scaledSize.width, scaledSize.height)];
    [fastPhoto unlockFocus];
        
    return [fastPhoto autorelease];
}

- (void)dirtyDisplayRectsForNewSelection:(NSIndexSet *)newSelection oldSelection:(NSIndexSet *)oldSelection
{
	NSRect visibleRect = [self visibleRect];
	
    // Figure out how the selection changed and only update those areas of the grid
	NSMutableIndexSet *changedIndexes = [NSMutableIndexSet indexSet];
	if (oldSelection && newSelection)
	{
		// First, see which of the old are different than the new
		unsigned int index = [newSelection firstIndex];
		
		while (index != NSNotFound)
		{
			if (![oldSelection containsIndex:index])
			{
				[changedIndexes addIndex:index];
			}
			index = [newSelection indexGreaterThanIndex:index];
		}
			
		// Next, see which of the new are different from the old
		index = [oldSelection firstIndex];
		while (index != NSNotFound)
		{
			if (![newSelection containsIndex:index])
			{
				[changedIndexes addIndex:index];
			}
			index = [oldSelection indexGreaterThanIndex:index];
		}
			
		// Loop through the changes and dirty the rect for each
		index = [changedIndexes firstIndex];
		while (index != NSNotFound)
		{
			NSRect photoRect = [self gridRectForIndex:index];
			if (NSIntersectsRect(visibleRect, photoRect))
			{
				[self setNeedsDisplayInRect:photoRect];
			}
			index = [changedIndexes indexGreaterThanIndex:index];
		}
			
	}
	else
	{
		[self setNeedsDisplayInRect:visibleRect];
	}
		
}

@end

