//
//  PDFLinkAnnotation.h
//  LinksNavigation
//
//  Created by Sorin Nistor on 6/11/11.
//  Copyright 2011 iPDFdev.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PDFLinkAnnotation : NSObject {
    CGPDFDictionaryRef annotationDictionary;
    CGRect pdfRectangle;
}

@property (readonly, assign) CGRect pdfRectangle;

- (id)initWithPDFDictionary:(CGPDFDictionaryRef)newAnnotationDictionary;
- (BOOL)hitTest:(CGPoint)point;
- (NSObject*)getLinkTarget:(CGPDFDocumentRef)document;
- (CGPDFArrayRef)findDestinationByName:(const char *)destinationName inDestsTree:(CGPDFDictionaryRef)node;

@end
