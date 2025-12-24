//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SFrameReceiverTransformImpl = @import("impls").SFrameReceiverTransform;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const SFrameDecrypterManager = @import("mixins").SFrameDecrypterManager;
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

pub const SFrameReceiverTransform = struct {
    pub const Meta = struct {
        pub const name = "SFrameReceiverTransform";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            SFrameDecrypterManager,
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onerror: typedefs.EventHandler = undefined,
            _internal: ?*SFrameReceiverTransformImpl.InternalState = null,
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
        return SFrameReceiverTransformImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SFrameReceiverTransformImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SFrameReceiverTransformImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(SFrameTransformOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SFrameReceiverTransformImpl.call_constructor(ctx, options);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SFrameReceiverTransformImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SFrameReceiverTransformImpl.set_onerror(instance, value);
    }

    pub fn call_addDecryptionKey(instance: *runtime.Instance, key: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
        
        return try SFrameReceiverTransformImpl.call_addDecryptionKey(instance, key, keyId);
    }

    pub fn call_removeDecryptionKey(instance: *runtime.Instance, keyId: CryptoKeyID) anyerror!runtime.JSValue {
        
        return try SFrameReceiverTransformImpl.call_removeDecryptionKey(instance, keyId);
    }

};
