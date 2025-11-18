//! Generated from: webrtc-identity.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIdentityAssertionImpl = @import("../impls/RTCIdentityAssertion.zig");

pub const RTCIdentityAssertion = struct {
    pub const Meta = struct {
        pub const name = "RTCIdentityAssertion";
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
            idp: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCIdentityAssertion, .{
        .deinit_fn = &deinit_wrapper,

        .get_idp = &get_idp,
        .get_name = &get_name,

        .set_idp = &set_idp,
        .set_name = &set_name,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RTCIdentityAssertionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCIdentityAssertionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, idp: runtime.DOMString, name: runtime.DOMString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try RTCIdentityAssertionImpl.constructor(state, idp, name);
        
        return instance;
    }

    pub fn get_idp(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return RTCIdentityAssertionImpl.get_idp(state);
    }

    pub fn set_idp(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        RTCIdentityAssertionImpl.set_idp(state, value);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return RTCIdentityAssertionImpl.get_name(state);
    }

    pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        RTCIdentityAssertionImpl.set_name(state, value);
    }

};
