//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigationDestinationImpl = @import("../impls/NavigationDestination.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        NavigationDestinationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigationDestinationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_url(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return NavigationDestinationImpl.get_url(state);
    }

    pub fn get_key(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigationDestinationImpl.get_key(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return NavigationDestinationImpl.get_id(state);
    }

    pub fn get_index(instance: *runtime.Instance) i64 {
        const state = instance.getState(State);
        return NavigationDestinationImpl.get_index(state);
    }

    pub fn get_sameDocument(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NavigationDestinationImpl.get_sameDocument(state);
    }

    pub fn call_getState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigationDestinationImpl.call_getState(state);
    }

};
