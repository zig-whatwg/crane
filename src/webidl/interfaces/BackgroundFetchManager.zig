//! Generated from: background-fetch.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchManagerImpl = @import("impls").BackgroundFetchManager;
const BackgroundFetchRegistration = @import("interfaces").BackgroundFetchRegistration;
const RequestInfo = @import("typedefs").RequestInfo;
const sequence = @import("interfaces").sequence;
const DOMString = @import("typedefs").DOMString;
const BackgroundFetchOptions = @import("dictionaries").BackgroundFetchOptions;

pub const BackgroundFetchManager = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
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

    pub const vtable = runtime.buildVTable(BackgroundFetchManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_fetch = &call_fetch,
        .call_get = &call_get,
        .call_getIds = &call_getIds,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return BackgroundFetchManagerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchManagerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_get(instance: *runtime.Instance, id: DOMString) anyerror!anyopaque {
        
        return try BackgroundFetchManagerImpl.call_get(instance, id);
    }

    pub fn call_fetch(instance: *runtime.Instance, id: DOMString, requests: anyopaque, options: BackgroundFetchOptions) anyerror!anyopaque {
        
        return try BackgroundFetchManagerImpl.call_fetch(instance, id, requests, options);
    }

    pub fn call_getIds(instance: *runtime.Instance) anyerror!anyopaque {
        return try BackgroundFetchManagerImpl.call_getIds(instance);
    }

};
