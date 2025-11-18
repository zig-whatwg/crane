//! Generated from: direct-sockets.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MulticastControllerImpl = @import("../impls/MulticastController.zig");

pub const MulticastController = struct {
    pub const Meta = struct {
        pub const name = "MulticastController";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            joinedGroups: FrozenArray<DOMString> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MulticastController, .{
        .deinit_fn = &deinit_wrapper,

        .get_joinedGroups = &get_joinedGroups,

        .call_joinGroup = &call_joinGroup,
        .call_leaveGroup = &call_leaveGroup,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MulticastControllerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MulticastControllerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_joinedGroups(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MulticastControllerImpl.get_joinedGroups(state);
    }

    pub fn call_joinGroup(instance: *runtime.Instance, ipAddress: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return MulticastControllerImpl.call_joinGroup(state, ipAddress);
    }

    pub fn call_leaveGroup(instance: *runtime.Instance, ipAddress: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return MulticastControllerImpl.call_leaveGroup(state, ipAddress);
    }

};
