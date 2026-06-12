pragma Singleton
import QtQuick

QtObject {
    // ── Brand Palette ──────────────────────────────────
    // Change these values to completely rebrand the widget

    readonly property color accent:          "#3a7bd5"
    readonly property color accentDark:      "#2b5278"
    readonly property color accentLight:     "#5a9be5"

    readonly property color danger:          "#F44336"
    readonly property color dangerHover:     "#e53935"

    readonly property color success:         "#43A047"
    readonly property color successHover:    "#4CAF50"

    readonly property color surface:         "#1a1a1a"
    readonly property color surfaceRaised:   "#2a2a2a"
    readonly property color surfaceOverlay:  "#2d2d2d"

    readonly property color textPrimary:     "#e0e0e0"
    readonly property color textSecondary:   "#cccccc"
    readonly property color textMuted:       "#888888"
    readonly property color textPlaceholder: "#606060"
    readonly property color textDisabled:    "#555555"
    readonly property color textOnAccent:    "#ffffff"

    readonly property color borderDefault:   "#404040"
    readonly property color borderFocus:     "#3a7bd5"

    readonly property color statusOnline:     "#4CAF50"
    readonly property color statusOffline:    "#F44336"
    readonly property color statusConnecting: "#999999"
    readonly property color statusWarning:    "#FFA726"

    // ── Semantic Aliases ──────────────────────────────
    // Map brand colors to specific UI elements

    readonly property color bubbleUserBg:          accentDark
    readonly property color bubbleUserBorder:      accent
    readonly property color bubbleAssistantBg:     surfaceOverlay
    readonly property color bubbleAssistantBorder: borderDefault

    readonly property color btnSecondaryBg:        "#3a3a3a"
    readonly property color btnSecondaryHover:     "#4a4a4a"
    readonly property color btnSecondaryText:      "#aaaaaa"
    readonly property color btnDisabledBg:         surfaceRaised

    readonly property color resizeHandleBg:        "#40ffffff"
    readonly property color resizeHandleFg:        "#80ffffff"

    // ── Typography ────────────────────────────────────

    readonly property string fontFamily:    ""
    readonly property int fontSizeXs:       10
    readonly property int fontSizeSm:       12
    readonly property int fontSizeBase:     13
    readonly property int fontSizeMd:       14
    readonly property int fontSizeLg:       16

    // ── Radii ─────────────────────────────────────────

    readonly property int radiusXs:  3
    readonly property int radiusSm:  6
    readonly property int radiusMd:  8

    // ── Spacing ───────────────────────────────────────

    readonly property int spacingXs: 2
    readonly property int spacingSm: 4
    readonly property int spacingMd: 8
    readonly property int spacingLg: 12

    // ── Layout ────────────────────────────────────────

    readonly property int bubbleMaxHeight:  360
    readonly property int inputMaxHeight:   100
    readonly property int inputMinHeight:   34
    readonly property int animationDuration: 250
}
