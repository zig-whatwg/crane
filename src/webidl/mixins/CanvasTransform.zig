//! Auto-generated mixin: CanvasTransform
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasTransformImpl = @import("impls").CanvasTransform;

// Re-export types from impl
pub const impl = @import("impls").CanvasTransform;

pub fn call_rotate(instance: *runtime.Instance, angle: runtime.JSValue) anyerror!void {
    return CanvasTransformImpl.call_rotate(instance, angle);
}

pub fn call_scale(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue) anyerror!void {
    return CanvasTransformImpl.call_scale(instance, x, y);
}

pub fn call_translate(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue) anyerror!void {
    return CanvasTransformImpl.call_translate(instance, x, y);
}

pub fn call_resetTransform(instance: *runtime.Instance) anyerror!void {
    return CanvasTransformImpl.call_resetTransform(instance);
}

pub fn call_transform(instance: *runtime.Instance, a: runtime.JSValue, b: runtime.JSValue, c: runtime.JSValue, d: runtime.JSValue, e: runtime.JSValue, f: runtime.JSValue) anyerror!void {
    return CanvasTransformImpl.call_transform(instance, a, b, c, d, e, f);
}

pub fn call_getTransform(instance: *runtime.Instance) !*runtime.Instance {
    return CanvasTransformImpl.call_getTransform(instance);
}

/// Arguments for setTransform (WebIDL overloading)
pub const SetTransformArgs = union(enum) {
    /// setTransform(a, b, c, d, e, f)
    unrestricted_double_unrestricted_double_unrestricted_double_unrestricted_double_unrestricted_double_unrestricted_double: struct {
        a: runtime.JSValue,
        b: runtime.JSValue,
        c: runtime.JSValue,
        d: runtime.JSValue,
        e: runtime.JSValue,
        f: runtime.JSValue,
    },
    /// setTransform(transform)
    DOMMatrix2DInit: webidl.Opt(dictionaries.DOMMatrix2DInit),
};

pub fn call_setTransform(instance: *runtime.Instance, args: SetTransformArgs) anyerror!void {
    return CanvasTransformImpl.call_setTransform(instance, args);
}

