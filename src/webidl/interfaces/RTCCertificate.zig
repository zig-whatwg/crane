//! Generated from: webrtc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCCertificateImpl = @import("impls").RTCCertificate;
const EpochTimeStamp = @import("typedefs").EpochTimeStamp;

pub const RTCCertificate = struct {
    pub const Meta = struct {
        pub const name = "RTCCertificate";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            expires: EpochTimeStamp = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCCertificate, .{
        .deinit_fn = &deinit_wrapper,

        .get_expires = &get_expires,

        .call_getFingerprints = &call_getFingerprints,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        RTCCertificateImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCCertificateImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_expires(instance: *runtime.Instance) anyerror!EpochTimeStamp {
        return try RTCCertificateImpl.get_expires(instance);
    }

    pub fn call_getFingerprints(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCCertificateImpl.call_getFingerprints(instance);
    }

};
