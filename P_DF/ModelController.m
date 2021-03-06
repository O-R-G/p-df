/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This view controller manages the display of a set of view controllers by way of implementing the UIPageViewControllerDataSource protocol.
 
 The controller serves as the data source for the page view controller; it therefore implements pageViewController:viewControllerBeforeViewController: and pageViewController:viewControllerAfterViewController:.
 
 It also implements a custom method, viewControllerAtIndex: which is useful in the implementation of the data source methods, and in the initial configuration of the application.
 
 There is no need to actually create view controllers for each page in advance -- indeed doing so incurs unnecessary overhead. Given the data model, these methods create, configure, and return a new view controller on demand.
 */


#import "ModelController.h"
#import "DataViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ModelController ()
{
    AVAudioPlayer *_audioPlayerStartup;
}
@end

@implementation ModelController

- (id)init
{
    self = [super init];
    if ( self ) {
        // Create the data model.
        NSURL *pdfURL = [[NSBundle mainBundle] URLForResource:@"input.pdf" withExtension:nil];
        if ( pdfURL != nil )
        {
            self.pdf = CGPDFDocumentCreateWithURL( (__bridge CFURLRef) pdfURL );
            self.numberOfPages = (int)CGPDFDocumentGetNumberOfPages( self.pdf );
            if ( self.numberOfPages % 2 ) self.numberOfPages++;
        } else {
            // missing pdf file, cannot proceed.
            NSLog(@"missing pdf file input.pdf");
            abort(); /* as per Technical Q&A QA1561: How do I programmatically quit my iOS application?*/
        }

        // Create audio player object and initialize with URL startup sound, play that, then load page-flip
    
        NSURL *startupsoundUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"startup" ofType:@"mp3"]];
        // NSURL *startupsoundUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Qasim Naqvi - Chronology 20160424 - 41° - 74° - 01 Chronology Part 1" ofType:@"mp3"]];
        _audioPlayerStartup = [[AVAudioPlayer alloc] initWithContentsOfURL:startupsoundUrl error:nil];

        [_audioPlayerStartup play];
    }
    return self;
}

- (void)dealloc
{
    if ( self.pdf != NULL )
    {
        CGPDFDocumentRelease( self.pdf );
    }
}

- (DataViewController *)viewControllerAtIndex:(NSUInteger)index storyboard:(UIStoryboard *)storyboard
{
    // Create a new view controller and pass suitable data.
    DataViewController *dataViewController = [storyboard instantiateViewControllerWithIdentifier:@"DataViewController"];
    dataViewController.pageNumber = (int)index + 1;
    dataViewController.pdf = self.pdf;
    
    return dataViewController;
}

- (NSUInteger)indexOfViewController:(DataViewController *)viewController
{   
     // Return the index of the given data view controller.
     // For simplicity, this implementation uses a static array of model objects and the view controller stores the model object; you can therefore use the model object to identify the index.
    
    return viewController.pageNumber - 1;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    NSUInteger index = [self indexOfViewController:(DataViewController *)viewController];
    if ( (index == 0) || (index == NSNotFound) )
    {
        return nil;
    }
    index--;
    return [self viewControllerAtIndex:index storyboard:viewController.storyboard];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    NSUInteger index = [self indexOfViewController:(DataViewController *)viewController];
    if ( index == NSNotFound )
    {
        return nil;
    }
    index++;
    if ( index == self.numberOfPages )
    {
        return nil;
    }
    return [self viewControllerAtIndex:index storyboard:viewController.storyboard];
}

@end
