	.section	.text,"ax",@progbits
	.assume	ADL = 1
	.file	"llvm-link"
	.section	.text._multiply,"ax",@progbits
	.globl	_multiply                       ; -- Begin function multiply
	.type	_multiply,@function
_multiply:                              ; @multiply
; %bb.0:
	call	__frameset0
	ld	bc, (ix + 6)
	ld	hl, (ix + 9)
	call	__imulu
	pop	ix
	ret
	.local	.Lfunc_end0
.Lfunc_end0:
	.size	_multiply, .Lfunc_end0-_multiply
                                        ; -- End function
	.section	.text._main,"ax",@progbits
	.globl	_main                           ; -- Begin function main
	.type	_main,@function
_main:                                  ; @main
; %bb.0:
	ld	iy, -3145600
	call	_os_ClrLCD
	call	_os_HomeUp
	call	_os_DrawStatusBar
	ld	hl, 30
	push	hl
	ld	hl, _.str
	push	hl
	call	_printf
	pop	hl
	pop	hl
	ld	hl, 20
	push	hl
	ld	hl, _.str
	push	hl
	call	_printf
	pop	hl
	pop	hl
	ld	hl, 1
	push	hl
	ld	hl, _.str
	push	hl
	call	_printf
	pop	hl
	pop	hl
	ld	bc, 3
	ld	de, 0
	.local	.LBB1_1
.LBB1_1:                                ; =>This Inner Loop Header: Depth=1
	ld	(_i), de
	push	de
	pop	hl
	or	a, a
	sbc	hl, bc
	call	pe, __setflag
	jp	p, .LBB1_3
; %bb.2:                                ;   in Loop: Header=BB1_1 Depth=1
	push	de
	ld	hl, _.str
	push	hl
	call	_printf
	ld	bc, 3
	pop	hl
	pop	hl
	ld	de, (_i)
	inc	de
	jr	.LBB1_1
	.local	.LBB1_3
.LBB1_3:                                ; %.preheader
                                        ; =>This Inner Loop Header: Depth=1
	call	_os_GetCSC
	or	a, a
	jr	z, .LBB1_3
; %bb.4:
	or	a, a
	sbc	hl, hl
	ret
	.local	.Lfunc_end1
.Lfunc_end1:
	.size	_main, .Lfunc_end1-_main
                                        ; -- End function
	.section	.text._math_utils_add,"ax",@progbits
	.globl	_math_utils_add                 ; -- Begin function math_utils_add
	.type	_math_utils_add,@function
_math_utils_add:                        ; @math_utils_add
; %bb.0:
	call	__frameset0
	ld	de, (ix + 6)
	ld	hl, (ix + 9)
	add	hl, de
	pop	ix
	ret
	.local	.Lfunc_end2
.Lfunc_end2:
	.size	_math_utils_add, .Lfunc_end2-_math_utils_add
                                        ; -- End function
	.section	.text._math_utils_multiply,"ax",@progbits
	.globl	_math_utils_multiply            ; -- Begin function math_utils_multiply
	.type	_math_utils_multiply,@function
_math_utils_multiply:                   ; @math_utils_multiply
; %bb.0:
	call	__frameset0
	ld	bc, (ix + 6)
	ld	hl, (ix + 9)
	call	__imulu
	pop	ix
	ret
	.local	.Lfunc_end3
.Lfunc_end3:
	.size	_math_utils_multiply, .Lfunc_end3-_math_utils_multiply
                                        ; -- End function
	.section	.rodata._.str,"a",@progbits
	.balign	1
	.local	_.str
_.str:
	.asciz	"%d\n"

	.section	.bss._i,"aw",@nobits
	.balign	1
	.local	_i
_i:
	.zero	3

	.ident	"clang version 19.1.0 (https://github.com/CE-Programming/llvm-project ef28e9c54cd1333a6091ab2ffbd315b465fc5090)"
	.ident	"clang version 19.1.0 (https://github.com/CE-Programming/llvm-project ef28e9c54cd1333a6091ab2ffbd315b465fc5090)"
	.section	".note.GNU-stack","",@progbits
	.extern	__Unwind_SjLj_Register
	.extern	__Unwind_SjLj_Unregister
	.extern	_os_HomeUp
	.extern	_os_ClrLCD
	.extern	_llvm.stackrestore.p0
	.extern	_llvm.eh.sjlj.functioncontext
	.extern	_os_GetCSC
	.extern	_printf
	.extern	_llvm.eh.sjlj.setup.dispatch
	.extern	_llvm.stacksave.p0
	.extern	_llvm.eh.sjlj.callsite
	.extern	__setflag
	.extern	_llvm.eh.sjlj.lsda
	.extern	__imulu
	.extern	__frameset0
	.extern	_os_DrawStatusBar
	.extern	_llvm.frameaddress.p0
