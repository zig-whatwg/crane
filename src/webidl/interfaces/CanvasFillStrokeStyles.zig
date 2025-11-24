//! Generated from: html.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasFillStrokeStylesImpl = @import("impls").CanvasFillStrokeStyles;
const CanvasGradient = @import("interfaces").CanvasGradient;
const CanvasImageSource = @import("typedefs").CanvasImageSource;
const CanvasPattern = @import("interfaces").CanvasPattern;
const DOMString = @import("typedefs").DOMString;

pub const CanvasFillStrokeStyles = struct {
    pub const Meta = struct {
        pub const name = "CanvasFillStrokeStyles";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "strokeStyle", "get_strokeStyle", "set_strokeStyle" },
            .{ "fillStyle", "get_fillStyle", "set_fillStyle" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "createLinearGradient", "call_createLinearGradient", 4 },
            .{ "createRadialGradient", "call_createRadialGradient", 6 },
            .{ "createConicGradient", "call_createConicGradient", 3 },
            .{ "createPattern", "call_createPattern", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createLinearGradient",
            "createRadialGradient",
            "createConicGradient",
            "createPattern",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "strokeStyle", "get_strokeStyle", "set_strokeStyle" },
            .{ "fillStyle", "get_fillStyle", "set_fillStyle" },
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
            _internal: ?*CanvasFillStrokeStylesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_fillStyle = &get_fillStyle,
        .get_strokeStyle = &get_strokeStyle,

        .set_fillStyle = &set_fillStyle,
        .set_strokeStyle = &set_strokeStyle,

        .call_createConicGradient = &call_createConicGradient,
        .call_createLinearGradient = &call_createLinearGradient,
        .call_createPattern = &call_createPattern,
        .call_createRadialGradient = &call_createRadialGradient,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasFillStrokeStylesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasFillStrokeStylesImpl.deinit(instance);
    }

    pub fn get_strokeStyle(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CanvasFillStrokeStylesImpl.get_strokeStyle(instance);
    }

    pub fn set_strokeStyle(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try CanvasFillStrokeStylesImpl.set_strokeStyle(instance, value);
    }

    pub fn get_fillStyle(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CanvasFillStrokeStylesImpl.get_fillStyle(instance);
    }

    pub fn set_fillStyle(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try CanvasFillStrokeStylesImpl.set_fillStyle(instance, value);
    }

    pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyerror!*runtime.Instance {
        
        return try CanvasFillStrokeStylesImpl.call_createLinearGradient(instance, x0, y0, x1, y1);
    }

    pub fn call_createPattern(instance: *runtime.Instance, image: CanvasImageSource, repetition: DOMString) anyerror!*runtime.Instance {
        
        return try CanvasFillStrokeStylesImpl.call_createPattern(instance, image, repetition);
    }

    pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyerror!*runtime.Instance {
        
        return try CanvasFillStrokeStylesImpl.call_createConicGradient(instance, startAngle, x, y);
    }

    pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyerror!*runtime.Instance {
        
        return try CanvasFillStrokeStylesImpl.call_createRadialGradient(instance, x0, y0, r0, x1, y1, r1);
    }

};
