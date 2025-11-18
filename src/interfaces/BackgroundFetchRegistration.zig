//! Generated from: background-fetch.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchRegistrationImpl = @import("../impls/BackgroundFetchRegistration.zig");
const EventTarget = @import("EventTarget.zig");

pub const BackgroundFetchRegistration = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchRegistration";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            id: runtime.DOMString = undefined,
            uploadTotal: u64 = undefined,
            uploaded: u64 = undefined,
            downloadTotal: u64 = undefined,
            downloaded: u64 = undefined,
            result: BackgroundFetchResult = undefined,
            failureReason: BackgroundFetchFailureReason = undefined,
            recordsAvailable: bool = undefined,
            onprogress: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BackgroundFetchRegistration, .{
        .deinit_fn = &deinit_wrapper,

        .get_downloadTotal = &get_downloadTotal,
        .get_downloaded = &get_downloaded,
        .get_failureReason = &get_failureReason,
        .get_id = &get_id,
        .get_onprogress = &get_onprogress,
        .get_recordsAvailable = &get_recordsAvailable,
        .get_result = &get_result,
        .get_uploadTotal = &get_uploadTotal,
        .get_uploaded = &get_uploaded,

        .set_onprogress = &set_onprogress,

        .call_abort = &call_abort,
        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_match = &call_match,
        .call_matchAll = &call_matchAll,
        .call_removeEventListener = &call_removeEventListener,
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
        BackgroundFetchRegistrationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BackgroundFetchRegistrationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.get_id(state);
    }

    pub fn get_uploadTotal(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.get_uploadTotal(state);
    }

    pub fn get_uploaded(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.get_uploaded(state);
    }

    pub fn get_downloadTotal(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.get_downloadTotal(state);
    }

    pub fn get_downloaded(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.get_downloaded(state);
    }

    pub fn get_result(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.get_result(state);
    }

    pub fn get_failureReason(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.get_failureReason(state);
    }

    pub fn get_recordsAvailable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.get_recordsAvailable(state);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.get_onprogress(state);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BackgroundFetchRegistrationImpl.set_onprogress(state, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BackgroundFetchRegistrationImpl.call_when(state, type_, options);
    }

    pub fn call_abort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BackgroundFetchRegistrationImpl.call_abort(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return BackgroundFetchRegistrationImpl.call_dispatchEvent(state, event);
    }

    pub fn call_match(instance: *runtime.Instance, request: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BackgroundFetchRegistrationImpl.call_match(state, request, options);
    }

    pub fn call_matchAll(instance: *runtime.Instance, request: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BackgroundFetchRegistrationImpl.call_matchAll(state, request, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BackgroundFetchRegistrationImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BackgroundFetchRegistrationImpl.call_removeEventListener(state, type_, callback, options);
    }

};
