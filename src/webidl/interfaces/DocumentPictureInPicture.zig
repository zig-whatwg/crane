//! Generated from: document-picture-in-picture.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DocumentPictureInPictureImpl = @import("impls").DocumentPictureInPicture;
const EventTarget = @import("interfaces").EventTarget;
const Window = @import("interfaces").Window;
const DocumentPictureInPictureOptions = @import("dictionaries").DocumentPictureInPictureOptions;
const EventHandler = @import("typedefs").EventHandler;
const Promise<Window> = @import("interfaces").Promise<Window>;

pub const DocumentPictureInPicture = struct {
    pub const Meta = struct {
        pub const name = "DocumentPictureInPicture";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            window: Window = undefined,
            onenter: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DocumentPictureInPicture, .{
        .deinit_fn = &deinit_wrapper,

        .get_onenter = &get_onenter,
        .get_window = &get_window,

        .set_onenter = &set_onenter,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestWindow = &call_requestWindow,
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
        DocumentPictureInPictureImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentPictureInPictureImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_window(instance: *runtime.Instance) anyerror!Window {
        return try DocumentPictureInPictureImpl.get_window(instance);
    }

    pub fn get_onenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try DocumentPictureInPictureImpl.get_onenter(instance);
    }

    pub fn set_onenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DocumentPictureInPictureImpl.set_onenter(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try DocumentPictureInPictureImpl.call_dispatchEvent(instance, event);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestWindow(instance: *runtime.Instance, options: DocumentPictureInPictureOptions) anyerror!anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try DocumentPictureInPictureImpl.call_requestWindow(instance, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try DocumentPictureInPictureImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try DocumentPictureInPictureImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try DocumentPictureInPictureImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
