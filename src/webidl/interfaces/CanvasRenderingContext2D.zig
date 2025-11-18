//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasRenderingContext2DImpl = @import("impls").CanvasRenderingContext2D;
const CanvasSettings = @import("interfaces").CanvasSettings;
const CanvasState = @import("interfaces").CanvasState;
const CanvasTransform = @import("interfaces").CanvasTransform;
const CanvasCompositing = @import("interfaces").CanvasCompositing;
const CanvasImageSmoothing = @import("interfaces").CanvasImageSmoothing;
const CanvasFillStrokeStyles = @import("interfaces").CanvasFillStrokeStyles;
const CanvasShadowStyles = @import("interfaces").CanvasShadowStyles;
const CanvasFilters = @import("interfaces").CanvasFilters;
const CanvasRect = @import("interfaces").CanvasRect;
const CanvasDrawPath = @import("interfaces").CanvasDrawPath;
const CanvasUserInterface = @import("interfaces").CanvasUserInterface;
const CanvasText = @import("interfaces").CanvasText;
const CanvasDrawImage = @import("interfaces").CanvasDrawImage;
const CanvasImageData = @import("interfaces").CanvasImageData;
const CanvasPathDrawingStyles = @import("interfaces").CanvasPathDrawingStyles;
const CanvasTextDrawingStyles = @import("interfaces").CanvasTextDrawingStyles;
const CanvasPath = @import("interfaces").CanvasPath;
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const CanvasFontVariantCaps = @import("enums").CanvasFontVariantCaps;
const CanvasFillRule = @import("enums").CanvasFillRule;
const TextMetrics = @import("interfaces").TextMetrics;
const ImageData = @import("interfaces").ImageData;
const Element = @import("interfaces").Element;
const CanvasDirection = @import("enums").CanvasDirection;
const DOMMatrix = @import("interfaces").DOMMatrix;
const CanvasTextBaseline = @import("enums").CanvasTextBaseline;
const CanvasGradient = @import("interfaces").CanvasGradient;
const CanvasLineCap = @import("enums").CanvasLineCap;
const (unrestricted double or DOMPointInit or sequence) = @import("interfaces").(unrestricted double or DOMPointInit or sequence);
const CanvasPattern = @import("interfaces").CanvasPattern;
const (DOMString or CanvasGradient or CanvasPattern) = @import("interfaces").(DOMString or CanvasGradient or CanvasPattern);
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
const HTMLCanvasElement = @import("interfaces").HTMLCanvasElement;

