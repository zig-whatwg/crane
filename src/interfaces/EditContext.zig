//! Generated from: edit-context.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EditContextImpl = @import("../impls/EditContext.zig");
const EventTarget = @import("EventTarget.zig");

pub const EditContext = struct {
    pub const Meta = struct {
        pub const name = "EditContext";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            text: runtime.DOMString = undefined,
            selectionStart: u32 = undefined,
            selectionEnd: u32 = undefined,
            characterBoundsRangeStart: u32 = undefined,
            ontextupdate: EventHandler = undefined,
            ontextformatupdate: EventHandler = undefined,
            oncharacterboundsupdate: EventHandler = undefined,
            oncompositionstart: EventHandler = undefined,
            oncompositionend: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(EditContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_characterBoundsRangeStart = &get_characterBoundsRangeStart,
        .get_oncharacterboundsupdate = &get_oncharacterboundsupdate,
        .get_oncompositionend = &get_oncompositionend,
        .get_oncompositionstart = &get_oncompositionstart,
        .get_ontextformatupdate = &get_ontextformatupdate,
        .get_ontextupdate = &get_ontextupdate,
        .get_selectionEnd = &get_selectionEnd,
        .get_selectionStart = &get_selectionStart,
        .get_text = &get_text,

        .set_oncharacterboundsupdate = &set_oncharacterboundsupdate,
        .set_oncompositionend = &set_oncompositionend,
        .set_oncompositionstart = &set_oncompositionstart,
        .set_ontextformatupdate = &set_ontextformatupdate,
        .set_ontextupdate = &set_ontextupdate,

        .call_addEventListener = &call_addEventListener,
        .call_attachedElements = &call_attachedElements,
        .call_characterBounds = &call_characterBounds,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_updateCharacterBounds = &call_updateCharacterBounds,
        .call_updateControlBounds = &call_updateControlBounds,
        .call_updateSelection = &call_updateSelection,
        .call_updateSelectionBounds = &call_updateSelectionBounds,
        .call_updateText = &call_updateText,
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
        EditContextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        EditContextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try EditContextImpl.constructor(state, options);
        
        return instance;
    }

    pub fn get_text(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return EditContextImpl.get_text(state);
    }

    pub fn get_selectionStart(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return EditContextImpl.get_selectionStart(state);
    }

    pub fn get_selectionEnd(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return EditContextImpl.get_selectionEnd(state);
    }

    pub fn get_characterBoundsRangeStart(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return EditContextImpl.get_characterBoundsRangeStart(state);
    }

    pub fn get_ontextupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return EditContextImpl.get_ontextupdate(state);
    }

    pub fn set_ontextupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        EditContextImpl.set_ontextupdate(state, value);
    }

    pub fn get_ontextformatupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return EditContextImpl.get_ontextformatupdate(state);
    }

    pub fn set_ontextformatupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        EditContextImpl.set_ontextformatupdate(state, value);
    }

    pub fn get_oncharacterboundsupdate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return EditContextImpl.get_oncharacterboundsupdate(state);
    }

    pub fn set_oncharacterboundsupdate(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        EditContextImpl.set_oncharacterboundsupdate(state, value);
    }

    pub fn get_oncompositionstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return EditContextImpl.get_oncompositionstart(state);
    }

    pub fn set_oncompositionstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        EditContextImpl.set_oncompositionstart(state, value);
    }

    pub fn get_oncompositionend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return EditContextImpl.get_oncompositionend(state);
    }

    pub fn set_oncompositionend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        EditContextImpl.set_oncompositionend(state, value);
    }

    pub fn call_updateSelection(instance: *runtime.Instance, start: u32, end: u32) anyopaque {
        const state = instance.getState(State);
        
        return EditContextImpl.call_updateSelection(state, start, end);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return EditContextImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_characterBounds(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return EditContextImpl.call_characterBounds(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return EditContextImpl.call_when(state, type_, options);
    }

    pub fn call_updateSelectionBounds(instance: *runtime.Instance, selectionBounds: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return EditContextImpl.call_updateSelectionBounds(state, selectionBounds);
    }

    pub fn call_updateControlBounds(instance: *runtime.Instance, controlBounds: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return EditContextImpl.call_updateControlBounds(state, controlBounds);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return EditContextImpl.call_dispatchEvent(state, event);
    }

    pub fn call_attachedElements(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return EditContextImpl.call_attachedElements(state);
    }

    pub fn call_updateCharacterBounds(instance: *runtime.Instance, rangeStart: u32, characterBounds: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return EditContextImpl.call_updateCharacterBounds(state, rangeStart, characterBounds);
    }

    pub fn call_updateText(instance: *runtime.Instance, rangeStart: u32, rangeEnd: u32, text: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return EditContextImpl.call_updateText(state, rangeStart, rangeEnd, text);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return EditContextImpl.call_addEventListener(state, type_, callback, options);
    }

};
