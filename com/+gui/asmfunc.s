.INCLUDE "../FXT65.inc"
.INCLUDE "../generic.mac"
.INCLUDE "../zr.inc"
.PROC BCOS
  .INCLUDE "../syscall.inc"  ; システムコール番号
.ENDPROC
.INCLUDE "../syscall.mac"

.BSS

.ZEROPAGE
ZP_PADSTAT: .RES 2
ZP_STRPTR:  .RES 2
ZP_VB_STUB: .RES 2

.DATA

.CONSTRUCTOR INIT

.CODE

.INCLUDE "./+gui/chdz_basic.s"
.INCLUDE "./+gui/se.s"

.EXPORT _pad,_system,_play_se

; コンストラクタ
.SEGMENT "ONCE"
INIT:
  ; ポートの設定
  LDA VIA::PAD_DDR         ; 0で入力、1で出力
  ORA #(VIA::PAD_CLK|VIA::PAD_PTS)
  AND #<~(VIA::PAD_DAT)
  STA VIA::PAD_DDR
  ; se
  init_se
  ; 割り込みハンドラの登録
  SEI
  loadAY16 VBLANK
  syscall IRQ_SETHNDR_VB
  storeAY16 ZP_VB_STUB
  CLI
  JMP CHDZ_BASIC_INIT

.CODE
VBLANK:
  tick_se
  JMP (ZP_VB_STUB)           ; 片付けはBCOSにやらせる

; -------------------------------------------------------------------
; PAD()関数
; ゲームパッドのボタン押下状況を取得する
; 引数: ボタン番号（ビット位置）
; 押されている=1, 押されていない=0を返す
; -------------------------------------------------------------------
.PROC _pad
  ; P/S下げる
  LDA VIA::PAD_REG
  ORA #VIA::PAD_PTS
  STA VIA::PAD_REG
  ; P/S下げる
  LDA VIA::PAD_REG
  AND #<~VIA::PAD_PTS
  STA VIA::PAD_REG
  ; 読み取りループ
  LDX #16
LOOP:
  LDA VIA::PAD_REG        ; データ読み取り
  ; クロック下げる
  AND #<~VIA::PAD_CLK
  STA VIA::PAD_REG
  ; 16bit値として格納
  ROR
  ROL ZP_PADSTAT+1
  ROL ZP_PADSTAT
  ; クロック上げる
  LDA VIA::PAD_REG        ; データ読み取り
  ORA #VIA::PAD_CLK
  STA VIA::PAD_REG
  DEX
  BNE LOOP
  LDA ZP_PADSTAT
  LDX ZP_PADSTAT+1
  ; LOW   : 7|B,Y,SEL,STA,↑,↓,←,→|0
  ; HIGH  : 7|A,X,L,R            |0
  RTS
.ENDPROC

; -------------------------------------------------------------------
; void system(unsigned char* commandline)
; -------------------------------------------------------------------
_system:
  PHX
  PLY
  storeAY16 ZP_STRPTR
  LDY #0
@LOOP:
  LDA (ZP_STRPTR),Y
  BEQ @END
  PHY
  syscall CON_INTERRUPT_CHR
  PLY
  INY
  BRA @LOOP
@END:
  syscall CRTC_RETBASE
  ; 大政奉還コード
  ; 割り込みハンドラの登録抹消
  SEI
  mem2AY16 ZP_VB_STUB
  syscall IRQ_SETHNDR_VB
  CLI
  JMP $5000

; play_se(unsigned char se_num)
_play_se:
  JSR PLAY_SE
  RTS

