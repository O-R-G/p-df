//
//  PDFLinkAnnotation.m
//  LinksNavigation
//
//  Created by Sorin Nistor on 6/11/11.
//  Copyright 2011 iPDFdev.com. All rights reserved.
//

#import "PDFLinkAnnotation.h"


@implementation PDFLinkAnnotation

@synthesize pdfRectangle;

- (id)initWithPDFDictionary:(CGPDFDictionaryRef)newAnnotationDictionary {
    self = [super init];
    if (self) {
        self->annotationDictionary = newAnnotationDictionary;
        
        // Normalize and cache the annotation rect definition for faster hit testing.
        CGPDFArrayRef rectArray = NULL;
        CGPDFDictionaryGetArray(annotationDictionary, "Rect", &rectArray);
        if (rectArray != NULL) {
            CGPDFReal llx = 0;
            CGPDFArrayGetNumber(rectArray, 0, &llx);
            CGPDFReal lly = 0;
            CGPDFArrayGetNumber(rectArray, 1, &lly);
            CGPDFReal urx = 0;
            CGPDFArrayGetNumber(rectArray, 2, &urx);
            CGPDFReal ury = 0;
            CGPDFArrayGetNumber(rectArray, 3, &ury);
            
            if (llx > urx) {
                CGPDFReal temp = llx;
                llx = urx;
                urx = temp;
            }
            if (lly > ury) {
                CGPDFReal temp = lly;
                lly = ury;
                ury = temp;
            }
            
            pdfRectangle = CGRectMake(llx, lly, urx - llx, ury - lly);
        }
    }
    
    return self;
}

- (void)dealloc {
    self->annotationDictionary = NULL;
    // [super dealloc];
}

- (BOOL)hitTest:(CGPoint)point {
    if ((pdfRectangle.origin.x <= point.x) &&
        (pdfRectangle.origin.y <= point.y) &&
        (point.x <= pdfRectangle.origin.x + pdfRectangle.size.width) &&
        (point.y <= pdfRectangle.origin.y + pdfRectangle.size.height)) {
        return YES;
    } else {
        return NO;
    }
}

- (NSObject*)getLinkTarget:(CGPDFDocumentRef)document {
    NSObject *linkTarget = nil;
    
    // Link target can be stored either in A entry or in Dest entry in annotation dictionary.
    // Dest entry is the destination array that we're looking for. It can be a direct array definition
    // or a name. If it is a name, we need to search recursively for the corresponding destination array 
    // in document's Dests tree.
    // A entry is an action dictionary. There are many action types, we're looking for GoTo and URI actions.
    // GoTo actions are used for links within the same document. The GoTo action has a D entry which is the
    // destination array, same format like Dest entry in annotation dictionary or a destination name.
    // URI actions are used for links to web resources. The URI action has a 
    // URI entry which is the destination URL.
    // If both entries are present, A entry takes precedence.
    
    CGPDFArrayRef destArray = NULL;
    CGPDFStringRef destName = NULL;
    CGPDFDictionaryRef actionDictionary = NULL;
    
    if (CGPDFDictionaryGetDictionary(annotationDictionary, "A", &actionDictionary)) {
        const char* actionType;
        if (CGPDFDictionaryGetName(actionDictionary, "S", &actionType)) {
            if (strcmp(actionType, "GoTo") == 0) {
                // D entry can be either a string object or an array object.
                if (!CGPDFDictionaryGetArray(actionDictionary, "D", &destArray)) {
                    CGPDFDictionaryGetString(actionDictionary, "D", &destName);
                }
            }
            if (strcmp(actionType, "URI") == 0) {
                CGPDFStringRef uriRef = NULL;
                if (CGPDFDictionaryGetString(actionDictionary, "URI", &uriRef)) {
                    const char *uri = (const char *)CGPDFStringGetBytePtr(uriRef);
                    linkTarget = [[NSString alloc] initWithCString: uri encoding: NSASCIIStringEncoding];
                }
            }
        }
    } else {
        // Dest entry can be either a string object or an array object.
        if (!CGPDFDictionaryGetArray(annotationDictionary, "Dest", &destArray)) {
            CGPDFDictionaryGetString(annotationDictionary, "Dest", &destName);
        }
    }
    
    if (destName != NULL) {
        // Traverse the Dests tree to locate the destination array.
        CGPDFDictionaryRef catalogDictionary = CGPDFDocumentGetCatalog(document);
        CGPDFDictionaryRef namesDictionary = NULL;
        if (CGPDFDictionaryGetDictionary(catalogDictionary, "Names", &namesDictionary)) {
            CGPDFDictionaryRef destsDictionary = NULL;
            if (CGPDFDictionaryGetDictionary(namesDictionary, "Dests", &destsDictionary)) {
                const char *destinationName = (const char *)CGPDFStringGetBytePtr(destName);
                destArray = [self findDestinationByName: destinationName inDestsTree: destsDictionary];
            }
        }
    }
    
    if (destArray != NULL) {
        int targetPageNumber = 0;
        // First entry in the array is the page the links points to.
        CGPDFDictionaryRef pageDictionaryFromDestArray = NULL;
        if (CGPDFArrayGetDictionary(destArray, 0, &pageDictionaryFromDestArray)) {
            NSUInteger documentPageCount = CGPDFDocumentGetNumberOfPages(document);
            for (int i = 1; i <= documentPageCount; i++) {
                CGPDFPageRef page = CGPDFDocumentGetPage(document, i);
                CGPDFDictionaryRef pageDictionaryFromPage = CGPDFPageGetDictionary(page);
                if (pageDictionaryFromPage == pageDictionaryFromDestArray) {
                    targetPageNumber = i;
                    break;
                }
            }
        } else {
            // Some PDF generators use incorrectly the page number as the first element of the array 
            // instead of a reference to the actual page.
            CGPDFInteger pageNumber = 0;
            if (CGPDFArrayGetInteger(destArray, 0, &pageNumber)) {
                targetPageNumber = (int)pageNumber + 1;
            }
        }
        
        if (targetPageNumber > 0) {
            linkTarget = [[NSNumber alloc] initWithInt: targetPageNumber]; 
        }
    }
    
    // [linkTarget autorelease];
    return linkTarget;
}

