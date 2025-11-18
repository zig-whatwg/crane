//! Generated from: gpc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GlobalPrivacyControlImpl = @import("../impls/GlobalPrivacyControl.zig");

pub const GlobalPrivacyControl = struct {
    pub const Meta = struct {
        pub const name = "GlobalPrivacyControl";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            globalPrivacyControl: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GlobalPrivacyControl, .{
        .deinit_fn = &deinit_wrapper,

        .get_globalPrivacyControl = &get_globalPrivacyControl,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GlobalPrivacyControlImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GlobalPrivacyControlImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_globalPrivacyControl(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return GlobalPrivacyControlImpl.get_globalPrivacyControl(state);
    }

};
