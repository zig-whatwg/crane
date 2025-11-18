//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorContentUtilsImpl = @import("../impls/NavigatorContentUtils.zig");

pub const NavigatorContentUtils = struct {
    pub const Meta = struct {
        pub const name = "NavigatorContentUtils";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorContentUtils, .{
        .deinit_fn = &deinit_wrapper,

        .call_registerProtocolHandler = &call_registerProtocolHandler,
        .call_unregisterProtocolHandler = &call_unregisterProtocolHandler,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NavigatorContentUtilsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigatorContentUtilsImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_unregisterProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorContentUtilsImpl.call_unregisterProtocolHandler(state, scheme, url);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_registerProtocolHandler(instance: *runtime.Instance, scheme: runtime.DOMString, url: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorContentUtilsImpl.call_registerProtocolHandler(state, scheme, url);
    }

};
