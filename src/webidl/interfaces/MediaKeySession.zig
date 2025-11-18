//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeySessionImpl = @import("impls").MediaKeySession;
const EventTarget = @import("interfaces").EventTarget;
const Promise<MediaKeySessionClosedReason> = @import("interfaces").Promise<MediaKeySessionClosedReason>;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const BufferSource = @import("typedefs").BufferSource;
const MediaKeyStatusMap = @import("interfaces").MediaKeyStatusMap;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const EventHandler = @import("typedefs").EventHandler;

pub const MediaKeySession = struct {
    pub const Meta = struct {
        pub const name = "MediaKeySession";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            sessionId: runtime.DOMString = undefined,
            expiration: f64 = undefined,
            closed: Promise<MediaKeySessionClosedReason> = undefined,
            keyStatuses: MediaKeyStatusMap = undefined,
            onkeystatuseschange: EventHandler = undefined,
            onmessage: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaKeySession, .{
        .deinit_fn = &deinit_wrapper,

        .get_closed = &get_closed,
        .get_expiration = &get_expiration,
        .get_keyStatuses = &get_keyStatuses,
        .get_onkeystatuseschange = &get_onkeystatuseschange,
        .get_onmessage = &get_onmessage,
        .get_sessionId = &get_sessionId,

        .set_onkeystatuseschange = &set_onkeystatuseschange,
        .set_onmessage = &set_onmessage,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_generateRequest = &call_generateRequest,
        .call_load = &call_load,
        .call_remove = &call_remove,
        .call_removeEventListener = &call_removeEventListener,
        .call_update = &call_update,
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
        MediaKeySessionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeySessionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sessionId(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaKeySessionImpl.get_sessionId(instance);
    }

    pub fn get_expiration(instance: *runtime.Instance) anyerror!f64 {
        return try MediaKeySessionImpl.get_expiration(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaKeySessionImpl.get_closed(instance);
    }

    pub fn get_keyStatuses(instance: *runtime.Instance) anyerror!MediaKeyStatusMap {
        return try MediaKeySessionImpl.get_keyStatuses(instance);
    }

    pub fn get_onkeystatuseschange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaKeySessionImpl.get_onkeystatuseschange(instance);
    }

    pub fn set_onkeystatuseschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaKeySessionImpl.set_onkeystatuseschange(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaKeySessionImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaKeySessionImpl.set_onmessage(instance, value);
    }

    pub fn call_update(instance: *runtime.Instance, response: BufferSource) anyerror!anyopaque {
        
        return try MediaKeySessionImpl.call_update(instance, response);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try MediaKeySessionImpl.call_when(instance, type_, options);
    }

    pub fn call_load(instance: *runtime.Instance, sessionId: DOMString) anyerror!anyopaque {
        
        return try MediaKeySessionImpl.call_load(instance, sessionId);
    }

    pub fn call_generateRequest(instance: *runtime.Instance, initDataType: DOMString, initData: BufferSource) anyerror!anyopaque {
        
        return try MediaKeySessionImpl.call_generateRequest(instance, initDataType, initData);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try MediaKeySessionImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_remove(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaKeySessionImpl.call_remove(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaKeySessionImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaKeySessionImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaKeySessionImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
