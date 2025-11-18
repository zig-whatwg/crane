//! Generated from: presentation-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationConnectionImpl = @import("impls").PresentationConnection;
const EventTarget = @import("interfaces").EventTarget;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const PresentationConnectionState = @import("enums").PresentationConnectionState;
const Blob = @import("interfaces").Blob;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const BinaryType = @import("enums").BinaryType;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        PresentationConnectionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationConnectionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PresentationConnectionImpl.get_id(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PresentationConnectionImpl.get_url(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!PresentationConnectionState {
        return try PresentationConnectionImpl.get_state(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionImpl.set_onconnect(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionImpl.set_onclose(instance, value);
    }

    pub fn get_onterminate(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionImpl.get_onterminate(instance);
    }

    pub fn set_onterminate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionImpl.set_onterminate(instance, value);
    }

    pub fn get_binaryType(instance: *runtime.Instance) anyerror!BinaryType {
        return try PresentationConnectionImpl.get_binaryType(instance);
    }

    pub fn set_binaryType(instance: *runtime.Instance, value: BinaryType) anyerror!void {
        try PresentationConnectionImpl.set_binaryType(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionImpl.set_onmessage(instance, value);
    }

    pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
        return try PresentationConnectionImpl.call_terminate(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try PresentationConnectionImpl.call_when(instance, type_, options);
    }

    /// Arguments for send (WebIDL overloading)
    pub const SendArgs = union(enum) {
        /// send(message)
        string: DOMString,
        /// send(data)
        Blob: Blob,
        /// send(data)
        ArrayBuffer: anyopaque,
        /// send(data)
        ArrayBufferView: ArrayBufferView,
    };

    pub fn call_send(instance: *runtime.Instance, args: SendArgs) anyerror!void {
        switch (args) {
            .string => |arg| return try PresentationConnectionImpl.string(instance, arg),
            .Blob => |arg| return try PresentationConnectionImpl.Blob(instance, arg),
            .ArrayBuffer => |arg| return try PresentationConnectionImpl.ArrayBuffer(instance, arg),
            .ArrayBufferView => |arg| return try PresentationConnectionImpl.ArrayBufferView(instance, arg),
        }
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try PresentationConnectionImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try PresentationConnectionImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PresentationConnectionImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try PresentationConnectionImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
