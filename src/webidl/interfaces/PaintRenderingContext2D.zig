//! Generated from: css-paint-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaintRenderingContext2DImpl = @import("impls").PaintRenderingContext2D;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasState = @import("mixins").CanvasState;
const CanvasTransform = @import("mixins").CanvasTransform;
const CanvasCompositing = @import("mixins").CanvasCompositing;
const CanvasImageSmoothing = @import("mixins").CanvasImageSmoothing;
const CanvasFillStrokeStyles = @import("mixins").CanvasFillStrokeStyles;
const CanvasShadowStyles = @import("mixins").CanvasShadowStyles;
const CanvasRect = @import("mixins").CanvasRect;
const CanvasDrawPath = @import("mixins").CanvasDrawPath;
const CanvasDrawImage = @import("mixins").CanvasDrawImage;
const CanvasPathDrawingStyles = @import("mixins").CanvasPathDrawingStyles;
const CanvasPath = @import("mixins").CanvasPath;
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const CanvasFillRule = @import("enums").CanvasFillRule;
const DOMMatrix = @import("interfaces").DOMMatrix;
const CanvasGradient = @import("interfaces").CanvasGradient;
const CanvasLineCap = @import("enums").CanvasLineCap;
const CanvasPattern = @import("interfaces").CanvasPattern;
const CanvasImageSource = @import("typedefs").CanvasImageSource;
const Path2D = @import("interfaces").Path2D;
const ImageSmoothingQuality = @import("enums").ImageSmoothingQuality;
const CanvasLineJoin = @import("enums").CanvasLineJoin;
const DOMString = @import("typedefs").DOMString;

