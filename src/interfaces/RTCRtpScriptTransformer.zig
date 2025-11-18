//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCRtpScriptTransformerImpl = @import("../impls/RTCRtpScriptTransformer.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        RTCRtpScriptTransformerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCRtpScriptTransformerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpScriptTransformerImpl.get_readable(state);
    }

    pub fn get_writable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpScriptTransformerImpl.get_writable(state);
    }

    pub fn get_onkeyframerequest(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpScriptTransformerImpl.get_onkeyframerequest(state);
    }

    pub fn set_onkeyframerequest(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCRtpScriptTransformerImpl.set_onkeyframerequest(state, value);
    }

    pub fn get_options(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpScriptTransformerImpl.get_options(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return RTCRtpScriptTransformerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_generateKeyFrame(instance: *runtime.Instance, rid: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpScriptTransformerImpl.call_generateKeyFrame(state, rid);
    }

    pub fn call_sendKeyFrameRequest(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCRtpScriptTransformerImpl.call_sendKeyFrameRequest(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpScriptTransformerImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpScriptTransformerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCRtpScriptTransformerImpl.call_removeEventListener(state, type_, callback, options);
    }

};
