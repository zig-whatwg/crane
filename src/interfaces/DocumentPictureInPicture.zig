//! Generated from: document-picture-in-picture.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DocumentPictureInPictureImpl = @import("../impls/DocumentPictureInPicture.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        DocumentPictureInPictureImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        DocumentPictureInPictureImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_window(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentPictureInPictureImpl.get_window(state);
    }

    pub fn get_onenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return DocumentPictureInPictureImpl.get_onenter(state);
    }

    pub fn set_onenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        DocumentPictureInPictureImpl.set_onenter(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return DocumentPictureInPictureImpl.call_dispatchEvent(state, event);
    }

    /// Extended attributes: [NewObject]
    pub fn call_requestWindow(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return DocumentPictureInPictureImpl.call_requestWindow(state, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DocumentPictureInPictureImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DocumentPictureInPictureImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return DocumentPictureInPictureImpl.call_removeEventListener(state, type_, callback, options);
    }

};
