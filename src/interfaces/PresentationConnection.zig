//! Generated from: presentation-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationConnectionImpl = @import("../impls/PresentationConnection.zig");
const EventTarget = @import("EventTarget.zig");

pub const PresentationConnection = struct {
    pub const Meta = struct {
        pub const name = "PresentationConnection";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            id: runtime.USVString = undefined,
            url: runtime.USVString = undefined,
            state: PresentationConnectionState = undefined,
            onconnect: EventHandler = undefined,
            onclose: EventHandler = undefined,
            onterminate: EventHandler = undefined,
            binaryType: BinaryType = undefined,
            onmessage: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PresentationConnection, .{
        .deinit_fn = &deinit_wrapper,

        .get_binaryType = &get_binaryType,
        .get_id = &get_id,
        .get_onclose = &get_onclose,
        .get_onconnect = &get_onconnect,
        .get_onmessage = &get_onmessage,
        .get_onterminate = &get_onterminate,
        .get_state = &get_state,
        .get_url = &get_url,

        .set_binaryType = &set_binaryType,
        .set_onclose = &set_onclose,
        .set_onconnect = &set_onconnect,
        .set_onmessage = &set_onmessage,
        .set_onterminate = &set_onterminate,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_send = &call_send,
        .call_send = &call_send,
        .call_send = &call_send,
        .call_send = &call_send,
        .call_terminate = &call_terminate,
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
        PresentationConnectionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PresentationConnectionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PresentationConnectionImpl.get_id(state);
    }

    pub fn get_url(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return PresentationConnectionImpl.get_url(state);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionImpl.get_state(state);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionImpl.get_onconnect(state);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PresentationConnectionImpl.set_onconnect(state, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionImpl.get_onclose(state);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PresentationConnectionImpl.set_onclose(state, value);
    }

    pub fn get_onterminate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionImpl.get_onterminate(state);
    }

    pub fn set_onterminate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PresentationConnectionImpl.set_onterminate(state, value);
    }

    pub fn get_binaryType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionImpl.get_binaryType(state);
    }

    pub fn set_binaryType(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PresentationConnectionImpl.set_binaryType(state, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PresentationConnectionImpl.set_onmessage(state, value);
    }

    pub fn call_terminate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionImpl.call_terminate(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PresentationConnectionImpl.call_when(state, type_, options);
    }

    /// Arguments for send (WebIDL overloading)
    pub const SendArgs = union(enum) {
        /// send(message)
        string: runtime.DOMString,
        /// send(data)
        Blob: anyopaque,
        /// send(data)
        ArrayBuffer: anyopaque,
        /// send(data)
        ArrayBufferView: anyopaque,
    };

    pub fn call_send(instance: *runtime.Instance, args: SendArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .string => |arg| return PresentationConnectionImpl.string(state, arg),
            .Blob => |arg| return PresentationConnectionImpl.Blob(state, arg),
            .ArrayBuffer => |arg| return PresentationConnectionImpl.ArrayBuffer(state, arg),
            .ArrayBufferView => |arg| return PresentationConnectionImpl.ArrayBufferView(state, arg),
        }
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return PresentationConnectionImpl.call_dispatchEvent(state, event);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PresentationConnectionImpl.call_close(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PresentationConnectionImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PresentationConnectionImpl.call_removeEventListener(state, type_, callback, options);
    }

};
