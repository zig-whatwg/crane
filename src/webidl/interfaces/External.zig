//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ExternalImpl = @import("impls").External;

pub const External = struct {
    pub const Meta = struct {
        pub const name = "External";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
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

    pub const vtable = runtime.buildVTable(External, .{
        .deinit_fn = &deinit_wrapper,

        .call_AddSearchProvider = &call_AddSearchProvider,
        .call_IsSearchProviderInstalled = &call_IsSearchProviderInstalled,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ExternalImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ExternalImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_AddSearchProvider(instance: *runtime.Instance) anyerror!void {
        return try ExternalImpl.call_AddSearchProvider(instance);
    }

    pub fn call_IsSearchProviderInstalled(instance: *runtime.Instance) anyerror!void {
        return try ExternalImpl.call_IsSearchProviderInstalled(instance);
    }

};
