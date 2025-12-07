//! Generated from: background-fetch.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BackgroundFetchRegistrationImpl = @import("impls").BackgroundFetchRegistration;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CacheQueryOptions = @import("dictionaries").CacheQueryOptions;
const RequestInfo = @import("typedefs").RequestInfo;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BackgroundFetchFailureReason = @import("enums").BackgroundFetchFailureReason;
const BackgroundFetchResult = @import("enums").BackgroundFetchResult;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const BackgroundFetchRecord = @import("interfaces").BackgroundFetchRecord;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const BackgroundFetchRegistration = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchRegistration";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "uploadTotal", "get_uploadTotal", null },
            .{ "uploaded", "get_uploaded", null },
            .{ "downloadTotal", "get_downloadTotal", null },
            .{ "downloaded", "get_downloaded", null },
            .{ "result", "get_result", null },
            .{ "failureReason", "get_failureReason", null },
            .{ "recordsAvailable", "get_recordsAvailable", null },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "abort", "call_abort", 0 },
            .{ "match", "call_match", 1 },
            .{ "matchAll", "call_matchAll", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "abort",
            "match",
            "matchAll",
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
            .{ "id", "get_id", null },
            .{ "uploadTotal", "get_uploadTotal", null },
            .{ "uploaded", "get_uploaded", null },
            .{ "downloadTotal", "get_downloadTotal", null },
            .{ "downloaded", "get_downloaded", null },
            .{ "result", "get_result", null },
            .{ "failureReason", "get_failureReason", null },
            .{ "recordsAvailable", "get_recordsAvailable", null },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
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
            id: runtime.DOMString = undefined,
            uploadTotal: u64 = undefined,
            uploaded: u64 = undefined,
            downloadTotal: u64 = undefined,
            downloaded: u64 = undefined,
            result: BackgroundFetchResult = undefined,
            failureReason: BackgroundFetchFailureReason = undefined,
            recordsAvailable: bool = undefined,
            onprogress: EventHandler = undefined,
            _internal: ?*BackgroundFetchRegistrationImpl.InternalState = null,
        },
    );

    const delegates = .{

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
        .call_match = &call_match,
        .call_matchAll = &call_matchAll,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BackgroundFetchRegistrationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchRegistrationImpl.deinit(instance);
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

    pub fn call_matchAll(instance: *runtime.Instance, request: webidl.Opt(RequestInfo), options: webidl.Opt(CacheQueryOptions)) anyerror!*const anyopaque {
        
        return try BackgroundFetchRegistrationImpl.call_matchAll(instance, request, options);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BackgroundFetchRegistrationImpl.call_abort(instance);
    }

    pub fn call_match(instance: *runtime.Instance, request: RequestInfo, options: webidl.Opt(CacheQueryOptions)) anyerror!*const anyopaque {
        
        return try BackgroundFetchRegistrationImpl.call_match(instance, request, options);
    }

};
