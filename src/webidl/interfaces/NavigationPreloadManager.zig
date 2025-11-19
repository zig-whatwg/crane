//! Generated from: service-workers.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationPreloadManagerImpl = @import("impls").NavigationPreloadManager;
const ByteString = @import("interfaces").ByteString;
const NavigationPreloadState = @import("dictionaries").NavigationPreloadState;

pub const NavigationPreloadManager = struct {
    pub const Meta = struct {
        pub const name = "NavigationPreloadManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigationPreloadManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_disable = &call_disable,
        .call_enable = &call_enable,
        .call_getState = &call_getState,
        .call_setHeaderValue = &call_setHeaderValue,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return NavigationPreloadManagerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationPreloadManagerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_setHeaderValue(instance: *runtime.Instance, value: runtime.ByteString) anyerror!anyopaque {
        
        return try NavigationPreloadManagerImpl.call_setHeaderValue(instance, value);
    }

    pub fn call_disable(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationPreloadManagerImpl.call_disable(instance);
    }

    pub fn call_getState(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationPreloadManagerImpl.call_getState(instance);
    }

    pub fn call_enable(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationPreloadManagerImpl.call_enable(instance);
    }

};
