//! Generated from: geometry.idl
//! Generated at: 2025-11-25T13:07:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMPointReadOnlyImpl = @import("impls").DOMPointReadOnly;
const DOMPoint = @import("interfaces").DOMPoint;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const DOMMatrixInit = @import("dictionaries").DOMMatrixInit;

pub const DOMPointReadOnly = struct {
    pub const Meta = struct {
        pub const name = "DOMPointReadOnly";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "fromPoint", "call_fromPoint", 0 },
            .{ "matrixTransform", "call_matrixTransform", 0 },
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "fromPoint",
            "matrixTransform",
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
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
            _internal: ?*DOMPointReadOnlyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_w = &get_w,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

        .call_fromPoint = &call_fromPoint,
        .call_matrixTransform = &call_matrixTransform,
        .call_toJSON = &call_toJSON,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMPointReadOnlyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMPointReadOnlyImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, x: f64, y: f64, z: f64, w: f64) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DOMPointReadOnlyImpl.call_constructor(allocator, ctx, x, y, z, w);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_y(instance);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_z(instance);
    }

    pub fn get_w(instance: *runtime.Instance) anyerror!f64 {
        return try DOMPointReadOnlyImpl.get_w(instance);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try DOMPointReadOnlyImpl.call_toJSON(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matrixTransform(instance: *runtime.Instance, matrix: DOMMatrixInit) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMPointReadOnlyImpl.call_matrixTransform(instance, matrix);
    }

    /// Extended attributes: [NewObject]
    pub fn call_fromPoint(instance: *runtime.Instance, other: DOMPointInit) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try DOMPointReadOnlyImpl.call_fromPoint(instance, other);
    }

};
