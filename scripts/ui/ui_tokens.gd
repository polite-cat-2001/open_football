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
const STAGE_PHOTO_SCALE := 1.16
const STAGE_PHOTO_INSET := 0.08
const SIDE_PHOTO_SCALE := STAGE_PHOTO_SCALE
const SIDE_PHOTO_INSET := STAGE_PHOTO_INSET

# Team select (prototype .teams/.team at 1920x1080) --------------------------
const TEAM_GAP := GAP
const TEAM_PANEL_W := 512.0
const TEAM_PANEL_H := 820.0
const TEAM_COLUMN_W := (PANEL_W - GAP) * 0.5
const TEAM_ART := 210.0
const TEAM_FLAG_H := 64.0
const TEAM_FLAG_MAX_W := 120.0
const TEAM_LEAGUE_H := 118.8
const TEAM_LEAGUE_MAX_W := 170.0
const TEAM_STARS_H := 35.0
const TEAM_STAT_LABEL_H := 16.0
const TEAM_STAT_VALUE_H := 36.0
const TEAM_BLOCK_COUNTRY_RATIO := 0.19
const TEAM_BLOCK_COMPETITION_RATIO := 0.26
const TEAM_OWNER_H := 18.0
const TEAM_CUE_W := 12.0
const TEAM_CUE_H := 18.0
const TEAM_CUE_GAP := 20.0
const TEAM_IDLE_ALPHA := 0.5
const TEAM_STATUS_GAP := 12.0
const TEAM_STATUS_H := 24.0
const TEAM_LEGEND_GAP := 16.0
const TEAM_SIDE_PAD := 20.0
const TEAM_CONTENT_W := TEAM_PANEL_W - TEAM_SIDE_PAD * 2.0
const TEAM_OWNER_TOP := 132.0
const TEAM_COUNTRY_NAME_TOP := 8.0
const TEAM_COUNTRY_NAME_H := 30.0
const TEAM_COUNTRY_ART_TOP := 60.0
const TEAM_COUNTRY_MARK_TOP := 54.0
const TEAM_TEAM_NAME_TOP := 10.0
const TEAM_TEAM_NAME_H := 79.0
const TEAM_CREST_TOP := 93.0
const TEAM_STARS_TOP := 311.0
const TEAM_STATS_TOP := 356.0
const TEAM_STATS_SEP := 8.0
const TEAM_STAT_GAP := 2.0
const TEAM_STATS_H := TEAM_STAT_LABEL_H + TEAM_STAT_GAP + TEAM_STAT_VALUE_H
const TEAM_COMP_NAME_TOP := 8.0
const TEAM_COMP_NAME_H := 28.0
const TEAM_COMP_ART_TOP := 44.2
const TEAM_COMP_ART_W := 180.0
const TEAM_COMP_ART_H := 128.8
const TEAM_COMP_FALLBACK_TOP := 49.2
const TEAM_READY_MARK_TOP := 80.0
const TEAM_READY_MARK_H := 48.0
const TEAM_MARK_H := 38.0

const TEAM_BLOCK_TOP := Color(0.960784, 0.968627, 0.980392, 0.95)
const TEAM_BLOCK_BOTTOM := Color(0.960784, 0.968627, 0.980392, 0.80)
const TEAM_BLOCK_FOCUS := Color(0.090196, 0.105882, 0.247059, 0.96)
const TEAM_BLOCK_DARK := Color(0.090196, 0.105882, 0.247059, 0.66)
const TEAM_STAR_FULL := Color(0.913725, 0.768627, 0.235294, 1.0)
const TEAM_STAR_EMPTY := Color(0.113725, 0.129412, 0.219608, 0.18)
const TEAM_STAR_EMPTY_FOCUS := Color(0.964706, 0.972549, 0.984314, 0.24)

# Kit select (prototype .kits/.kit-panel/.preview at 1920x1080) --------------
const KIT_PANEL_H := 420.0
const KIT_HOME_FRACTION := 1.15
const KIT_MIDDLE_FRACTION := 0.9
const KIT_MIDDLE_MIN := 320.0
const KIT_PAD_TOP := 18.0
const KIT_PAD_SIDE := 26.0
const KIT_PAD_BOTTOM := 20.0
const KIT_HEAD_H := 26.0
const KIT_LOGO := 22.0
const KIT_LOGO_GAP := 8.0
const KIT_NAME_TOP := 4.0
const KIT_NAME_H := 36.0
const KIT_CAROUSEL_TOP := 6.0
const KIT_ARROW_W := 34.0
const KIT_ARROW_GLYPH_W := 18.0
const KIT_ARROW_GLYPH_H := 26.0
const KIT_NEIGHBOR_H := 0.58
const KIT_FOOT_H := 48.0
const KIT_DOT_W := 26.0
const KIT_DOT_H := 4.0
const KIT_DOT_GAP := 8.0
const KIT_STATUS_GAP := 12.0
const KIT_STATUS_H := 24.0
const KIT_LEGEND_GAP := 16.0
const KIT_PREVIEW_PAD := 20.0
const KIT_PREVIEW_HEAD_H := 26.0
const KIT_PREVIEW_FOOT_H := 28.0
const KIT_PREVIEW_GAP := 10.0

