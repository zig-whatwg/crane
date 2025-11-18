//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StylePropertyMapImpl = @import("impls").StylePropertyMap;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const (CSSStyleValue or USVString) = @import("interfaces").(CSSStyleValue or USVString);

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
        
        // Initialize the instance (Impl receives full instance)
        StylePropertyMapImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StylePropertyMapImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try StylePropertyMapImpl.get_size(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, property: runtime.USVString) anyerror!void {
        
        return try StylePropertyMapImpl.call_delete(instance, property);
    }

    pub fn call_append(instance: *runtime.Instance, property: runtime.USVString, values: anyopaque) anyerror!void {
        
        return try StylePropertyMapImpl.call_append(instance, property, values);
    }

    pub fn call_getAll(instance: *runtime.Instance, property: runtime.USVString) anyerror!anyopaque {
        
        return try StylePropertyMapImpl.call_getAll(instance, property);
    }

    pub fn call_has(instance: *runtime.Instance, property: runtime.USVString) anyerror!bool {
        
        return try StylePropertyMapImpl.call_has(instance, property);
    }

    pub fn call_set(instance: *runtime.Instance, property: runtime.USVString, values: anyopaque) anyerror!void {
        
        return try StylePropertyMapImpl.call_set(instance, property, values);
    }

    pub fn call_get(instance: *runtime.Instance, property: runtime.USVString) anyerror!anyopaque {
        
        return try StylePropertyMapImpl.call_get(instance, property);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try StylePropertyMapImpl.call_clear(instance);
    }

};
