//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSS2PropertiesImpl = @import("impls").CSS2Properties;

pub const CSS2Properties = struct {
    pub const Meta = struct {
        pub const name = "CSS2Properties";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            azimuth: runtime.DOMString = undefined,
            background: runtime.DOMString = undefined,
            backgroundAttachment: runtime.DOMString = undefined,
            backgroundColor: runtime.DOMString = undefined,
            backgroundImage: runtime.DOMString = undefined,
            backgroundPosition: runtime.DOMString = undefined,
            backgroundRepeat: runtime.DOMString = undefined,
            border: runtime.DOMString = undefined,
            borderCollapse: runtime.DOMString = undefined,
            borderColor: runtime.DOMString = undefined,
            borderSpacing: runtime.DOMString = undefined,
            borderStyle: runtime.DOMString = undefined,
            borderTop: runtime.DOMString = undefined,
            borderRight: runtime.DOMString = undefined,
            borderBottom: runtime.DOMString = undefined,
            borderLeft: runtime.DOMString = undefined,
            borderTopColor: runtime.DOMString = undefined,
            borderRightColor: runtime.DOMString = undefined,
            borderBottomColor: runtime.DOMString = undefined,
            borderLeftColor: runtime.DOMString = undefined,
            borderTopStyle: runtime.DOMString = undefined,
            borderRightStyle: runtime.DOMString = undefined,
            borderBottomStyle: runtime.DOMString = undefined,
            borderLeftStyle: runtime.DOMString = undefined,
            borderTopWidth: runtime.DOMString = undefined,
            borderRightWidth: runtime.DOMString = undefined,
            borderBottomWidth: runtime.DOMString = undefined,
            borderLeftWidth: runtime.DOMString = undefined,
            borderWidth: runtime.DOMString = undefined,
            bottom: runtime.DOMString = undefined,
            captionSide: runtime.DOMString = undefined,
            clear: runtime.DOMString = undefined,
            clip: runtime.DOMString = undefined,
            color: runtime.DOMString = undefined,
            content: runtime.DOMString = undefined,
            counterIncrement: runtime.DOMString = undefined,
            counterReset: runtime.DOMString = undefined,
            cue: runtime.DOMString = undefined,
            cueAfter: runtime.DOMString = undefined,
            cueBefore: runtime.DOMString = undefined,
            cursor: runtime.DOMString = undefined,
            direction: runtime.DOMString = undefined,
            display: runtime.DOMString = undefined,
            elevation: runtime.DOMString = undefined,
            emptyCells: runtime.DOMString = undefined,
            cssFloat: runtime.DOMString = undefined,
            font: runtime.DOMString = undefined,
            fontFamily: runtime.DOMString = undefined,
            fontSize: runtime.DOMString = undefined,
            fontSizeAdjust: runtime.DOMString = undefined,
            fontStretch: runtime.DOMString = undefined,
            fontStyle: runtime.DOMString = undefined,
            fontVariant: runtime.DOMString = undefined,
            fontWeight: runtime.DOMString = undefined,
            height: runtime.DOMString = undefined,
            left: runtime.DOMString = undefined,
            letterSpacing: runtime.DOMString = undefined,
            lineHeight: runtime.DOMString = undefined,
            listStyle: runtime.DOMString = undefined,
            listStyleImage: runtime.DOMString = undefined,
            listStylePosition: runtime.DOMString = undefined,
            listStyleType: runtime.DOMString = undefined,
            margin: runtime.DOMString = undefined,
            marginTop: runtime.DOMString = undefined,
            marginRight: runtime.DOMString = undefined,
            marginBottom: runtime.DOMString = undefined,
            marginLeft: runtime.DOMString = undefined,
            markerOffset: runtime.DOMString = undefined,
            marks: runtime.DOMString = undefined,
            maxHeight: runtime.DOMString = undefined,
            maxWidth: runtime.DOMString = undefined,
            minHeight: runtime.DOMString = undefined,
            minWidth: runtime.DOMString = undefined,
            orphans: runtime.DOMString = undefined,
            outline: runtime.DOMString = undefined,
            outlineColor: runtime.DOMString = undefined,
            outlineStyle: runtime.DOMString = undefined,
            outlineWidth: runtime.DOMString = undefined,
            overflow: runtime.DOMString = undefined,
            padding: runtime.DOMString = undefined,
            paddingTop: runtime.DOMString = undefined,
            paddingRight: runtime.DOMString = undefined,
            paddingBottom: runtime.DOMString = undefined,
            paddingLeft: runtime.DOMString = undefined,
            page: runtime.DOMString = undefined,
            pageBreakAfter: runtime.DOMString = undefined,
            pageBreakBefore: runtime.DOMString = undefined,
            pageBreakInside: runtime.DOMString = undefined,
            pause: runtime.DOMString = undefined,
            pauseAfter: runtime.DOMString = undefined,
            pauseBefore: runtime.DOMString = undefined,
            pitch: runtime.DOMString = undefined,
            pitchRange: runtime.DOMString = undefined,
            playDuring: runtime.DOMString = undefined,
            position: runtime.DOMString = undefined,
            quotes: runtime.DOMString = undefined,
            richness: runtime.DOMString = undefined,
            right: runtime.DOMString = undefined,
            size: runtime.DOMString = undefined,
            speak: runtime.DOMString = undefined,
            speakHeader: runtime.DOMString = undefined,
            speakNumeral: runtime.DOMString = undefined,
            speakPunctuation: runtime.DOMString = undefined,
            speechRate: runtime.DOMString = undefined,
            stress: runtime.DOMString = undefined,
            tableLayout: runtime.DOMString = undefined,
            textAlign: runtime.DOMString = undefined,
            textDecoration: runtime.DOMString = undefined,
            textIndent: runtime.DOMString = undefined,
            textShadow: runtime.DOMString = undefined,
            textTransform: runtime.DOMString = undefined,
            top: runtime.DOMString = undefined,
            unicodeBidi: runtime.DOMString = undefined,
            verticalAlign: runtime.DOMString = undefined,
            visibility: runtime.DOMString = undefined,
            voiceFamily: runtime.DOMString = undefined,
            volume: runtime.DOMString = undefined,
            whiteSpace: runtime.DOMString = undefined,
            widows: runtime.DOMString = undefined,
            width: runtime.DOMString = undefined,
            wordSpacing: runtime.DOMString = undefined,
            zIndex: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSS2Properties, .{
        .deinit_fn = &deinit_wrapper,

        .get_azimuth = &get_azimuth,
        .get_background = &get_background,
        .get_backgroundAttachment = &get_backgroundAttachment,
        .get_backgroundColor = &get_backgroundColor,
        .get_backgroundImage = &get_backgroundImage,
        .get_backgroundPosition = &get_backgroundPosition,
        .get_backgroundRepeat = &get_backgroundRepeat,
        .get_border = &get_border,
        .get_borderBottom = &get_borderBottom,
        .get_borderBottomColor = &get_borderBottomColor,
        .get_borderBottomStyle = &get_borderBottomStyle,
        .get_borderBottomWidth = &get_borderBottomWidth,
        .get_borderCollapse = &get_borderCollapse,
        .get_borderColor = &get_borderColor,
        .get_borderLeft = &get_borderLeft,
        .get_borderLeftColor = &get_borderLeftColor,
        .get_borderLeftStyle = &get_borderLeftStyle,
        .get_borderLeftWidth = &get_borderLeftWidth,
        .get_borderRight = &get_borderRight,
        .get_borderRightColor = &get_borderRightColor,
        .get_borderRightStyle = &get_borderRightStyle,
        .get_borderRightWidth = &get_borderRightWidth,
        .get_borderSpacing = &get_borderSpacing,
        .get_borderStyle = &get_borderStyle,
        .get_borderTop = &get_borderTop,
        .get_borderTopColor = &get_borderTopColor,
        .get_borderTopStyle = &get_borderTopStyle,
        .get_borderTopWidth = &get_borderTopWidth,
        .get_borderWidth = &get_borderWidth,
        .get_bottom = &get_bottom,
        .get_captionSide = &get_captionSide,
        .get_clear = &get_clear,
        .get_clip = &get_clip,
        .get_color = &get_color,
        .get_content = &get_content,
        .get_counterIncrement = &get_counterIncrement,
        .get_counterReset = &get_counterReset,
        .get_cssFloat = &get_cssFloat,
        .get_cue = &get_cue,
        .get_cueAfter = &get_cueAfter,
        .get_cueBefore = &get_cueBefore,
        .get_cursor = &get_cursor,
        .get_direction = &get_direction,
        .get_display = &get_display,
        .get_elevation = &get_elevation,
        .get_emptyCells = &get_emptyCells,
        .get_font = &get_font,
        .get_fontFamily = &get_fontFamily,
        .get_fontSize = &get_fontSize,
        .get_fontSizeAdjust = &get_fontSizeAdjust,
        .get_fontStretch = &get_fontStretch,
        .get_fontStyle = &get_fontStyle,
        .get_fontVariant = &get_fontVariant,
        .get_fontWeight = &get_fontWeight,
        .get_height = &get_height,
        .get_left = &get_left,
        .get_letterSpacing = &get_letterSpacing,
        .get_lineHeight = &get_lineHeight,
        .get_listStyle = &get_listStyle,
        .get_listStyleImage = &get_listStyleImage,
        .get_listStylePosition = &get_listStylePosition,
        .get_listStyleType = &get_listStyleType,
        .get_margin = &get_margin,
        .get_marginBottom = &get_marginBottom,
        .get_marginLeft = &get_marginLeft,
        .get_marginRight = &get_marginRight,
        .get_marginTop = &get_marginTop,
        .get_markerOffset = &get_markerOffset,
        .get_marks = &get_marks,
        .get_maxHeight = &get_maxHeight,
        .get_maxWidth = &get_maxWidth,
        .get_minHeight = &get_minHeight,
        .get_minWidth = &get_minWidth,
        .get_orphans = &get_orphans,
        .get_outline = &get_outline,
        .get_outlineColor = &get_outlineColor,
        .get_outlineStyle = &get_outlineStyle,
        .get_outlineWidth = &get_outlineWidth,
        .get_overflow = &get_overflow,
        .get_padding = &get_padding,
        .get_paddingBottom = &get_paddingBottom,
        .get_paddingLeft = &get_paddingLeft,
        .get_paddingRight = &get_paddingRight,
        .get_paddingTop = &get_paddingTop,
        .get_page = &get_page,
        .get_pageBreakAfter = &get_pageBreakAfter,
        .get_pageBreakBefore = &get_pageBreakBefore,
        .get_pageBreakInside = &get_pageBreakInside,
        .get_pause = &get_pause,
        .get_pauseAfter = &get_pauseAfter,
        .get_pauseBefore = &get_pauseBefore,
        .get_pitch = &get_pitch,
        .get_pitchRange = &get_pitchRange,
        .get_playDuring = &get_playDuring,
        .get_position = &get_position,
        .get_quotes = &get_quotes,
        .get_richness = &get_richness,
        .get_right = &get_right,
        .get_size = &get_size,
        .get_speak = &get_speak,
        .get_speakHeader = &get_speakHeader,
        .get_speakNumeral = &get_speakNumeral,
        .get_speakPunctuation = &get_speakPunctuation,
        .get_speechRate = &get_speechRate,
        .get_stress = &get_stress,
        .get_tableLayout = &get_tableLayout,
        .get_textAlign = &get_textAlign,
        .get_textDecoration = &get_textDecoration,
        .get_textIndent = &get_textIndent,
        .get_textShadow = &get_textShadow,
        .get_textTransform = &get_textTransform,
        .get_top = &get_top,
        .get_unicodeBidi = &get_unicodeBidi,
        .get_verticalAlign = &get_verticalAlign,
        .get_visibility = &get_visibility,
        .get_voiceFamily = &get_voiceFamily,
        .get_volume = &get_volume,
        .get_whiteSpace = &get_whiteSpace,
        .get_widows = &get_widows,
        .get_width = &get_width,
        .get_wordSpacing = &get_wordSpacing,
        .get_zIndex = &get_zIndex,

        .set_azimuth = &set_azimuth,
        .set_background = &set_background,
        .set_backgroundAttachment = &set_backgroundAttachment,
        .set_backgroundColor = &set_backgroundColor,
        .set_backgroundImage = &set_backgroundImage,
        .set_backgroundPosition = &set_backgroundPosition,
        .set_backgroundRepeat = &set_backgroundRepeat,
        .set_border = &set_border,
        .set_borderBottom = &set_borderBottom,
        .set_borderBottomColor = &set_borderBottomColor,
        .set_borderBottomStyle = &set_borderBottomStyle,
        .set_borderBottomWidth = &set_borderBottomWidth,
        .set_borderCollapse = &set_borderCollapse,
        .set_borderColor = &set_borderColor,
        .set_borderLeft = &set_borderLeft,
        .set_borderLeftColor = &set_borderLeftColor,
        .set_borderLeftStyle = &set_borderLeftStyle,
        .set_borderLeftWidth = &set_borderLeftWidth,
        .set_borderRight = &set_borderRight,
        .set_borderRightColor = &set_borderRightColor,
        .set_borderRightStyle = &set_borderRightStyle,
        .set_borderRightWidth = &set_borderRightWidth,
        .set_borderSpacing = &set_borderSpacing,
        .set_borderStyle = &set_borderStyle,
        .set_borderTop = &set_borderTop,
        .set_borderTopColor = &set_borderTopColor,
        .set_borderTopStyle = &set_borderTopStyle,
        .set_borderTopWidth = &set_borderTopWidth,
        .set_borderWidth = &set_borderWidth,
        .set_bottom = &set_bottom,
        .set_captionSide = &set_captionSide,
        .set_clear = &set_clear,
        .set_clip = &set_clip,
        .set_color = &set_color,
        .set_content = &set_content,
        .set_counterIncrement = &set_counterIncrement,
        .set_counterReset = &set_counterReset,
        .set_cssFloat = &set_cssFloat,
        .set_cue = &set_cue,
        .set_cueAfter = &set_cueAfter,
        .set_cueBefore = &set_cueBefore,
        .set_cursor = &set_cursor,
        .set_direction = &set_direction,
        .set_display = &set_display,
        .set_elevation = &set_elevation,
        .set_emptyCells = &set_emptyCells,
        .set_font = &set_font,
        .set_fontFamily = &set_fontFamily,
        .set_fontSize = &set_fontSize,
        .set_fontSizeAdjust = &set_fontSizeAdjust,
        .set_fontStretch = &set_fontStretch,
        .set_fontStyle = &set_fontStyle,
        .set_fontVariant = &set_fontVariant,
        .set_fontWeight = &set_fontWeight,
        .set_height = &set_height,
        .set_left = &set_left,
        .set_letterSpacing = &set_letterSpacing,
        .set_lineHeight = &set_lineHeight,
        .set_listStyle = &set_listStyle,
        .set_listStyleImage = &set_listStyleImage,
        .set_listStylePosition = &set_listStylePosition,
        .set_listStyleType = &set_listStyleType,
        .set_margin = &set_margin,
        .set_marginBottom = &set_marginBottom,
        .set_marginLeft = &set_marginLeft,
        .set_marginRight = &set_marginRight,
        .set_marginTop = &set_marginTop,
        .set_markerOffset = &set_markerOffset,
        .set_marks = &set_marks,
        .set_maxHeight = &set_maxHeight,
        .set_maxWidth = &set_maxWidth,
        .set_minHeight = &set_minHeight,
        .set_minWidth = &set_minWidth,
        .set_orphans = &set_orphans,
        .set_outline = &set_outline,
        .set_outlineColor = &set_outlineColor,
        .set_outlineStyle = &set_outlineStyle,
        .set_outlineWidth = &set_outlineWidth,
        .set_overflow = &set_overflow,
        .set_padding = &set_padding,
        .set_paddingBottom = &set_paddingBottom,
        .set_paddingLeft = &set_paddingLeft,
        .set_paddingRight = &set_paddingRight,
        .set_paddingTop = &set_paddingTop,
        .set_page = &set_page,
        .set_pageBreakAfter = &set_pageBreakAfter,
        .set_pageBreakBefore = &set_pageBreakBefore,
        .set_pageBreakInside = &set_pageBreakInside,
        .set_pause = &set_pause,
        .set_pauseAfter = &set_pauseAfter,
        .set_pauseBefore = &set_pauseBefore,
        .set_pitch = &set_pitch,
        .set_pitchRange = &set_pitchRange,
        .set_playDuring = &set_playDuring,
        .set_position = &set_position,
        .set_quotes = &set_quotes,
        .set_richness = &set_richness,
        .set_right = &set_right,
        .set_size = &set_size,
        .set_speak = &set_speak,
        .set_speakHeader = &set_speakHeader,
        .set_speakNumeral = &set_speakNumeral,
        .set_speakPunctuation = &set_speakPunctuation,
        .set_speechRate = &set_speechRate,
        .set_stress = &set_stress,
        .set_tableLayout = &set_tableLayout,
        .set_textAlign = &set_textAlign,
        .set_textDecoration = &set_textDecoration,
        .set_textIndent = &set_textIndent,
        .set_textShadow = &set_textShadow,
        .set_textTransform = &set_textTransform,
        .set_top = &set_top,
        .set_unicodeBidi = &set_unicodeBidi,
        .set_verticalAlign = &set_verticalAlign,
        .set_visibility = &set_visibility,
        .set_voiceFamily = &set_voiceFamily,
        .set_volume = &set_volume,
        .set_whiteSpace = &set_whiteSpace,
        .set_widows = &set_widows,
        .set_width = &set_width,
        .set_wordSpacing = &set_wordSpacing,
        .set_zIndex = &set_zIndex,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSS2PropertiesImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSS2PropertiesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_azimuth(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_azimuth(instance);
    }

    pub fn set_azimuth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_azimuth(instance, value);
    }

    pub fn get_background(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_background(instance);
    }

    pub fn set_background(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_background(instance, value);
    }

    pub fn get_backgroundAttachment(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_backgroundAttachment(instance);
    }

    pub fn set_backgroundAttachment(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_backgroundAttachment(instance, value);
    }

    pub fn get_backgroundColor(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_backgroundColor(instance);
    }

    pub fn set_backgroundColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_backgroundColor(instance, value);
    }

    pub fn get_backgroundImage(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_backgroundImage(instance);
    }

    pub fn set_backgroundImage(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_backgroundImage(instance, value);
    }

    pub fn get_backgroundPosition(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_backgroundPosition(instance);
    }

    pub fn set_backgroundPosition(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_backgroundPosition(instance, value);
    }

    pub fn get_backgroundRepeat(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_backgroundRepeat(instance);
    }

    pub fn set_backgroundRepeat(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_backgroundRepeat(instance, value);
    }

    pub fn get_border(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_border(instance);
    }

    pub fn set_border(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_border(instance, value);
    }

    pub fn get_borderCollapse(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderCollapse(instance);
    }

    pub fn set_borderCollapse(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderCollapse(instance, value);
    }

    pub fn get_borderColor(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderColor(instance);
    }

    pub fn set_borderColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderColor(instance, value);
    }

    pub fn get_borderSpacing(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderSpacing(instance);
    }

    pub fn set_borderSpacing(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderSpacing(instance, value);
    }

    pub fn get_borderStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderStyle(instance);
    }

    pub fn set_borderStyle(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderStyle(instance, value);
    }

    pub fn get_borderTop(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderTop(instance);
    }

    pub fn set_borderTop(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderTop(instance, value);
    }

    pub fn get_borderRight(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderRight(instance);
    }

    pub fn set_borderRight(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderRight(instance, value);
    }

    pub fn get_borderBottom(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderBottom(instance);
    }

    pub fn set_borderBottom(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderBottom(instance, value);
    }

    pub fn get_borderLeft(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderLeft(instance);
    }

    pub fn set_borderLeft(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderLeft(instance, value);
    }

    pub fn get_borderTopColor(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderTopColor(instance);
    }

    pub fn set_borderTopColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderTopColor(instance, value);
    }

    pub fn get_borderRightColor(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderRightColor(instance);
    }

    pub fn set_borderRightColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderRightColor(instance, value);
    }

    pub fn get_borderBottomColor(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderBottomColor(instance);
    }

    pub fn set_borderBottomColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderBottomColor(instance, value);
    }

    pub fn get_borderLeftColor(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderLeftColor(instance);
    }

    pub fn set_borderLeftColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderLeftColor(instance, value);
    }

    pub fn get_borderTopStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderTopStyle(instance);
    }

    pub fn set_borderTopStyle(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderTopStyle(instance, value);
    }

    pub fn get_borderRightStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderRightStyle(instance);
    }

    pub fn set_borderRightStyle(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderRightStyle(instance, value);
    }

    pub fn get_borderBottomStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderBottomStyle(instance);
    }

    pub fn set_borderBottomStyle(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderBottomStyle(instance, value);
    }

    pub fn get_borderLeftStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderLeftStyle(instance);
    }

    pub fn set_borderLeftStyle(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderLeftStyle(instance, value);
    }

    pub fn get_borderTopWidth(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderTopWidth(instance);
    }

    pub fn set_borderTopWidth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderTopWidth(instance, value);
    }

    pub fn get_borderRightWidth(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderRightWidth(instance);
    }

    pub fn set_borderRightWidth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderRightWidth(instance, value);
    }

    pub fn get_borderBottomWidth(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderBottomWidth(instance);
    }

    pub fn set_borderBottomWidth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderBottomWidth(instance, value);
    }

    pub fn get_borderLeftWidth(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderLeftWidth(instance);
    }

    pub fn set_borderLeftWidth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderLeftWidth(instance, value);
    }

    pub fn get_borderWidth(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_borderWidth(instance);
    }

    pub fn set_borderWidth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_borderWidth(instance, value);
    }

    pub fn get_bottom(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_bottom(instance);
    }

    pub fn set_bottom(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_bottom(instance, value);
    }

    pub fn get_captionSide(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_captionSide(instance);
    }

    pub fn set_captionSide(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_captionSide(instance, value);
    }

    pub fn get_clear(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_clear(instance);
    }

    pub fn set_clear(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_clear(instance, value);
    }

    pub fn get_clip(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_clip(instance);
    }

    pub fn set_clip(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_clip(instance, value);
    }

    pub fn get_color(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_color(instance);
    }

    pub fn set_color(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_color(instance, value);
    }

    pub fn get_content(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_content(instance);
    }

    pub fn set_content(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_content(instance, value);
    }

    pub fn get_counterIncrement(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_counterIncrement(instance);
    }

    pub fn set_counterIncrement(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_counterIncrement(instance, value);
    }

    pub fn get_counterReset(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_counterReset(instance);
    }

    pub fn set_counterReset(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_counterReset(instance, value);
    }

    pub fn get_cue(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_cue(instance);
    }

    pub fn set_cue(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_cue(instance, value);
    }

    pub fn get_cueAfter(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_cueAfter(instance);
    }

    pub fn set_cueAfter(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_cueAfter(instance, value);
    }

    pub fn get_cueBefore(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_cueBefore(instance);
    }

    pub fn set_cueBefore(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_cueBefore(instance, value);
    }

    pub fn get_cursor(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_cursor(instance);
    }

    pub fn set_cursor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_cursor(instance, value);
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_direction(instance);
    }

    pub fn set_direction(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_direction(instance, value);
    }

    pub fn get_display(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_display(instance);
    }

    pub fn set_display(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_display(instance, value);
    }

    pub fn get_elevation(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_elevation(instance);
    }

    pub fn set_elevation(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_elevation(instance, value);
    }

    pub fn get_emptyCells(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_emptyCells(instance);
    }

    pub fn set_emptyCells(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_emptyCells(instance, value);
    }

    pub fn get_cssFloat(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_cssFloat(instance);
    }

    pub fn set_cssFloat(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_cssFloat(instance, value);
    }

    pub fn get_font(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_font(instance);
    }

    pub fn set_font(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_font(instance, value);
    }

    pub fn get_fontFamily(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_fontFamily(instance);
    }

    pub fn set_fontFamily(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_fontFamily(instance, value);
    }

    pub fn get_fontSize(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_fontSize(instance);
    }

    pub fn set_fontSize(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_fontSize(instance, value);
    }

    pub fn get_fontSizeAdjust(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_fontSizeAdjust(instance);
    }

    pub fn set_fontSizeAdjust(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_fontSizeAdjust(instance, value);
    }

    pub fn get_fontStretch(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_fontStretch(instance);
    }

    pub fn set_fontStretch(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_fontStretch(instance, value);
    }

    pub fn get_fontStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_fontStyle(instance);
    }

    pub fn set_fontStyle(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_fontStyle(instance, value);
    }

    pub fn get_fontVariant(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_fontVariant(instance);
    }

    pub fn set_fontVariant(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_fontVariant(instance, value);
    }

    pub fn get_fontWeight(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_fontWeight(instance);
    }

    pub fn set_fontWeight(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_fontWeight(instance, value);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_height(instance);
    }

    pub fn set_height(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_height(instance, value);
    }

    pub fn get_left(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_left(instance);
    }

    pub fn set_left(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_left(instance, value);
    }

    pub fn get_letterSpacing(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_letterSpacing(instance);
    }

    pub fn set_letterSpacing(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_letterSpacing(instance, value);
    }

    pub fn get_lineHeight(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_lineHeight(instance);
    }

    pub fn set_lineHeight(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_lineHeight(instance, value);
    }

    pub fn get_listStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_listStyle(instance);
    }

    pub fn set_listStyle(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_listStyle(instance, value);
    }

    pub fn get_listStyleImage(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_listStyleImage(instance);
    }

    pub fn set_listStyleImage(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_listStyleImage(instance, value);
    }

    pub fn get_listStylePosition(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_listStylePosition(instance);
    }

    pub fn set_listStylePosition(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_listStylePosition(instance, value);
    }

    pub fn get_listStyleType(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_listStyleType(instance);
    }

    pub fn set_listStyleType(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_listStyleType(instance, value);
    }

    pub fn get_margin(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_margin(instance);
    }

    pub fn set_margin(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_margin(instance, value);
    }

    pub fn get_marginTop(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_marginTop(instance);
    }

    pub fn set_marginTop(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_marginTop(instance, value);
    }

    pub fn get_marginRight(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_marginRight(instance);
    }

    pub fn set_marginRight(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_marginRight(instance, value);
    }

    pub fn get_marginBottom(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_marginBottom(instance);
    }

    pub fn set_marginBottom(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_marginBottom(instance, value);
    }

    pub fn get_marginLeft(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_marginLeft(instance);
    }

    pub fn set_marginLeft(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_marginLeft(instance, value);
    }

    pub fn get_markerOffset(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_markerOffset(instance);
    }

    pub fn set_markerOffset(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_markerOffset(instance, value);
    }

    pub fn get_marks(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_marks(instance);
    }

    pub fn set_marks(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_marks(instance, value);
    }

    pub fn get_maxHeight(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_maxHeight(instance);
    }

    pub fn set_maxHeight(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_maxHeight(instance, value);
    }

    pub fn get_maxWidth(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_maxWidth(instance);
    }

    pub fn set_maxWidth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_maxWidth(instance, value);
    }

    pub fn get_minHeight(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_minHeight(instance);
    }

    pub fn set_minHeight(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_minHeight(instance, value);
    }

    pub fn get_minWidth(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_minWidth(instance);
    }

    pub fn set_minWidth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_minWidth(instance, value);
    }

    pub fn get_orphans(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_orphans(instance);
    }

    pub fn set_orphans(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_orphans(instance, value);
    }

    pub fn get_outline(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_outline(instance);
    }

    pub fn set_outline(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_outline(instance, value);
    }

    pub fn get_outlineColor(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_outlineColor(instance);
    }

    pub fn set_outlineColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_outlineColor(instance, value);
    }

    pub fn get_outlineStyle(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_outlineStyle(instance);
    }

    pub fn set_outlineStyle(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_outlineStyle(instance, value);
    }

    pub fn get_outlineWidth(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_outlineWidth(instance);
    }

    pub fn set_outlineWidth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_outlineWidth(instance, value);
    }

    pub fn get_overflow(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_overflow(instance);
    }

    pub fn set_overflow(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_overflow(instance, value);
    }

    pub fn get_padding(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_padding(instance);
    }

    pub fn set_padding(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_padding(instance, value);
    }

    pub fn get_paddingTop(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_paddingTop(instance);
    }

    pub fn set_paddingTop(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_paddingTop(instance, value);
    }

    pub fn get_paddingRight(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_paddingRight(instance);
    }

    pub fn set_paddingRight(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_paddingRight(instance, value);
    }

    pub fn get_paddingBottom(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_paddingBottom(instance);
    }

    pub fn set_paddingBottom(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_paddingBottom(instance, value);
    }

    pub fn get_paddingLeft(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_paddingLeft(instance);
    }

    pub fn set_paddingLeft(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_paddingLeft(instance, value);
    }

    pub fn get_page(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_page(instance);
    }

    pub fn set_page(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_page(instance, value);
    }

    pub fn get_pageBreakAfter(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_pageBreakAfter(instance);
    }

    pub fn set_pageBreakAfter(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_pageBreakAfter(instance, value);
    }

    pub fn get_pageBreakBefore(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_pageBreakBefore(instance);
    }

    pub fn set_pageBreakBefore(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_pageBreakBefore(instance, value);
    }

    pub fn get_pageBreakInside(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_pageBreakInside(instance);
    }

    pub fn set_pageBreakInside(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_pageBreakInside(instance, value);
    }

    pub fn get_pause(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_pause(instance);
    }

    pub fn set_pause(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_pause(instance, value);
    }

    pub fn get_pauseAfter(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_pauseAfter(instance);
    }

    pub fn set_pauseAfter(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_pauseAfter(instance, value);
    }

    pub fn get_pauseBefore(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_pauseBefore(instance);
    }

    pub fn set_pauseBefore(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_pauseBefore(instance, value);
    }

    pub fn get_pitch(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_pitch(instance);
    }

    pub fn set_pitch(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_pitch(instance, value);
    }

    pub fn get_pitchRange(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_pitchRange(instance);
    }

    pub fn set_pitchRange(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_pitchRange(instance, value);
    }

    pub fn get_playDuring(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_playDuring(instance);
    }

    pub fn set_playDuring(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_playDuring(instance, value);
    }

    pub fn get_position(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_position(instance);
    }

    pub fn set_position(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_position(instance, value);
    }

    pub fn get_quotes(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_quotes(instance);
    }

    pub fn set_quotes(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_quotes(instance, value);
    }

    pub fn get_richness(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_richness(instance);
    }

    pub fn set_richness(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_richness(instance, value);
    }

    pub fn get_right(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_right(instance);
    }

    pub fn set_right(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_right(instance, value);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_size(instance);
    }

    pub fn set_size(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_size(instance, value);
    }

    pub fn get_speak(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_speak(instance);
    }

    pub fn set_speak(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_speak(instance, value);
    }

    pub fn get_speakHeader(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_speakHeader(instance);
    }

    pub fn set_speakHeader(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_speakHeader(instance, value);
    }

    pub fn get_speakNumeral(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_speakNumeral(instance);
    }

    pub fn set_speakNumeral(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_speakNumeral(instance, value);
    }

    pub fn get_speakPunctuation(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_speakPunctuation(instance);
    }

    pub fn set_speakPunctuation(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_speakPunctuation(instance, value);
    }

    pub fn get_speechRate(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_speechRate(instance);
    }

    pub fn set_speechRate(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_speechRate(instance, value);
    }

    pub fn get_stress(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_stress(instance);
    }

    pub fn set_stress(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_stress(instance, value);
    }

    pub fn get_tableLayout(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_tableLayout(instance);
    }

    pub fn set_tableLayout(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_tableLayout(instance, value);
    }

    pub fn get_textAlign(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_textAlign(instance);
    }

    pub fn set_textAlign(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_textAlign(instance, value);
    }

    pub fn get_textDecoration(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_textDecoration(instance);
    }

    pub fn set_textDecoration(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_textDecoration(instance, value);
    }

    pub fn get_textIndent(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_textIndent(instance);
    }

    pub fn set_textIndent(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_textIndent(instance, value);
    }

    pub fn get_textShadow(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_textShadow(instance);
    }

    pub fn set_textShadow(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_textShadow(instance, value);
    }

    pub fn get_textTransform(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_textTransform(instance);
    }

    pub fn set_textTransform(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_textTransform(instance, value);
    }

    pub fn get_top(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_top(instance);
    }

    pub fn set_top(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_top(instance, value);
    }

    pub fn get_unicodeBidi(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_unicodeBidi(instance);
    }

    pub fn set_unicodeBidi(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_unicodeBidi(instance, value);
    }

    pub fn get_verticalAlign(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_verticalAlign(instance);
    }

    pub fn set_verticalAlign(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_verticalAlign(instance, value);
    }

    pub fn get_visibility(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_visibility(instance);
    }

    pub fn set_visibility(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_visibility(instance, value);
    }

    pub fn get_voiceFamily(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_voiceFamily(instance);
    }

    pub fn set_voiceFamily(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_voiceFamily(instance, value);
    }

    pub fn get_volume(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_volume(instance);
    }

    pub fn set_volume(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_volume(instance, value);
    }

    pub fn get_whiteSpace(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_whiteSpace(instance);
    }

    pub fn set_whiteSpace(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_whiteSpace(instance, value);
    }

    pub fn get_widows(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_widows(instance);
    }

    pub fn set_widows(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_widows(instance, value);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_width(instance);
    }

    pub fn set_width(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_width(instance, value);
    }

    pub fn get_wordSpacing(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_wordSpacing(instance);
    }

    pub fn set_wordSpacing(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_wordSpacing(instance, value);
    }

    pub fn get_zIndex(instance: *runtime.Instance) anyerror!DOMString {
        return try CSS2PropertiesImpl.get_zIndex(instance);
    }

    pub fn set_zIndex(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSS2PropertiesImpl.set_zIndex(instance, value);
    }

};
