; -------------------------------------------------------------------
; ECHOコマンド
; -------------------------------------------------------------------
; CCPが余計なことをするせいで勝手に大文字になってしまう
; -------------------------------------------------------------------
.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../fs/structfs.s"
.INCLUDE "../fscons.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

; -------------------------------------------------------------------
;                             実行領域
; -------------------------------------------------------------------
.CODE
START:
  syscall CON_OUT_STR
  RTS

