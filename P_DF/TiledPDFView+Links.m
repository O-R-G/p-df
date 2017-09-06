//
//  TiledPDFView+Links.m
//  LinksNavigation
//
//  Created by Sorin Nistor on 6/21/11.
//  Copyright 2011 iPDFdev.com. All rights reserved.
//

#import "TiledPDFView+Links.h"
#import "PDFPageRenderer.h"
#import "PDFLinkAnnotation.h"


@implementation TiledPDFView (Links)

- (void)renderPDFPageInContext: (CGContextRef)context {
	pageRenderRect = [PDFPageRenderer renderPage: pdfPage inContext: context inRectangle: self.bounds];
    
    // float yellowComponents[4] = { 1.0, 1.0, 0.0, 1.0 };
    
    CGFloat yellowComponents[4] = { 1, 1, 0, 1 };
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    // CGContextSetStrokeColorSpace(context, rgbColorSpace);
    CGContextSetFillColorSpace(context, rgbColorSpace);
    CGColorRef yellow = CGColorCreate(rgbColorSpace, yellowComponents);
    // CGContextSetStrokeColorWithColor(context, yellow);
    CGContextSetFillColorWithColor(context, yellow);

    for (int i = 0; i < [pageLinks count]; i++) {
        PDFLinkAnnotation *linkAnnotation = [pageLinks objectAtIndex: i];
        CGPoint pt1 = [self convertPDFPointToViewPoint: linkAnnotation.pdfRectangle.origin];
        CGPoint pt2 = CGPointMake(
                                  linkAnnotation.pdfRectangle.origin.x + linkAnnotation.pdfRectangle.size.width, 
                                  linkAnnotation.pdfRectangle.origin.y + linkAnnotation.pdfRectangle.size.height);
        pt2 = [self convertPDFPointToViewPoint: pt2];
        
        CGRect linkRectangle = CGRectMake(pt1.x, pt1.y, pt2.x - pt1.x, pt2.y - pt1.y);
        CGContextAddRect(context, linkRectangle);

        // CGContextStrokePath(context);
        // CGContextFillPath(context);
    }
    
    // CGColorRelease(yellow);
    // CGColorSpaceRelease(rgbColorSpace);
}

- (IBAction)handleUserTap:(UIGestureRecognizer *)sender {
    CGPoint tapPosition = [sender locationInView:sender.view.superview];
    
    CGPoint pdfPosition = [self convertViewPointToPDFPoint: tapPosition];
    
    // Test if there is a link annotation at the point.
    // The z-order for the links is defined by the link position in the pageLinks array.
    // The last link in the array is the top most.
    for (int i = (int)[pageLinks count] - 1; i >= 0; i--) {
        PDFLinkAnnotation *link = [pageLinks objectAtIndex: i];
        if ([link hitTest: pdfPosition]) {
            CGPDFDocumentRef document = CGPDFPageGetDocument(pdfPage);
            NSObject *linkTarget = [link getLinkTarget: document];
            if (linkTarget != nil) {
                if ([linkTarget isKindOfClass:[NSNumber class]]) {
                    NSNumber *targetPageNumber = (NSNumber *)linkTarget;
                    CGPDFPageRef targetPage = CGPDFDocumentGetPage(document, [targetPageNumber intValue]);
                    if (targetPage != NULL) {
                        [self setPage: targetPage];
                        [self setNeedsDisplay];
                    }
                } else {
                    if ([linkTarget isKindOfClass: [NSString class]]) {
                        NSString *linkUri = (NSString *)linkTarget;
                        NSURL *url = [NSURL URLWithString: linkUri];
                        // force orientation change before opening safari so that "back to p!df appears
                        [UIViewController attemptRotationToDeviceOrientation]; 
                        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                            if (success) {
                                NSLog(@"Opened url");
                            }
                        }];
                    }
                }
            }
            break;
        }
    }
}

- (void)loadPageLinks:(CGPDFPageRef)page {
    CGPDFDictionaryRef pageDictionary = CGPDFPageGetDictionary(page);
    CGPDFArrayRef annotsArray = NULL;
    
    // PDF links are link annotations stored in the page's Annots array.
    CGPDFDictionaryGetArray(pageDictionary, "Annots", &annotsArray);
    if (annotsArray != NULL) {
        NSUInteger annotsCount = CGPDFArrayGetCount(annotsArray);
        
        for (int j = 0; j < annotsCount; j++) {
            CGPDFDictionaryRef annotationDictionary = NULL;            
            if (CGPDFArrayGetDictionary(annotsArray, j, &annotationDictionary)) {
                const char *annotationType;
                CGPDFDictionaryGetName(annotationDictionary, "Subtype", &annotationType);
                
                // Link annotations are identified by Link name stored in Subtype key in annotation dictionary.
                if (strcmp(annotationType, "Link") == 0) {
                    PDFLinkAnnotation *linkAnnotation = [[PDFLinkAnnotation alloc] initWithPDFDictionary: annotationDictionary];
                    [pageLinks addObject: linkAnnotation];
                    // [linkAnnotation release];
                }
            }
        }
    }
}

