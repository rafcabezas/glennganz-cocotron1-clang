#import <objc/runtime.h>
#import <string.h>
#import <stddef.h>
#import <stdlib.h>
#import <ctype.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSRaiseException.h>

#define ACCESSORS_HASH(POINTER) ((((size_t)POINTER >> 8) ^ (size_t)POINTER))

//raf- Based on libobjc's implementation from: libobj http://gcc.gnu.org/svn/gcc/branches/cilkplus/libobjc

/* The property accessors automatically call various methods from the
 Foundation library (eg, GNUstep-base).  These methods are not
 implemented here, but we need to declare them so we can compile the
 runtime.  The Foundation library will need to provide
 implementations of these methods (most likely in the root class,
 eg, NSObject) as the accessors only work with objects of classes
 that implement these methods.  */
@interface _libobjcNSObject
- (id) copyWithZone: (void *)zone;
- (id) mutableCopyWithZone: (void *)zone;
@end
#define COPY(X)         [((_libobjcNSObject *)(X)) copyWithZone: NULL]
#define MUTABLE_COPY(X) [((_libobjcNSObject *)(X)) mutableCopyWithZone: NULL]


#if OBJC_WITH_GC

#  define AUTORELEASE(X)  (X)
#  define RELEASE(X)
#  define RETAIN(X)       (X)

#else

@interface _libobjcNSObject (RetainReleaseMethods)
- (id) autorelease;
- (oneway void) release;
- (id) retain;
@end
#  define AUTORELEASE(X)  [((_libobjcNSObject *)(X)) autorelease]
#  define RELEASE(X)      [((_libobjcNSObject *)(X)) release]
#  define RETAIN(X)       [((_libobjcNSObject *)(X)) retain]

#endif


const char *property_getAttributes(objc_property_t property){
   return property->attributes;
}

const char *property_getName(objc_property_t property) {
   return property->name;
}

id objc_assign_ivar(id self,id value,unsigned int offset){
//   NSCLog("objc_assign_ivar(%x,%s,%x,%s,%d)",self,(self!=nil)?self->isa->name:"nil",value,(value!=nil)?value->isa->name:"nil",offset);
   id *ivar=(id *)(((uint8_t *)self)+offset);
   return *ivar=value;
}

/* This is the function that the Apple/NeXT runtime has instead of
 objc_getPropertyStruct and objc_setPropertyStruct.  We include it
 for API compatibility (just for people who may have used
 objc_copyStruct on the NeXT runtime thinking it was a public API);
 the compiler never generates calls to it with the GNU runtime.
 This function is clumsy because it requires two locks instead of
 one.  */
void
objc_copyStruct (void *destination, const void *source, size_t size, BOOL is_atomic, BOOL __attribute__((unused)) has_strong)
{
    if (is_atomic == NO)
        memcpy (destination, source, size);
    else
    {
        /* We don't know which one is the property, so we have to lock
         both.  One of them is most likely a temporary buffer in the
         local stack and we really wouldn't want to lock it (our
         objc_getPropertyStruct and objc_setPropertyStruct functions
         don't lock it).  Note that if we're locking more than one
         accessor lock at once, we need to always lock them in the
         same order to avoid deadlocks.  */
        
        if (ACCESSORS_HASH (source) == ACCESSORS_HASH (destination))
        {
            /* A lucky collision.  */
            @synchronized((void *)source) {
                memcpy ((void *)destination, source, size);
            }
            return;
        }
        
        if (ACCESSORS_HASH (source) > ACCESSORS_HASH (destination))
        {
            @synchronized((void *)source) {
                @synchronized((void *)destination) {
                    memcpy (destination, source, size);
                }
            }
        }
        else
        {
            @synchronized((void *)destination) {
                @synchronized((void *)source) {
                    memcpy (destination, source, size);
                }
            }
        }
    }
}

/* The compiler uses this function when implementing some synthesized
 setters for properties of type 'id'.
 
 PS: Note how 'should_copy' is declared 'BOOL' but then actually
 takes values from 0 to 2.  This hack was introduced by Apple; we
 do the same for compatibility reasons.  */
void
objc_setProperty (id self, SEL __attribute__((unused)) _cmd, size_t offset, id new_value, BOOL is_atomic, BOOL should_copy)
{
    if (self != nil)
    {
        id *pointer_to_ivar = (id *)((char *)self + offset);
        id retained_value;
#if !OBJC_WITH_GC
        id old_value;
#endif
        
        switch (should_copy)
        {
            case 0: /* retain */
            {
                if (*pointer_to_ivar == new_value)
                    return;
                retained_value = RETAIN (new_value);
                break;
            }
            case 2: /* mutable copy */
            {
                retained_value = MUTABLE_COPY (new_value);
                break;
            }
            case 1: /* copy */
            default:
            {
                retained_value = COPY (new_value);
                break;
            }
        }
        
        if (is_atomic == NO)
        {
#if !OBJC_WITH_GC
            old_value = *pointer_to_ivar;
#endif
            *pointer_to_ivar = retained_value;
        }
        else
        {
            @synchronized((void *)pointer_to_ivar) {
#if !OBJC_WITH_GC
                old_value = *pointer_to_ivar;
#endif
                *pointer_to_ivar = retained_value;
            }
        }
#if !OBJC_WITH_GC
        RELEASE (old_value);
#endif
    }
}

/* The compiler uses this function when implementing some synthesized
 getters for properties of type 'id'.  */
id
objc_getProperty (id self, SEL __attribute__((unused)) _cmd, size_t offset, BOOL is_atomic)
{
    if (self != nil)
    {
        id *pointer_to_ivar = (id *)((char *)self + offset);
        
        
        if (is_atomic == NO)
        {
            /* Note that in this case, we do not RETAIN/AUTORELEASE the
             returned value.  The programmer should do it if it is
             needed.  Since access is non-atomic, other threads can be
             ignored and the caller has full control of what happens
             to the object and whether it needs to be RETAINed or not,
             so it makes sense to leave the decision to him/her.  This
             is also what the Apple/NeXT runtime does.  */
            return *pointer_to_ivar;
        }
        else
        {
            id result;
            @synchronized((void*)pointer_to_ivar) {
                result = RETAIN (*(pointer_to_ivar));
            }
            return AUTORELEASE (result);
        }
    }
    
    return nil;
}


/* The compiler uses this function when implementing some synthesized
 getters for properties of arbitrary C types.  The data is just
 copied.  Compatibility Note: this function does not exist in the
 Apple/NeXT runtime.  */
void
objc_getPropertyStruct (void *destination, const void *source, size_t size, BOOL is_atomic, BOOL __attribute__((unused)) has_strong)
{
    if (is_atomic == NO)
        memcpy (destination, source, size);
    else
    {
        @synchronized((void *)source) {
            memcpy (destination, source, size);
        }
    }
}

/* The compiler uses this function when implementing some synthesized
 setters for properties of arbitrary C types.  The data is just
 copied.  Compatibility Note: this function does not exist in the
 Apple/NeXT runtime.  */
void
objc_setPropertyStruct (void *destination, const void *source, size_t size, BOOL is_atomic, BOOL __attribute__((unused)) has_strong)
{
    if (is_atomic == NO)
        memcpy (destination, source, size);
    else
    {
        @synchronized(destination) {
            memcpy (destination, source, size);
        }
    }
}
