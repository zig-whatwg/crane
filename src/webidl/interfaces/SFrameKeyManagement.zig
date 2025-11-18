//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SFrameKeyManagementImpl = @import("impls").SFrameKeyManagement;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const EventHandler = @import("typedefs").EventHandler;
const CryptoKey = @import("interfaces").CryptoKey;

pub const SFrameKeyManagement = struct {
    pub const Meta = struct {
        pub const name = "SFrameKeyManagement";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SFrameKeyManagement, .{
        .deinit_fn = &deinit_wrapper,

        .get_onerror = &get_onerror,

        .set_onerror = &set_onerror,

        .call_setEncryptionKey = &call_setEncryptionKey,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SFrameKeyManagementImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SFrameKeyManagementImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SFrameKeyManagementImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SFrameKeyManagementImpl.set_onerror(instance, value);
    }

    pub fn call_setEncryptionKey(instance: *runtime.Instance, key: CryptoKey, keyID: CryptoKeyID) anyerror!anyopaque {
        
        return try SFrameKeyManagementImpl.call_setEncryptionKey(instance, key, keyID);
    }

};
