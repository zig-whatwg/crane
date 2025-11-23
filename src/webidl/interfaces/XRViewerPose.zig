//! Generated from: webxr.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRViewerPoseImpl = @import("impls").XRViewerPose;
const XRPose = @import("interfaces").XRPose;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const XRView = @import("interfaces").XRView;
const DOMPointReadOnly = @import("interfaces").DOMPointReadOnly;

pub const XRViewerPose = struct {
    pub const Meta = struct {
        pub const name = "XRViewerPose";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRPose;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "views", "get_views", null },
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
            .{ "views", "get_views", null },
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
            views: runtime.FrozenArray(XRView) = undefined,
            cached_views: ?runtime.FrozenArray(XRView) = null,
            _internal: ?*XRViewerPoseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_views = &get_views,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRViewerPoseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRViewerPoseImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_views(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_views) |cached| {
            return cached;
        }
        const value = try XRViewerPoseImpl.get_views(instance);
        state.own.cached_views = value;
        return value;
    }

};
