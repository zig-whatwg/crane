//! Generated from: WEBGL_lose_context.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_lose_contextImpl = @import("impls").WEBGL_lose_context;

pub const WEBGL_lose_context = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_lose_context";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
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

    pub const vtable = runtime.buildVTable(WEBGL_lose_context, .{
        .deinit_fn = &deinit_wrapper,

        .call_loseContext = &call_loseContext,
        .call_restoreContext = &call_restoreContext,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return WEBGL_lose_contextImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_lose_contextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_loseContext(instance: *runtime.Instance) anyerror!void {
        return try WEBGL_lose_contextImpl.call_loseContext(instance);
    }

    pub fn call_restoreContext(instance: *runtime.Instance) anyerror!void {
        return try WEBGL_lose_contextImpl.call_restoreContext(instance);
    }

};
