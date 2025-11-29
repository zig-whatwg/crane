//! Generated from: storage.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StorageManagerImpl = @import("impls").StorageManager;
const mixins = @import("mixins");
const FileSystemDirectoryHandle = @import("interfaces").FileSystemDirectoryHandle;
const StorageEstimate = @import("dictionaries").StorageEstimate;

pub const StorageManager = struct {
    pub const Meta = struct {
        pub const name = "StorageManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "persisted", "call_persisted", 0 },
            .{ "persist", "call_persist", 0 },
            .{ "estimate", "call_estimate", 0 },
            .{ "getDirectory", "call_getDirectory", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "persisted",
            "persist",
            "estimate",
            "getDirectory",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*StorageManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_estimate = &call_estimate,
        .call_getDirectory = &call_getDirectory,
        .call_persist = &call_persist,
        .call_persisted = &call_persisted,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StorageManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StorageManagerImpl.deinit(instance);
    }

    pub fn call_getDirectory(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageManagerImpl.call_getDirectory(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_persist(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageManagerImpl.call_persist(instance);
    }

    pub fn call_estimate(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageManagerImpl.call_estimate(instance);
    }

    pub fn call_persisted(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try StorageManagerImpl.call_persisted(instance);
    }

};
