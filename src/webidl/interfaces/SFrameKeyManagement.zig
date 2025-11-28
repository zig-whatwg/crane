//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-11-28T19:11:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameKeyManagementImpl = @import("impls").SFrameKeyManagement;
const mixins = @import("mixins");
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const EventHandler = @import("typedefs").EventHandler;
const CryptoKey = @import("interfaces").CryptoKey;

pub const SFrameKeyManagement = struct {
    pub const Meta = struct {
        pub const name = "SFrameKeyManagement";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onerror", "get_onerror", "set_onerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setEncryptionKey", "call_setEncryptionKey", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setEncryptionKey",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onerror", "get_onerror", "set_onerror" },
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
            onerror: EventHandler = undefined,
            _internal: ?*SFrameKeyManagementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onerror = &get_onerror,

        .set_onerror = &set_onerror,

        .call_setEncryptionKey = &call_setEncryptionKey,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SFrameKeyManagementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SFrameKeyManagementImpl.deinit(instance);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SFrameKeyManagementImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SFrameKeyManagementImpl.set_onerror(instance, value);
    }

    pub fn call_setEncryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyID: webidl.Opt(CryptoKeyID)) anyerror!*const anyopaque {
        
        return try SFrameKeyManagementImpl.call_setEncryptionKey(instance, key, keyID);
    }

};
