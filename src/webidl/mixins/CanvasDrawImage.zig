//! Auto-generated mixin: CanvasDrawImage
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasDrawImageImpl = @import("impls").CanvasDrawImage;

// Re-export types from impl
pub const impl = @import("impls").CanvasDrawImage;

/// Arguments for drawImage (WebIDL overloading)
pub const DrawImageArgs = union(enum) {
    /// drawImage(image, dx, dy)
    CanvasImageSource_unrestricted_double_unrestricted_double: struct {
        image: typedefs.CanvasImageSource,
        dx: runtime.JSValue,
        dy: runtime.JSValue,
    },
    /// drawImage(image, dx, dy, dw, dh)
    CanvasImageSource_unrestricted_double_unrestricted_double_unrestricted_double_unrestricted_double: struct {
        image: typedefs.CanvasImageSource,
        dx: runtime.JSValue,
        dy: runtime.JSValue,
        dw: runtime.JSValue,
        dh: runtime.JSValue,
    },
    /// drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh)
    CanvasImageSource_unrestricted_double_unrestricted_double_unrestricted_double_unrestricted_double_unrestricted_double_unrestricted_double_unrestricted_double_unrestricted_double: struct {
        image: typedefs.CanvasImageSource,
        sx: runtime.JSValue,
        sy: runtime.JSValue,
        sw: runtime.JSValue,
        sh: runtime.JSValue,
        dx: runtime.JSValue,
        dy: runtime.JSValue,
        dw: runtime.JSValue,
        dh: runtime.JSValue,
    },
};

pub fn call_drawImage(instance: *runtime.Instance, args: DrawImageArgs) anyerror!void {
    return CanvasDrawImageImpl.call_drawImage(instance, args);
}

