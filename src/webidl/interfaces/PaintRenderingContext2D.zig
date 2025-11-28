//! Generated from: css-paint-api.idl
//! Generated at: 2025-11-28T19:11:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaintRenderingContext2DImpl = @import("impls").PaintRenderingContext2D;
const mixins = @import("mixins");
const CanvasState = @import("interfaces").CanvasState;
const CanvasTransform = @import("interfaces").CanvasTransform;
const CanvasCompositing = @import("interfaces").CanvasCompositing;
const CanvasImageSmoothing = @import("interfaces").CanvasImageSmoothing;
const CanvasFillStrokeStyles = @import("interfaces").CanvasFillStrokeStyles;
const CanvasShadowStyles = @import("interfaces").CanvasShadowStyles;
const CanvasRect = @import("interfaces").CanvasRect;
const CanvasDrawPath = @import("interfaces").CanvasDrawPath;
const CanvasDrawImage = @import("interfaces").CanvasDrawImage;
const CanvasPathDrawingStyles = @import("interfaces").CanvasPathDrawingStyles;
const CanvasPath = @import("interfaces").CanvasPath;
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
const sequence = @import("interfaces").sequence;
const CanvasLineJoin = @import("enums").CanvasLineJoin;
const DOMString = @import("typedefs").DOMString;

