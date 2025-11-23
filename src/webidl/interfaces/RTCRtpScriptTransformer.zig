//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-11-23T01:18:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpScriptTransformerImpl = @import("impls").RTCRtpScriptTransformer;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ReadableStream = @import("interfaces").ReadableStream;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const WritableStream = @import("interfaces").WritableStream;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const RTCRtpScriptTransformer = struct {
    pub const Meta = struct {
        pub const name = "RTCRtpScriptTransformer";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "onkeyframerequest", "get_onkeyframerequest", "set_onkeyframerequest" },
            .{ "options", "get_options", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "generateKeyFrame", "call_generateKeyFrame", 0 },
            .{ "sendKeyFrameRequest", "call_sendKeyFrameRequest", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "generateKeyFrame",
            "sendKeyFrameRequest",
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
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "onkeyframerequest", "get_onkeyframerequest", "set_onkeyframerequest" },
            .{ "options", "get_options", null },
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
            readable: ReadableStream = undefined,
            writable: WritableStream = undefined,
            onkeyframerequest: EventHandler = undefined,
            options: *const anyopaque = undefined,
        },
    );

    const delegates = .{

        .get_onkeyframerequest = &get_onkeyframerequest,
        .get_options = &get_options,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .set_onkeyframerequest = &set_onkeyframerequest,

        .call_generateKeyFrame = &call_generateKeyFrame,
        .call_sendKeyFrameRequest = &call_sendKeyFrameRequest,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCRtpScriptTransformerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCRtpScriptTransformerImpl.deinit(instance);
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

    pub fn get_options(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCRtpScriptTransformerImpl.get_options(instance);
    }

    pub fn call_sendKeyFrameRequest(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCRtpScriptTransformerImpl.call_sendKeyFrameRequest(instance);
    }

    pub fn call_generateKeyFrame(instance: *runtime.Instance, rid: DOMString) anyerror!*const anyopaque {
        
        return try RTCRtpScriptTransformerImpl.call_generateKeyFrame(instance, rid);
    }

};
