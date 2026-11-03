class_name UiTokens
extends RefCounted

# Single source of truth for the UI design system. Values are the prototype's
# computed CSS at a 1920x1080 design canvas (web/src/app.css), not the
# prototype wiki, which is out of date.

# Palette -------------------------------------------------------------------
const TILE := Color(0.960784, 0.968627, 0.980392, 0.95)
const TILE_DISABLED := Color(0.960784, 0.968627, 0.980392, 0.86)
const FOCUS_FILL := Color(0.090196, 0.105882, 0.247059, 1.0)
const INK := Color(0.113725, 0.129412, 0.219608, 1.0)
const INK_2 := Color(0.352941, 0.372549, 0.470588, 1.0)
const FOCUS_INK := Color(0.964706, 0.972549, 0.984314, 1.0)
const FOCUS_INK_2 := Color(0.964706, 0.972549, 0.984314, 0.66)
const RAIL := Color(0.901961, 0.137255, 0.431373, 1.0)
const FOCUS_MARK := Color(0.788235, 0.949020, 0.152941, 1.0)
const STAGE_BG := Color(0.039216, 0.062745, 0.125490, 1.0)
const ERROR_PINK := Color(1.0, 0.607843, 0.658824, 1.0)

const TAB_INACTIVE := Color(0.078431, 0.098039, 0.203922, 0.62)
const TAB_STRIP := Color(0.960784, 0.968627, 0.980392, 0.30)
const LEGEND_INK := Color(0.964706, 0.972549, 0.984314, 0.86)
const KBD_FILL := Color(1.0, 1.0, 1.0, 0.14)
const KBD_BORDER := Color(1.0, 1.0, 1.0, 0.22)
const CRUMBS_PLATE := Color(0.960784, 0.968627, 0.980392, 0.92)
const PANEL_NOTE := Color(0.960784, 0.968627, 0.980392, 0.86)
const CHIP_FILL := Color(0.113725, 0.129412, 0.219608, 0.16)
const SHADOW := Color(0.015686, 0.035294, 0.078431, 0.30)
const SHADOW_SELECTED := Color(0.015686, 0.035294, 0.078431, 0.44)
const SHADOW_DISABLED := Color(0.015686, 0.035294, 0.078431, 0.18)

const SIDE_HEAD := Color(0.376471, 0.396078, 0.478431, 0.94)
const SIDE_HEAD_INK := Color(1.0, 1.0, 1.0, 1.0)
const SIDE_BODY := Color(0.960784, 0.968627, 0.980392, 0.90)
const SIDE_BODY_FADE := Color(0.960784, 0.968627, 0.980392, 0.0)
const SIDE_LABEL := Color(0.113725, 0.129412, 0.219608, 0.22)
const SIDE_CUE := Color(0.113725, 0.129412, 0.219608, 0.45)
const SIDE_READY_FILL := FOCUS_MARK
const SIDE_READY_INK := INK
const SIDE_TONES := [
	Color(0.184314, 0.427451, 0.964706, 1.0),
	Color(0.901961, 0.137255, 0.431373, 1.0),
	Color(0.941176, 0.549020, 0.0, 1.0),
	Color(0.058824, 0.615686, 0.462745, 1.0),
]

# Geometry ------------------------------------------------------------------
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const SAFE := 44.0
const GAP := 10.0
const RAIL_W := 6.0
const PANEL_W := 1480.0
const GRID_H := 626.4
const TAB_H := 52.0
const SELECTED_PUSH := 6.0
const SELECTED_SCALE := 1.008

const GLYPH_HERO := 152
const GLYPH_WIDE := 120
const GLYPH_SMALL := 76

const SIDE_HEAD_H := 56.0
const SIDE_BODY_RATIO := 0.64
const SIDE_BODY_MIN := 440.0
const SIDE_BODY_MAX := 700.0
const SIDE_DEVICE := 112.0
const SIDE_DEVICE_INSET := 260.0
const SIDE_GLYPH := 92.0
const SIDE_ROW_GAP := 6.0
const SIDE_ROW_PAD := 16.0
const SIDE_TRACK_INSET := 8.0
const SIDE_LABEL_OFFSET := 30.0
const SIDE_LABEL_BOX := 80.0
const SIDE_READY := 24.0
const SIDE_STATUS_GAP := 12.0
const SIDE_STATUS_H := 24.0
const SIDE_LEGEND_GAP := 16.0
const SIDE_NAME_W := 240.0
const SIDE_NAME_H := 18.0
const SIDE_NAME_GAP := 4.0
const SIDE_NAME_MIN_ROW := 110.0
const SIDE_NAME_OUTLINE := 3
const SIDE_CUE_W := 7.0
const SIDE_CUE_H := 10.0
const SIDE_CUE_GAP := 16.0
const SIDE_READY_INSET := 4.0
const SIDE_READY_LIFT := -8.0
const SIDE_READY_SIDE_GAP := 4.0
const SIDE_PHOTO_SCALE := 1.16
const SIDE_PHOTO_INSET := 0.08

# Typography ----------------------------------------------------------------
const FONT_BARLOW_600 := "res://assets/ui/fonts/BarlowCondensed-SemiBold.ttf"
const FONT_BARLOW_700 := "res://assets/ui/fonts/BarlowCondensed-Bold.ttf"
const FONT_BARLOW_800 := "res://assets/ui/fonts/BarlowCondensed-ExtraBold.ttf"
const FONT_INTER := "res://assets/ui/fonts/Inter-Variable.ttf"

const SIZE_HERO_TITLE := 64
const SIZE_WIDE_TITLE := 52
const SIZE_TILE_TITLE := 44
const SIZE_TILE_SUB := 17
const SIZE_TILE_SUB_WIDE := 18
const SIZE_META := 15
const SIZE_MATCH_VALUE := 26
const SIZE_TAB := 23
const SIZE_BRAND := 26
const SIZE_ROW_TITLE := 34
const SIZE_ROW_SUB := 15
const SIZE_PANEL_NOTE := 16
const SIZE_CRUMBS := 22
const SIZE_LEGEND := 15
const SIZE_KBD := 12
const SIZE_SIDE_TITLE := 24
const SIZE_SIDE_NAME := 64
const SIZE_SIDE_PLAYER := 15
const SIZE_SIDE_STATUS := 15

# Motion --------------------------------------------------------------------
const SCREEN_OUT := 0.15
const SCREEN_IN := 0.24
const TAB_MARKER := 0.28
const TAB_COLOR := 0.22
const TILE_COLOR := 0.14
const TILE_SHADOW := 0.18
const TILE_MOVE := 0.18
const RAIL_FADE := 0.12
const TILE_ENTER := 0.38
const TILE_STAGGER := 0.028
const TILE_ENTER_SHIFT := 64.0
const SIDE_DEVICE_MOVE := 0.34
