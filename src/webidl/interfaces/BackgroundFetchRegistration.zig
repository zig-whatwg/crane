//! Generated from: background-fetch.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BackgroundFetchRegistrationImpl = @import("impls").BackgroundFetchRegistration;
const EventTarget = @import("interfaces").EventTarget;
const BackgroundFetchFailureReason = @import("enums").BackgroundFetchFailureReason;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const BackgroundFetchResult = @import("enums").BackgroundFetchResult;
const Promise<BackgroundFetchRecord> = @import("interfaces").Promise<BackgroundFetchRecord>;
const RequestInfo = @import("typedefs").RequestInfo;
const CacheQueryOptions = @import("dictionaries").CacheQueryOptions;
const Promise<sequence<BackgroundFetchRecord>> = @import("interfaces").Promise<sequence<BackgroundFetchRecord>>;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        BackgroundFetchRegistrationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchRegistrationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try BackgroundFetchRegistrationImpl.get_id(instance);
    }

    pub fn get_uploadTotal(instance: *runtime.Instance) anyerror!u64 {
        return try BackgroundFetchRegistrationImpl.get_uploadTotal(instance);
    }

    pub fn get_uploaded(instance: *runtime.Instance) anyerror!u64 {
        return try BackgroundFetchRegistrationImpl.get_uploaded(instance);
    }

    pub fn get_downloadTotal(instance: *runtime.Instance) anyerror!u64 {
        return try BackgroundFetchRegistrationImpl.get_downloadTotal(instance);
    }

    pub fn get_downloaded(instance: *runtime.Instance) anyerror!u64 {
        return try BackgroundFetchRegistrationImpl.get_downloaded(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!BackgroundFetchResult {
        return try BackgroundFetchRegistrationImpl.get_result(instance);
    }

    pub fn get_failureReason(instance: *runtime.Instance) anyerror!BackgroundFetchFailureReason {
        return try BackgroundFetchRegistrationImpl.get_failureReason(instance);
    }

    pub fn get_recordsAvailable(instance: *runtime.Instance) anyerror!bool {
        return try BackgroundFetchRegistrationImpl.get_recordsAvailable(instance);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        return try BackgroundFetchRegistrationImpl.get_onprogress(instance);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BackgroundFetchRegistrationImpl.set_onprogress(instance, value);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try BackgroundFetchRegistrationImpl.call_when(instance, type_, options);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!anyopaque {
        return try BackgroundFetchRegistrationImpl.call_abort(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try BackgroundFetchRegistrationImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_match(instance: *runtime.Instance, request: RequestInfo, options: CacheQueryOptions) anyerror!anyopaque {
        
        return try BackgroundFetchRegistrationImpl.call_match(instance, request, options);
    }

    pub fn call_matchAll(instance: *runtime.Instance, request: RequestInfo, options: CacheQueryOptions) anyerror!anyopaque {
        
        return try BackgroundFetchRegistrationImpl.call_matchAll(instance, request, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BackgroundFetchRegistrationImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BackgroundFetchRegistrationImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
