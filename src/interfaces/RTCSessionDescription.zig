//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCSessionDescriptionImpl = @import("../impls/RTCSessionDescription.zig");

pub const RTCSessionDescription = struct {
    pub const Meta = struct {
        pub const name = "RTCSessionDescription";
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
            type: RTCSdpType = undefined,
            sdp: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCSessionDescription, .{
        .deinit_fn = &deinit_wrapper,

        .get_sdp = &get_sdp,
        .get_type = &get_type,

        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RTCSessionDescriptionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCSessionDescriptionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, descriptionInitDict: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try RTCSessionDescriptionImpl.constructor(state, descriptionInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCSessionDescriptionImpl.get_type(state);
    }

    pub fn get_sdp(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return RTCSessionDescriptionImpl.get_sdp(state);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCSessionDescriptionImpl.call_toJSON(state);
    }

};
