//
//  PDFPageRenderer.h
//
//  Created by Sorin Nistor on 3/21/11.
//  Copyright 2011 iPDFdev.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PDFPageRenderer : NSObject {
}

+ (CGSize) renderPage: (CGPDFPageRef) page inContext: (CGContextRef) context;
+ (CGSize) renderPage: (CGPDFPageRef) page inContext: (CGContextRef) context atPoint: (CGPoint) point;
+ (CGSize) renderPage: (CGPDFPageRef) page inContext: (CGContextRef) context atPoint: (CGPoint) point withZoom: (float) zoom;
+ (CGRect) renderPage: (CGPDFPageRef) page inContext: (CGContextRef) context inRectangle: (CGRect) rectangle;

@end
