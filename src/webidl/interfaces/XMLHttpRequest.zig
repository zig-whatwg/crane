//! Generated from: xhr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XMLHttpRequestImpl = @import("impls").XMLHttpRequest;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XMLHttpRequestEventTarget = @import("interfaces").XMLHttpRequestEventTarget;
const Document = @import("interfaces").Document;
const XMLHttpRequestResponseType = @import("enums").XMLHttpRequestResponseType;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ByteString = @import("typedefs").ByteString;
const XMLHttpRequestBodyInit = @import("typedefs").XMLHttpRequestBodyInit;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const XMLHttpRequestUpload = @import("interfaces").XMLHttpRequestUpload;
const USVString = @import("typedefs").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const AttributionReportingRequestOptions = @import("dictionaries").AttributionReportingRequestOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const PrivateToken = @import("dictionaries").PrivateToken;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const XMLHttpRequest = struct {
    pub const Meta = struct {
        pub const name = "XMLHttpRequest";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = XMLHttpRequestEventTarget.State;
        pub const ParentInterface = XMLHttpRequestEventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onreadystatechange", "get_onreadystatechange", "set_onreadystatechange" },
            .{ "readyState", "get_readyState", null },
            .{ "timeout", "get_timeout", "set_timeout" },
            .{ "withCredentials", "get_withCredentials", "set_withCredentials" },
            .{ "upload", "get_upload", null },
            .{ "responseURL", "get_responseURL", null },
            .{ "status", "get_status", null },
            .{ "statusText", "get_statusText", null },
            .{ "responseType", "get_responseType", "set_responseType" },
            .{ "response", "get_response", null },
            .{ "responseText", "get_responseText", null },
            .{ "responseXML", "get_responseXML", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "open", "call_open", 2 },
            .{ "setRequestHeader", "call_setRequestHeader", 2 },
            .{ "send", "call_send", 0 },
            .{ "abort", "call_abort", 0 },
            .{ "getResponseHeader", "call_getResponseHeader", 1 },
            .{ "getAllResponseHeaders", "call_getAllResponseHeaders", 0 },
            .{ "overrideMimeType", "call_overrideMimeType", 1 },
            .{ "setAttributionReporting", "call_setAttributionReporting", 1 },
            .{ "setPrivateToken", "call_setPrivateToken", 1 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "UNSENT", "get_UNSENT" },
            .{ "OPENED", "get_OPENED" },
            .{ "HEADERS_RECEIVED", "get_HEADERS_RECEIVED" },
            .{ "LOADING", "get_LOADING" },
            .{ "DONE", "get_DONE" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "open",
            "setRequestHeader",
            "send",
            "abort",
            "getResponseHeader",
            "getAllResponseHeaders",
            "overrideMimeType",
            "setAttributionReporting",
            "setPrivateToken",
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
            .{ "onreadystatechange", "get_onreadystatechange", "set_onreadystatechange" },
            .{ "readyState", "get_readyState", null },
            .{ "timeout", "get_timeout", "set_timeout" },
            .{ "withCredentials", "get_withCredentials", "set_withCredentials" },
            .{ "upload", "get_upload", null },
            .{ "responseURL", "get_responseURL", null },
            .{ "status", "get_status", null },
            .{ "statusText", "get_statusText", null },
            .{ "responseType", "get_responseType", "set_responseType" },
            .{ "response", "get_response", null },
            .{ "responseText", "get_responseText", null },
            .{ "responseXML", "get_responseXML", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onreadystatechange: typedefs.EventHandler = undefined,
            readyState: u16 = undefined,
            timeout: u32 = undefined,
            withCredentials: bool = undefined,
            upload: *runtime.Instance = undefined,
            responseURL: runtime.USVString = undefined,
            status: u16 = undefined,
            statusText: runtime.ByteString = undefined,
            responseType: enums.XMLHttpRequestResponseType = undefined,
            response: runtime.JSValue = undefined,
            responseText: runtime.USVString = undefined,
            responseXML: ?*runtime.Instance = null,
            cached_upload: ?*runtime.Instance = null,
            _internal: ?*XMLHttpRequestImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short UNSENT = 0;
    pub fn get_UNSENT() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short OPENED = 1;
    pub fn get_OPENED() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short HEADERS_RECEIVED = 2;
    pub fn get_HEADERS_RECEIVED() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short LOADING = 3;
    pub fn get_LOADING() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short DONE = 4;
    pub fn get_DONE() u16 {
        return 4;
    }

    const delegates = .{

        .get_DONE = &get_DONE,
        .get_HEADERS_RECEIVED = &get_HEADERS_RECEIVED,
        .get_LOADING = &get_LOADING,
        .get_OPENED = &get_OPENED,
        .get_UNSENT = &get_UNSENT,
        .get_onreadystatechange = &get_onreadystatechange,
        .get_readyState = &get_readyState,
        .get_response = &get_response,
        .get_responseText = &get_responseText,
        .get_responseType = &get_responseType,
        .get_responseURL = &get_responseURL,
        .get_responseXML = &get_responseXML,
        .get_status = &get_status,
        .get_statusText = &get_statusText,
        .get_timeout = &get_timeout,
        .get_upload = &get_upload,
        .get_withCredentials = &get_withCredentials,

        .set_onreadystatechange = &set_onreadystatechange,
        .set_responseType = &set_responseType,
        .set_timeout = &set_timeout,
        .set_withCredentials = &set_withCredentials,

        .call_abort = &call_abort,
        .call_getAllResponseHeaders = &call_getAllResponseHeaders,
        .call_getResponseHeader = &call_getResponseHeader,
        .call_open = &call_open,
        .call_overrideMimeType = &call_overrideMimeType,
        .call_send = &call_send,
        .call_setAttributionReporting = &call_setAttributionReporting,
        .call_setPrivateToken = &call_setPrivateToken,
        .call_setRequestHeader = &call_setRequestHeader,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XMLHttpRequestImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XMLHttpRequestImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XMLHttpRequestImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XMLHttpRequestImpl.call_constructor(ctx);
    }

    pub fn get_onreadystatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestImpl.get_onreadystatechange(instance);
    }

    pub fn set_onreadystatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestImpl.set_onreadystatechange(instance, value);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
        return try XMLHttpRequestImpl.get_readyState(instance);
    }

    pub fn get_timeout(instance: *runtime.Instance) anyerror!u32 {
        return try XMLHttpRequestImpl.get_timeout(instance);
    }

    pub fn set_timeout(instance: *runtime.Instance, value: u32) anyerror!void {
        try XMLHttpRequestImpl.set_timeout(instance, value);
    }

    pub fn get_withCredentials(instance: *runtime.Instance) anyerror!bool {
        return try XMLHttpRequestImpl.get_withCredentials(instance);
    }

    pub fn set_withCredentials(instance: *runtime.Instance, value: bool) anyerror!void {
        try XMLHttpRequestImpl.set_withCredentials(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_upload(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_upload) |cached| {
            return cached;
        }
        const value = try XMLHttpRequestImpl.get_upload(instance);
        state.own.cached_upload = value;
        return value;
    }

    pub fn get_responseURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try XMLHttpRequestImpl.get_responseURL(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!u16 {
        return try XMLHttpRequestImpl.get_status(instance);
    }

    pub fn get_statusText(instance: *runtime.Instance) anyerror!runtime.ByteString {
        return try XMLHttpRequestImpl.get_statusText(instance);
    }

    pub fn get_responseType(instance: *runtime.Instance) anyerror!XMLHttpRequestResponseType {
        return try XMLHttpRequestImpl.get_responseType(instance);
    }

    pub fn set_responseType(instance: *runtime.Instance, value: XMLHttpRequestResponseType) anyerror!void {
        try XMLHttpRequestImpl.set_responseType(instance, value);
    }

    pub fn get_response(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try XMLHttpRequestImpl.get_response(instance);
    }

    pub fn get_responseText(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try XMLHttpRequestImpl.get_responseText(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_responseXML(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try XMLHttpRequestImpl.get_responseXML(instance);
    }

    pub fn call_setRequestHeader(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
        
        return try XMLHttpRequestImpl.call_setRequestHeader(instance, name, value);
    }

    pub fn call_send(instance: *runtime.Instance, body: webidl.Opt(?runtime.JSValue)) anyerror!void {
        
        return try XMLHttpRequestImpl.call_send(instance, body);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try XMLHttpRequestImpl.call_abort(instance);
    }

    pub fn call_getResponseHeader(instance: *runtime.Instance, name: runtime.ByteString) anyerror!?runtime.ByteString {
        
        return try XMLHttpRequestImpl.call_getResponseHeader(instance, name);
    }

    pub fn call_setPrivateToken(instance: *runtime.Instance, privateToken: PrivateToken) anyerror!void {
        
        return try XMLHttpRequestImpl.call_setPrivateToken(instance, privateToken);
    }

    pub fn call_open(instance: *runtime.Instance, method: runtime.ByteString, url: runtime.USVString) anyerror!void {
        
        return try XMLHttpRequestImpl.call_open(instance, method, url);
    }

    pub fn call_overrideMimeType(instance: *runtime.Instance, mime: DOMString) anyerror!void {
        
        return try XMLHttpRequestImpl.call_overrideMimeType(instance, mime);
    }

    pub fn call_getAllResponseHeaders(instance: *runtime.Instance) anyerror!runtime.ByteString {
        return try XMLHttpRequestImpl.call_getAllResponseHeaders(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_setAttributionReporting(instance: *runtime.Instance, options: AttributionReportingRequestOptions) anyerror!void {
        
        return try XMLHttpRequestImpl.call_setAttributionReporting(instance, options);
    }

};
