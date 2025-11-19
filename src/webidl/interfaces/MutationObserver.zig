//! Generated from: dom.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MutationObserverImpl = @import("impls").MutationObserver;
const MutationCallback = @import("callbacks").MutationCallback;
const Node = @import("interfaces").Node;
const MutationRecord = @import("interfaces").MutationRecord;
const MutationObserverInit = @import("dictionaries").MutationObserverInit;

pub const MutationObserver = struct {
    pub const Meta = struct {
        pub const name = "MutationObserver";
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

    pub const vtable = runtime.buildVTable(MutationObserver, .{
        .deinit_fn = &deinit_wrapper,

        .call_disconnect = &call_disconnect,
        .call_observe = &call_observe,
        .call_takeRecords = &call_takeRecords,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return MutationObserverImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MutationObserverImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, callback: MutationCallback) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try MutationObserverImpl.constructor(instance, callback);
        
        return instance;
    }

    pub fn call_observe(instance: *runtime.Instance, target: Node, options: MutationObserverInit) anyerror!void {
        
        return try MutationObserverImpl.call_observe(instance, target, options);
    }

    pub fn call_disconnect(instance: *runtime.Instance) anyerror!void {
        return try MutationObserverImpl.call_disconnect(instance);
    }

    pub fn call_takeRecords(instance: *runtime.Instance) anyerror!anyopaque {
        return try MutationObserverImpl.call_takeRecords(instance);
    }

};