const KIT_PANEL_TOP := TEAM_BLOCK_TOP
const KIT_PANEL_BOTTOM := TEAM_BLOCK_BOTTOM
const KIT_PANEL_FOCUS := TEAM_BLOCK_FOCUS
const KIT_PANEL_DARK := TEAM_BLOCK_DARK
const KIT_DOT_OFF := Color(0.113725, 0.129412, 0.219608, 0.22)
const KIT_DOT_ON := RAIL
const KIT_DOT_OFF_FOCUS := Color(0.964706, 0.972549, 0.984314, 0.26)
const KIT_DOT_ON_FOCUS := FOCUS_MARK
const KIT_ARROW_INK := INK
const KIT_ARROW_FOCUS := FOCUS_MARK
const KIT_ART_EDGE := Color(0.090196, 0.105882, 0.247059, 0.26)
const KIT_PREVIEW_PITCH := Color(0.121569, 0.478431, 0.266667, 1.0)

# Match hub (prototype .hub/.lineup/.scoreboard/.command at 1920x1080) ------
const HUB_H := 680.0
const HUB_TOP_H := 530.0
const HUB_ROW_GAP := 40.0
const HUB_SIDE_W := 362.5
const HUB_SCORE_W := 735.0
const HUB_COMMAND_H := 110.0
const HUB_COMMAND_GAP := GAP
const HUB_LINEUP_PAD_TOP := 14.0
const HUB_LINEUP_PAD_SIDE := 18.0
const HUB_LINEUP_PAD_BOTTOM := 16.0
const HUB_LINEUP_NUM_W := 30.0
const HUB_LINEUP_CAP_W := 18.0
const HUB_LINEUP_ROLE_W := 30.0
const HUB_LINEUP_GAP := 6.0
const HUB_LINEUP_MIN_ROWS := 11
const HUB_SCORE_META_TOP := 9.0
const HUB_SCORE_META_BOTTOM := 10.0
const HUB_SCORE_META_SIDE := 16.0
const HUB_SCORE_META_GAP := 3.0
const HUB_SCORE_CLUB_TOP := 14.0
const HUB_SCORE_CLUB_SIDE := 18.0
const HUB_SCORE_CLUB_BOTTOM := 16.0
const HUB_SCORE_CLUB_GAP := 4.0
const HUB_CREST_MIN := 120.0
const HUB_CREST_MAX := 190.0
const HUB_STARS_H := 35.0
const HUB_STATS_TOP := 8.0
const HUB_STATS_SEP := 8.0
const HUB_STAT_LABEL_H := 16.0
const HUB_STAT_VALUE_H := 36.0
const HUB_COMMAND_PAD_X := 10.0
const HUB_COMMAND_PAD_Y := 8.0
const HUB_COMMAND_INNER_GAP := 6.0
const HUB_COMMAND_GLYPH := 40.0
const HUB_STATUS_GAP := 12.0
const HUB_STATUS_H := 24.0
const HUB_LEGEND_GAP := 16.0
const HUB_OPTIONS_PANEL_W := 900.0
const HUB_OPTIONS_PANEL_H := 520.0
const HUB_OPTIONS_ROW_H := 56.0
const HUB_OPTIONS_GAP := 10.0
const HUB_SIDES_PANEL_W := 980.0
const HUB_SIDES_PANEL_H := 500.0
const HUB_SIDES_CARD_H := 240.0
const HUB_SIDES_ART := 96.0

const HUB_PANEL_TOP := Color(0.090196, 0.105882, 0.247059, 0.78)
const HUB_PANEL_BOTTOM := Color(0.090196, 0.105882, 0.247059, 0.58)
const HUB_DIVIDER := Color(0.964706, 0.972549, 0.984314, 0.14)
const HUB_DIVIDER_STRONG := Color(0.964706, 0.972549, 0.984314, 0.16)
const HUB_LINEUP_INK := FOCUS_INK
const HUB_LINEUP_INK_2 := FOCUS_INK_2
const HUB_CAP := RAIL
const HUB_SCRIM := Color(0.015686, 0.035294, 0.078431, 0.78)
const HUB_OPTION_ROW := Color(0.964706, 0.972549, 0.984314, 0.08)
const HUB_OPTION_ROW_FOCUS := Color(0.090196, 0.105882, 0.247059, 0.96)
const HUB_OPTION_STUB := Color(0.964706, 0.972549, 0.984314, 0.55)

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
const SIZE_TEAM_COUNTRY := 24
const SIZE_TEAM_CLUB := 36
const SIZE_TEAM_COMPETITION := 21
const SIZE_TEAM_MARK := 28
const SIZE_TEAM_MARK_READY := 40
const SIZE_TEAM_OWNER := 13
const SIZE_TEAM_STAT_LABEL := 12
const SIZE_TEAM_STAT_VALUE := 36
const SIZE_KIT_TEAM := 14
const SIZE_KIT_COUNT := 19
const SIZE_KIT_NAME := 32
const SIZE_KIT_READY := 40
const SIZE_KIT_PREVIEW_TITLE := 22
const SIZE_KIT_PREVIEW_SUB := 12
const SIZE_KIT_PREVIEW_TEAM := 20
const SIZE_KIT_PREVIEW_VS := 13
const SIZE_HUB_META := 16
const SIZE_HUB_VENUE := 18
const SIZE_HUB_TEAM := 40
const SIZE_HUB_LINEUP_NUM := 24
const SIZE_HUB_LINEUP_NAME := 20
const SIZE_HUB_LINEUP_ROLE := 12
const SIZE_HUB_COMMAND := 20
const SIZE_HUB_OPTION := 18
const SIZE_HUB_OPTION_VALUE := 26
const SIZE_HUB_OPTION_TITLE := 28

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
const KIT_PANEL_COLOR := 0.16
const KIT_PANEL_MOVE := 0.18
const KIT_PANEL_SHADOW := 0.18
