; 2色モードChDzによるキャラクタ表示
.INCLUDE "FXT65.inc"

; -------------------------------------------------------------------
; -------------------------------------------------------------------
; CRTC基底状態関連ルーチン
;   GCHRより上位の範疇だがとりあえずここに
; -------------------------------------------------------------------
; -------------------------------------------------------------------

; -------------------------------------------------------------------
; BCOS 23                  基底状態を設定
; -------------------------------------------------------------------
; input   : A = CFG
;         : Y = RF
; -------------------------------------------------------------------
FUNC_CRTC_SETBASE:
  ;STA BASE_CFG
  STY BASE_RF
  RTS

; -------------------------------------------------------------------
; BCOS 24                   基底状態に回帰
; -------------------------------------------------------------------
FUNC_CRTC_RETBASE:
  STZ CRTC2::CHRW           ; キャラクタボックス有効、幅1
  LDA #7
  STA CRTC2::CHRH           ; 高さ8
  LDA #(CRTC2::WF|0)        ; 第0フレーム
  STA CRTC2::CONF
  LDA #(CRTC2::TT|1)        ; 2色モード有効
  STA CRTC2::CONF
  LDA BASE_RF
  STA CRTC2::DISP           ; 表示フレーム復帰
  RTS

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
  ;LDA COL_BACK
  ;ASL
  ;ASL
  ;ASL
  ;ASL
  ;STA ZP_X
  ;LDA COL_MAIN
  ;AND #%00001111
  ;ORA ZP_X
  ;STA CRTC::TCP
  LDA COL_BACK
  ORA #CRTC2::T0
  STA CRTC2::CONF
  LDA COL_MAIN
  ORA #CRTC2::T1
  STA CRTC2::CONF
  RTS

INIT:
  ; 2色モードの色を白黒に初期化
  LDA #$04                  ; 青
  STA COL_BACK              ; 背景色に設定
  LDA #$0F                  ; 白
  STA COL_MAIN              ; 文字色に設定
  LDY #0
  JSR FUNC_CRTC_SETBASE     ; 基底状態を設定
  JSR FUNC_CRTC_RETBASE     ; CRTCを基底状態にする
  JSR CLEAR_TXTVRAM         ; TRAMの空白埋め
  JSR SET_TCP
  JSR DRAW_ALLLINE          ; 全体描画
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
.REPEAT 3
  ASL                       ; 行数を右にシフト
  ROR ZP_Y                  ; おこぼれをインデックスとするx3
.ENDREP
  CLC
  ADC #>TXTVRAM768          ; TXTVRAM上位に加算
  STA ZP_TRAM_VEC16+1       ; ページ数登録
  LDY ZP_Y                  ; インデックスをYにロード
DRAW_LINE_RAW:
  ; 行を描画する
  ; TRAM_VEC16を上位だけ設定しておき、そのなかのインデックスもYで持っておく
  ; 連続実行すると次の行を描画できる
  TYA                       ; インデックスをAに
  AND #%11100000            ; 行として意味のある部分を抽出
  TAX                       ; しばらく使わないXに保存
  ; HVの初期化
  STZ ZP_X
  STZ CRTC2::PTRX
  ; 0~2のページオフセットを取得
  LDA ZP_TRAM_VEC16+1
  SEC
  SBC #>TXTVRAM768
  STA ZP_Y
  ; インデックスの垂直部分3bitを挿入
  TYA
.REPEAT 3
  ASL
  ROL ZP_Y
.ENDREP
  ; 8倍
  LDA ZP_Y
  ASL
  ASL
  ASL
  STA ZP_Y
  STA CRTC2::PTRY
  ; --- フォント参照ベクタ作成
DRAW_TXT_LOOP:
  LDA #>FONT2048
  STA ZP_FONT_VEC16+1
  ; フォントあぶれ初期化
  STZ ZP_FONT_SR
  ; アスキーコード読み取り
  TXA                       ; 保存していたページ内行を復帰してインデックスに
  TAY
  LDA (ZP_TRAM_VEC16),Y
.REPEAT 3
  ASL                       ; 8倍してあぶれた分をアドレス上位に加算
  ROL ZP_FONT_SR
.ENDREP
  STA ZP_FONT_VEC16
  LDA ZP_FONT_SR
  ADC ZP_FONT_VEC16+1       ; キャリーは最後のROLにより0
  STA ZP_FONT_VEC16+1
  ; --- フォント書き込み
  ; カーソルセット
  ;LDA ZP_X
  ;STA CRTC::VMAH
  ; 一文字表示ループ
  LDY #0
CHAR_LOOP:
  ;LDA ZP_Y
  ;STA CRTC::VMAV
  ; フォントデータ読み取り
  LDA (ZP_FONT_VEC16),Y
  STA CRTC2::WDAT
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

