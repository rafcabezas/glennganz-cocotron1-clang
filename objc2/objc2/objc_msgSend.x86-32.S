/*
#define DTABLE_OFFSET  32
#define SMALLOBJ_MASK  1
#define SHIFT_OFFSET   4
#define DATA_OFFSET    12
#define SLOT_OFFSET    16
.macro MSGSEND receiver, sel, fpret
	.cfi_startproc                        
	movl  \receiver(%esp), %eax
	test  %eax, %eax                      # If the receiver is nil
	jz    4f                              # return nil
	test  $SMALLOBJ_MASK, %eax            # Check if the receiver is a small object
	jnz   6f                              # Get the small object class

	mov   (%eax), %eax                    # Load the class
1:                                        # classLoaded
	movl  \sel(%esp), %ecx
	mov   DTABLE_OFFSET(%eax), %eax       # Load the dtable from the class
	
	mov   (%ecx), %ecx                    # Load the selector index

	                                      # Register use at this point:
	                                      # %eax: dtable
	                                      # %ecx: Selector index
	                                      # %edx: selector index fragment

	mov   SHIFT_OFFSET(%eax), %edx        # Load the shift (dtable size)
	mov   DATA_OFFSET(%eax), %eax         # load the address of the start of the array
	cmpl  $8, %edx                        # If this is a small dtable, jump to the small dtable handlers
	je    2f 
	cmpl  $0, %edx 
	je    3f 

	mov   %ecx, %edx
	and   $0xff0000, %edx
	shrl  $14, %edx                       # Right shift 16, but then left shift by 2 (* sizeof(void*))
	add   %edx, %eax
	mov   (%eax), %eax
	mov   DATA_OFFSET(%eax), %eax
2:                                        # dtable16:
	mov   %ecx, %edx
	and   $0xff00, %edx
	shrl  $6, %edx
	add   %edx, %eax
	mov   (%eax), %eax
	mov   DATA_OFFSET(%eax), %eax
3:                                        # dtable8:
	and   $0xff, %ecx
	shll  $2, %ecx
	add   %ecx, %eax
	mov   (%eax), %eax

	test  %eax, %eax
	jz    5f                             # Nil slot - invoke some kind of forwarding mechanism
	mov   SLOT_OFFSET(%eax), %eax
	jmp   *%eax
4:                                       # returnNil:
.if \fpret
	fldz
.else 
	xor   %eax, %eax                     # return 0 (int)
	xor   %edx, %edx                     # Return 64-bit zero (%edx is
	                                     # caller-save, so it's safe to do this in the general case.
.endif
	ret
5:                                       # slowSend:
	mov   \sel(%esp), %ecx
	lea   \receiver(%esp), %eax

	push  %ecx                           # _cmd
	push  %eax                           # &self
	.cfi_def_cfa_offset 12
	call  slowMsgLookup@PLT
	add   $8, %esp                       # restore the stack


	jmp   *%eax
6:                                       # smallObject:
	push  %ebx                           # Save old %ebx
	calll 7f
7:
	popl  %ebx;
8:
	addl  $_GLOBAL_OFFSET_TABLE_+(8b-7b), %ebx
	leal  SmallObjectClasses@GOTOFF(%ebx), %eax
	mov   (%eax), %eax
	popl  %ebx
	jmp   1b 
	.cfi_endproc
.endm
.globl objc_msgSend_fpret
#	.type	objc_msgSend_fpret, @function
objc_msgSend_fpret:
	MSGSEND 4, 8, 1
.globl objc_msgSend
#	.type	objc_msgSend, @function
objc_msgSend:
	MSGSEND 4, 8, 0
.globl objc_msgSend_stret
#	.type	objc_msgSend_stret, @function
objc_msgSend_stret:
	MSGSEND 8, 12, 0
*/

# Original - Christopher Lloyd <cjwl@objc.net>
.globl _objc_msgSendv
_objc_msgSendv:
pushl	%ebp
movl	%esp, %ebp
pushl	12(%ebp)
pushl   8(%ebp)
call	_objc_msg_lookup
movl 16(%ebp),%ecx # ecx=argumentFrameByteSize
movl 20(%ebp),%edx # edx=argumentFrame
pushNext:
subl $4,%ecx       # argumentFrameByteSize-=sizeof(int)
cmpl $4,%ecx       # check if we're at _cmd in argumentFrame
jle done
pushl (%edx,%ecx)
jmp pushNext
done:
pushl 12(%ebp) # push _cmd
pushl 8(%ebp)  # push self
call *%eax
leave
ret

.globl _objc_msgSendv_stret
_objc_msgSendv_stret:
pushl	%ebp
movl	%esp, %ebp
pushl	16(%ebp) # _cmd
pushl	12(%ebp) # self
call	_objc_msg_lookup
movl 20(%ebp),%ecx # ecx=argumentFrameByteSize
movl 24(%ebp),%edx # edx=argumentFrame
pushNext_stret:
subl $4,%ecx       # argumentFrameByteSize-=sizeof(int)
cmpl $8,%ecx       # check if we're at _cmd in argumentFrame
jle done_stret
pushl (%edx,%ecx)
jmp pushNext_stret
done_stret:
pushl 16(%ebp) # push _cmd
pushl 12(%ebp) # push self
pushl 8(%ebp)  # push return value ptr
call *%eax
leave
ret

.section .drectve
.ascii " -export:objc_msgSendv"
.ascii " -export:objc_msgSendv_stret"
