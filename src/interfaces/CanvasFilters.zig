//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasFiltersImpl = @import("../impls/CanvasFilters.zig");

pub const CanvasFilters = struct {
    pub const Meta = struct {
        pub const name = "CanvasFilters";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            filter: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasFilters, .{
        .deinit_fn = &deinit_wrapper,

        .get_filter = &get_filter,

        .set_filter = &set_filter,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasFiltersImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasFiltersImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_filter(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasFiltersImpl.get_filter(state);
    }

    pub fn set_filter(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CanvasFiltersImpl.set_filter(state, value);
    }

};
