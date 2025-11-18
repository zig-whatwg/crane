//! Generated from: webcrypto.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CryptoKeyImpl = @import("../impls/CryptoKey.zig");

pub const CryptoKey = struct {
    pub const Meta = struct {
        pub const name = "CryptoKey";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: KeyType = undefined,
            extractable: bool = undefined,
            algorithm: anyopaque = undefined,
            usages: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CryptoKey, .{
        .deinit_fn = &deinit_wrapper,

        .get_algorithm = &get_algorithm,
        .get_extractable = &get_extractable,
        .get_type = &get_type,
        .get_usages = &get_usages,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CryptoKeyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CryptoKeyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CryptoKeyImpl.get_type(state);
    }

    pub fn get_extractable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CryptoKeyImpl.get_extractable(state);
    }

    pub fn get_algorithm(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CryptoKeyImpl.get_algorithm(state);
    }

    pub fn get_usages(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CryptoKeyImpl.get_usages(state);
    }

};
