//! Generated from: FileAPI.idl
//! Generated at: 2025-11-25T13:07:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileReaderImpl = @import("impls").FileReader;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Blob = @import("interfaces").Blob;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const Event = @import("interfaces").Event;
const EventListener = @import("interfaces").EventListener;
const DOMException = @import("interfaces").DOMException;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const FileReader = struct {
    pub const Meta = struct {
        pub const name = "FileReader";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
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
            .{ "readyState", "get_readyState", null },
            .{ "result", "get_result", null },
            .{ "error", "get_error", null },
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onloadend", "get_onloadend", "set_onloadend" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "readAsArrayBuffer", "call_readAsArrayBuffer", 1 },
            .{ "readAsBinaryString", "call_readAsBinaryString", 1 },
            .{ "readAsText", "call_readAsText", 1 },
            .{ "readAsDataURL", "call_readAsDataURL", 1 },
            .{ "abort", "call_abort", 0 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "EMPTY", "get_EMPTY" },
            .{ "LOADING", "get_LOADING" },
            .{ "DONE", "get_DONE" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "readAsArrayBuffer",
            "readAsBinaryString",
            "readAsText",
            "readAsDataURL",
            "abort",
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
            .{ "readyState", "get_readyState", null },
            .{ "result", "get_result", null },
            .{ "error", "get_error", null },
            .{ "onloadstart", "get_onloadstart", "set_onloadstart" },
            .{ "onprogress", "get_onprogress", "set_onprogress" },
            .{ "onload", "get_onload", "set_onload" },
            .{ "onabort", "get_onabort", "set_onabort" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onloadend", "get_onloadend", "set_onloadend" },
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
            readyState: u16 = undefined,
            result: ?union(enum) {
                DOMString: runtime.DOMString,
                ArrayBuffer: runtime.ArrayBuffer,
            } = null,
            @"error": ?*runtime.Instance = null,
            onloadstart: EventHandler = undefined,
            onprogress: EventHandler = undefined,
            onload: EventHandler = undefined,
            onabort: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onloadend: EventHandler = undefined,
            _internal: ?*FileReaderImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short EMPTY = 0;
    pub fn get_EMPTY() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short LOADING = 1;
    pub fn get_LOADING() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short DONE = 2;
    pub fn get_DONE() u16 {
        return 2;
    }

    const delegates = .{

        .get_DONE = &get_DONE,
        .get_EMPTY = &get_EMPTY,
        .get_LOADING = &get_LOADING,
        .get_error = &get_error,
        .get_onabort = &get_onabort,
        .get_onerror = &get_onerror,
        .get_onload = &get_onload,
        .get_onloadend = &get_onloadend,
        .get_onloadstart = &get_onloadstart,
        .get_onprogress = &get_onprogress,
        .get_readyState = &get_readyState,
        .get_result = &get_result,

        .set_onabort = &set_onabort,
        .set_onerror = &set_onerror,
        .set_onload = &set_onload,
        .set_onloadend = &set_onloadend,
        .set_onloadstart = &set_onloadstart,
        .set_onprogress = &set_onprogress,

        .call_abort = &call_abort,
        .call_readAsArrayBuffer = &call_readAsArrayBuffer,
        .call_readAsBinaryString = &call_readAsBinaryString,
        .call_readAsDataURL = &call_readAsDataURL,
        .call_readAsText = &call_readAsText,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileReaderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileReaderImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FileReaderImpl.call_constructor(allocator, ctx);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
        return try FileReaderImpl.get_readyState(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FileReaderImpl.get_result(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try FileReaderImpl.get_error(instance);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try FileReaderImpl.get_onloadstart(instance);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FileReaderImpl.set_onloadstart(instance, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyerror!EventHandler {
        return try FileReaderImpl.get_onprogress(instance);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FileReaderImpl.set_onprogress(instance, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyerror!EventHandler {
        return try FileReaderImpl.get_onload(instance);
    }

    pub fn set_onload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FileReaderImpl.set_onload(instance, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try FileReaderImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FileReaderImpl.set_onabort(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try FileReaderImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FileReaderImpl.set_onerror(instance, value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyerror!EventHandler {
        return try FileReaderImpl.get_onloadend(instance);
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try FileReaderImpl.set_onloadend(instance, value);
    }

    pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!void {
        
        return try FileReaderImpl.call_readAsArrayBuffer(instance, blob);
    }

    pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!void {
        
        return try FileReaderImpl.call_readAsBinaryString(instance, blob);
    }

    pub fn call_readAsDataURL(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!void {
        
        return try FileReaderImpl.call_readAsDataURL(instance, blob);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try FileReaderImpl.call_abort(instance);
    }

    pub fn call_readAsText(instance: *runtime.Instance, blob: *runtime.Instance, encoding: DOMString) anyerror!void {
        
        return try FileReaderImpl.call_readAsText(instance, blob, encoding);
    }

};
