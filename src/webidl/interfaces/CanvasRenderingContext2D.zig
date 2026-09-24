//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasRenderingContext2DImpl = @import("impls").CanvasRenderingContext2D;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasSettings = @import("mixins").CanvasSettings;
const CanvasState = @import("mixins").CanvasState;
const CanvasTransform = @import("mixins").CanvasTransform;
const CanvasCompositing = @import("mixins").CanvasCompositing;
const CanvasImageSmoothing = @import("mixins").CanvasImageSmoothing;
const CanvasFillStrokeStyles = @import("mixins").CanvasFillStrokeStyles;
const CanvasShadowStyles = @import("mixins").CanvasShadowStyles;
const CanvasFilters = @import("mixins").CanvasFilters;
const CanvasRect = @import("mixins").CanvasRect;
const CanvasDrawPath = @import("mixins").CanvasDrawPath;
const CanvasUserInterface = @import("mixins").CanvasUserInterface;
const CanvasText = @import("mixins").CanvasText;
const CanvasDrawImage = @import("mixins").CanvasDrawImage;
const CanvasImageData = @import("mixins").CanvasImageData;
const CanvasPathDrawingStyles = @import("mixins").CanvasPathDrawingStyles;
const CanvasTextDrawingStyles = @import("mixins").CanvasTextDrawingStyles;
const CanvasPath = @import("mixins").CanvasPath;
const HTMLCanvasElement = @import("interfaces").HTMLCanvasElement;
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const CanvasFontVariantCaps = @import("enums").CanvasFontVariantCaps;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const CanvasFillRule = @import("enums").CanvasFillRule;
const TextMetrics = @import("interfaces").TextMetrics;
const ImageData = @import("interfaces").ImageData;
const Element = @import("interfaces").Element;
const CanvasDirection = @import("enums").CanvasDirection;
const DOMMatrix = @import("interfaces").DOMMatrix;
const CanvasTextBaseline = @import("enums").CanvasTextBaseline;
const CanvasGradient = @import("interfaces").CanvasGradient;
const CanvasLineCap = @import("enums").CanvasLineCap;
const CanvasPattern = @import("interfaces").CanvasPattern;
const CanvasImageSource = @import("typedefs").CanvasImageSource;
const CanvasTextRendering = @import("enums").CanvasTextRendering;
const Path2D = @import("interfaces").Path2D;
const CanvasRenderingContext2DSettings = @import("dictionaries").CanvasRenderingContext2DSettings;
const ImageDataSettings = @import("dictionaries").ImageDataSettings;
const CanvasTextAlign = @import("enums").CanvasTextAlign;
const ImageSmoothingQuality = @import("enums").ImageSmoothingQuality;
const CanvasLineJoin = @import("enums").CanvasLineJoin;
const CanvasFontKerning = @import("enums").CanvasFontKerning;
const CanvasFontStretch = @import("enums").CanvasFontStretch;
const DOMString = @import("typedefs").DOMString;

