#if defined(__clang__) && !defined(__OBJC_RUNTIME_INTERNAL__)
#pragma clang system_header
#endif

#ifndef __OBJC_ARC_INCLUDED__
#define __OBJC_ARC_INCLUDED__
/**
 * Autoreleases the argument.  Equivalent to [obj autorelease].
 */
id _objc_autorelease(id obj);
/**
 * Autoreleases a return value.  This is equivalent to [obj autorelease], but
 * may also store the object somewhere where it can be quickly removed without
 * the need for any message sending.
 */
id _objc_autoreleaseReturnValue(id obj);
/**
 * Initializes object as a weak pointer and stores value in it, or nil if value
 * has already begun deallocation.
 */
id _objc_initWeak(id *object, id value);
/**
 * Loads the object.  Returns nil if the object stored at this address has
 * already begun deallocation.
 */
id _objc_loadWeak(id* object);
/**
 * Loads a weak value and retains it.
 */
id _objc_loadWeakRetained(id* obj);
/**
 * Retains the argument.  Equivalent to [obj retain].
 */
id _objc_retain(id obj);
/**
 * Retains and autoreleases an object.  Equivalent to [[obj retain] autorelease].
 */
id _objc_retainAutorelease(id obj);
/**
 * Retains and releases a return value.  Equivalent to
 * objc_retain(objc_autoreleaseReturnValue(obj)).
 */
id _objc_retainAutoreleaseReturnValue(id obj);
/**
 * Retains a return value that has previously been autoreleased and returned.
 * This is equivalent to objc_retainAutoreleaseReturnValue(), but may support a
 * fast path, skipping the autorelease pool entirely.
 */
id _objc_retainAutoreleasedReturnValue(id obj);
/**
 * Retains a block.
 */
id _objc_retainBlock(id b);
/**
 * Stores value in addr.  This first retains value, then releases the old value
 * at addr, and stores the retained value in the address.
 */
id _objc_storeStrong(id *addr, id value);
/**
 * Stores obj in zeroing weak pointer addr.  If obj has begun deallocation,
 * then this stores nil.
 */
id _objc_storeWeak(id *addr, id obj);
/**
 * Allocates an autorelease pool and pushes it onto the top of the autorelease
 * pool stack.  Note that the returned autorelease pool is not required to be
 * an object.
 */
void *_objc_autoreleasePoolPush(void);
/**
 * Pops the specified autorelease pool from the stack, sending release messages
 * to every object that has been autreleased since the pool was created.
 */
void _objc_autoreleasePoolPop(void *pool);
/**
 * Initializes dest as a weak pointer and stores the value stored in src into
 * it.  
 */
void _objc_copyWeak(id *dest, id *src);
/**
 * Destroys addr as a weak pointer.
 */
void _objc_destroyWeak(id* addr);
/**
 * Equivalent to objc_copyWeak(), but may also set src to nil.
 */
void _objc_moveWeak(id *dest, id *src);
/**
 * Releases an object.  Equivalent to [obj release].
 */
void _objc_release(id obj);
/**
 * Mark the object as about to begin deallocation.  All subsequent reads of
 * weak pointers will return 0.  This function should be called in -release,
 * before calling [self dealloc].
 *
 * Nonstandard extension.
 */
void _objc_delete_weak_refs(id obj);
/**
 * Returns the total number of objects in the ARC-managed autorelease pool.
 */
unsigned long _objc_arc_autorelease_count_np(void);
/**
 * Returns the total number of times that an object has been autoreleased in
 * this thread.
 */
unsigned long _objc_arc_autorelease_count_for_object_np(id obj);

#define __setup_arc_hooks__ \
id objc_autorelease(id obj) { return _objc_autorelease(obj); } \
id objc_autoreleaseReturnValue(id obj) { return _objc_autoreleaseReturnValue(obj); } \
id objc_initWeak(id *object, id value) { return _objc_initWeak(object,value); } \
id objc_loadWeak(id* object) { return _objc_loadWeak(object); } \
id objc_loadWeakRetained(id* obj) { return _objc_loadWeakRetained(obj); } \
id objc_retain(id obj) { return _objc_retain(obj); } \
id objc_retainAutorelease(id obj) { return _objc_retainAutorelease(obj); } \
id objc_retainAutoreleaseReturnValue(id obj) { return _objc_retainAutoreleaseReturnValue(obj); } \
id objc_retainAutoreleasedReturnValue(id obj) { return _objc_retainAutoreleasedReturnValue(obj); } \
id objc_retainBlock(id b) { return _objc_retainBlock(b); } \
id objc_storeStrong(id *addr, id value) { return _objc_storeStrong(addr,value); } \
id objc_storeWeak(id *addr, id obj) { return _objc_storeWeak(addr,obj); } \
void *objc_autoreleasePoolPush(void) { return _objc_autoreleasePoolPush(); } \
void objc_autoreleasePoolPop(void *pool) { _objc_autoreleasePoolPop(pool); } \
void objc_copyWeak(id *dest, id *src) { _objc_copyWeak(dest,src); } \
void objc_destroyWeak(id* addr) { _objc_destroyWeak(addr); } \
void objc_moveWeak(id *dest, id *src) { _objc_moveWeak(dest,src); } \
void objc_release(id obj) { _objc_release(obj); } \
void objc_delete_weak_refs(id obj) { _objc_delete_weak_refs(obj); } \
unsigned long objc_arc_autorelease_count_np(void) { return _objc_arc_autorelease_count_np(); } \
unsigned long objc_arc_autorelease_count_for_object_np(id obj) { return _objc_arc_autorelease_count_for_object_np(obj); }

#endif // __OBJC_ARC_INCLUDED__

