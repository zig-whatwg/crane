//! Generated from: css-paint-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PaintRenderingContext2DImpl = @import("../impls/PaintRenderingContext2D.zig");
const CanvasState = @import("CanvasState.zig");
const CanvasTransform = @import("CanvasTransform.zig");
const CanvasCompositing = @import("CanvasCompositing.zig");
const CanvasImageSmoothing = @import("CanvasImageSmoothing.zig");
const CanvasFillStrokeStyles = @import("CanvasFillStrokeStyles.zig");
const CanvasShadowStyles = @import("CanvasShadowStyles.zig");
const CanvasRect = @import("CanvasRect.zig");
const CanvasDrawPath = @import("CanvasDrawPath.zig");
const CanvasDrawImage = @import("CanvasDrawImage.zig");
const CanvasPathDrawingStyles = @import("CanvasPathDrawingStyles.zig");
const CanvasPath = @import("CanvasPath.zig");

pub const PaintRenderingContext2D = struct {
    pub const Meta = struct {
        pub const name = "PaintRenderingContext2D";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
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
    };

    pub const State = runtime.FlattenedState(
        struct {
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
            lineWidth: f64 = undefined,
            lineCap: CanvasLineCap = undefined,
            lineJoin: CanvasLineJoin = undefined,
            miterLimit: f64 = undefined,
            lineDashOffset: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PaintRenderingContext2D, .{
        .deinit_fn = &deinit_wrapper,

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
        .call_clip = &call_clip,
        .call_closePath = &call_closePath,
        .call_createConicGradient = &call_createConicGradient,
        .call_createLinearGradient = &call_createLinearGradient,
        .call_createPattern = &call_createPattern,
        .call_createRadialGradient = &call_createRadialGradient,
        .call_drawImage = &call_drawImage,
        .call_drawImage = &call_drawImage,
        .call_drawImage = &call_drawImage,
        .call_ellipse = &call_ellipse,
        .call_fill = &call_fill,
        .call_fill = &call_fill,
        .call_fillRect = &call_fillRect,
        .call_getLineDash = &call_getLineDash,
        .call_getTransform = &call_getTransform,
        .call_isContextLost = &call_isContextLost,
        .call_isPointInPath = &call_isPointInPath,
        .call_isPointInPath = &call_isPointInPath,
        .call_isPointInStroke = &call_isPointInStroke,
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
        .call_setTransform = &call_setTransform,
        .call_stroke = &call_stroke,
        .call_stroke = &call_stroke,
        .call_strokeRect = &call_strokeRect,
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
        
        // Initialize the state (Impl receives full hierarchy)
        PaintRenderingContext2DImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_globalAlpha(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_globalAlpha(state);
    }

    pub fn set_globalAlpha(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_globalAlpha(state, value);
    }

    pub fn get_globalCompositeOperation(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_globalCompositeOperation(state);
    }

    pub fn set_globalCompositeOperation(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_globalCompositeOperation(state, value);
    }

    pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_imageSmoothingEnabled(state);
    }

    pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_imageSmoothingEnabled(state, value);
    }

    pub fn get_imageSmoothingQuality(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_imageSmoothingQuality(state);
    }

    pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_imageSmoothingQuality(state, value);
    }

    pub fn get_strokeStyle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_strokeStyle(state);
    }

    pub fn set_strokeStyle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_strokeStyle(state, value);
    }

    pub fn get_fillStyle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_fillStyle(state);
    }

    pub fn set_fillStyle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_fillStyle(state, value);
    }

    pub fn get_shadowOffsetX(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_shadowOffsetX(state);
    }

    pub fn set_shadowOffsetX(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_shadowOffsetX(state, value);
    }

    pub fn get_shadowOffsetY(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_shadowOffsetY(state);
    }

    pub fn set_shadowOffsetY(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_shadowOffsetY(state, value);
    }

    pub fn get_shadowBlur(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_shadowBlur(state);
    }

    pub fn set_shadowBlur(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_shadowBlur(state, value);
    }

    pub fn get_shadowColor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_shadowColor(state);
    }

    pub fn set_shadowColor(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_shadowColor(state, value);
    }

    pub fn get_lineWidth(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_lineWidth(state);
    }

    pub fn set_lineWidth(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_lineWidth(state, value);
    }

    pub fn get_lineCap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_lineCap(state);
    }

    pub fn set_lineCap(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_lineCap(state, value);
    }

    pub fn get_lineJoin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_lineJoin(state);
    }

    pub fn set_lineJoin(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_lineJoin(state, value);
    }

    pub fn get_miterLimit(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_miterLimit(state);
    }

    pub fn set_miterLimit(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_miterLimit(state, value);
    }

    pub fn get_lineDashOffset(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.get_lineDashOffset(state);
    }

    pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        PaintRenderingContext2DImpl.set_lineDashOffset(state, value);
    }

    /// Arguments for isPointInPath (WebIDL overloading)
    pub const IsPointInPathArgs = union(enum) {
        /// isPointInPath(x, y, fillRule)
        unrestricted double_unrestricted double_CanvasFillRule: struct {
            x: f64,
            y: f64,
            fillRule: anyopaque,
        },
        /// isPointInPath(path, x, y, fillRule)
        Path2D_unrestricted double_unrestricted double_CanvasFillRule: struct {
            path: anyopaque,
            x: f64,
            y: f64,
            fillRule: anyopaque,
        },
    };

    pub fn call_isPointInPath(instance: *runtime.Instance, args: IsPointInPathArgs) bool {
        const state = instance.getState(State);
        switch (args) {
            .unrestricted double_unrestricted double_CanvasFillRule => |a| return PaintRenderingContext2DImpl.unrestricted double_unrestricted double_CanvasFillRule(state, a.x, a.y, a.fillRule),
            .Path2D_unrestricted double_unrestricted double_CanvasFillRule => |a| return PaintRenderingContext2DImpl.Path2D_unrestricted double_unrestricted double_CanvasFillRule(state, a.path, a.x, a.y, a.fillRule),
        }
    }

    pub fn call_getLineDash(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.call_getLineDash(state);
    }

    pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_ellipse(state, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
    }

    pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_clearRect(state, x, y, w, h);
    }

    pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_createConicGradient(state, startAngle, x, y);
    }

    pub fn call_transform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_transform(state, a, b, c, d, e, f);
    }

    pub fn call_restore(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.call_restore(state);
    }

    /// Arguments for clip (WebIDL overloading)
    pub const ClipArgs = union(enum) {
        /// clip(fillRule)
        CanvasFillRule: anyopaque,
        /// clip(path, fillRule)
        Path2D_CanvasFillRule: struct {
            path: anyopaque,
            fillRule: anyopaque,
        },
    };

    pub fn call_clip(instance: *runtime.Instance, args: ClipArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CanvasFillRule => |arg| return PaintRenderingContext2DImpl.CanvasFillRule(state, arg),
            .Path2D_CanvasFillRule => |a| return PaintRenderingContext2DImpl.Path2D_CanvasFillRule(state, a.path, a.fillRule),
        }
    }

    pub fn call_reset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.call_reset(state);
    }

    /// Arguments for stroke (WebIDL overloading)
    pub const StrokeArgs = union(enum) {
        /// stroke()
        no_params: void,
        /// stroke(path)
        Path2D: anyopaque,
    };

    pub fn call_stroke(instance: *runtime.Instance, args: StrokeArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return PaintRenderingContext2DImpl.no_params(state),
            .Path2D => |arg| return PaintRenderingContext2DImpl.Path2D(state, arg),
        }
    }

    /// Arguments for drawImage (WebIDL overloading)
    pub const DrawImageArgs = union(enum) {
        /// drawImage(image, dx, dy)
        CanvasImageSource_unrestricted double_unrestricted double: struct {
            image: anyopaque,
            dx: f64,
            dy: f64,
        },
        /// drawImage(image, dx, dy, dw, dh)
        CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double: struct {
            image: anyopaque,
            dx: f64,
            dy: f64,
            dw: f64,
            dh: f64,
        },
        /// drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh)
        CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double: struct {
            image: anyopaque,
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

    pub fn call_drawImage(instance: *runtime.Instance, args: DrawImageArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CanvasImageSource_unrestricted double_unrestricted double => |a| return PaintRenderingContext2DImpl.CanvasImageSource_unrestricted double_unrestricted double(state, a.image, a.dx, a.dy),
            .CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return PaintRenderingContext2DImpl.CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double(state, a.image, a.dx, a.dy, a.dw, a.dh),
            .CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return PaintRenderingContext2DImpl.CanvasImageSource_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double(state, a.image, a.sx, a.sy, a.sw, a.sh, a.dx, a.dy, a.dw, a.dh),
        }
    }

    pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_arc(state, x, y, radius, startAngle, endAngle, counterclockwise);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getTransform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return PaintRenderingContext2DImpl.call_getTransform(state);
    }

    pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_createRadialGradient(state, x0, y0, r0, x1, y1, r1);
    }

    pub fn call_closePath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.call_closePath(state);
    }

    pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_roundRect(state, x, y, w, h, radii);
    }

    pub fn call_createPattern(instance: *runtime.Instance, image: anyopaque, repetition: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_createPattern(state, image, repetition);
    }

    pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_lineTo(state, x, y);
    }

    pub fn call_resetTransform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.call_resetTransform(state);
    }

    pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_arcTo(state, x1, y1, x2, y2, radius);
    }

    pub fn call_setLineDash(instance: *runtime.Instance, segments: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_setLineDash(state, segments);
    }

    pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_moveTo(state, x, y);
    }

    pub fn call_save(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.call_save(state);
    }

    pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_quadraticCurveTo(state, cpx, cpy, x, y);
    }

    pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_bezierCurveTo(state, cp1x, cp1y, cp2x, cp2y, x, y);
    }

    pub fn call_isContextLost(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.call_isContextLost(state);
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
            path: anyopaque,
            x: f64,
            y: f64,
        },
    };

    pub fn call_isPointInStroke(instance: *runtime.Instance, args: IsPointInStrokeArgs) bool {
        const state = instance.getState(State);
        switch (args) {
            .unrestricted double_unrestricted double => |a| return PaintRenderingContext2DImpl.unrestricted double_unrestricted double(state, a.x, a.y),
            .Path2D_unrestricted double_unrestricted double => |a| return PaintRenderingContext2DImpl.Path2D_unrestricted double_unrestricted double(state, a.path, a.x, a.y),
        }
    }

    pub fn call_rotate(instance: *runtime.Instance, angle: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_rotate(state, angle);
    }

    pub fn call_scale(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_scale(state, x, y);
    }

    pub fn call_translate(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_translate(state, x, y);
    }

    pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_createLinearGradient(state, x0, y0, x1, y1);
    }

    pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_strokeRect(state, x, y, w, h);
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
        DOMMatrix2DInit: anyopaque,
    };

    pub fn call_setTransform(instance: *runtime.Instance, args: SetTransformArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double => |a| return PaintRenderingContext2DImpl.unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double_unrestricted double(state, a.a, a.b, a.c, a.d, a.e, a.f),
            .DOMMatrix2DInit => |arg| return PaintRenderingContext2DImpl.DOMMatrix2DInit(state, arg),
        }
    }

    pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_fillRect(state, x, y, w, h);
    }

    pub fn call_beginPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PaintRenderingContext2DImpl.call_beginPath(state);
    }

    pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyopaque {
        const state = instance.getState(State);
        
        return PaintRenderingContext2DImpl.call_rect(state, x, y, w, h);
    }

    /// Arguments for fill (WebIDL overloading)
    pub const FillArgs = union(enum) {
        /// fill(fillRule)
        CanvasFillRule: anyopaque,
        /// fill(path, fillRule)
        Path2D_CanvasFillRule: struct {
            path: anyopaque,
            fillRule: anyopaque,
        },
    };

    pub fn call_fill(instance: *runtime.Instance, args: FillArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .CanvasFillRule => |arg| return PaintRenderingContext2DImpl.CanvasFillRule(state, arg),
            .Path2D_CanvasFillRule => |a| return PaintRenderingContext2DImpl.Path2D_CanvasFillRule(state, a.path, a.fillRule),
        }
    }

};
