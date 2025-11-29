//! Generated from: html.idl
//! Generated at: 2025-11-29T05:01:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasRectImpl = @import("impls").CanvasRect;
const mixins = @import("mixins");

pub const CanvasRect = struct {
    pub const Meta = struct {
        pub const name = "CanvasRect";
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
            .{ "clearRect", "call_clearRect", 4 },
            .{ "fillRect", "call_fillRect", 4 },
            .{ "strokeRect", "call_strokeRect", 4 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clearRect",
            "fillRect",
            "strokeRect",
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
            _internal: ?*CanvasRectImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_clearRect = &call_clearRect,
        .call_fillRect = &call_fillRect,
        .call_strokeRect = &call_strokeRect,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasRectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasRectImpl.deinit(instance);
    }

    pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try CanvasRectImpl.call_clearRect(instance, x, y, w, h);
    }

    pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try CanvasRectImpl.call_fillRect(instance, x, y, w, h);
    }

    pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try CanvasRectImpl.call_strokeRect(instance, x, y, w, h);
    }

};
