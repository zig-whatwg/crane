//! Generated from: FileAPI.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileReaderImpl = @import("../impls/FileReader.zig");
const EventTarget = @import("EventTarget.zig");

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
            result: ?(DOMString or ArrayBuffer) = null,
            error: ?DOMException = null,
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FileReaderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FileReaderImpl.deinit(state);
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
        try FileReaderImpl.constructor(state);
        
        return instance;
    }

    pub fn get_readyState(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return FileReaderImpl.get_readyState(state);
    }

    pub fn get_result(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileReaderImpl.get_result(state);
    }

    pub fn get_error(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileReaderImpl.get_error(state);
    }

    pub fn get_onloadstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileReaderImpl.get_onloadstart(state);
    }

    pub fn set_onloadstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FileReaderImpl.set_onloadstart(state, value);
    }

    pub fn get_onprogress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileReaderImpl.get_onprogress(state);
    }

    pub fn set_onprogress(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FileReaderImpl.set_onprogress(state, value);
    }

    pub fn get_onload(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileReaderImpl.get_onload(state);
    }

    pub fn set_onload(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FileReaderImpl.set_onload(state, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileReaderImpl.get_onabort(state);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FileReaderImpl.set_onabort(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileReaderImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FileReaderImpl.set_onerror(state, value);
    }

    pub fn get_onloadend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileReaderImpl.get_onloadend(state);
    }

    pub fn set_onloadend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        FileReaderImpl.set_onloadend(state, value);
    }

    pub fn call_readAsDataURL(instance: *runtime.Instance, blob: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileReaderImpl.call_readAsDataURL(state, blob);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileReaderImpl.call_when(state, type_, options);
    }

    pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileReaderImpl.call_readAsBinaryString(state, blob);
    }

    pub fn call_abort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileReaderImpl.call_abort(state);
    }

    pub fn call_readAsText(instance: *runtime.Instance, blob: anyopaque, encoding: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return FileReaderImpl.call_readAsText(state, blob, encoding);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return FileReaderImpl.call_dispatchEvent(state, event);
    }

    pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileReaderImpl.call_readAsArrayBuffer(state, blob);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileReaderImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileReaderImpl.call_removeEventListener(state, type_, callback, options);
    }

};
