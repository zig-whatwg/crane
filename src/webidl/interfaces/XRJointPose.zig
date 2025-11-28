//! Generated from: webxr-hand-input.idl
//! Generated at: 2025-11-28T19:11:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRJointPoseImpl = @import("impls").XRJointPose;
const mixins = @import("mixins");
const XRPose = @import("interfaces").XRPose;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRJointPose = struct {
    pub const Meta = struct {
        pub const name = "XRJointPose";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRPose;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "radius", "get_radius", null },
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
            .{ "radius", "get_radius", null },
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
            radius: f32 = undefined,
            _internal: ?*XRJointPoseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_radius = &get_radius,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRJointPoseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRJointPoseImpl.deinit(instance);
    }

    pub fn get_radius(instance: *runtime.Instance) anyerror!f32 {
        return try XRJointPoseImpl.get_radius(instance);
    }

};
