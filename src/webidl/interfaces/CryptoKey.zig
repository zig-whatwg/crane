//! Generated from: webcrypto.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CryptoKeyImpl = @import("impls").CryptoKey;
const KeyType = @import("enums").KeyType;

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
        
        // Initialize the instance (Impl receives full instance)
        CryptoKeyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CryptoKeyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!KeyType {
        return try CryptoKeyImpl.get_type(instance);
    }

    pub fn get_extractable(instance: *runtime.Instance) anyerror!bool {
        return try CryptoKeyImpl.get_extractable(instance);
    }

    pub fn get_algorithm(instance: *runtime.Instance) anyerror!anyopaque {
        return try CryptoKeyImpl.get_algorithm(instance);
    }

    pub fn get_usages(instance: *runtime.Instance) anyerror!anyopaque {
        return try CryptoKeyImpl.get_usages(instance);
    }

};
