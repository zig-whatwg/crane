//! Generated from: direct-sockets.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MulticastControllerImpl = @import("impls").MulticastController;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const FrozenArray<DOMString> = @import("interfaces").FrozenArray<DOMString>;

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
        
        // Initialize the instance (Impl receives full instance)
        MulticastControllerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MulticastControllerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_joinedGroups(instance: *runtime.Instance) anyerror!anyopaque {
        return try MulticastControllerImpl.get_joinedGroups(instance);
    }

    pub fn call_joinGroup(instance: *runtime.Instance, ipAddress: DOMString) anyerror!anyopaque {
        
        return try MulticastControllerImpl.call_joinGroup(instance, ipAddress);
    }

    pub fn call_leaveGroup(instance: *runtime.Instance, ipAddress: DOMString) anyerror!anyopaque {
        
        return try MulticastControllerImpl.call_leaveGroup(instance, ipAddress);
    }

};
