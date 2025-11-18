//! Generated from: webcrypto.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CryptoImpl = @import("impls").Crypto;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const SubtleCrypto = @import("interfaces").SubtleCrypto;

pub const Crypto = struct {
    pub const Meta = struct {
        pub const name = "Crypto";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            subtle: SubtleCrypto = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Crypto, .{
        .deinit_fn = &deinit_wrapper,

        .get_subtle = &get_subtle,

        .call_getRandomValues = &call_getRandomValues,
        .call_randomUUID = &call_randomUUID,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CryptoImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CryptoImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_subtle(instance: *runtime.Instance) anyerror!SubtleCrypto {
        return try CryptoImpl.get_subtle(instance);
    }

    pub fn call_getRandomValues(instance: *runtime.Instance, array: ArrayBufferView) anyerror!ArrayBufferView {
        
        return try CryptoImpl.call_getRandomValues(instance, array);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_randomUUID(instance: *runtime.Instance) anyerror!DOMString {
        return try CryptoImpl.call_randomUUID(instance);
    }

};
