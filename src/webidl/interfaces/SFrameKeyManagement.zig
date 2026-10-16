//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameKeyManagementImpl = @import("impls").SFrameKeyManagement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const EventHandler = @import("typedefs").EventHandler;
const CryptoKey = @import("interfaces").CryptoKey;

pub const SFrameKeyManagement = struct {
    pub const Meta = struct {
        pub const name = "SFrameKeyManagement";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onerror: typedefs.EventHandler = undefined,
            _internal: ?*SFrameKeyManagementImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SFrameKeyManagement")) {
            if (comptime @hasDecl(impls.SFrameKeyManagement, "installHooks")) impls.SFrameKeyManagement.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SFrameKeyManagementImpl, "get_onerror")) return try SFrameKeyManagementImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SFrameKeyManagementImpl, "set_onerror")) return try SFrameKeyManagementImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn call_setEncryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyID: webidl.Opt(CryptoKeyID)) anyerror!runtime.JSValue {
        return try SFrameKeyManagementImpl.call_setEncryptionKey(instance, key, keyID);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_setEncryptionKey",
    };
};