pub const CanvasRenderingContext2D = struct {
    pub const Meta = struct {
        pub const name = "CanvasRenderingContext2D";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            CanvasSettings,
            CanvasState,
            CanvasTransform,
            CanvasCompositing,
            CanvasImageSmoothing,
            CanvasFillStrokeStyles,
            CanvasShadowStyles,
            CanvasFilters,
            CanvasRect,
            CanvasDrawPath,
            CanvasUserInterface,
            CanvasText,
            CanvasDrawImage,
            CanvasImageData,
            CanvasPathDrawingStyles,
            CanvasTextDrawingStyles,
            CanvasPath,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "canvas", "get_canvas", null },
            .{ "globalAlpha", "get_globalAlpha", "set_globalAlpha" },
            .{ "globalCompositeOperation", "get_globalCompositeOperation", "set_globalCompositeOperation" },
            .{ "imageSmoothingEnabled", "get_imageSmoothingEnabled", "set_imageSmoothingEnabled" },
            .{ "imageSmoothingQuality", "get_imageSmoothingQuality", "set_imageSmoothingQuality" },
            .{ "strokeStyle", "get_strokeStyle", "set_strokeStyle" },
            .{ "fillStyle", "get_fillStyle", "set_fillStyle" },
            .{ "shadowOffsetX", "get_shadowOffsetX", "set_shadowOffsetX" },
            .{ "shadowOffsetY", "get_shadowOffsetY", "set_shadowOffsetY" },
            .{ "shadowBlur", "get_shadowBlur", "set_shadowBlur" },
            .{ "shadowColor", "get_shadowColor", "set_shadowColor" },
            .{ "filter", "get_filter", "set_filter" },
            .{ "lineWidth", "get_lineWidth", "set_lineWidth" },
            .{ "lineCap", "get_lineCap", "set_lineCap" },
            .{ "lineJoin", "get_lineJoin", "set_lineJoin" },
            .{ "miterLimit", "get_miterLimit", "set_miterLimit" },
            .{ "lineDashOffset", "get_lineDashOffset", "set_lineDashOffset" },
            .{ "lang", "get_lang", "set_lang" },
            .{ "font", "get_font", "set_font" },
            .{ "textAlign", "get_textAlign", "set_textAlign" },
            .{ "textBaseline", "get_textBaseline", "set_textBaseline" },
            .{ "direction", "get_direction", "set_direction" },
            .{ "letterSpacing", "get_letterSpacing", "set_letterSpacing" },
            .{ "fontKerning", "get_fontKerning", "set_fontKerning" },
            .{ "fontStretch", "get_fontStretch", "set_fontStretch" },
            .{ "fontVariantCaps", "get_fontVariantCaps", "set_fontVariantCaps" },
            .{ "textRendering", "get_textRendering", "set_textRendering" },
            .{ "wordSpacing", "get_wordSpacing", "set_wordSpacing" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getContextAttributes", "call_getContextAttributes", 0 },
            .{ "save", "call_save", 0 },
            .{ "restore", "call_restore", 0 },
            .{ "reset", "call_reset", 0 },
            .{ "isContextLost", "call_isContextLost", 0 },
            .{ "scale", "call_scale", 2 },
            .{ "rotate", "call_rotate", 1 },
            .{ "translate", "call_translate", 2 },
            .{ "transform", "call_transform", 6 },
            .{ "getTransform", "call_getTransform", 0 },
            .{ "setTransform", "call_setTransform", 0 },
            .{ "resetTransform", "call_resetTransform", 0 },
            .{ "createLinearGradient", "call_createLinearGradient", 4 },
            .{ "createRadialGradient", "call_createRadialGradient", 6 },
            .{ "createConicGradient", "call_createConicGradient", 3 },
            .{ "createPattern", "call_createPattern", 2 },
            .{ "clearRect", "call_clearRect", 4 },
            .{ "fillRect", "call_fillRect", 4 },
            .{ "strokeRect", "call_strokeRect", 4 },
            .{ "beginPath", "call_beginPath", 0 },
            .{ "fill", "call_fill", 0 },
            .{ "stroke", "call_stroke", 0 },
            .{ "clip", "call_clip", 0 },
            .{ "isPointInPath", "call_isPointInPath", 2 },
            .{ "isPointInStroke", "call_isPointInStroke", 2 },
            .{ "drawFocusIfNeeded", "call_drawFocusIfNeeded", 1 },
            .{ "fillText", "call_fillText", 3 },
            .{ "strokeText", "call_strokeText", 3 },
            .{ "measureText", "call_measureText", 1 },
            .{ "drawImage", "call_drawImage", 3 },
            .{ "createImageData", "call_createImageData", 1 },
            .{ "getImageData", "call_getImageData", 4 },
            .{ "putImageData", "call_putImageData", 3 },
            .{ "setLineDash", "call_setLineDash", 1 },
            .{ "getLineDash", "call_getLineDash", 0 },
            .{ "closePath", "call_closePath", 0 },
            .{ "moveTo", "call_moveTo", 2 },
            .{ "lineTo", "call_lineTo", 2 },
            .{ "quadraticCurveTo", "call_quadraticCurveTo", 4 },
            .{ "bezierCurveTo", "call_bezierCurveTo", 6 },
            .{ "arcTo", "call_arcTo", 5 },
            .{ "rect", "call_rect", 4 },
            .{ "roundRect", "call_roundRect", 4 },
            .{ "arc", "call_arc", 5 },
            .{ "ellipse", "call_ellipse", 7 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getContextAttributes",
            "save",
            "restore",
            "reset",
            "isContextLost",
            "scale",
            "rotate",
            "translate",
            "transform",
            "getTransform",
            "setTransform",
            "resetTransform",
            "createLinearGradient",
            "createRadialGradient",
            "createConicGradient",
            "createPattern",
            "clearRect",
            "fillRect",
            "strokeRect",
            "beginPath",
            "fill",
            "stroke",
            "clip",
            "isPointInPath",
            "isPointInStroke",
            "drawFocusIfNeeded",
            "fillText",
            "strokeText",
            "measureText",
            "drawImage",
            "createImageData",
            "getImageData",
            "putImageData",
            "setLineDash",
            "getLineDash",
            "closePath",
            "moveTo",
            "lineTo",
            "quadraticCurveTo",
            "bezierCurveTo",
            "arcTo",
            "rect",
            "roundRect",
            "arc",
            "ellipse",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "canvas", "get_canvas", null },
            .{ "globalAlpha", "get_globalAlpha", "set_globalAlpha" },
            .{ "globalCompositeOperation", "get_globalCompositeOperation", "set_globalCompositeOperation" },
            .{ "imageSmoothingEnabled", "get_imageSmoothingEnabled", "set_imageSmoothingEnabled" },
            .{ "imageSmoothingQuality", "get_imageSmoothingQuality", "set_imageSmoothingQuality" },
            .{ "strokeStyle", "get_strokeStyle", "set_strokeStyle" },
            .{ "fillStyle", "get_fillStyle", "set_fillStyle" },
            .{ "shadowOffsetX", "get_shadowOffsetX", "set_shadowOffsetX" },
            .{ "shadowOffsetY", "get_shadowOffsetY", "set_shadowOffsetY" },
            .{ "shadowBlur", "get_shadowBlur", "set_shadowBlur" },
            .{ "shadowColor", "get_shadowColor", "set_shadowColor" },
            .{ "filter", "get_filter", "set_filter" },
            .{ "lineWidth", "get_lineWidth", "set_lineWidth" },
            .{ "lineCap", "get_lineCap", "set_lineCap" },
            .{ "lineJoin", "get_lineJoin", "set_lineJoin" },
            .{ "miterLimit", "get_miterLimit", "set_miterLimit" },
            .{ "lineDashOffset", "get_lineDashOffset", "set_lineDashOffset" },
            .{ "font", "get_font", "set_font" },
            .{ "textAlign", "get_textAlign", "set_textAlign" },
            .{ "textBaseline", "get_textBaseline", "set_textBaseline" },
            .{ "direction", "get_direction", "set_direction" },
            .{ "letterSpacing", "get_letterSpacing", "set_letterSpacing" },
            .{ "fontKerning", "get_fontKerning", "set_fontKerning" },
            .{ "fontStretch", "get_fontStretch", "set_fontStretch" },
            .{ "fontVariantCaps", "get_fontVariantCaps", "set_fontVariantCaps" },
            .{ "textRendering", "get_textRendering", "set_textRendering" },
            .{ "wordSpacing", "get_wordSpacing", "set_wordSpacing" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "lang", "get_lang", "set_lang" },
        };

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            canvas: *runtime.Instance = undefined,
            globalAlpha: f64 = undefined,
            globalCompositeOperation: typedefs.DOMString = undefined,
            imageSmoothingEnabled: bool = undefined,
            imageSmoothingQuality: enums.ImageSmoothingQuality = undefined,
            strokeStyle: union(enum) {
                DOMString: runtime.DOMString,
                CanvasGradient: CanvasGradient,
                CanvasPattern: CanvasPattern,
            } = undefined,
            fillStyle: union(enum) {
                DOMString: runtime.DOMString,
                CanvasGradient: CanvasGradient,
                CanvasPattern: CanvasPattern,
            } = undefined,
            shadowOffsetX: f64 = undefined,
            shadowOffsetY: f64 = undefined,
            shadowBlur: f64 = undefined,
            shadowColor: typedefs.DOMString = undefined,
            filter: typedefs.DOMString = undefined,
            lineWidth: f64 = undefined,
            lineCap: enums.CanvasLineCap = undefined,
            lineJoin: enums.CanvasLineJoin = undefined,
            miterLimit: f64 = undefined,
            lineDashOffset: f64 = undefined,
            lang: typedefs.DOMString = undefined,
            font: typedefs.DOMString = undefined,
            textAlign: enums.CanvasTextAlign = undefined,
            textBaseline: enums.CanvasTextBaseline = undefined,
            direction: enums.CanvasDirection = undefined,
            letterSpacing: typedefs.DOMString = undefined,
            fontKerning: enums.CanvasFontKerning = undefined,
            fontStretch: enums.CanvasFontStretch = undefined,
            fontVariantCaps: enums.CanvasFontVariantCaps = undefined,
            textRendering: enums.CanvasTextRendering = undefined,
            wordSpacing: typedefs.DOMString = undefined,
            _internal: ?*CanvasRenderingContext2DImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_canvas = &get_canvas,
        .get_direction = &get_direction,
        .get_fillStyle = &get_fillStyle,
        .get_filter = &get_filter,
        .get_font = &get_font,
        .get_fontKerning = &get_fontKerning,
        .get_fontStretch = &get_fontStretch,
        .get_fontVariantCaps = &get_fontVariantCaps,
        .get_globalAlpha = &get_globalAlpha,
        .get_globalCompositeOperation = &get_globalCompositeOperation,
        .get_imageSmoothingEnabled = &get_imageSmoothingEnabled,
        .get_imageSmoothingQuality = &get_imageSmoothingQuality,
        .get_lang = &get_lang,
        .get_letterSpacing = &get_letterSpacing,
        .get_lineCap = &get_lineCap,
        .get_lineDashOffset = &get_lineDashOffset,
        .get_lineJoin = &get_lineJoin,
        .get_lineWidth = &get_lineWidth,
        .get_miterLimit = &get_miterLimit,
        .get_shadowBlur = &get_shadowBlur,
        .get_shadowColor = &get_shadowColor,
        .get_shadowOffsetX = &get_shadowOffsetX,
        .get_shadowOffsetY = &get_shadowOffsetY,
        .get_strokeStyle = &get_strokeStyle,
        .get_textAlign = &get_textAlign,
        .get_textBaseline = &get_textBaseline,
        .get_textRendering = &get_textRendering,
        .get_wordSpacing = &get_wordSpacing,

        .set_direction = &set_direction,
        .set_fillStyle = &set_fillStyle,
        .set_filter = &set_filter,
        .set_font = &set_font,
        .set_fontKerning = &set_fontKerning,
        .set_fontStretch = &set_fontStretch,
        .set_fontVariantCaps = &set_fontVariantCaps,
        .set_globalAlpha = &set_globalAlpha,
        .set_globalCompositeOperation = &set_globalCompositeOperation,
        .set_imageSmoothingEnabled = &set_imageSmoothingEnabled,
        .set_imageSmoothingQuality = &set_imageSmoothingQuality,
        .set_lang = &set_lang,
        .set_letterSpacing = &set_letterSpacing,
        .set_lineCap = &set_lineCap,
        .set_lineDashOffset = &set_lineDashOffset,
        .set_lineJoin = &set_lineJoin,
        .set_lineWidth = &set_lineWidth,
        .set_miterLimit = &set_miterLimit,
        .set_shadowBlur = &set_shadowBlur,
        .set_shadowColor = &set_shadowColor,
        .set_shadowOffsetX = &set_shadowOffsetX,
        .set_shadowOffsetY = &set_shadowOffsetY,
        .set_strokeStyle = &set_strokeStyle,
        .set_textAlign = &set_textAlign,
        .set_textBaseline = &set_textBaseline,
        .set_textRendering = &set_textRendering,
        .set_wordSpacing = &set_wordSpacing,

        .call_arc = &call_arc,
        .call_arcTo = &call_arcTo,
        .call_beginPath = &call_beginPath,
        .call_bezierCurveTo = &call_bezierCurveTo,
        .call_clearRect = &call_clearRect,
        .call_clip = &call_clip,
        .call_closePath = &call_closePath,
        .call_createConicGradient = &call_createConicGradient,
        .call_createImageData = &call_createImageData,
        .call_createLinearGradient = &call_createLinearGradient,
        .call_createPattern = &call_createPattern,
        .call_createRadialGradient = &call_createRadialGradient,
        .call_drawFocusIfNeeded = &call_drawFocusIfNeeded,
        .call_drawImage = &call_drawImage,
        .call_ellipse = &call_ellipse,
        .call_fill = &call_fill,
        .call_fillRect = &call_fillRect,
        .call_fillText = &call_fillText,
        .call_getContextAttributes = &call_getContextAttributes,
        .call_getImageData = &call_getImageData,
        .call_getLineDash = &call_getLineDash,
        .call_getTransform = &call_getTransform,
        .call_isContextLost = &call_isContextLost,
        .call_isPointInPath = &call_isPointInPath,
        .call_isPointInStroke = &call_isPointInStroke,
        .call_lineTo = &call_lineTo,
        .call_measureText = &call_measureText,
        .call_moveTo = &call_moveTo,
        .call_putImageData = &call_putImageData,
        .call_quadraticCurveTo = &call_quadraticCurveTo,
        .call_rect = &call_rect,
        .call_reset = &call_reset,
        .call_resetTransform = &call_resetTransform,
        .call_restore = &call_restore,
        .call_rotate = &call_rotate,
        .call_roundRect = &call_roundRect,
        .call_save = &call_save,
        .call_scale = &call_scale,
        .call_setLineDash = &call_setLineDash,
        .call_setTransform = &call_setTransform,
        .call_stroke = &call_stroke,
        .call_strokeRect = &call_strokeRect,
        .call_strokeText = &call_strokeText,
        .call_transform = &call_transform,
        .call_translate = &call_translate,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasRenderingContext2DImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CanvasRenderingContext2DImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasRenderingContext2DImpl.deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CanvasRenderingContext2DImpl.get_canvas(instance);
    }

    pub const get_globalAlpha = mixins.CanvasCompositing.get_globalAlpha;
    pub const set_globalAlpha = mixins.CanvasCompositing.set_globalAlpha;

    pub const get_globalCompositeOperation = mixins.CanvasCompositing.get_globalCompositeOperation;
    pub const set_globalCompositeOperation = mixins.CanvasCompositing.set_globalCompositeOperation;

    pub const get_imageSmoothingEnabled = mixins.CanvasImageSmoothing.get_imageSmoothingEnabled;
    pub const set_imageSmoothingEnabled = mixins.CanvasImageSmoothing.set_imageSmoothingEnabled;

    pub const get_imageSmoothingQuality = mixins.CanvasImageSmoothing.get_imageSmoothingQuality;
    pub const set_imageSmoothingQuality = mixins.CanvasImageSmoothing.set_imageSmoothingQuality;

    pub fn get_strokeStyle(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CanvasRenderingContext2DImpl.get_strokeStyle(instance);
    }

    pub fn set_strokeStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try CanvasRenderingContext2DImpl.set_strokeStyle(instance, value);
    }

    pub fn get_fillStyle(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CanvasRenderingContext2DImpl.get_fillStyle(instance);
    }

    pub fn set_fillStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try CanvasRenderingContext2DImpl.set_fillStyle(instance, value);
    }

    pub const get_shadowOffsetX = mixins.CanvasShadowStyles.get_shadowOffsetX;
    pub const set_shadowOffsetX = mixins.CanvasShadowStyles.set_shadowOffsetX;

    pub const get_shadowOffsetY = mixins.CanvasShadowStyles.get_shadowOffsetY;
    pub const set_shadowOffsetY = mixins.CanvasShadowStyles.set_shadowOffsetY;

    pub const get_shadowBlur = mixins.CanvasShadowStyles.get_shadowBlur;
    pub const set_shadowBlur = mixins.CanvasShadowStyles.set_shadowBlur;

    pub const get_shadowColor = mixins.CanvasShadowStyles.get_shadowColor;
    pub const set_shadowColor = mixins.CanvasShadowStyles.set_shadowColor;

    pub const get_filter = mixins.CanvasFilters.get_filter;
    pub const set_filter = mixins.CanvasFilters.set_filter;

    pub fn get_lineWidth(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasRenderingContext2DImpl.get_lineWidth(instance);
    }

    pub fn set_lineWidth(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasRenderingContext2DImpl.set_lineWidth(instance, value);
    }

    pub fn get_lineCap(instance: *runtime.Instance) anyerror!CanvasLineCap {
        return try CanvasRenderingContext2DImpl.get_lineCap(instance);
    }

    pub fn set_lineCap(instance: *runtime.Instance, value: CanvasLineCap) anyerror!void {
        try CanvasRenderingContext2DImpl.set_lineCap(instance, value);
    }

    pub fn get_lineJoin(instance: *runtime.Instance) anyerror!CanvasLineJoin {
        return try CanvasRenderingContext2DImpl.get_lineJoin(instance);
    }

    pub fn set_lineJoin(instance: *runtime.Instance, value: CanvasLineJoin) anyerror!void {
        try CanvasRenderingContext2DImpl.set_lineJoin(instance, value);
    }

    pub fn get_miterLimit(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasRenderingContext2DImpl.get_miterLimit(instance);
    }

    pub fn set_miterLimit(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasRenderingContext2DImpl.set_miterLimit(instance, value);
    }

    pub fn get_lineDashOffset(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasRenderingContext2DImpl.get_lineDashOffset(instance);
    }

    pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasRenderingContext2DImpl.set_lineDashOffset(instance, value);
    }

    pub const get_lang = mixins.CanvasTextDrawingStyles.get_lang;
    pub const set_lang = mixins.CanvasTextDrawingStyles.set_lang;

    pub const get_font = mixins.CanvasTextDrawingStyles.get_font;
    pub const set_font = mixins.CanvasTextDrawingStyles.set_font;

    pub const get_textAlign = mixins.CanvasTextDrawingStyles.get_textAlign;
    pub const set_textAlign = mixins.CanvasTextDrawingStyles.set_textAlign;

    pub const get_textBaseline = mixins.CanvasTextDrawingStyles.get_textBaseline;
    pub const set_textBaseline = mixins.CanvasTextDrawingStyles.set_textBaseline;

    pub const get_direction = mixins.CanvasTextDrawingStyles.get_direction;
    pub const set_direction = mixins.CanvasTextDrawingStyles.set_direction;

    pub const get_letterSpacing = mixins.CanvasTextDrawingStyles.get_letterSpacing;
    pub const set_letterSpacing = mixins.CanvasTextDrawingStyles.set_letterSpacing;

    pub const get_fontKerning = mixins.CanvasTextDrawingStyles.get_fontKerning;
    pub const set_fontKerning = mixins.CanvasTextDrawingStyles.set_fontKerning;

    pub const get_fontStretch = mixins.CanvasTextDrawingStyles.get_fontStretch;
    pub const set_fontStretch = mixins.CanvasTextDrawingStyles.set_fontStretch;

    pub const get_fontVariantCaps = mixins.CanvasTextDrawingStyles.get_fontVariantCaps;
    pub const set_fontVariantCaps = mixins.CanvasTextDrawingStyles.set_fontVariantCaps;

    pub const get_textRendering = mixins.CanvasTextDrawingStyles.get_textRendering;
    pub const set_textRendering = mixins.CanvasTextDrawingStyles.set_textRendering;

    pub const get_wordSpacing = mixins.CanvasTextDrawingStyles.get_wordSpacing;
    pub const set_wordSpacing = mixins.CanvasTextDrawingStyles.set_wordSpacing;

    pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyerror!*runtime.Instance {
        return try CanvasRenderingContext2DImpl.call_createRadialGradient(instance, x0, y0, r0, x1, y1, r1);
    }

    pub const call_save = mixins.CanvasState.call_save;

    pub const call_createImageData = mixins.CanvasImageData.call_createImageData;

    pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_moveTo(instance, x, y);
    }

    pub const call_stroke = mixins.CanvasDrawPath.call_stroke;

    pub fn call_setLineDash(instance: *runtime.Instance, segments: runtime.JSValue) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_setLineDash(instance, segments);
    }

    pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_bezierCurveTo(instance, cp1x, cp1y, cp2x, cp2y, x, y);
    }

    pub const call_fillRect = mixins.CanvasRect.call_fillRect;

    pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyerror!*runtime.Instance {
        return try CanvasRenderingContext2DImpl.call_createConicGradient(instance, startAngle, x, y);
    }

    pub const call_getTransform = mixins.CanvasTransform.call_getTransform;

    pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: webidl.Opt(runtime.JSValue)) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_roundRect(instance, x, y, w, h, radii);
    }

    pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_ellipse(instance, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
    }

    pub const call_drawFocusIfNeeded = mixins.CanvasUserInterface.call_drawFocusIfNeeded;

    pub const call_getImageData = mixins.CanvasImageData.call_getImageData;

    pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_rect(instance, x, y, w, h);
    }

    pub const call_isPointInPath = mixins.CanvasDrawPath.call_isPointInPath;

    pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_arc(instance, x, y, radius, startAngle, endAngle, counterclockwise);
    }

    pub const call_isContextLost = mixins.CanvasState.call_isContextLost;

    pub const call_getContextAttributes = mixins.CanvasSettings.call_getContextAttributes;

    pub const call_rotate = mixins.CanvasTransform.call_rotate;

    pub const call_putImageData = mixins.CanvasImageData.call_putImageData;

    pub const call_beginPath = mixins.CanvasDrawPath.call_beginPath;

    pub const call_clearRect = mixins.CanvasRect.call_clearRect;

    pub const call_scale = mixins.CanvasTransform.call_scale;

    pub const call_strokeRect = mixins.CanvasRect.call_strokeRect;

    pub const call_reset = mixins.CanvasState.call_reset;

    pub const call_translate = mixins.CanvasTransform.call_translate;

    pub const call_drawImage = mixins.CanvasDrawImage.call_drawImage;

    pub const call_setTransform = mixins.CanvasTransform.call_setTransform;

    pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyerror!*runtime.Instance {
        return try CanvasRenderingContext2DImpl.call_createLinearGradient(instance, x0, y0, x1, y1);
    }

    pub const call_fill = mixins.CanvasDrawPath.call_fill;

    pub const call_fillText = mixins.CanvasText.call_fillText;

    pub const call_restore = mixins.CanvasState.call_restore;

    pub fn call_getLineDash(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CanvasRenderingContext2DImpl.call_getLineDash(instance);
    }

    pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_arcTo(instance, x1, y1, x2, y2, radius);
    }

    pub const call_strokeText = mixins.CanvasText.call_strokeText;

    pub fn call_createPattern(instance: *runtime.Instance, image: CanvasImageSource, repetition: DOMString) anyerror!?*runtime.Instance {
        return try CanvasRenderingContext2DImpl.call_createPattern(instance, image, repetition);
    }

    pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_closePath(instance);
    }

    pub const call_resetTransform = mixins.CanvasTransform.call_resetTransform;

    pub const call_isPointInStroke = mixins.CanvasDrawPath.call_isPointInStroke;

    pub const call_transform = mixins.CanvasTransform.call_transform;

    pub const call_measureText = mixins.CanvasText.call_measureText;

    pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_quadraticCurveTo(instance, cpx, cpy, x, y);
    }

    pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_lineTo(instance, x, y);
    }

    pub const call_clip = mixins.CanvasDrawPath.call_clip;

    pub const call_createImageData__1 = mixins.CanvasImageData.call_createImageData__1;

    pub const call_stroke__1 = mixins.CanvasDrawPath.call_stroke__1;

    pub const call_drawFocusIfNeeded__1 = mixins.CanvasUserInterface.call_drawFocusIfNeeded__1;

    pub const call_isPointInPath__1 = mixins.CanvasDrawPath.call_isPointInPath__1;

    pub const call_putImageData__1 = mixins.CanvasImageData.call_putImageData__1;

    pub const call_drawImage__1 = mixins.CanvasDrawImage.call_drawImage__1;

    pub const call_drawImage__2 = mixins.CanvasDrawImage.call_drawImage__2;

    pub const call_setTransform__1 = mixins.CanvasTransform.call_setTransform__1;

    pub const call_fill__1 = mixins.CanvasDrawPath.call_fill__1;

    pub const call_isPointInStroke__1 = mixins.CanvasDrawPath.call_isPointInStroke__1;

    pub const call_clip__1 = mixins.CanvasDrawPath.call_clip__1;

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "createImageData", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_createImageData", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
            .{ .function = "call_createImageData__1", .implemented = @hasDecl(mixins.CanvasImageData.impl, "call_createImageData__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "ImageData")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").ImageData.State) } else .other)} }} },
        } },
        .{ "stroke", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_stroke", .args = &.{} },
            .{ .function = "call_stroke__1", .implemented = @hasDecl(mixins.CanvasDrawPath.impl, "call_stroke__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }} },
        } },
        .{ "drawFocusIfNeeded", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_drawFocusIfNeeded", .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Element")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Element.State) } else .other)} }} },
            .{ .function = "call_drawFocusIfNeeded__1", .implemented = @hasDecl(mixins.CanvasUserInterface.impl, "call_drawFocusIfNeeded__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Element")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Element.State) } else .other)} } } },
        } },
        .{ "isPointInPath", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_isPointInPath", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
            .{ .function = "call_isPointInPath__1", .implemented = @hasDecl(mixins.CanvasDrawPath.impl, "call_isPointInPath__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
        } },
        .{ "putImageData", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_putImageData", .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "ImageData")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").ImageData.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
            .{ .function = "call_putImageData__1", .implemented = @hasDecl(mixins.CanvasImageData.impl, "call_putImageData__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "ImageData")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").ImageData.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
        .{ "drawImage", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_drawImage", .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
            .{ .function = "call_drawImage__1", .implemented = @hasDecl(mixins.CanvasDrawImage.impl, "call_drawImage__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
            .{ .function = "call_drawImage__2", .implemented = @hasDecl(mixins.CanvasDrawImage.impl, "call_drawImage__2"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
        .{ "setTransform", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_setTransform", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
            .{ .function = "call_setTransform__1", .implemented = @hasDecl(mixins.CanvasTransform.impl, "call_setTransform__1"), .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
        } },
        .{ "fill", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_fill", .args = &.{.{ .kinds = &.{.string}, .optionality = .optional }} },
            .{ .function = "call_fill__1", .implemented = @hasDecl(mixins.CanvasDrawPath.impl, "call_fill__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
        } },
        .{ "isPointInStroke", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_isPointInStroke", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
            .{ .function = "call_isPointInStroke__1", .implemented = @hasDecl(mixins.CanvasDrawPath.impl, "call_isPointInStroke__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
        .{ "clip", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_clip", .args = &.{.{ .kinds = &.{.string}, .optionality = .optional }} },
            .{ .function = "call_clip__1", .implemented = @hasDecl(mixins.CanvasDrawPath.impl, "call_clip__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
        } },
    };

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "call_createPattern", 0b10 },
    };
};
