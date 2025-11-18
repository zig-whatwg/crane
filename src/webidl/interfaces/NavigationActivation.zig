//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationActivationImpl = @import("impls").NavigationActivation;
const NavigationHistoryEntry = @import("interfaces").NavigationHistoryEntry;
const NavigationType = @import("enums").NavigationType;

pub const NavigationActivation = struct {
    pub const Meta = struct {
        pub const name = "NavigationActivation";
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
            from: ?NavigationHistoryEntry = null,
            entry: NavigationHistoryEntry = undefined,
            navigationType: NavigationType = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigationActivation, .{
        .deinit_fn = &deinit_wrapper,

        .get_entry = &get_entry,
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
        NavigationActivationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationActivationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_from(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationActivationImpl.get_from(instance);
    }

    pub fn get_entry(instance: *runtime.Instance) anyerror!NavigationHistoryEntry {
        return try NavigationActivationImpl.get_entry(instance);
    }

    pub fn get_navigationType(instance: *runtime.Instance) anyerror!NavigationType {
        return try NavigationActivationImpl.get_navigationType(instance);
    }

};
