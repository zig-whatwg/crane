//! Generated from: xhr.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XMLHttpRequestImpl = @import("../impls/XMLHttpRequest.zig");
const XMLHttpRequestEventTarget = @import("XMLHttpRequestEventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        XMLHttpRequestImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try XMLHttpRequestImpl.constructor(state);
        
        return instance;
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_onloadstart(state);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_onloadstart(state, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_onprogress(state);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_onprogress(state, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_onabort(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_onerror(state, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_onload(state);
    }

    pub fn set_onload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_onload(state, value);
    }

    pub fn get_ontimeout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_ontimeout(state);
    }

    pub fn set_ontimeout(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_ontimeout(state, value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_onloadend(state);
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_onloadend(state, value);
    }

    pub fn get_onreadystatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_onreadystatechange(state);
    }

    pub fn set_onreadystatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_onreadystatechange(state, value);
    }

    pub fn get_readyState(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_readyState(state);
    }

    pub fn get_timeout(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_timeout(state);
    }

    pub fn set_timeout(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_timeout(state, value);
    }

    pub fn get_withCredentials(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_withCredentials(state);
    }

    pub fn set_withCredentials(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_withCredentials(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_upload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_upload) |cached| {
            return cached;
        }
        const value = XMLHttpRequestImpl.get_upload(state);
        state.cached_upload = value;
        return value;
    }

    pub fn get_responseURL(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_responseURL(state);
    }

    pub fn get_status(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_status(state);
    }

    pub fn get_statusText(instance: *runtime.Instance) runtime.ByteString {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_statusText(state);
    }

    pub fn get_responseType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_responseType(state);
    }

    pub fn set_responseType(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XMLHttpRequestImpl.set_responseType(state, value);
    }

    pub fn get_response(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_response(state);
    }

    pub fn get_responseText(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_responseText(state);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_responseXML(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.get_responseXML(state);
    }

    pub fn call_setPrivateToken(instance: *runtime.Instance, privateToken: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_setPrivateToken(state, privateToken);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_when(state, type_, options);
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

    pub fn call_open(instance: *runtime.Instance, args: OpenArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .ByteString_USVString => |a| return XMLHttpRequestImpl.ByteString_USVString(state, a.method, a.url),
            .ByteString_USVString_bool_USVString?_USVString? => |a| return XMLHttpRequestImpl.ByteString_USVString_bool_USVString?_USVString?(state, a.method, a.url, a.async_, a.username, a.password),
        }
    }

    pub fn call_send(instance: *runtime.Instance, body: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_send(state, body);
    }

    pub fn call_abort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.call_abort(state);
    }

    pub fn call_getResponseHeader(instance: *runtime.Instance, name: runtime.ByteString) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_getResponseHeader(state, name);
    }

    pub fn call_overrideMimeType(instance: *runtime.Instance, mime: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_overrideMimeType(state, mime);
    }

    pub fn call_getAllResponseHeaders(instance: *runtime.Instance) runtime.ByteString {
        const state = instance.getState(State);
        return XMLHttpRequestImpl.call_getAllResponseHeaders(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_removeEventListener(state, type_, callback, options);
    }

    /// Extended attributes: [SecureContext]
    pub fn call_setAttributionReporting(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_setAttributionReporting(state, options);
    }

    pub fn call_setRequestHeader(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyopaque {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_setRequestHeader(state, name, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XMLHttpRequestImpl.call_dispatchEvent(state, event);
    }

};