pub const PaintRenderingContext2D = struct {
    pub const Meta = struct {
        pub const name = "PaintRenderingContext2D";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            CanvasState,
            CanvasTransform,
            CanvasCompositing,
            CanvasImageSmoothing,
            CanvasFillStrokeStyles,
            CanvasShadowStyles,
            CanvasRect,
            CanvasDrawPath,
            CanvasDrawImage,
            CanvasPathDrawingStyles,
            CanvasPath,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "PaintWorklet" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .PaintWorklet = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
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
            .{ "lineWidth", "get_lineWidth", "set_lineWidth" },
            .{ "lineCap", "get_lineCap", "set_lineCap" },
            .{ "lineJoin", "get_lineJoin", "set_lineJoin" },
            .{ "miterLimit", "get_miterLimit", "set_miterLimit" },
            .{ "lineDashOffset", "get_lineDashOffset", "set_lineDashOffset" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
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
            .{ "drawImage", "call_drawImage", 3 },
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
            "drawImage",
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
            .{ "lineWidth", "get_lineWidth", "set_lineWidth" },
            .{ "lineCap", "get_lineCap", "set_lineCap" },
            .{ "lineJoin", "get_lineJoin", "set_lineJoin" },
            .{ "miterLimit", "get_miterLimit", "set_miterLimit" },
            .{ "lineDashOffset", "get_lineDashOffset", "set_lineDashOffset" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
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
            lineWidth: f64 = undefined,
            lineCap: enums.CanvasLineCap = undefined,
            lineJoin: enums.CanvasLineJoin = undefined,
            miterLimit: f64 = undefined,
            lineDashOffset: f64 = undefined,
            _internal: ?*PaintRenderingContext2DImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_fillStyle = &get_fillStyle,
        .get_globalAlpha = &get_globalAlpha,
        .get_globalCompositeOperation = &get_globalCompositeOperation,
        .get_imageSmoothingEnabled = &get_imageSmoothingEnabled,
        .get_imageSmoothingQuality = &get_imageSmoothingQuality,
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

        .set_fillStyle = &set_fillStyle,
        .set_globalAlpha = &set_globalAlpha,
        .set_globalCompositeOperation = &set_globalCompositeOperation,
        .set_imageSmoothingEnabled = &set_imageSmoothingEnabled,
        .set_imageSmoothingQuality = &set_imageSmoothingQuality,
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

        .call_arc = &call_arc,
        .call_arcTo = &call_arcTo,
        .call_beginPath = &call_beginPath,
        .call_bezierCurveTo = &call_bezierCurveTo,
        .call_clearRect = &call_clearRect,
        .call_clip = &call_clip,
        .call_closePath = &call_closePath,
        .call_createConicGradient = &call_createConicGradient,
        .call_createLinearGradient = &call_createLinearGradient,
        .call_createPattern = &call_createPattern,
        .call_createRadialGradient = &call_createRadialGradient,
        .call_drawImage = &call_drawImage,
        .call_ellipse = &call_ellipse,
        .call_fill = &call_fill,
        .call_fillRect = &call_fillRect,
        .call_getLineDash = &call_getLineDash,
        .call_getTransform = &call_getTransform,
        .call_isContextLost = &call_isContextLost,
        .call_isPointInPath = &call_isPointInPath,
        .call_isPointInStroke = &call_isPointInStroke,
        .call_lineTo = &call_lineTo,
        .call_moveTo = &call_moveTo,
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
        .call_transform = &call_transform,
        .call_translate = &call_translate,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaintRenderingContext2DImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PaintRenderingContext2DImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaintRenderingContext2DImpl.deinit(instance);
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
        return try PaintRenderingContext2DImpl.get_strokeStyle(instance);
    }

    pub fn set_strokeStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try PaintRenderingContext2DImpl.set_strokeStyle(instance, value);
    }

    pub fn get_fillStyle(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PaintRenderingContext2DImpl.get_fillStyle(instance);
    }

    pub fn set_fillStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try PaintRenderingContext2DImpl.set_fillStyle(instance, value);
    }

    pub const get_shadowOffsetX = mixins.CanvasShadowStyles.get_shadowOffsetX;
    pub const set_shadowOffsetX = mixins.CanvasShadowStyles.set_shadowOffsetX;

    pub const get_shadowOffsetY = mixins.CanvasShadowStyles.get_shadowOffsetY;
    pub const set_shadowOffsetY = mixins.CanvasShadowStyles.set_shadowOffsetY;

    pub const get_shadowBlur = mixins.CanvasShadowStyles.get_shadowBlur;
    pub const set_shadowBlur = mixins.CanvasShadowStyles.set_shadowBlur;

    pub const get_shadowColor = mixins.CanvasShadowStyles.get_shadowColor;
    pub const set_shadowColor = mixins.CanvasShadowStyles.set_shadowColor;

    pub fn get_lineWidth(instance: *runtime.Instance) anyerror!f64 {
        return try PaintRenderingContext2DImpl.get_lineWidth(instance);
    }

    pub fn set_lineWidth(instance: *runtime.Instance, value: f64) anyerror!void {
        try PaintRenderingContext2DImpl.set_lineWidth(instance, value);
    }

    pub fn get_lineCap(instance: *runtime.Instance) anyerror!CanvasLineCap {
        return try PaintRenderingContext2DImpl.get_lineCap(instance);
    }

    pub fn set_lineCap(instance: *runtime.Instance, value: CanvasLineCap) anyerror!void {
        try PaintRenderingContext2DImpl.set_lineCap(instance, value);
    }

    pub fn get_lineJoin(instance: *runtime.Instance) anyerror!CanvasLineJoin {
        return try PaintRenderingContext2DImpl.get_lineJoin(instance);
    }

    pub fn set_lineJoin(instance: *runtime.Instance, value: CanvasLineJoin) anyerror!void {
        try PaintRenderingContext2DImpl.set_lineJoin(instance, value);
    }

    pub fn get_miterLimit(instance: *runtime.Instance) anyerror!f64 {
        return try PaintRenderingContext2DImpl.get_miterLimit(instance);
    }

    pub fn set_miterLimit(instance: *runtime.Instance, value: f64) anyerror!void {
        try PaintRenderingContext2DImpl.set_miterLimit(instance, value);
    }

    pub fn get_lineDashOffset(instance: *runtime.Instance) anyerror!f64 {
        return try PaintRenderingContext2DImpl.get_lineDashOffset(instance);
    }

    pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try PaintRenderingContext2DImpl.set_lineDashOffset(instance, value);
    }

    pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyerror!*runtime.Instance {
        return try PaintRenderingContext2DImpl.call_createRadialGradient(instance, x0, y0, r0, x1, y1, r1);
    }

    pub const call_save = mixins.CanvasState.call_save;

    pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        return try PaintRenderingContext2DImpl.call_moveTo(instance, x, y);
    }

    pub const call_stroke = mixins.CanvasDrawPath.call_stroke;

    pub fn call_setLineDash(instance: *runtime.Instance, segments: runtime.JSValue) anyerror!void {
        return try PaintRenderingContext2DImpl.call_setLineDash(instance, segments);
    }

    pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyerror!void {
        return try PaintRenderingContext2DImpl.call_bezierCurveTo(instance, cp1x, cp1y, cp2x, cp2y, x, y);
    }

    pub const call_fillRect = mixins.CanvasRect.call_fillRect;

    pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyerror!*runtime.Instance {
        return try PaintRenderingContext2DImpl.call_createConicGradient(instance, startAngle, x, y);
    }

    pub const call_getTransform = mixins.CanvasTransform.call_getTransform;

    pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: webidl.Opt(runtime.JSValue)) anyerror!void {
        return try PaintRenderingContext2DImpl.call_roundRect(instance, x, y, w, h, radii);
    }

    pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
        return try PaintRenderingContext2DImpl.call_ellipse(instance, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
    }

    pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
        return try PaintRenderingContext2DImpl.call_arc(instance, x, y, radius, startAngle, endAngle, counterclockwise);
    }

    pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        return try PaintRenderingContext2DImpl.call_rect(instance, x, y, w, h);
    }

    pub const call_isPointInPath = mixins.CanvasDrawPath.call_isPointInPath;

    pub const call_isContextLost = mixins.CanvasState.call_isContextLost;

    pub const call_rotate = mixins.CanvasTransform.call_rotate;

    pub const call_beginPath = mixins.CanvasDrawPath.call_beginPath;

    pub const call_clearRect = mixins.CanvasRect.call_clearRect;

    pub const call_scale = mixins.CanvasTransform.call_scale;

    pub const call_strokeRect = mixins.CanvasRect.call_strokeRect;

    pub const call_reset = mixins.CanvasState.call_reset;

    pub const call_translate = mixins.CanvasTransform.call_translate;

    pub const call_drawImage = mixins.CanvasDrawImage.call_drawImage;

    pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyerror!*runtime.Instance {
        return try PaintRenderingContext2DImpl.call_createLinearGradient(instance, x0, y0, x1, y1);
    }

    pub const call_setTransform = mixins.CanvasTransform.call_setTransform;

    pub const call_fill = mixins.CanvasDrawPath.call_fill;

    pub fn call_getLineDash(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PaintRenderingContext2DImpl.call_getLineDash(instance);
    }

    pub const call_restore = mixins.CanvasState.call_restore;

    pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyerror!void {
        return try PaintRenderingContext2DImpl.call_arcTo(instance, x1, y1, x2, y2, radius);
    }

    pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
        return try PaintRenderingContext2DImpl.call_closePath(instance);
    }

    pub fn call_createPattern(instance: *runtime.Instance, image: CanvasImageSource, repetition: DOMString) anyerror!?*runtime.Instance {
        return try PaintRenderingContext2DImpl.call_createPattern(instance, image, repetition);
    }

    pub const call_resetTransform = mixins.CanvasTransform.call_resetTransform;

    pub const call_isPointInStroke = mixins.CanvasDrawPath.call_isPointInStroke;

    pub const call_transform = mixins.CanvasTransform.call_transform;

    pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyerror!void {
        return try PaintRenderingContext2DImpl.call_quadraticCurveTo(instance, cpx, cpy, x, y);
    }

    pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        return try PaintRenderingContext2DImpl.call_lineTo(instance, x, y);
    }

    pub const call_clip = mixins.CanvasDrawPath.call_clip;

    pub const call_stroke__1 = mixins.CanvasDrawPath.call_stroke__1;

    pub const call_isPointInPath__1 = mixins.CanvasDrawPath.call_isPointInPath__1;

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
        .{ "stroke", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_stroke", .args = &.{} },
            .{ .function = "call_stroke__1", .implemented = @hasDecl(mixins.CanvasDrawPath.impl, "call_stroke__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }} },
        } },
        .{ "isPointInPath", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_isPointInPath", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
            .{ .function = "call_isPointInPath__1", .implemented = @hasDecl(mixins.CanvasDrawPath.impl, "call_isPointInPath__1"), .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Path2D")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Path2D.State) } else .other)} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
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
