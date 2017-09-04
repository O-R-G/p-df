//
//  TiledPDFView+Links.h
//  LinksNavigation
//
//  Created by Sorin Nistor on 6/21/11.
//  Copyright 2011 iPDFdev.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TiledPDFView.h"

@interface TiledPDFView (Links)

- (void)renderPDFPageInContext: (CGContextRef)context;
- (CGPoint)convertViewPointToPDFPoint:(CGPoint)viewPoint;
- (CGPoint)convertPDFPointToViewPoint:(CGPoint)pdfPoint;
- (void)loadPageLinks:(CGPDFPageRef)page;    

@end
