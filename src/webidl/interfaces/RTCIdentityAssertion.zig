//! Generated from: webrtc-identity.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIdentityAssertionImpl = @import("impls").RTCIdentityAssertion;

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
        
        // Initialize the instance (Impl receives full instance)
        RTCIdentityAssertionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIdentityAssertionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, idp: DOMString, name: DOMString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try RTCIdentityAssertionImpl.constructor(instance, idp, name);
        
        return instance;
    }

    pub fn get_idp(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCIdentityAssertionImpl.get_idp(instance);
    }

    pub fn set_idp(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try RTCIdentityAssertionImpl.set_idp(instance, value);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCIdentityAssertionImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try RTCIdentityAssertionImpl.set_name(instance, value);
    }

};
