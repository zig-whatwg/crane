//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationTransitionImpl = @import("impls").NavigationTransition;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const NavigationType = @import("enums").NavigationType;
const NavigationHistoryEntry = @import("interfaces").NavigationHistoryEntry;

pub const NavigationTransition = struct {
    pub const Meta = struct {
        pub const name = "NavigationTransition";
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
        struct {
            navigationType: NavigationType = undefined,
            from: NavigationHistoryEntry = undefined,
            committed: Promise<undefined> = undefined,
            finished: Promise<undefined> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigationTransition, .{
        .deinit_fn = &deinit_wrapper,

        .get_committed = &get_committed,
        .get_finished = &get_finished,
        .get_from = &get_from,
        .get_navigationType = &get_navigationType,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NavigationTransitionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationTransitionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_navigationType(instance: *runtime.Instance) anyerror!NavigationType {
        return try NavigationTransitionImpl.get_navigationType(instance);
    }

    pub fn get_from(instance: *runtime.Instance) anyerror!NavigationHistoryEntry {
        return try NavigationTransitionImpl.get_from(instance);
    }

    pub fn get_committed(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationTransitionImpl.get_committed(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationTransitionImpl.get_finished(instance);
    }

};
