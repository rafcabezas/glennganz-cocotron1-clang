/* Copyright (c) 2013 Raf Cabezas

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#import <objc/runtime.h>
#import "objc_class.h"
#import <Foundation/Foundation.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSMutableDictionary.h>
#import <CoreFoundation/CFDictionary.h>

/* Based on code from http://stackoverflow.com/questions/1916130/objc-setassociatedobject-unavailable-in-iphone-simulator */

@implementation NSObject (OTAssociatedObjectsSimulator)

static CFMutableDictionaryRef theDictionaries = nil;

static void Swizzle(Class c, SEL orig, SEL new) // swizzling by Mike Ash
{
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if (class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

- (NSMutableDictionary *)otAssociatedObjectsDictionary
{
    if (!theDictionaries)
    {
        theDictionaries = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        Swizzle([NSObject class], @selector(dealloc), @selector(otAssociatedObjectDealloc));
    }
    
    NSMutableDictionary *dictionary = (id)CFDictionaryGetValue(theDictionaries, self);
    if (!dictionary)
    {
        dictionary = [NSMutableDictionary dictionary];
        CFDictionaryAddValue(theDictionaries, self, dictionary);
    }
    
    return dictionary;
}

- (void)otAssociatedObjectDealloc
{
    CFDictionaryRemoveValue(theDictionaries, self);
    [self otAssociatedObjectDealloc];
}

@end

void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy)
{
    NSCAssert(policy == OBJC_ASSOCIATION_RETAIN_NONATOMIC, @"Only OBJC_ASSOCIATION_RETAIN_NONATOMIC supported");
    
    [[object otAssociatedObjectsDictionary] setObject:value forKey:[NSValue valueWithPointer:key]];
}

id objc_getAssociatedObject(id object, const void *key)
{
    return [[object otAssociatedObjectsDictionary] objectForKey:[NSValue valueWithPointer:key]];
}

void objc_removeAssociatedObjects(id object)
{
    [[object otAssociatedObjectsDictionary] removeAllObjects];
}
