//! Generated from: FileAPI.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileReaderImpl = @import("impls").FileReader;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
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
            readyState: u16 = undefined,
            result: ?union(enum) {
                DOMString: runtime.DOMString,
                ArrayBuffer: ArrayBuffer,
            } = null,
            @"error": ?DOMException = null,
            onloadstart: EventHandler = undefined,
            onprogress: EventHandler = undefined,
            onload: EventHandler = undefined,
            onabort: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onloadend: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
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

    pub const vtable = runtime.buildVTable(FileReader, .{
        .deinit_fn = &deinit_wrapper,

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
        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_readAsArrayBuffer = &call_readAsArrayBuffer,
        .call_readAsBinaryString = &call_readAsBinaryString,
        .call_readAsDataURL = &call_readAsDataURL,
        .call_readAsText = &call_readAsText,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return FileReaderImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileReaderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try FileReaderImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
        return try FileReaderImpl.get_readyState(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!anyopaque {
        return try FileReaderImpl.get_result(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!DOMException {
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

    pub fn call_readAsDataURL(instance: *runtime.Instance, blob: Blob) anyerror!void {
        
        return try FileReaderImpl.call_readAsDataURL(instance, blob);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try FileReaderImpl.call_when(instance, @"type", options);
    }

    pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: Blob) anyerror!void {
        
        return try FileReaderImpl.call_readAsBinaryString(instance, blob);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try FileReaderImpl.call_abort(instance);
    }

    pub fn call_readAsText(instance: *runtime.Instance, blob: Blob, encoding: DOMString) anyerror!void {
        
        return try FileReaderImpl.call_readAsText(instance, blob, encoding);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try FileReaderImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: Blob) anyerror!void {
        
        return try FileReaderImpl.call_readAsArrayBuffer(instance, blob);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try FileReaderImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try FileReaderImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};
