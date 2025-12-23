//! Auto-generated mixin: CanvasDrawPath
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasDrawPathImpl = @import("impls").CanvasDrawPath;

// Re-export types from impl
pub const impl = @import("impls").CanvasDrawPath;

pub fn call_beginPath(instance: *runtime.Instance) anyerror!void {
    return CanvasDrawPathImpl.call_beginPath(instance);
}

/// Arguments for isPointInPath (WebIDL overloading)
pub const IsPointInPathArgs = union(enum) {
    /// isPointInPath(x, y, fillRule)
    unrestricted_double_unrestricted_double_CanvasFillRule: struct {
        x: runtime.JSValue,
        y: runtime.JSValue,
        fillRule: webidl.Opt(enums.CanvasFillRule),
    },
    /// isPointInPath(path, x, y, fillRule)
    Path2D_unrestricted_double_unrestricted_double_CanvasFillRule: struct {
        path: *runtime.Instance,
        x: runtime.JSValue,
        y: runtime.JSValue,
        fillRule: webidl.Opt(enums.CanvasFillRule),
    },
};

pub fn call_isPointInPath(instance: *runtime.Instance, args: IsPointInPathArgs) anyerror!void {
    return CanvasDrawPathImpl.call_isPointInPath(instance, args);
}

/// Arguments for stroke (WebIDL overloading)
pub const StrokeArgs = union(enum) {
    /// stroke()
    no_params: void,
    /// stroke(path)
    Path2D: *runtime.Instance,
};

pub fn call_stroke(instance: *runtime.Instance, args: StrokeArgs) anyerror!void {
    return CanvasDrawPathImpl.call_stroke(instance, args);
}

/// Arguments for isPointInStroke (WebIDL overloading)
pub const IsPointInStrokeArgs = union(enum) {
    /// isPointInStroke(x, y)
    unrestricted_double_unrestricted_double: struct {
        x: runtime.JSValue,
        y: runtime.JSValue,
    },
    /// isPointInStroke(path, x, y)
    Path2D_unrestricted_double_unrestricted_double: struct {
        path: *runtime.Instance,
        x: runtime.JSValue,
        y: runtime.JSValue,
    },
};

pub fn call_isPointInStroke(instance: *runtime.Instance, args: IsPointInStrokeArgs) anyerror!void {
    return CanvasDrawPathImpl.call_isPointInStroke(instance, args);
}

/// Arguments for fill (WebIDL overloading)
pub const FillArgs = union(enum) {
    /// fill(fillRule)
    CanvasFillRule: webidl.Opt(enums.CanvasFillRule),
    /// fill(path, fillRule)
    Path2D_CanvasFillRule: struct {
        path: *runtime.Instance,
        fillRule: webidl.Opt(enums.CanvasFillRule),
    },
};

pub fn call_fill(instance: *runtime.Instance, args: FillArgs) anyerror!void {
    return CanvasDrawPathImpl.call_fill(instance, args);
}

/// Arguments for clip (WebIDL overloading)
pub const ClipArgs = union(enum) {
    /// clip(fillRule)
    CanvasFillRule: webidl.Opt(enums.CanvasFillRule),
    /// clip(path, fillRule)
    Path2D_CanvasFillRule: struct {
        path: *runtime.Instance,
        fillRule: webidl.Opt(enums.CanvasFillRule),
    },
};

pub fn call_clip(instance: *runtime.Instance, args: ClipArgs) anyerror!void {
    return CanvasDrawPathImpl.call_clip(instance, args);
}

