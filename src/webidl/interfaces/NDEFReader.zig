//! Generated from: web-nfc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NDEFReaderImpl = @import("impls").NDEFReader;
const EventTarget = @import("interfaces").EventTarget;
const NDEFMessageSource = @import("typedefs").NDEFMessageSource;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const NDEFMakeReadOnlyOptions = @import("dictionaries").NDEFMakeReadOnlyOptions;
const NDEFScanOptions = @import("dictionaries").NDEFScanOptions;
const NDEFWriteOptions = @import("dictionaries").NDEFWriteOptions;
const EventHandler = @import("typedefs").EventHandler;

pub const NDEFReader = struct {
    pub const Meta = struct {
        pub const name = "NDEFReader";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onreading: EventHandler = undefined,
            onreadingerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NDEFReader, .{
        .deinit_fn = &deinit_wrapper,

        .get_onreading = &get_onreading,
        .get_onreadingerror = &get_onreadingerror,

        .set_onreading = &set_onreading,
        .set_onreadingerror = &set_onreadingerror,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_makeReadOnly = &call_makeReadOnly,
        .call_removeEventListener = &call_removeEventListener,
        .call_scan = &call_scan,
        .call_when = &call_when,
        .call_write = &call_write,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NDEFReaderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NDEFReaderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try NDEFReaderImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_onreading(instance: *runtime.Instance) anyerror!EventHandler {
        return try NDEFReaderImpl.get_onreading(instance);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NDEFReaderImpl.set_onreading(instance, value);
    }

    pub fn get_onreadingerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try NDEFReaderImpl.get_onreadingerror(instance);
    }

    pub fn set_onreadingerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NDEFReaderImpl.set_onreadingerror(instance, value);
    }

    pub fn call_scan(instance: *runtime.Instance, options: NDEFScanOptions) anyerror!anyopaque {
        
        return try NDEFReaderImpl.call_scan(instance, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try NDEFReaderImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try NDEFReaderImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_makeReadOnly(instance: *runtime.Instance, options: NDEFMakeReadOnlyOptions) anyerror!anyopaque {
        
        return try NDEFReaderImpl.call_makeReadOnly(instance, options);
    }

    pub fn call_write(instance: *runtime.Instance, message: NDEFMessageSource, options: NDEFWriteOptions) anyerror!anyopaque {
        
        return try NDEFReaderImpl.call_write(instance, message, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NDEFReaderImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NDEFReaderImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
