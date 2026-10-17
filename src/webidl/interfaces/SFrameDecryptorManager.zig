//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameDecryptorManagerImpl = @import("impls").SFrameDecryptorManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const EventHandler = @import("typedefs").EventHandler;
const CryptoKey = @import("interfaces").CryptoKey;

pub const SFrameDecryptorManager = struct {
    pub const Meta = struct {
        pub const name = "SFrameDecryptorManager";
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
            .{ "addDecryptionKey", "call_addDecryptionKey", 2 },
            .{ "removeDecryptionKey", "call_removeDecryptionKey", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addDecryptionKey",
            "removeDecryptionKey",
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
            _internal: ?*SFrameDecryptorManagerImpl.InternalState = null,
        },
    );

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SFrameDecryptorManager")) {
            if (comptime @hasDecl(impls.SFrameDecryptorManager, "installHooks")) impls.SFrameDecryptorManager.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SFrameDecryptorManagerImpl, "get_onerror")) return try SFrameDecryptorManagerImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SFrameDecryptorManagerImpl, "set_onerror")) return try SFrameDecryptorManagerImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn call_addDecryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
        return try SFrameDecryptorManagerImpl.call_addDecryptionKey(instance, key, keyId);
    }

    pub fn call_removeDecryptionKey(instance: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
        return try SFrameDecryptorManagerImpl.call_removeDecryptionKey(instance, keyId);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_addDecryptionKey", 0, "CryptoKey" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_addDecryptionKey",
        "call_removeDecryptionKey",
    };
};
