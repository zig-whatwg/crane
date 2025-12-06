//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-12-05T20:30:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameTransformImpl = @import("impls").SFrameTransform;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const SFrameKeyManagement = @import("interfaces").SFrameKeyManagement;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CryptoKey = @import("interfaces").CryptoKey;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const SFrameTransformOptions = @import("dictionaries").SFrameTransformOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const SFrameTransform = struct {
    pub const Meta = struct {
        pub const name = "SFrameTransform";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            SFrameKeyManagement,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

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
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onerror: EventHandler = undefined,
            _internal: ?*SFrameTransformImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onerror = &get_onerror,

        .set_onerror = &set_onerror,

        .call_setEncryptionKey = &call_setEncryptionKey,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SFrameTransformImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SFrameTransformImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: webidl.Opt(SFrameTransformOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SFrameTransformImpl.call_constructor(allocator, ctx, options);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SFrameTransformImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SFrameTransformImpl.set_onerror(instance, value);
    }

    pub fn call_setEncryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyID: webidl.Opt(CryptoKeyID)) anyerror!*const anyopaque {
        return try SFrameTransformImpl.call_setEncryptionKey(instance, key, keyID);
    }
};
