//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StylePropertyMapReadOnlyImpl = @import("../impls/StylePropertyMapReadOnly.zig");

pub const StylePropertyMapReadOnly = struct {
    pub const Meta = struct {
        pub const name = "StylePropertyMapReadOnly";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            size: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(StylePropertyMapReadOnly, .{
        .deinit_fn = &deinit_wrapper,

        .get_size = &get_size,

        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        StylePropertyMapReadOnlyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StylePropertyMapReadOnlyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return StylePropertyMapReadOnlyImpl.get_size(state);
    }

    pub fn call_get(instance: *runtime.Instance, property: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return StylePropertyMapReadOnlyImpl.call_get(state, property);
    }

    pub fn call_getAll(instance: *runtime.Instance, property: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return StylePropertyMapReadOnlyImpl.call_getAll(state, property);
    }

    pub fn call_has(instance: *runtime.Instance, property: runtime.USVString) bool {
        const state = instance.getState(State);
        
        return StylePropertyMapReadOnlyImpl.call_has(state, property);
    }

};
