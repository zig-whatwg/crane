//! Generated from: webcrypto.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CryptoImpl = @import("../impls/Crypto.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CryptoImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CryptoImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_subtle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CryptoImpl.get_subtle(state);
    }

    pub fn call_getRandomValues(instance: *runtime.Instance, array: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CryptoImpl.call_getRandomValues(state, array);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_randomUUID(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CryptoImpl.call_randomUUID(state);
    }

};
