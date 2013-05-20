#import <objc/objc-export.h>
#import <objc/objc.h>
//#include <windows.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <ctype.h>
#include <unistd.h>
//#include <sys/mman.h>
#define BOOL_DEFINED
//#include "objc/runtime.h"

//#include "blocks_runtime_internal.h"
//#include "blocks_runtime.h"
#include "../AppleObjcRuntime/Block.h"
#include "../AppleObjcRuntime/Block_private.h"

#include "lock.h"
#include "visibility.h"

/** From mman https://code.google.com/p/mman-win32/source/browse/trunk/mman.h */
#include "mman.h"
/** From mman https://code.google.com/p/mman-win32/source/browse/trunk/mman.h */


#if defined(_WIN32) || defined(WINDOWS)

/* Some versions of MinGW are missing _vscprintf's declaration, although they
   * still provide the symbol in the import library.
   */
#ifdef __MINGW32__
_CRTIMP int _vscprintf(const char *format, va_list argptr);
#endif

int asprintf(char **strp, const char *fmt, ...)
{
    va_list args;
    va_list args_copy;
    int length;
    size_t size;
    
    va_start(args, fmt);
    
    va_copy(args_copy, args);
    
#ifdef _WIN32
    /* We need to use _vcsprintf to calculate the length as vsnprintf returns -1
     * if the number of characters to write is greater than count.
     */
    length = _vscprintf(fmt, args_copy);
#else
    char dummy;
    length = vsnprintf(&dummy, sizeof dummy, fmt, args_copy);
#endif
    
    va_end(args_copy);
    
    assert(length >= 0);
    size = length + 1;
    
    *strp = malloc(size);
    if (!*strp) {
        return -1;
    }
    
    va_start(args, fmt);
    vsnprintf(*strp, size, fmt, args);
    va_end(args);
    
    return length;
}

#endif /* _WIN32 */

/* QNX needs a special header for asprintf() */
#ifdef __QNXNTO__
#include <nbutil.h>
#endif

#define PAGE_SIZE 4096

static void *executeBuffer;
static void *writeBuffer;
static ptrdiff_t offset;
static mutex_t trampoline_lock;
static char *tmpPattern;

struct wx_buffer
{
	void *w;
	void *x;
};

PRIVATE void init_trampolines(void)
{
	INIT_LOCK(trampoline_lock);
	char *tmp = getenv("TMPDIR");
	if (NULL == tmp)
	{
		tmp = "/tmp/";
	}
	if (0 > asprintf(&tmpPattern, "%s/objc_trampolinesXXXXXXXXXXX", tmp))
	{
		abort();
	}
}

static struct wx_buffer alloc_buffer(size_t size)
{
	LOCK_FOR_SCOPE(&trampoline_lock);
	if ((0 == offset) || (offset + size >= PAGE_SIZE))
	{
		int fd = mkstemp(tmpPattern);
		unlink(tmpPattern);
		ftruncate(fd, PAGE_SIZE);
		void *w = mmap(NULL, PAGE_SIZE, PROT_WRITE, MAP_SHARED, fd, 0);
		executeBuffer = mmap(NULL, PAGE_SIZE, PROT_READ|PROT_EXEC, MAP_SHARED, fd, 0);
		*((void**)w) = writeBuffer;
		writeBuffer = w;
		offset = sizeof(void*);
	}
	struct wx_buffer b = { writeBuffer + offset, executeBuffer + offset };
	offset += size;
	return b;
}

extern void __objc_block_trampoline;
extern void __objc_block_trampoline_end;
extern void __objc_block_trampoline_sret;
extern void __objc_block_trampoline_end_sret;

IMP imp_implementationWithBlock(void *block)
{
	struct Block_layout *b = block;
	void *start;
	void *end;

	if ((b->flags & BLOCK_USE_SRET) == BLOCK_USE_SRET)
	{
		start = &__objc_block_trampoline_sret;
		end = &__objc_block_trampoline_end_sret;
	}
	else
	{
		start = &__objc_block_trampoline;
		end = &__objc_block_trampoline_end;
	}

	size_t trampolineSize = end - start;
	// If we don't have a trampoline intrinsic for this architecture, return a
	// null IMP.
	if (0 >= trampolineSize) { return 0; }

	struct wx_buffer buf = alloc_buffer(trampolineSize + 2*sizeof(void*));
	void **out = buf.w;
	out[0] = (void*)b->invoke;
	out[1] = Block_copy(b);
	memcpy(&out[2], start, trampolineSize);
	out = buf.x;
	return (IMP)&out[2];
}

static void* isBlockIMP(void *anIMP)
{
	LOCK(&trampoline_lock);
	void *e = executeBuffer;
	void *w = writeBuffer;
	UNLOCK(&trampoline_lock);
	while (e)
	{
		if ((anIMP > e) && (anIMP < e + PAGE_SIZE))
		{
			return ((char*)w) + ((char*)anIMP - (char*)e);
		}
		e = *(void**)e;
		w = *(void**)w;
	}
	return 0;
}

void *imp_getBlock(IMP anImp)
{
	if (0 == isBlockIMP((void*)anImp)) { return 0; }
	return *(((void**)anImp) - 1);
}
BOOL imp_removeBlock(IMP anImp)
{
	void *w = isBlockIMP((void*)anImp);
	if (0 == w) { return NO; }
	Block_release(((void**)anImp) - 1);
	return YES;
}

PRIVATE size_t lengthOfTypeEncoding(const char *types)
{
    fprintf(stderr,"block_to_imp lengthOfTypeEncoding NOT IMPLEMENTED!\n");
    return 0;
}

char *block_copyIMPTypeEncoding_np(void*block)
{
	char *buffer = strdup(block_getType_np(block));
	if (NULL == buffer) { return NULL; }
	char *replace = buffer;
	// Skip the return type
	replace += lengthOfTypeEncoding(replace);
	while (isdigit(*replace)) { replace++; }
	// The first argument type should be @? (block), and we need to transform
	// it to @, so we have to delete the ?.  Assert here because this isn't a
	// block encoding at all if the first argument is not a block, and since we
	// got it from block_getType_np(), this means something is badly wrong.
	assert('@' == *replace);
	replace++;
	assert('?' == *replace);
	// Use strlen(replace) not replace+1, because we want to copy the NULL
	// terminator as well.
	memmove(replace, replace+1, strlen(replace));
	// The next argument should be an object, and we want to replace it with a
	// selector
	while (isdigit(*replace)) { replace++; }
	if ('@' != *replace)
	{
		free(buffer);
		return NULL;
	}
	*replace = ':';
	return buffer;
}