- (CGPoint)convertViewPointToPDFPoint:(CGPoint)viewPoint {
    CGPoint pdfPoint = CGPointMake(0, 0);
    
    CGRect cropBox = CGPDFPageGetBoxRect(pdfPage, kCGPDFCropBox);
    
    int rotation = CGPDFPageGetRotationAngle(pdfPage);
    
    switch (rotation) {
        case 90:
        case -270:
            pdfPoint.x = cropBox.size.width * (viewPoint.y - pageRenderRect.origin.y) / pageRenderRect.size.height;
            pdfPoint.y = cropBox.size.height * (viewPoint.x - pageRenderRect.origin.x) / pageRenderRect.size.width;
            break;
        case 180:
        case -180:
            pdfPoint.x = cropBox.size.width * (pageRenderRect.size.width - (viewPoint.x - pageRenderRect.origin.x)) / pageRenderRect.size.width;
            pdfPoint.y = cropBox.size.height * (viewPoint.y - pageRenderRect.origin.y) / pageRenderRect.size.height;
            break;
        case -90:
        case 270:
            pdfPoint.x = cropBox.size.width * (pageRenderRect.size.height - (viewPoint.y - pageRenderRect.origin.y)) / pageRenderRect.size.height;
            pdfPoint.y = cropBox.size.height * (pageRenderRect.size.width - (viewPoint.x - pageRenderRect.origin.x)) / pageRenderRect.size.width;
            break;
        case 0:
        default:
            pdfPoint.x = cropBox.size.width * (viewPoint.x - pageRenderRect.origin.x) / pageRenderRect.size.width;
            pdfPoint.y = cropBox.size.height * (pageRenderRect.size.height - (viewPoint.y - pageRenderRect.origin.y)) / pageRenderRect.size.height;
            break;
    }
    
    pdfPoint.x = pdfPoint.x + cropBox.origin.x;
    pdfPoint.y = pdfPoint.y+ cropBox.origin.y;
    
    return pdfPoint;
}

- (CGPoint)convertPDFPointToViewPoint:(CGPoint)pdfPoint {
    CGPoint viewPoint = CGPointMake(0, 0);
    
    CGRect cropBox = CGPDFPageGetBoxRect(pdfPage, kCGPDFCropBox);
    
    int rotation = CGPDFPageGetRotationAngle(pdfPage);
    
    switch (rotation) {
        case 90:
        case -270:
            viewPoint.x = pageRenderRect.size.width * (pdfPoint.y - cropBox.origin.y) / cropBox.size.height;
            viewPoint.y = pageRenderRect.size.height * (pdfPoint.x - cropBox.origin.x) / cropBox.size.width;
            break;
        case 180:
        case -180:
            viewPoint.x = pageRenderRect.size.width * (cropBox.size.width - (pdfPoint.x - cropBox.origin.x)) / cropBox.size.width;
            viewPoint.y = pageRenderRect.size.height * (pdfPoint.y - cropBox.origin.y) / cropBox.size.height;
            break;
        case -90:
        case 270:
            viewPoint.x = pageRenderRect.size.width * (cropBox.size.height - (pdfPoint.y - cropBox.origin.y)) / cropBox.size.height;
            viewPoint.y = pageRenderRect.size.height * (cropBox.size.width - (pdfPoint.x - cropBox.origin.x)) / cropBox.size.width;
            break;
        case 0:
        default:
            viewPoint.x = pageRenderRect.size.width * (pdfPoint.x - cropBox.origin.x) / cropBox.size.width;
            viewPoint.y = pageRenderRect.size.height * (cropBox.size.height - (pdfPoint.y - cropBox.origin.y)) / cropBox.size.height;
            break;
    }
    
    viewPoint.x = viewPoint.x + pageRenderRect.origin.x;
    viewPoint.y = viewPoint.y + pageRenderRect.origin.y;
    
    return viewPoint;
}

@end
