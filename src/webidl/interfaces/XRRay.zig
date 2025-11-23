//! Generated from: webxr-hit-test.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRRayImpl = @import("impls").XRRay;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const XRRayDirectionInit = @import("dictionaries").XRRayDirectionInit;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRRay = struct {
    pub const Meta = struct {
        pub const name = "XRRay";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "origin", "get_origin", null },
            .{ "direction", "get_direction", null },
            .{ "matrix", "get_matrix", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "origin", "get_origin", null },
            .{ "direction", "get_direction", null },
            .{ "matrix", "get_matrix", null },
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
            origin: *runtime.Instance = undefined,
            direction: *runtime.Instance = undefined,
            matrix: runtime.Float32Array = undefined,
            cached_origin: ?*runtime.Instance = null,
            cached_direction: ?*runtime.Instance = null,
            cached_matrix: ?runtime.Float32Array = null,
            _internal: ?*XRRayImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_direction = &get_direction,
        .get_matrix = &get_matrix,
        .get_origin = &get_origin,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRRayImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRRayImpl.deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(origin, direction)
        DOMPointInit_XRRayDirectionInit: struct {
            origin: DOMPointInit,
            direction: XRRayDirectionInit,
        },
        /// constructor(transform)
        XRRigidTransform: XRRigidTransform,
    };

    /// WebIDL constructor (overloaded)
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try XRRayImpl.call_constructor(allocator, ctx, args);
    }

    /// Extended attributes: [SameObject]
    pub fn get_origin(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_origin) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_origin(instance);
        state.own.cached_origin = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_direction(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_direction) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_direction(instance);
        state.own.cached_direction = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_matrix(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_matrix) |cached| {
            return cached;
        }
        const value = try XRRayImpl.get_matrix(instance);
        state.own.cached_matrix = value;
        return value;
    }

};
