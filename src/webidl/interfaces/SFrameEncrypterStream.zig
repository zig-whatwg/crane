//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SFrameEncrypterStreamImpl = @import("impls").SFrameEncrypterStream;
const EventTarget = @import("interfaces").EventTarget;
const GenericTransformStream = @import("interfaces").GenericTransformStream;
const SFrameKeyManagement = @import("interfaces").SFrameKeyManagement;
const ReadableStream = @import("interfaces").ReadableStream;
const SFrameTransformOptions = @import("dictionaries").SFrameTransformOptions;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const WritableStream = @import("interfaces").WritableStream;
const CryptoKeyID = @import("typedefs").CryptoKeyID;
const EventHandler = @import("typedefs").EventHandler;
const CryptoKey = @import("interfaces").CryptoKey;

pub const SFrameEncrypterStream = struct {
    pub const Meta = struct {
        pub const name = "SFrameEncrypterStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
            GenericTransformStream,
            SFrameKeyManagement,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            readable: ReadableStream = undefined,
            writable: WritableStream = undefined,
            onerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SFrameEncrypterStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_onerror = &get_onerror,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .set_onerror = &set_onerror,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_setEncryptionKey = &call_setEncryptionKey,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SFrameEncrypterStreamImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SFrameEncrypterStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: SFrameTransformOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SFrameEncrypterStreamImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!ReadableStream {
        return try SFrameEncrypterStreamImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!WritableStream {
        return try SFrameEncrypterStreamImpl.get_writable(instance);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SFrameEncrypterStreamImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SFrameEncrypterStreamImpl.set_onerror(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try SFrameEncrypterStreamImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_setEncryptionKey(instance: *runtime.Instance, key: CryptoKey, keyID: CryptoKeyID) anyerror!anyopaque {
        
        return try SFrameEncrypterStreamImpl.call_setEncryptionKey(instance, key, keyID);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try SFrameEncrypterStreamImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SFrameEncrypterStreamImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SFrameEncrypterStreamImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
