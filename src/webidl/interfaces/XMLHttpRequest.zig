//! Generated from: xhr.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XMLHttpRequestImpl = @import("impls").XMLHttpRequest;
const XMLHttpRequestEventTarget = @import("interfaces").XMLHttpRequestEventTarget;
const Document = @import("interfaces").Document;
const XMLHttpRequestResponseType = @import("enums").XMLHttpRequestResponseType;
const AttributionReportingRequestOptions = @import("dictionaries").AttributionReportingRequestOptions;
const ByteString = @import("interfaces").ByteString;
const XMLHttpRequestUpload = @import("interfaces").XMLHttpRequestUpload;
const (Document or XMLHttpRequestBodyInit) = @import("interfaces").(Document or XMLHttpRequestBodyInit);
const PrivateToken = @import("dictionaries").PrivateToken;
const USVString = @import("interfaces").USVString;
const EventHandler = @import("typedefs").EventHandler;

pub const XMLHttpRequest = struct {
    pub const Meta = struct {
        pub const name = "XMLHttpRequest";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XMLHttpRequestEventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onreadystatechange: EventHandler = undefined,
            readyState: u16 = undefined,
            timeout: u32 = undefined,
            withCredentials: bool = undefined,
            upload: XMLHttpRequestUpload = undefined,
            responseURL: runtime.USVString = undefined,
            status: u16 = undefined,
            statusText: runtime.ByteString = undefined,
            responseType: XMLHttpRequestResponseType = undefined,
            response: anyopaque = undefined,
            responseText: runtime.USVString = undefined,
            responseXML: ?Document = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
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

    pub const vtable = runtime.buildVTable(XMLHttpRequest, .{
        .deinit_fn = &deinit_wrapper,

        .get_DONE = &get_DONE,
        .get_HEADERS_RECEIVED = &get_HEADERS_RECEIVED,
        .get_LOADING = &get_LOADING,
        .get_OPENED = &get_OPENED,
        .get_UNSENT = &get_UNSENT,
        .get_onabort = &get_onabort,
        .get_onerror = &get_onerror,
        .get_onload = &get_onload,
        .get_onloadend = &get_onloadend,
        .get_onloadstart = &get_onloadstart,
        .get_onprogress = &get_onprogress,
        .get_onreadystatechange = &get_onreadystatechange,
        .get_ontimeout = &get_ontimeout,
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

        .set_onabort = &set_onabort,
        .set_onerror = &set_onerror,
        .set_onload = &set_onload,
        .set_onloadend = &set_onloadend,
        .set_onloadstart = &set_onloadstart,
        .set_onprogress = &set_onprogress,
        .set_onreadystatechange = &set_onreadystatechange,
        .set_ontimeout = &set_ontimeout,
        .set_responseType = &set_responseType,
        .set_timeout = &set_timeout,
        .set_withCredentials = &set_withCredentials,

        .call_abort = &call_abort,
        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getAllResponseHeaders = &call_getAllResponseHeaders,
        .call_getResponseHeader = &call_getResponseHeader,
        .call_open = &call_open,
        .call_overrideMimeType = &call_overrideMimeType,
        .call_removeEventListener = &call_removeEventListener,
        .call_send = &call_send,
        .call_setAttributionReporting = &call_setAttributionReporting,
        .call_setPrivateToken = &call_setPrivateToken,
        .call_setRequestHeader = &call_setRequestHeader,
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
        XMLHttpRequestImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XMLHttpRequestImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try XMLHttpRequestImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestImpl.get_onloadstart(instance);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestImpl.set_onloadstart(instance, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestImpl.get_onprogress(instance);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestImpl.set_onprogress(instance, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestImpl.set_onabort(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestImpl.set_onerror(instance, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestImpl.get_onload(instance);
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestImpl.set_onload(instance, value);
    }

    pub fn get_ontimeout(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestImpl.get_ontimeout(instance);
    }

    pub fn set_ontimeout(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestImpl.set_ontimeout(instance, value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyerror!EventHandler {
        return try XMLHttpRequestImpl.get_onloadend(instance);
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XMLHttpRequestImpl.set_onloadend(instance, value);
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
    pub fn get_upload(instance: *runtime.Instance) anyerror!XMLHttpRequestUpload {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_upload) |cached| {
            return cached;
        }
        const value = try XMLHttpRequestImpl.get_upload(instance);
        state.cached_upload = value;
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

    pub fn get_response(instance: *runtime.Instance) anyerror!anyopaque {
        return try XMLHttpRequestImpl.get_response(instance);
    }

    pub fn get_responseText(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try XMLHttpRequestImpl.get_responseText(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_responseXML(instance: *runtime.Instance) anyerror!anyopaque {
        return try XMLHttpRequestImpl.get_responseXML(instance);
    }

    pub fn call_setPrivateToken(instance: *runtime.Instance, privateToken: PrivateToken) anyerror!void {
        
        return try XMLHttpRequestImpl.call_setPrivateToken(instance, privateToken);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XMLHttpRequestImpl.call_when(instance, type_, options);
    }

    /// Arguments for open (WebIDL overloading)
    pub const OpenArgs = union(enum) {
        /// open(method, url)
        ByteString_USVString: struct {
            method: runtime.ByteString,
            url: runtime.USVString,
        },
        /// open(method, url, async, username, password)
        ByteString_USVString_bool_USVString?_USVString?: struct {
            method: runtime.ByteString,
            url: runtime.USVString,
            async_: bool,
            username: anyopaque,
            password: anyopaque,
        },
    };

    pub fn call_open(instance: *runtime.Instance, args: OpenArgs) anyerror!void {
        switch (args) {
            .ByteString_USVString => |a| return try XMLHttpRequestImpl.ByteString_USVString(instance, a.method, a.url),
            .ByteString_USVString_bool_USVString?_USVString? => |a| return try XMLHttpRequestImpl.ByteString_USVString_bool_USVString?_USVString?(instance, a.method, a.url, a.async_, a.username, a.password),
        }
    }

    pub fn call_send(instance: *runtime.Instance, body: anyopaque) anyerror!void {
        
        return try XMLHttpRequestImpl.call_send(instance, body);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try XMLHttpRequestImpl.call_abort(instance);
    }

    pub fn call_getResponseHeader(instance: *runtime.Instance, name: runtime.ByteString) anyerror!anyopaque {
        
        return try XMLHttpRequestImpl.call_getResponseHeader(instance, name);
    }

    pub fn call_overrideMimeType(instance: *runtime.Instance, mime: DOMString) anyerror!void {
        
        return try XMLHttpRequestImpl.call_overrideMimeType(instance, mime);
    }

    pub fn call_getAllResponseHeaders(instance: *runtime.Instance) anyerror!runtime.ByteString {
        return try XMLHttpRequestImpl.call_getAllResponseHeaders(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XMLHttpRequestImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XMLHttpRequestImpl.call_removeEventListener(instance, type_, callback, options);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_setAttributionReporting(instance: *runtime.Instance, options: AttributionReportingRequestOptions) anyerror!void {
        
        return try XMLHttpRequestImpl.call_setAttributionReporting(instance, options);
    }

    pub fn call_setRequestHeader(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
        
        return try XMLHttpRequestImpl.call_setRequestHeader(instance, name, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XMLHttpRequestImpl.call_dispatchEvent(instance, event);
    }

};
