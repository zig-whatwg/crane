//! Generated from: webxr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRViewerPoseImpl = @import("impls").XRViewerPose;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRPose = @import("XRPose.zig").XRPose;
const XRRigidTransform = @import("XRRigidTransform.zig").XRRigidTransform;
const XRView = @import("XRView.zig").XRView;
const DOMPointReadOnly = @import("DOMPointReadOnly.zig").DOMPointReadOnly;

pub const XRViewerPose = struct {
    pub const Meta = struct {
        pub const name = "XRViewerPose";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XRPose.State;
        pub const ParentInterface = XRPose;
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
            views: runtime.JSValue = undefined,
            cached_views: ?runtime.JSValue = null,
            _internal: ?*XRViewerPoseImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_views = &get_views,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XRViewerPoseImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XRViewerPoseImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRViewerPoseImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_views(instance: *runtime.Instance) anyerror!runtime.JSValue {
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
