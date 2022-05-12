; -------------------------------------------------------------------
; Helloコマンド
; -------------------------------------------------------------------
; TCのテスト
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC

.macro syscall func
  LDX #(BCOS::func)*2
  JSR BCOS::SYSCALL
.endmac

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  loadAY16 STR_HELLO
  syscall CON_OUT_STR
  RTS                             ; BCOS0でも等価でありたいが現状そうでないのでリターン

STR_HELLO: .ASCIIZ "hello, world"
