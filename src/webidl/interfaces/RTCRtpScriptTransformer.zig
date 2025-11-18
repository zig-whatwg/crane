//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpScriptTransformerImpl = @import("impls").RTCRtpScriptTransformer;
const EventTarget = @import("interfaces").EventTarget;
const ReadableStream = @import("interfaces").ReadableStream;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const WritableStream = @import("interfaces").WritableStream;
const EventHandler = @import("typedefs").EventHandler;

pub const RTCRtpScriptTransformer = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpScriptTransformer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            readable: ReadableStream = undefined,
            writable: WritableStream = undefined,
            onkeyframerequest: EventHandler = undefined,
            options: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCRtpScriptTransformer, .{
        .deinit_fn = &deinit_wrapper,

        .get_onkeyframerequest = &get_onkeyframerequest,
        .get_options = &get_options,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .set_onkeyframerequest = &set_onkeyframerequest,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_generateKeyFrame = &call_generateKeyFrame,
        .call_removeEventListener = &call_removeEventListener,
        .call_sendKeyFrameRequest = &call_sendKeyFrameRequest,
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
        RTCRtpScriptTransformerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCRtpScriptTransformerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!ReadableStream {
        return try RTCRtpScriptTransformerImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!WritableStream {
        return try RTCRtpScriptTransformerImpl.get_writable(instance);
    }

    pub fn get_onkeyframerequest(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCRtpScriptTransformerImpl.get_onkeyframerequest(instance);
    }

    pub fn set_onkeyframerequest(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCRtpScriptTransformerImpl.set_onkeyframerequest(instance, value);
    }

    pub fn get_options(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpScriptTransformerImpl.get_options(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RTCRtpScriptTransformerImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_generateKeyFrame(instance: *runtime.Instance, rid: DOMString) anyerror!anyopaque {
        
        return try RTCRtpScriptTransformerImpl.call_generateKeyFrame(instance, rid);
    }

    pub fn call_sendKeyFrameRequest(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCRtpScriptTransformerImpl.call_sendKeyFrameRequest(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RTCRtpScriptTransformerImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCRtpScriptTransformerImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCRtpScriptTransformerImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
