//! Generated from: turtledove.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ProtectedAudienceImpl = @import("impls").ProtectedAudience;
const DOMString = @import("typedefs").DOMString;

pub const ProtectedAudience = struct {
    pub const Meta = struct {
        pub const name = "ProtectedAudience";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ProtectedAudience, .{
        .deinit_fn = &deinit_wrapper,

        .call_queryFeatureSupport = &call_queryFeatureSupport,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ProtectedAudienceImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ProtectedAudienceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_queryFeatureSupport(instance: *runtime.Instance, feature: DOMString) anyerror!anyopaque {
        
        return try ProtectedAudienceImpl.call_queryFeatureSupport(instance, feature);
    }

};