pub const CanvasRenderingContext2D = struct {
    pub const Meta = struct {
        pub const name = "CanvasRenderingContext2D";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
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
    };

    pub const State = runtime.FlattenedState(
        struct {
            canvas: HTMLCanvasElement = undefined,
            globalAlpha: f64 = undefined,
            globalCompositeOperation: runtime.DOMString = undefined,
            imageSmoothingEnabled: bool = undefined,
            imageSmoothingQuality: ImageSmoothingQuality = undefined,
            strokeStyle: (DOMString or CanvasGradient or CanvasPattern) = undefined,
            fillStyle: (DOMString or CanvasGradient or CanvasPattern) = undefined,
            shadowOffsetX: f64 = undefined,
            shadowOffsetY: f64 = undefined,
            shadowBlur: f64 = undefined,
            shadowColor: runtime.DOMString = undefined,
            filter: runtime.DOMString = undefined,
            lineWidth: f64 = undefined,
            lineCap: CanvasLineCap = undefined,
            lineJoin: CanvasLineJoin = undefined,
            miterLimit: f64 = undefined,
            lineDashOffset: f64 = undefined,
            lang: runtime.DOMString = undefined,
            font: runtime.DOMString = undefined,
            textAlign: CanvasTextAlign = undefined,
            textBaseline: CanvasTextBaseline = undefined,
            direction: CanvasDirection = undefined,
            letterSpacing: runtime.DOMString = undefined,
            fontKerning: CanvasFontKerning = undefined,
            fontStretch: CanvasFontStretch = undefined,
            fontVariantCaps: CanvasFontVariantCaps = undefined,
            textRendering: CanvasTextRendering = undefined,
            wordSpacing: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasRenderingContext2D, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CanvasRenderingContext2DImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasRenderingContext2DImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyerror!HTMLCanvasElement {
        return try CanvasRenderingContext2DImpl.get_canvas(instance);
    }

    pub fn get_globalAlpha(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasRenderingContext2DImpl.get_globalAlpha(instance);
    }

    pub fn set_globalAlpha(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasRenderingContext2DImpl.set_globalAlpha(instance, value);
    }

    pub fn get_globalCompositeOperation(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasRenderingContext2DImpl.get_globalCompositeOperation(instance);
    }

    pub fn set_globalCompositeOperation(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasRenderingContext2DImpl.set_globalCompositeOperation(instance, value);
    }

    pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) anyerror!bool {
        return try CanvasRenderingContext2DImpl.get_imageSmoothingEnabled(instance);
    }

    pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try CanvasRenderingContext2DImpl.set_imageSmoothingEnabled(instance, value);
    }

    pub fn get_imageSmoothingQuality(instance: *runtime.Instance) anyerror!ImageSmoothingQuality {
        return try CanvasRenderingContext2DImpl.get_imageSmoothingQuality(instance);
    }

    pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: ImageSmoothingQuality) anyerror!void {
        try CanvasRenderingContext2DImpl.set_imageSmoothingQuality(instance, value);
    }

    pub fn get_strokeStyle(instance: *runtime.Instance) anyerror!anyopaque {
        return try CanvasRenderingContext2DImpl.get_strokeStyle(instance);
    }

    pub fn set_strokeStyle(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CanvasRenderingContext2DImpl.set_strokeStyle(instance, value);
    }

    pub fn get_fillStyle(instance: *runtime.Instance) anyerror!anyopaque {
        return try CanvasRenderingContext2DImpl.get_fillStyle(instance);
    }

    pub fn set_fillStyle(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CanvasRenderingContext2DImpl.set_fillStyle(instance, value);
    }

    pub fn get_shadowOffsetX(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasRenderingContext2DImpl.get_shadowOffsetX(instance);
    }

    pub fn set_shadowOffsetX(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasRenderingContext2DImpl.set_shadowOffsetX(instance, value);
    }

    pub fn get_shadowOffsetY(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasRenderingContext2DImpl.get_shadowOffsetY(instance);
    }

    pub fn set_shadowOffsetY(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasRenderingContext2DImpl.set_shadowOffsetY(instance, value);
    }

    pub fn get_shadowBlur(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasRenderingContext2DImpl.get_shadowBlur(instance);
    }

    pub fn set_shadowBlur(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasRenderingContext2DImpl.set_shadowBlur(instance, value);
    }

    pub fn get_shadowColor(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasRenderingContext2DImpl.get_shadowColor(instance);
    }

    pub fn set_shadowColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasRenderingContext2DImpl.set_shadowColor(instance, value);
    }

    pub fn get_filter(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasRenderingContext2DImpl.get_filter(instance);
    }

    pub fn set_filter(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasRenderingContext2DImpl.set_filter(instance, value);
    }

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

    pub fn get_lang(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasRenderingContext2DImpl.get_lang(instance);
    }

    pub fn set_lang(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasRenderingContext2DImpl.set_lang(instance, value);
    }

    pub fn get_font(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasRenderingContext2DImpl.get_font(instance);
    }

    pub fn set_font(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasRenderingContext2DImpl.set_font(instance, value);
    }

    pub fn get_textAlign(instance: *runtime.Instance) anyerror!CanvasTextAlign {
        return try CanvasRenderingContext2DImpl.get_textAlign(instance);
    }

    pub fn set_textAlign(instance: *runtime.Instance, value: CanvasTextAlign) anyerror!void {
        try CanvasRenderingContext2DImpl.set_textAlign(instance, value);
    }

    pub fn get_textBaseline(instance: *runtime.Instance) anyerror!CanvasTextBaseline {
        return try CanvasRenderingContext2DImpl.get_textBaseline(instance);
    }

    pub fn set_textBaseline(instance: *runtime.Instance, value: CanvasTextBaseline) anyerror!void {
        try CanvasRenderingContext2DImpl.set_textBaseline(instance, value);
    }

    pub fn get_direction(instance: *runtime.Instance) anyerror!CanvasDirection {
        return try CanvasRenderingContext2DImpl.get_direction(instance);
    }

    pub fn set_direction(instance: *runtime.Instance, value: CanvasDirection) anyerror!void {
        try CanvasRenderingContext2DImpl.set_direction(instance, value);
    }

    pub fn get_letterSpacing(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasRenderingContext2DImpl.get_letterSpacing(instance);
    }

    pub fn set_letterSpacing(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasRenderingContext2DImpl.set_letterSpacing(instance, value);
    }

    pub fn get_fontKerning(instance: *runtime.Instance) anyerror!CanvasFontKerning {
        return try CanvasRenderingContext2DImpl.get_fontKerning(instance);
    }

    pub fn set_fontKerning(instance: *runtime.Instance, value: CanvasFontKerning) anyerror!void {
        try CanvasRenderingContext2DImpl.set_fontKerning(instance, value);
    }

    pub fn get_fontStretch(instance: *runtime.Instance) anyerror!CanvasFontStretch {
        return try CanvasRenderingContext2DImpl.get_fontStretch(instance);
    }

    pub fn set_fontStretch(instance: *runtime.Instance, value: CanvasFontStretch) anyerror!void {
        try CanvasRenderingContext2DImpl.set_fontStretch(instance, value);
    }

    pub fn get_fontVariantCaps(instance: *runtime.Instance) anyerror!CanvasFontVariantCaps {
        return try CanvasRenderingContext2DImpl.get_fontVariantCaps(instance);
    }

    pub fn set_fontVariantCaps(instance: *runtime.Instance, value: CanvasFontVariantCaps) anyerror!void {
        try CanvasRenderingContext2DImpl.set_fontVariantCaps(instance, value);
    }

    pub fn get_textRendering(instance: *runtime.Instance) anyerror!CanvasTextRendering {
        return try CanvasRenderingContext2DImpl.get_textRendering(instance);
    }

    pub fn set_textRendering(instance: *runtime.Instance, value: CanvasTextRendering) anyerror!void {
        try CanvasRenderingContext2DImpl.set_textRendering(instance, value);
    }

    pub fn get_wordSpacing(instance: *runtime.Instance) anyerror!DOMString {
        return try CanvasRenderingContext2DImpl.get_wordSpacing(instance);
    }

    pub fn set_wordSpacing(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CanvasRenderingContext2DImpl.set_wordSpacing(instance, value);
    }

    pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_rect(instance, x, y, w, h);
    }

    /// Arguments for isPointInPath (WebIDL overloading)
    pub const IsPointInPathArgs = union(enum) {
        /// isPointInPath(x, y, fillRule)
        unrestricted double_unrestricted double_CanvasFillRule: struct {
            x: f64,
            y: f64,
            fillRule: CanvasFillRule,
        },
        /// isPointInPath(path, x, y, fillRule)
        Path2D_unrestricted double_unrestricted double_CanvasFillRule: struct {
            path: Path2D,
            x: f64,
            y: f64,
            fillRule: CanvasFillRule,
        },
    };

    pub fn call_isPointInPath(instance: *runtime.Instance, args: IsPointInPathArgs) anyerror!bool {
        switch (args) {
            .unrestricted double_unrestricted double_CanvasFillRule => |a| return try CanvasRenderingContext2DImpl.unrestricted double_unrestricted double_CanvasFillRule(instance, a.x, a.y, a.fillRule),
            .Path2D_unrestricted double_unrestricted double_CanvasFillRule => |a| return try CanvasRenderingContext2DImpl.Path2D_unrestricted double_unrestricted double_CanvasFillRule(instance, a.path, a.x, a.y, a.fillRule),
        }
    }

    pub fn call_getLineDash(instance: *runtime.Instance) anyerror!anyopaque {
        return try CanvasRenderingContext2DImpl.call_getLineDash(instance);
    }

    pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_ellipse(instance, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
    }

    pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_clearRect(instance, x, y, w, h);
    }

    pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyerror!CanvasGradient {
        
        return try CanvasRenderingContext2DImpl.call_createConicGradient(instance, startAngle, x, y);
    }

    pub fn call_transform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_transform(instance, a, b, c, d, e, f);
    }

    pub fn call_restore(instance: *runtime.Instance) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_restore(instance);
    }

    /// Arguments for clip (WebIDL overloading)
    pub const ClipArgs = union(enum) {
        /// clip(fillRule)
        CanvasFillRule: CanvasFillRule,
        /// clip(path, fillRule)
        Path2D_CanvasFillRule: struct {
            path: Path2D,
            fillRule: CanvasFillRule,
        },
    };

    pub fn call_clip(instance: *runtime.Instance, args: ClipArgs) anyerror!void {
        switch (args) {
            .CanvasFillRule => |arg| return try CanvasRenderingContext2DImpl.CanvasFillRule(instance, arg),
            .Path2D_CanvasFillRule => |a| return try CanvasRenderingContext2DImpl.Path2D_CanvasFillRule(instance, a.path, a.fillRule),
        }
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_reset(instance);
    }

    pub fn call_strokeText(instance: *runtime.Instance, text: DOMString, x: f64, y: f64, maxWidth: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_strokeText(instance, text, x, y, maxWidth);
    }

    /// Arguments for stroke (WebIDL overloading)
    pub const StrokeArgs = union(enum) {
        /// stroke()
        no_params: void,
        /// stroke(path)
        Path2D: Path2D,
    };

    pub fn call_stroke(instance: *runtime.Instance, args: StrokeArgs) anyerror!void {
        switch (args) {
            .no_params => return try CanvasRenderingContext2DImpl.no_params(instance),
            .Path2D => |arg| return try CanvasRenderingContext2DImpl.Path2D(instance, arg),
        }
    }

    /// Arguments for drawImage (WebIDL overloading)
    pub const DrawImageArgs = union(enum) {
        /// drawImage(image, dx, dy)
        CanvasImageSource_unrestricted double_unrestricted double: struct {
            image: CanvasImageSource,
            dx: f64,
            dy: f64,
        },
        /// drawImage(image, dx, dy, dw, dh)
        CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double: struct {
            image: CanvasImageSource,
            dx: f64,
            dy: f64,
            dw: f64,
            dh: f64,
        },
        /// drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh)
        CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double: struct {
            image: CanvasImageSource,
            sx: f64,
            sy: f64,
            sw: f64,
            sh: f64,
            dx: f64,
            dy: f64,
            dw: f64,
            dh: f64,
        },
    };

    pub fn call_drawImage(instance: *runtime.Instance, args: DrawImageArgs) anyerror!void {
        switch (args) {
            .CanvasImageSource_unrestricted double_unrestricted double => |a| return try CanvasRenderingContext2DImpl.CanvasImageSource_unrestricted double_unrestricted double(instance, a.image, a.dx, a.dy),
            .CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return try CanvasRenderingContext2DImpl.CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double(instance, a.image, a.dx, a.dy, a.dw, a.dh),
            .CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return try CanvasRenderingContext2DImpl.CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double(instance, a.image, a.sx, a.sy, a.sw, a.sh, a.dx, a.dy, a.dw, a.dh),
        }
    }

    pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: ImageDataSettings) anyerror!ImageData {
        // [EnforceRange] on sx
        if (!runtime.isInRange(sx)) return error.TypeError;
        // [EnforceRange] on sy
        if (!runtime.isInRange(sy)) return error.TypeError;
        // [EnforceRange] on sw
        if (!runtime.isInRange(sw)) return error.TypeError;
        // [EnforceRange] on sh
        if (!runtime.isInRange(sh)) return error.TypeError;
        
        return try CanvasRenderingContext2DImpl.call_getImageData(instance, sx, sy, sw, sh, settings);
    }

    pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_arc(instance, x, y, radius, startAngle, endAngle, counterclockwise);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getTransform(instance: *runtime.Instance) anyerror!DOMMatrix {
        // [NewObject] - Caller owns the returned object
        return try CanvasRenderingContext2DImpl.call_getTransform(instance);
    }

    pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyerror!CanvasGradient {
        
        return try CanvasRenderingContext2DImpl.call_createRadialGradient(instance, x0, y0, r0, x1, y1, r1);
    }

    /// Arguments for drawFocusIfNeeded (WebIDL overloading)
    pub const DrawFocusIfNeededArgs = union(enum) {
        /// drawFocusIfNeeded(element)
        Element: Element,
        /// drawFocusIfNeeded(path, element)
        Path2D_Element: struct {
            path: Path2D,
            element: Element,
        },
    };

    pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, args: DrawFocusIfNeededArgs) anyerror!void {
        switch (args) {
            .Element => |arg| return try CanvasRenderingContext2DImpl.Element(instance, arg),
            .Path2D_Element => |a| return try CanvasRenderingContext2DImpl.Path2D_Element(instance, a.path, a.element),
        }
    }

    pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_closePath(instance);
    }

    pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: anyopaque) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_roundRect(instance, x, y, w, h, radii);
    }

    pub fn call_createPattern(instance: *runtime.Instance, image: CanvasImageSource, repetition: DOMString) anyerror!anyopaque {
        
        return try CanvasRenderingContext2DImpl.call_createPattern(instance, image, repetition);
    }

    pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_lineTo(instance, x, y);
    }

    pub fn call_resetTransform(instance: *runtime.Instance) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_resetTransform(instance);
    }

    pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_arcTo(instance, x1, y1, x2, y2, radius);
    }

    pub fn call_getContextAttributes(instance: *runtime.Instance) anyerror!CanvasRenderingContext2DSettings {
        return try CanvasRenderingContext2DImpl.call_getContextAttributes(instance);
    }

    pub fn call_setLineDash(instance: *runtime.Instance, segments: anyopaque) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_setLineDash(instance, segments);
    }

    pub fn call_save(instance: *runtime.Instance) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_save(instance);
    }

    pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_moveTo(instance, x, y);
    }

    pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_quadraticCurveTo(instance, cpx, cpy, x, y);
    }

    pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
        return try CanvasRenderingContext2DImpl.call_isContextLost(instance);
    }

    /// Arguments for isPointInStroke (WebIDL overloading)
    pub const IsPointInStrokeArgs = union(enum) {
        /// isPointInStroke(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
        /// isPointInStroke(path, x, y)
        Path2D_unrestricted double_unrestricted double: struct {
            path: Path2D,
            x: f64,
            y: f64,
        },
    };

    pub fn call_isPointInStroke(instance: *runtime.Instance, args: IsPointInStrokeArgs) anyerror!bool {
        switch (args) {
            .unrestricted double_unrestricted double => |a| return try CanvasRenderingContext2DImpl.unrestricted double_unrestricted double(instance, a.x, a.y),
            .Path2D_unrestricted double_unrestricted double => |a| return try CanvasRenderingContext2DImpl.Path2D_unrestricted double_unrestricted double(instance, a.path, a.x, a.y),
        }
    }

    pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_bezierCurveTo(instance, cp1x, cp1y, cp2x, cp2y, x, y);
    }

    pub fn call_rotate(instance: *runtime.Instance, angle: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_rotate(instance, angle);
    }

    /// Arguments for createImageData (WebIDL overloading)
    pub const CreateImageDataArgs = union(enum) {
        /// createImageData(sw, sh, settings)
        long_long_ImageDataSettings: struct {
            sw: i32,
            sh: i32,
            settings: ImageDataSettings,
        },
        /// createImageData(imageData)
        ImageData: ImageData,
    };

    pub fn call_createImageData(instance: *runtime.Instance, args: CreateImageDataArgs) anyerror!ImageData {
        switch (args) {
            .long_long_ImageDataSettings => |a| return try CanvasRenderingContext2DImpl.long_long_ImageDataSettings(instance, a.sw, a.sh, a.settings),
            .ImageData => |arg| return try CanvasRenderingContext2DImpl.ImageData(instance, arg),
        }
    }

    pub fn call_scale(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_scale(instance, x, y);
    }

    pub fn call_translate(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_translate(instance, x, y);
    }

    pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyerror!CanvasGradient {
        
        return try CanvasRenderingContext2DImpl.call_createLinearGradient(instance, x0, y0, x1, y1);
    }

    pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_strokeRect(instance, x, y, w, h);
    }

    /// Arguments for setTransform (WebIDL overloading)
    pub const SetTransformArgs = union(enum) {
        /// setTransform(a, b, c, d, e, f)
        unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double: struct {
            a: f64,
            b: f64,
            c: f64,
            d: f64,
            e: f64,
            f: f64,
        },
        /// setTransform(transform)
        DOMMatrix2DInit: DOMMatrix2DInit,
    };

    pub fn call_setTransform(instance: *runtime.Instance, args: SetTransformArgs) anyerror!void {
        switch (args) {
            .unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return try CanvasRenderingContext2DImpl.unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double(instance, a.a, a.b, a.c, a.d, a.e, a.f),
            .DOMMatrix2DInit => |arg| return try CanvasRenderingContext2DImpl.DOMMatrix2DInit(instance, arg),
        }
    }

    pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_fillRect(instance, x, y, w, h);
    }

    pub fn call_beginPath(instance: *runtime.Instance) anyerror!void {
        return try CanvasRenderingContext2DImpl.call_beginPath(instance);
    }

    pub fn call_fillText(instance: *runtime.Instance, text: DOMString, x: f64, y: f64, maxWidth: f64) anyerror!void {
        
        return try CanvasRenderingContext2DImpl.call_fillText(instance, text, x, y, maxWidth);
    }

    pub fn call_measureText(instance: *runtime.Instance, text: DOMString) anyerror!TextMetrics {
        
        return try CanvasRenderingContext2DImpl.call_measureText(instance, text);
    }

    /// Arguments for fill (WebIDL overloading)
    pub const FillArgs = union(enum) {
        /// fill(fillRule)
        CanvasFillRule: CanvasFillRule,
        /// fill(path, fillRule)
        Path2D_CanvasFillRule: struct {
            path: Path2D,
            fillRule: CanvasFillRule,
        },
    };

    pub fn call_fill(instance: *runtime.Instance, args: FillArgs) anyerror!void {
        switch (args) {
            .CanvasFillRule => |arg| return try CanvasRenderingContext2DImpl.CanvasFillRule(instance, arg),
            .Path2D_CanvasFillRule => |a| return try CanvasRenderingContext2DImpl.Path2D_CanvasFillRule(instance, a.path, a.fillRule),
        }
    }

    /// Arguments for putImageData (WebIDL overloading)
    pub const PutImageDataArgs = union(enum) {
        /// putImageData(imageData, dx, dy)
        ImageData_long_long: struct {
            imageData: ImageData,
            dx: i32,
            dy: i32,
        },
        /// putImageData(imageData, dx, dy, dirtyX, dirtyY, dirtyWidth, dirtyHeight)
        ImageData_long_long_long_long_long_long: struct {
            imageData: ImageData,
            dx: i32,
            dy: i32,
            dirtyX: i32,
            dirtyY: i32,
            dirtyWidth: i32,
            dirtyHeight: i32,
        },
    };

    pub fn call_putImageData(instance: *runtime.Instance, args: PutImageDataArgs) anyerror!void {
        switch (args) {
            .ImageData_long_long => |a| return try CanvasRenderingContext2DImpl.ImageData_long_long(instance, a.imageData, a.dx, a.dy),
            .ImageData_long_long_long_long_long_long => |a| return try CanvasRenderingContext2DImpl.ImageData_long_long_long_long_long_long(instance, a.imageData, a.dx, a.dy, a.dirtyX, a.dirtyY, a.dirtyWidth, a.dirtyHeight),
        }
    }

};
