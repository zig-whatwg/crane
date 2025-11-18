//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StylePropertyMapImpl = @import("../impls/StylePropertyMap.zig");
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig");

pub const StylePropertyMap = struct {
    pub const Meta = struct {
        pub const name = "StylePropertyMap";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *StylePropertyMapReadOnly;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(StylePropertyMap, .{
        .deinit_fn = &deinit_wrapper,

        .get_size = &get_size,

        .call_append = &call_append,
        .call_clear = &call_clear,
        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,
        .call_set = &call_set,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        StylePropertyMapImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StylePropertyMapImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return StylePropertyMapImpl.get_size(state);
    }

    pub fn call_delete(instance: *runtime.Instance, property: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return StylePropertyMapImpl.call_delete(state, property);
    }

    pub fn call_append(instance: *runtime.Instance, property: runtime.USVString, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return StylePropertyMapImpl.call_append(state, property, values);
    }

    pub fn call_getAll(instance: *runtime.Instance, property: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return StylePropertyMapImpl.call_getAll(state, property);
    }

    pub fn call_has(instance: *runtime.Instance, property: runtime.USVString) bool {
        const state = instance.getState(State);
        
        return StylePropertyMapImpl.call_has(state, property);
    }

    pub fn call_set(instance: *runtime.Instance, property: runtime.USVString, values: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return StylePropertyMapImpl.call_set(state, property, values);
    }

    pub fn call_get(instance: *runtime.Instance, property: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return StylePropertyMapImpl.call_get(state, property);
    }

    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StylePropertyMapImpl.call_clear(state);
    }

};
