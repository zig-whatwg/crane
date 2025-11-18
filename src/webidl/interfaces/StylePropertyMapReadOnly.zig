//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StylePropertyMapReadOnlyImpl = @import("impls").StylePropertyMapReadOnly;
const (undefined or CSSStyleValue) = @import("interfaces").(undefined or CSSStyleValue);

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
        
        // Initialize the instance (Impl receives full instance)
        StylePropertyMapReadOnlyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StylePropertyMapReadOnlyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try StylePropertyMapReadOnlyImpl.get_size(instance);
    }

    pub fn call_get(instance: *runtime.Instance, property: runtime.USVString) anyerror!anyopaque {
        
        return try StylePropertyMapReadOnlyImpl.call_get(instance, property);
    }

    pub fn call_getAll(instance: *runtime.Instance, property: runtime.USVString) anyerror!anyopaque {
        
        return try StylePropertyMapReadOnlyImpl.call_getAll(instance, property);
    }

    pub fn call_has(instance: *runtime.Instance, property: runtime.USVString) anyerror!bool {
        
        return try StylePropertyMapReadOnlyImpl.call_has(instance, property);
    }

};
