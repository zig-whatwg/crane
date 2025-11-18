//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCIceCandidatePairImpl = @import("../impls/RTCIceCandidatePair.zig");

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RTCIceCandidatePairImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCIceCandidatePairImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_local(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_local) |cached| {
            return cached;
        }
        const value = RTCIceCandidatePairImpl.get_local(state);
        state.cached_local = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_remote(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_remote) |cached| {
            return cached;
        }
        const value = RTCIceCandidatePairImpl.get_remote(state);
        state.cached_remote = value;
        return value;
    }

};
