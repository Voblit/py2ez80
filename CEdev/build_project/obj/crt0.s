.macro LIBLOAD_LIBS
.endm

 .assume adl=1
 .equ ti.mpTmr1Counter, 0x0F20000
 .equ ti.mpTmrCtrl, 0x0F20030
 .equ ti.bTmr1Enable, 0
 .equ ti.bTmr1Crystal, 1
 .equ ti.bTmr1Overflow, 2
 .equ ti.bTmr1CountUp, 9
 .equ ti.Arc_Unarc, 0x021448
 .equ ti.usb_ResetTimer, 0x00004F0
 .equ ti.usb_DisableTimer, 0x00004F4
 .equ ti.HomeUp, 0x020828
 .equ ti.DrawStatusBar, 0x021A3C
 .equ ti.ChkFindSym, 0x02050C
 .equ ti.Mov9ToOP1, 0x020320
 .equ ti.PutS, 0x0207C0
 .equ ti.ChkInRam, 0x021F98
 .equ ti.OP1, 0xD005F8
 .equ ti.OP3, 0xD0060E
 .equ ti.AppVarObj, 0x15
 .equ ti.ClrScrn, 0x020814
 .equ ti.NewLine, 0x0207F0
 .equ ti.GetKey, 0x020D8C
 .equ ti.flags, 0xD00080
 .equ ti.RunIndicOff, 0x020848
 .equ ti.PushRealO1, 0x020614
 .equ ti.Mov8b, 0x020304
 .equ ti.AnsName, 0x020FF4
 .equ ti.FindSym, 0x020510
 .equ ti.StrngObj, 4
 .equ ti.Get_Tok_Strng, 0x020870
 .equ ti.Isa2ByteTok, 0x0204AC
 .equ ti.PopRealO1, 0x0205DC
 .equ ti.MovFrOP1, 0x02032C
 .equ ti.ClrLCDFull, 0x020808
 .equ ti.boot.memclear, 0x0000B0
 .section .header,"ax",@progbits
 .local __header
__header:
 .db 0xEF, 0x7B, 0x00 ; 0x00 is signifier for C programs
 .section .init,"ax",@progbits
 .global __start
 .type __start, @function
__start:
 ld iy, ti.flags
 call ti.RunIndicOff ; assumes iy = flags
 call ti.usb_DisableTimer
 di
 ; zeroize bss
 ld hl, ___bss_low
 ld bc, ___bss_len
 push bc
 push hl
 ; void memclear(void *dst, size_t size)
 call ti.boot.memclear
 pop hl
 pop hl
 res 1, (iy + 0x0D) ; no text buffer
 res 3, (iy + 0x4A) ; use first shadow buffer
 set 5, (iy + 0x4C) ; only display
 ld hl, 0xE00305
 ld a, (hl)
 ld (_exit.flash_wait_states), a
 ld (hl), h ; set flash wait states to 3; 1 was definitely
      ; too low, 2 is untested
 ld (_exit.sp), sp ; save sp for exiting
 call _main
 .equ __start._main, $ - 3
;-------------------------------------------------------------------------------
; call atexit/on_exit and fini functions
;-------------------------------------------------------------------------------
 .global ___exithl
 .type ___exithl, @function
___exithl:
;-------------------------------------------------------------------------------
; We have now called all atexit/on_exit and fini functions
; HL = exit status
;-------------------------------------------------------------------------------
 ld sp, 0
 .global _exit.sp
 .equ _exit.sp, $ - 3
 push hl
 ld iy, ti.flags
 ld a, 0
 .local _exit.flash_wait_states
 .equ _exit.flash_wait_states, $ - 1
 ld (0xE00305), a
 call ti.usb_ResetTimer
 ld a, 1
 ld (0xF00008), a ; clear on interrupt
 res 4, (iy + 0x09) ; onInterrupt,(iy+onFlags)
 set 0, (iy + 0x03) ; graphDraw,(iy+graphFlags)
 set 1, (iy + 0x0D) ; use text buffer
 res 3, (iy + 0x4A) ; use first shadow buffer
 res 5, (iy + 0x4C) ; use shadow buffer
 call ti.ClrLCDFull
 call ti.HomeUp
 call ti.DrawStatusBar
 pop hl ; hl = exit code
 ret
 .extern _main
