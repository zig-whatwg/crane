//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeySessionImpl = @import("../impls/MediaKeySession.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        MediaKeySessionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaKeySessionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sessionId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaKeySessionImpl.get_sessionId(state);
    }

    pub fn get_expiration(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return MediaKeySessionImpl.get_expiration(state);
    }

    pub fn get_closed(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaKeySessionImpl.get_closed(state);
    }

    pub fn get_keyStatuses(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaKeySessionImpl.get_keyStatuses(state);
    }

    pub fn get_onkeystatuseschange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaKeySessionImpl.get_onkeystatuseschange(state);
    }

    pub fn set_onkeystatuseschange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaKeySessionImpl.set_onkeystatuseschange(state, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaKeySessionImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaKeySessionImpl.set_onmessage(state, value);
    }

    pub fn call_update(instance: *runtime.Instance, response: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeySessionImpl.call_update(state, response);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeySessionImpl.call_when(state, type_, options);
    }

    pub fn call_load(instance: *runtime.Instance, sessionId: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeySessionImpl.call_load(state, sessionId);
    }

    pub fn call_generateRequest(instance: *runtime.Instance, initDataType: runtime.DOMString, initData: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeySessionImpl.call_generateRequest(state, initDataType, initData);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return MediaKeySessionImpl.call_dispatchEvent(state, event);
    }

    pub fn call_remove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaKeySessionImpl.call_remove(state);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaKeySessionImpl.call_close(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeySessionImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaKeySessionImpl.call_removeEventListener(state, type_, callback, options);
    }

};
