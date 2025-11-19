//! Generated from: web-locks.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LockManagerImpl = @import("impls").LockManager;
const LockOptions = @import("dictionaries").LockOptions;
const LockGrantedCallback = @import("callbacks").LockGrantedCallback;
const DOMString = @import("typedefs").DOMString;
const LockManagerSnapshot = @import("dictionaries").LockManagerSnapshot;

pub const LockManager = struct {
    pub const Meta = struct {
        pub const name = "LockManager";
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

    pub const vtable = runtime.buildVTable(LockManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_query = &call_query,
        .call_request = &call_request,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return LockManagerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LockManagerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_request(instance: *runtime.Instance, name: DOMString, callback: LockGrantedCallback) anyerror!anyopaque {
        
        return try LockManagerImpl.call_request(instance, name, callback);
    }

    pub fn call_query(instance: *runtime.Instance) anyerror!anyopaque {
        return try LockManagerImpl.call_query(instance);
    }

};
