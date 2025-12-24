//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameDecrypterManagerImpl = @import("impls").SFrameDecrypterManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const EventHandler = @import("typedefs").EventHandler;
const CryptoKey = @import("interfaces").CryptoKey;

pub const SFrameDecrypterManager = struct {
    pub const Meta = struct {
        pub const name = "SFrameDecrypterManager";
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
            onerror: typedefs.EventHandler = undefined,
            _internal: ?*SFrameDecrypterManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onerror = &get_onerror,

        .set_onerror = &set_onerror,

        .call_addDecryptionKey = &call_addDecryptionKey,
        .call_removeDecryptionKey = &call_removeDecryptionKey,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SFrameDecrypterManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SFrameDecrypterManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SFrameDecrypterManagerImpl.deinit(instance);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SFrameDecrypterManagerImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SFrameDecrypterManagerImpl.set_onerror(instance, value);
    }

    pub fn call_addDecryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
        
        return try SFrameDecrypterManagerImpl.call_addDecryptionKey(instance, key, keyId);
    }

    pub fn call_removeDecryptionKey(instance: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
        
        return try SFrameDecrypterManagerImpl.call_removeDecryptionKey(instance, keyId);
    }

};
