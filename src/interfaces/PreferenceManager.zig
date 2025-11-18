//! Generated from: mediaqueries-5.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PreferenceManagerImpl = @import("../impls/PreferenceManager.zig");

pub const PreferenceManager = struct {
    pub const Meta = struct {
        pub const name = "PreferenceManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            colorScheme: PreferenceObject = undefined,
            contrast: PreferenceObject = undefined,
            reducedMotion: PreferenceObject = undefined,
            reducedTransparency: PreferenceObject = undefined,
            reducedData: PreferenceObject = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PreferenceManager, .{
        .deinit_fn = &deinit_wrapper,

        .get_colorScheme = &get_colorScheme,
        .get_contrast = &get_contrast,
        .get_reducedData = &get_reducedData,
        .get_reducedMotion = &get_reducedMotion,
        .get_reducedTransparency = &get_reducedTransparency,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        PreferenceManagerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PreferenceManagerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_colorScheme(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PreferenceManagerImpl.get_colorScheme(state);
    }

    pub fn get_contrast(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PreferenceManagerImpl.get_contrast(state);
    }

    pub fn get_reducedMotion(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PreferenceManagerImpl.get_reducedMotion(state);
    }

    pub fn get_reducedTransparency(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PreferenceManagerImpl.get_reducedTransparency(state);
    }

    pub fn get_reducedData(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PreferenceManagerImpl.get_reducedData(state);
    }

};
