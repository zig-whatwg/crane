//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationDestinationImpl = @import("impls").NavigationDestination;

pub const NavigationDestination = struct {
    pub const Meta = struct {
        pub const name = "NavigationDestination";
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
            url: runtime.USVString = undefined,
            key: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            index: i64 = undefined,
            sameDocument: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigationDestination, .{
        .deinit_fn = &deinit_wrapper,

        .get_id = &get_id,
        .get_index = &get_index,
        .get_key = &get_key,
        .get_sameDocument = &get_sameDocument,
        .get_url = &get_url,

        .call_getState = &call_getState,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NavigationDestinationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigationDestinationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try NavigationDestinationImpl.get_url(instance);
    }

    pub fn get_key(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigationDestinationImpl.get_key(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigationDestinationImpl.get_id(instance);
    }

    pub fn get_index(instance: *runtime.Instance) anyerror!i64 {
        return try NavigationDestinationImpl.get_index(instance);
    }

    pub fn get_sameDocument(instance: *runtime.Instance) anyerror!bool {
        return try NavigationDestinationImpl.get_sameDocument(instance);
    }

    pub fn call_getState(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigationDestinationImpl.call_getState(instance);
    }

};
