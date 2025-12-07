//! Generated from: html.idl
//! Generated at: 2025-12-07T19:33:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const CanvasTransformImpl = @import("impls").CanvasTransform;
const mixins = @import("mixins");
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const DOMMatrix = @import("interfaces").DOMMatrix;

pub const CanvasTransform = struct {
    pub const Meta = struct {
        pub const name = "CanvasTransform";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "scale", "call_scale", 2 },
            .{ "rotate", "call_rotate", 1 },
            .{ "translate", "call_translate", 2 },
            .{ "transform", "call_transform", 6 },
            .{ "getTransform", "call_getTransform", 0 },
            .{ "setTransform", "call_setTransform", 6 },
            .{ "setTransform", "call_setTransform", 0 },
            .{ "resetTransform", "call_resetTransform", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "scale",
            "rotate",
            "translate",
            "transform",
            "getTransform",
            "setTransform",
            "setTransform",
            "resetTransform",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*CanvasTransformImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getTransform = &call_getTransform,
        .call_resetTransform = &call_resetTransform,
        .call_rotate = &call_rotate,
        .call_scale = &call_scale,
        .call_setTransform = &call_setTransform,
        .call_transform = &call_transform,
        .call_translate = &call_translate,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasTransformImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasTransformImpl.deinit(instance);
    }

    pub fn call_resetTransform(instance: *runtime.Instance) anyerror!void {
        return try CanvasTransformImpl.call_resetTransform(instance);
    }

    pub fn call_setTransform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
        
        return try CanvasTransformImpl.call_setTransform(instance, a, b, c, d, e, f);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getTransform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try CanvasTransformImpl.call_getTransform(instance);
    }

    pub fn call_transform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
        
        return try CanvasTransformImpl.call_transform(instance, a, b, c, d, e, f);
    }

    pub fn call_rotate(instance: *runtime.Instance, angle: f64) anyerror!void {
        
        return try CanvasTransformImpl.call_rotate(instance, angle);
    }

    pub fn call_scale(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasTransformImpl.call_scale(instance, x, y);
    }

    pub fn call_translate(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasTransformImpl.call_translate(instance, x, y);
    }

};
