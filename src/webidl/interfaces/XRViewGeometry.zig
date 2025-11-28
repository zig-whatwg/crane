//! Generated from: webxr.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRViewGeometryImpl = @import("impls").XRViewGeometry;
const mixins = @import("mixins");
const XRRigidTransform = @import("interfaces").XRRigidTransform;

pub const XRViewGeometry = struct {
    pub const Meta = struct {
        pub const name = "XRViewGeometry";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
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
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "projectionMatrix", "get_projectionMatrix", null },
            .{ "transform", "get_transform", null },
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
            projectionMatrix: runtime.Float32Array = undefined,
            transform: *runtime.Instance = undefined,
            cached_transform: ?*runtime.Instance = null,
            _internal: ?*XRViewGeometryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_projectionMatrix = &get_projectionMatrix,
        .get_transform = &get_transform,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRViewGeometryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRViewGeometryImpl.deinit(instance);
    }

    pub fn get_projectionMatrix(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try XRViewGeometryImpl.get_projectionMatrix(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_transform) |cached| {
            return cached;
        }
        const value = try XRViewGeometryImpl.get_transform(instance);
        state.own.cached_transform = value;
        return value;
    }

};