pub const PaintRenderingContext2D = struct {
    pub const Meta = struct {
        pub const name = "PaintRenderingContext2D";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            .{ "setTransform", "call_setTransform", 6 },
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
            .{ "fill", "call_fill", 1 },
            .{ "stroke", "call_stroke", 0 },
            .{ "stroke", "call_stroke", 1 },
            .{ "clip", "call_clip", 0 },
            .{ "clip", "call_clip", 1 },
            .{ "isPointInPath", "call_isPointInPath", 2 },
            .{ "isPointInPath", "call_isPointInPath", 3 },
            .{ "isPointInStroke", "call_isPointInStroke", 2 },
            .{ "isPointInStroke", "call_isPointInStroke", 3 },
            .{ "drawImage", "call_drawImage", 3 },
            .{ "drawImage", "call_drawImage", 5 },
            .{ "drawImage", "call_drawImage", 9 },
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
            "fill",
            "stroke",
            "stroke",
            "clip",
            "clip",
            "isPointInPath",
            "isPointInPath",
            "isPointInStroke",
            "isPointInStroke",
            "drawImage",
            "drawImage",
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
        pub const inherited_methods = .{
        };
        
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            globalAlpha: f64 = undefined,
            globalCompositeOperation: runtime.DOMString = undefined,
            imageSmoothingEnabled: bool = undefined,
            imageSmoothingQuality: ImageSmoothingQuality = undefined,
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
            shadowColor: runtime.DOMString = undefined,
            lineWidth: f64 = undefined,
            lineCap: CanvasLineCap = undefined,
            lineJoin: CanvasLineJoin = undefined,
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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PaintRenderingContext2DImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PaintRenderingContext2DImpl.deinit(instance);
    }

    pub fn get_globalAlpha(instance: *runtime.Instance) anyerror!f64 {
        return try PaintRenderingContext2DImpl.get_globalAlpha(instance);
    }

    pub fn set_globalAlpha(instance: *runtime.Instance, value: f64) anyerror!void {
        try PaintRenderingContext2DImpl.set_globalAlpha(instance, value);
    }

    pub fn get_globalCompositeOperation(instance: *runtime.Instance) anyerror!DOMString {
        return try PaintRenderingContext2DImpl.get_globalCompositeOperation(instance);
    }

    pub fn set_globalCompositeOperation(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try PaintRenderingContext2DImpl.set_globalCompositeOperation(instance, value);
    }

    pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) anyerror!bool {
        return try PaintRenderingContext2DImpl.get_imageSmoothingEnabled(instance);
    }

    pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try PaintRenderingContext2DImpl.set_imageSmoothingEnabled(instance, value);
    }

    pub fn get_imageSmoothingQuality(instance: *runtime.Instance) anyerror!ImageSmoothingQuality {
        return try PaintRenderingContext2DImpl.get_imageSmoothingQuality(instance);
    }

    pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: ImageSmoothingQuality) anyerror!void {
        try PaintRenderingContext2DImpl.set_imageSmoothingQuality(instance, value);
    }

    pub fn get_strokeStyle(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaintRenderingContext2DImpl.get_strokeStyle(instance);
    }

    pub fn set_strokeStyle(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try PaintRenderingContext2DImpl.set_strokeStyle(instance, value);
    }

    pub fn get_fillStyle(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaintRenderingContext2DImpl.get_fillStyle(instance);
    }

    pub fn set_fillStyle(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try PaintRenderingContext2DImpl.set_fillStyle(instance, value);
    }

    pub fn get_shadowOffsetX(instance: *runtime.Instance) anyerror!f64 {
        return try PaintRenderingContext2DImpl.get_shadowOffsetX(instance);
    }

    pub fn set_shadowOffsetX(instance: *runtime.Instance, value: f64) anyerror!void {
        try PaintRenderingContext2DImpl.set_shadowOffsetX(instance, value);
    }

    pub fn get_shadowOffsetY(instance: *runtime.Instance) anyerror!f64 {
        return try PaintRenderingContext2DImpl.get_shadowOffsetY(instance);
    }

    pub fn set_shadowOffsetY(instance: *runtime.Instance, value: f64) anyerror!void {
        try PaintRenderingContext2DImpl.set_shadowOffsetY(instance, value);
    }

    pub fn get_shadowBlur(instance: *runtime.Instance) anyerror!f64 {
        return try PaintRenderingContext2DImpl.get_shadowBlur(instance);
    }

    pub fn set_shadowBlur(instance: *runtime.Instance, value: f64) anyerror!void {
        try PaintRenderingContext2DImpl.set_shadowBlur(instance, value);
    }

    pub fn get_shadowColor(instance: *runtime.Instance) anyerror!DOMString {
        return try PaintRenderingContext2DImpl.get_shadowColor(instance);
    }

    pub fn set_shadowColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try PaintRenderingContext2DImpl.set_shadowColor(instance, value);
    }

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

    pub fn call_isPointInPath(instance: *runtime.Instance, x: f64, y: f64, fillRule: webidl.Opt(CanvasFillRule)) anyerror!bool {
        
        return try PaintRenderingContext2DImpl.call_isPointInPath(instance, x, y, fillRule);
    }

    pub fn call_getLineDash(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PaintRenderingContext2DImpl.call_getLineDash(instance);
    }

    pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_ellipse(instance, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
    }

    pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_clearRect(instance, x, y, w, h);
    }

    pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyerror!*runtime.Instance {
        
        return try PaintRenderingContext2DImpl.call_createConicGradient(instance, startAngle, x, y);
    }

    pub fn call_transform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_transform(instance, a, b, c, d, e, f);
    }

    pub fn call_restore(instance: *runtime.Instance) anyerror!void {
        return try PaintRenderingContext2DImpl.call_restore(instance);
    }

    pub fn call_clip(instance: *runtime.Instance, fillRule: webidl.Opt(CanvasFillRule)) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_clip(instance, fillRule);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try PaintRenderingContext2DImpl.call_reset(instance);
    }

    pub fn call_stroke(instance: *runtime.Instance) anyerror!void {
        return try PaintRenderingContext2DImpl.call_stroke(instance);
    }

    pub fn call_drawImage(instance: *runtime.Instance, image: CanvasImageSource, dx: f64, dy: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_drawImage(instance, image, dx, dy);
    }

    pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_arc(instance, x, y, radius, startAngle, endAngle, counterclockwise);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getTransform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try PaintRenderingContext2DImpl.call_getTransform(instance);
    }

    pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyerror!*runtime.Instance {
        
        return try PaintRenderingContext2DImpl.call_createRadialGradient(instance, x0, y0, r0, x1, y1, r1);
    }

    pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
        return try PaintRenderingContext2DImpl.call_closePath(instance);
    }

    pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: webidl.Opt(*const anyopaque)) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_roundRect(instance, x, y, w, h, radii);
    }

    pub fn call_createPattern(instance: *runtime.Instance, image: CanvasImageSource, repetition: DOMString) anyerror!?*runtime.Instance {
        
        return try PaintRenderingContext2DImpl.call_createPattern(instance, image, repetition);
    }

    pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_lineTo(instance, x, y);
    }

    pub fn call_resetTransform(instance: *runtime.Instance) anyerror!void {
        return try PaintRenderingContext2DImpl.call_resetTransform(instance);
    }

    pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_arcTo(instance, x1, y1, x2, y2, radius);
    }

    pub fn call_setLineDash(instance: *runtime.Instance, segments: *const anyopaque) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_setLineDash(instance, segments);
    }

    pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_moveTo(instance, x, y);
    }

    pub fn call_save(instance: *runtime.Instance) anyerror!void {
        return try PaintRenderingContext2DImpl.call_save(instance);
    }

    pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_quadraticCurveTo(instance, cpx, cpy, x, y);
    }

    pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_bezierCurveTo(instance, cp1x, cp1y, cp2x, cp2y, x, y);
    }

    pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
        return try PaintRenderingContext2DImpl.call_isContextLost(instance);
    }

    pub fn call_isPointInStroke(instance: *runtime.Instance, x: f64, y: f64) anyerror!bool {
        
        return try PaintRenderingContext2DImpl.call_isPointInStroke(instance, x, y);
    }

    pub fn call_rotate(instance: *runtime.Instance, angle: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_rotate(instance, angle);
    }

    pub fn call_scale(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_scale(instance, x, y);
    }

    pub fn call_translate(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_translate(instance, x, y);
    }

    pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyerror!*runtime.Instance {
        
        return try PaintRenderingContext2DImpl.call_createLinearGradient(instance, x0, y0, x1, y1);
    }

    pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_strokeRect(instance, x, y, w, h);
    }

    pub fn call_setTransform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_setTransform(instance, a, b, c, d, e, f);
    }

    pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_fillRect(instance, x, y, w, h);
    }

    pub fn call_beginPath(instance: *runtime.Instance) anyerror!void {
        return try PaintRenderingContext2DImpl.call_beginPath(instance);
    }

    pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_rect(instance, x, y, w, h);
    }

    pub fn call_fill(instance: *runtime.Instance, fillRule: webidl.Opt(CanvasFillRule)) anyerror!void {
        
        return try PaintRenderingContext2DImpl.call_fill(instance, fillRule);
    }

};
