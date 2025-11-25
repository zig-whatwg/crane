//! Generated from: webxr.idl
//! Generated at: 2025-11-25T13:07:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRRigidTransformImpl = @import("impls").XRRigidTransform;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRRigidTransform = struct {
    pub const Meta = struct {
        pub const name = "XRRigidTransform";
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
            .{ "position", "get_position", null },
            .{ "orientation", "get_orientation", null },
            .{ "matrix", "get_matrix", null },
            .{ "inverse", "get_inverse", null },
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
            .{ "position", "get_position", null },
            .{ "orientation", "get_orientation", null },
            .{ "matrix", "get_matrix", null },
            .{ "inverse", "get_inverse", null },
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
            position: *runtime.Instance = undefined,
            orientation: *runtime.Instance = undefined,
            matrix: runtime.Float32Array = undefined,
            inverse: *runtime.Instance = undefined,
            cached_position: ?*runtime.Instance = null,
            cached_orientation: ?*runtime.Instance = null,
            cached_inverse: ?*runtime.Instance = null,
            _internal: ?*XRRigidTransformImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_inverse = &get_inverse,
        .get_matrix = &get_matrix,
        .get_orientation = &get_orientation,
        .get_position = &get_position,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRRigidTransformImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRRigidTransformImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, position: DOMPointInit, orientation: DOMPointInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XRRigidTransformImpl.call_constructor(allocator, ctx, position, orientation);
    }

    /// Extended attributes: [SameObject]
    pub fn get_position(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_position) |cached| {
            return cached;
        }
        const value = try XRRigidTransformImpl.get_position(instance);
        state.own.cached_position = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_orientation) |cached| {
            return cached;
        }
        const value = try XRRigidTransformImpl.get_orientation(instance);
        state.own.cached_orientation = value;
        return value;
    }

    pub fn get_matrix(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRRigidTransformImpl.get_matrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_inverse(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_inverse) |cached| {
            return cached;
        }
        const value = try XRRigidTransformImpl.get_inverse(instance);
        state.own.cached_inverse = value;
        return value;
    }

};
