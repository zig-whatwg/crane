//! Generated from: webrtc.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIceCandidatePairImpl = @import("impls").RTCIceCandidatePair;
const RTCIceCandidate = @import("interfaces").RTCIceCandidate;

pub const RTCIceCandidatePair = struct {
    pub const Meta = struct {
        pub const name = "RTCIceCandidatePair";
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
            local: RTCIceCandidate = undefined,
            remote: RTCIceCandidate = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCIceCandidatePair, .{
        .deinit_fn = &deinit_wrapper,

        .get_local = &get_local,
        .get_remote = &get_remote,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return RTCIceCandidatePairImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCIceCandidatePairImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_local(instance: *runtime.Instance) anyerror!RTCIceCandidate {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_local) |cached| {
            return cached;
        }
        const value = try RTCIceCandidatePairImpl.get_local(instance);
        state.cached_local = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_remote(instance: *runtime.Instance) anyerror!RTCIceCandidate {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_remote) |cached| {
            return cached;
        }
        const value = try RTCIceCandidatePairImpl.get_remote(instance);
        state.cached_remote = value;
        return value;
    }

};
