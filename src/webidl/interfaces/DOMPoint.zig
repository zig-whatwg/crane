//! Generated from: geometry.idl
//! Generated at: 2025-11-28T19:11:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMPointImpl = @import("impls").DOMPoint;
const mixins = @import("mixins");
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const DOMMatrixInit = @import("dictionaries").DOMMatrixInit;

pub const DOMPoint = struct {
    pub const Meta = struct {
        pub const name = "DOMPoint";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMPointReadOnly;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
            .{ .name = "LegacyWindowAlias", .value = .{ .identifier = "SVGPoint" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "z", "get_z", null },
            .{ "w", "get_w", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "fromPoint", "call_fromPoint", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "fromPoint",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "matrixTransform",
            "toJSON",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "z", "get_z", null },
            .{ "w", "get_w", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            x: f64 = undefined,
            y: f64 = undefined,
            z: f64 = undefined,
            w: f64 = undefined,
            _internal: ?*DOMPointImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_w = &get_w,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

        .call_fromPoint = &call_fromPoint,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMPointImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMPointImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), z: webidl.Opt(f64), w: webidl.Opt(f64)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMPointImpl.call_constructor(allocator, ctx, x, y, z, w);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_z(instance);
    }

    pub fn get_w(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointImpl.get_w(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromPoint(instance: *runtime.Instance, other: webidl.Opt(DOMPointInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMPointImpl.call_fromPoint(instance, other);
    }

};
