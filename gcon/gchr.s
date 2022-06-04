; 2色モードChDzによるキャラクタ表示
.INCLUDE "FXT65.inc"

; -------------------------------------------------------------------
; BCOS 8             テキスト画面色操作
; -------------------------------------------------------------------
; input   : A = 動作選択
;               $0 : 文字色を取得
;               $1 : 背景色を取得
;               $2 : 文字色を設定
;               $3 : 背景色を設定
;           Y = 色データ（下位ニブル有効、$2,$3動作時のみ
; output  : A = 取得した色データ
; 二色モードに限らず画面の状態は勝手に叩いていいのだが、
; GCHRモジュールを使うならカーネルの支配下にないといけない
; -------------------------------------------------------------------
FUNC_GCHR_COL:
  BIT #%00000010  ; bit1が立ってたら設定、でなければ取得
  BNE @SETTING
@GETTING:
  ROR             ; bit0が立ってたら背景色、でなければ文字色
  BCS @GETBACK
@GETMAIN:
  LDA COL_MAIN
  RTS
@GETBACK:
  LDA COL_BACK
  RTS
@SETTING:
  ROR             ; bit0が立ってたら背景色、でなければ文字色
  BCS @SETBACK
@SETMAIN:
  STY COL_MAIN
  BRA SET_TCP
@SETBACK:
  STY COL_BACK
SET_TCP:
  ; 2色パレットを変数から反映する
  LDA COL_BACK
  ASL
  ASL
  ASL
  ASL
  STA ZP_X
  LDA COL_MAIN
  AND #%00001111
  ORA ZP_X
  STA CRTC::TCP
  RTS

INIT:
  ; 2色モードの色を白黒に初期化
  ;LDA #$00                  ; 黒
  LDA #$44                  ; 青
  STA COL_BACK              ; 背景色に設定
  ;LDA #$03                  ; 緑
  LDA #$FF                  ; 白
  STA COL_MAIN              ; 文字色に設定
  JSR CLEAR_TXTVRAM         ; TRAMの空白埋め
ENTER_TXTMODE:
  STZ CRTC::WF              ; f0に対する書き込み
  JSR SET_TCP
  JSR DRAW_ALLLINE          ; 全体描画
  LDA #%11110010            ; 全内部行を2色モード、書き込みカウントアップ無効、2色モード座標
  STA CRTC::CFG
  STZ CRTC::RF              ; f0を表示
  RTS

DRAW_ALLLINE:
  ; TRAMから全行を反映する
  loadmem16 ZP_TRAM_VEC16,TXTVRAM768
  LDY #0
  LDX #6
DRAW_ALLLINE_LOOP:
  PHX
  JSR DRAW_LINE_RAW
  JSR DRAW_LINE_RAW
  JSR DRAW_LINE_RAW
  JSR DRAW_LINE_RAW
  PLX
  DEX
  BNE DRAW_ALLLINE_LOOP
  RTS

DRAW_LINE:
  ; Yで指定された行を描画する
  TYA                       ; 行数をAに
  STZ ZP_Y                  ; シフト先をクリア
  ASL                       ; 行数を右にシフト
  ROR ZP_Y                  ; おこぼれをインデックスとするx3
  ASL
  ROR ZP_Y
  ASL
  ROR ZP_Y                  ; A:ページ数0~2 ZP_Y:ページ内インデックス行頭
  CLC
  ADC #>TXTVRAM768          ; TXTVRAM上位に加算
  STA ZP_TRAM_VEC16+1       ; ページ数登録
  LDY ZP_Y                  ; インデックスをYにロード
DRAW_LINE_RAW:
  ; 行を描画する
  ; TRAM_VEC16を上位だけ設定しておき、そのなかのインデックスもYで持っておく
  ; 連続実行すると次の行を描画できる
  BBS4  ZP_CON_DEV_CFG,@SKP_RTS
  RTS
@SKP_RTS:
  TYA                       ; インデックスをAに
  AND #%11100000            ; 行として意味のある部分を抽出
  TAX                       ; しばらく使わないXに保存
  ; HVの初期化
  STZ ZP_X
  ; 0~2のページオフセットを取得
  LDA ZP_TRAM_VEC16+1
  SEC
  SBC #>TXTVRAM768
  STA ZP_Y
  ; インデックスの垂直部分3bitを挿入
  TYA
  ASL
  ROL ZP_Y
  ASL
  ROL ZP_Y
  ASL
  ROL ZP_Y
  ; 8倍
  LDA ZP_Y
  ASL
  ASL
  ASL
  STA ZP_Y
  ; --- フォント参照ベクタ作成
DRAW_TXT_LOOP:
  LDA #>FONT2048
  STA ZP_FONT_VEC16+1
  ; フォントあぶれ初期化
  LDY #0
  STY ZP_FONT_SR
  ; アスキーコード読み取り
  TXA                       ; 保存していたページ内行を復帰してインデックスに
  TAY
  LDA (ZP_TRAM_VEC16),Y
  ASL                       ; 8倍してあぶれた分をアドレス上位に加算
  ROL ZP_FONT_SR
  ASL
  ROL ZP_FONT_SR
  ASL
  ROL ZP_FONT_SR
  STA ZP_FONT_VEC16
  LDA ZP_FONT_SR
  ADC ZP_FONT_VEC16+1       ; キャリーは最後のROLにより0
  STA ZP_FONT_VEC16+1
  ; --- フォント書き込み
  ; カーソルセット
  LDA ZP_X
  STA CRTC::VMAH
  ; 一文字表示ループ
  LDY #0
CHAR_LOOP:
  LDA ZP_Y
  STA CRTC::VMAV
  ; フォントデータ読み取り
  LDA (ZP_FONT_VEC16),Y
  STA CRTC::WDBF
  INC ZP_Y
  INY
  CPY #8
  BNE CHAR_LOOP
  ; --- 次の文字へアドレス類を更新
  ; テキストVRAM読み取りベクタ
  INX
  BNE SKP_TXTNP
  INC ZP_TRAM_VEC16+1
SKP_TXTNP:
  ; H
  INC ZP_X
  LDA ZP_X
  AND #%00011111  ; 左端に戻るたびゼロ
  BNE SKP_EXT_DRAWLINE
  TXA
  TAY
  RTS
SKP_EXT_DRAWLINE:
  ; V
  SEC
  LDA ZP_Y
  SBC #8
  STA ZP_Y
  BRA DRAW_TXT_LOOP

CLEAR_TXTVRAM:
  loadmem16 ZR0,TXTVRAM768
  LDA #' '
  LDY #0
  LDX #3
CLEAR_TXTVRAM_LOOP:
  STA (ZR0),Y
  INY
  BNE CLEAR_TXTVRAM_LOOP
  INC ZR0+1
  DEX
  BNE CLEAR_TXTVRAM_LOOP
  RTS

