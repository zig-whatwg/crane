//! Generated from: web-locks.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LockManagerImpl = @import("../impls/LockManager.zig");

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
        .call_request = &call_request,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        LockManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        LockManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for request (WebIDL overloading)
    pub const RequestArgs = union(enum) {
        /// request(name, callback)
        string_LockGrantedCallback: struct {
            name: runtime.DOMString,
            callback: anyopaque,
        },
        /// request(name, options, callback)
        string_LockOptions_LockGrantedCallback: struct {
            name: runtime.DOMString,
            options: anyopaque,
            callback: anyopaque,
        },
    };

    pub fn call_request(instance: *runtime.Instance, args: RequestArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .string_LockGrantedCallback => |a| return LockManagerImpl.string_LockGrantedCallback(state, a.name, a.callback),
            .string_LockOptions_LockGrantedCallback => |a| return LockManagerImpl.string_LockOptions_LockGrantedCallback(state, a.name, a.options, a.callback),
        }
    }

    pub fn call_query(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return LockManagerImpl.call_query(state);
    }

};