- (CGPDFArrayRef)findDestinationByName:(const char *)destinationName inDestsTree:(CGPDFDictionaryRef)node {
    CGPDFArrayRef destinationArray = NULL;
    CGPDFArrayRef limitsArray = NULL;
    if (CGPDFDictionaryGetArray(node, "Limits", &limitsArray)) {
        CGPDFStringRef lowerLimit = NULL;
        CGPDFStringRef upperLimit = NULL;
        if (CGPDFArrayGetString(limitsArray, 0, &lowerLimit)) {
            if (CGPDFArrayGetString(limitsArray, 1, &upperLimit)) {
                const unsigned char *ll = CGPDFStringGetBytePtr(lowerLimit);
                const unsigned char *ul = CGPDFStringGetBytePtr(upperLimit);
                if ((strcmp(destinationName, (const char*)ll) < 0) ||
                    (strcmp(destinationName, (const char*)ul) > 0)) {
                    return NULL;
                }
            }
        }
    }
    
    CGPDFArrayRef namesArray = NULL;
    if (CGPDFDictionaryGetArray(node, "Names", &namesArray)) {
        NSUInteger namesCount = CGPDFArrayGetCount(namesArray);
        for (int i = 0; i < namesCount; i = i + 2) {
            CGPDFStringRef destName;
            if (CGPDFArrayGetString(namesArray, i, &destName)) {
                const unsigned char *dn = CGPDFStringGetBytePtr(destName);
                if (strcmp((const char*)dn, destinationName) == 0) {
                    if (!CGPDFArrayGetArray(namesArray, i + 1, &destinationArray)) {
                        CGPDFDictionaryRef destinationDictionary = NULL;
                        if (CGPDFArrayGetDictionary(namesArray, i + 1, &destinationDictionary)) {
                            CGPDFDictionaryGetArray(destinationDictionary, "D", &destinationArray);
                        }
                    }
                    
                    return destinationArray;
                }
            }
        }
    }
    
    CGPDFArrayRef kidsArray = NULL;
    if (CGPDFDictionaryGetArray(node, "Kids", &kidsArray)) {
        NSUInteger kidsCount = CGPDFArrayGetCount(kidsArray);
        for (int i = 0; i < kidsCount; i++) {
            CGPDFDictionaryRef kidNode = NULL;
            if (CGPDFArrayGetDictionary(kidsArray, i, &kidNode)) {
                destinationArray = [self findDestinationByName: destinationName inDestsTree: kidNode];
                if (destinationArray != NULL) {
                    return destinationArray;
                }
            }
        }
    }
    
    return NULL;
}

@end
