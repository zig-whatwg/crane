//! Generated from: webxr.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRPoseImpl = @import("impls").XRPose;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRPose = struct {
    pub const Meta = struct {
        pub const name = "XRPose";
        pub const is_mixin = false;
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
            .{ "transform", "get_transform", null },
            .{ "linearVelocity", "get_linearVelocity", null },
            .{ "angularVelocity", "get_angularVelocity", null },
            .{ "emulatedPosition", "get_emulatedPosition", null },
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
            .{ "transform", "get_transform", null },
            .{ "linearVelocity", "get_linearVelocity", null },
            .{ "angularVelocity", "get_angularVelocity", null },
            .{ "emulatedPosition", "get_emulatedPosition", null },
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
            transform: *runtime.Instance = undefined,
            linearVelocity: ?*runtime.Instance = null,
            angularVelocity: ?*runtime.Instance = null,
            emulatedPosition: bool = undefined,
            cached_transform: ?*runtime.Instance = null,
            cached_linearVelocity: ?*runtime.Instance = null,
            cached_angularVelocity: ?*runtime.Instance = null,
            _internal: ?*XRPoseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_angularVelocity = &get_angularVelocity,
        .get_emulatedPosition = &get_emulatedPosition,
        .get_linearVelocity = &get_linearVelocity,
        .get_transform = &get_transform,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRPoseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRPoseImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_transform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_transform) |cached| {
            return cached;
        }
        const value = try XRPoseImpl.get_transform(instance);
        state.own.cached_transform = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_linearVelocity(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_linearVelocity) |cached| {
            return cached;
        }
        const value = try XRPoseImpl.get_linearVelocity(instance);
        state.own.cached_linearVelocity = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_angularVelocity(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_angularVelocity) |cached| {
            return cached;
        }
        const value = try XRPoseImpl.get_angularVelocity(instance);
        state.own.cached_angularVelocity = value;
        return value;
    }

    pub fn get_emulatedPosition(instance: *runtime.Instance) anyerror!bool {
        return try XRPoseImpl.get_emulatedPosition(instance);
    }

};
