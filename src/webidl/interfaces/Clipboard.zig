//! Generated from: clipboard-apis.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClipboardImpl = @import("impls").Clipboard;
const EventTarget = @import("interfaces").EventTarget;
const ClipboardUnsanitizedFormats = @import("dictionaries").ClipboardUnsanitizedFormats;
const Promise<DOMString> = @import("interfaces").Promise<DOMString>;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const ClipboardItems = @import("typedefs").ClipboardItems;
const Promise<ClipboardItems> = @import("interfaces").Promise<ClipboardItems>;

pub const Clipboard = struct {
    pub const Meta = struct {
        pub const name = "Clipboard";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Clipboard, .{
        .deinit_fn = &deinit_wrapper,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_read = &call_read,
        .call_readText = &call_readText,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
        .call_write = &call_write,
        .call_writeText = &call_writeText,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ClipboardImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ClipboardImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ClipboardImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_writeText(instance: *runtime.Instance, data: DOMString) anyerror!anyopaque {
        
        return try ClipboardImpl.call_writeText(instance, data);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ClipboardImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ClipboardImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_read(instance: *runtime.Instance, formats: ClipboardUnsanitizedFormats) anyerror!anyopaque {
        
        return try ClipboardImpl.call_read(instance, formats);
    }

    pub fn call_write(instance: *runtime.Instance, data: ClipboardItems) anyerror!anyopaque {
        
        return try ClipboardImpl.call_write(instance, data);
    }

    pub fn call_readText(instance: *runtime.Instance) anyerror!anyopaque {
        return try ClipboardImpl.call_readText(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ClipboardImpl.call_addEventListener(instance, type_, callback, options);
    }

};
