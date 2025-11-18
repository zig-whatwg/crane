//! Generated from: edit-context.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EditContextImpl = @import("impls").EditContext;
const EventTarget = @import("interfaces").EventTarget;
const DOMRect = @import("interfaces").DOMRect;
const EditContextInit = @import("dictionaries").EditContextInit;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        EditContextImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EditContextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, options: EditContextInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try EditContextImpl.constructor(instance, options);
        
        return instance;
    }

    pub fn get_text(instance: *runtime.Instance) anyerror!DOMString {
        return try EditContextImpl.get_text(instance);
    }

    pub fn get_selectionStart(instance: *runtime.Instance) anyerror!u32 {
        return try EditContextImpl.get_selectionStart(instance);
    }

    pub fn get_selectionEnd(instance: *runtime.Instance) anyerror!u32 {
        return try EditContextImpl.get_selectionEnd(instance);
    }

    pub fn get_characterBoundsRangeStart(instance: *runtime.Instance) anyerror!u32 {
        return try EditContextImpl.get_characterBoundsRangeStart(instance);
    }

    pub fn get_ontextupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try EditContextImpl.get_ontextupdate(instance);
    }

    pub fn set_ontextupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EditContextImpl.set_ontextupdate(instance, value);
    }

    pub fn get_ontextformatupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try EditContextImpl.get_ontextformatupdate(instance);
    }

    pub fn set_ontextformatupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EditContextImpl.set_ontextformatupdate(instance, value);
    }

    pub fn get_oncharacterboundsupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try EditContextImpl.get_oncharacterboundsupdate(instance);
    }

    pub fn set_oncharacterboundsupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EditContextImpl.set_oncharacterboundsupdate(instance, value);
    }

    pub fn get_oncompositionstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try EditContextImpl.get_oncompositionstart(instance);
    }

    pub fn set_oncompositionstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EditContextImpl.set_oncompositionstart(instance, value);
    }

    pub fn get_oncompositionend(instance: *runtime.Instance) anyerror!EventHandler {
        return try EditContextImpl.get_oncompositionend(instance);
    }

    pub fn set_oncompositionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try EditContextImpl.set_oncompositionend(instance, value);
    }

    pub fn call_updateSelection(instance: *runtime.Instance, start: u32, end: u32) anyerror!void {
        
        return try EditContextImpl.call_updateSelection(instance, start, end);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try EditContextImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_characterBounds(instance: *runtime.Instance) anyerror!anyopaque {
        return try EditContextImpl.call_characterBounds(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try EditContextImpl.call_when(instance, type_, options);
    }

    pub fn call_updateSelectionBounds(instance: *runtime.Instance, selectionBounds: DOMRect) anyerror!void {
        
        return try EditContextImpl.call_updateSelectionBounds(instance, selectionBounds);
    }

    pub fn call_updateControlBounds(instance: *runtime.Instance, controlBounds: DOMRect) anyerror!void {
        
        return try EditContextImpl.call_updateControlBounds(instance, controlBounds);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try EditContextImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_attachedElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try EditContextImpl.call_attachedElements(instance);
    }

    pub fn call_updateCharacterBounds(instance: *runtime.Instance, rangeStart: u32, characterBounds: anyopaque) anyerror!void {
        
        return try EditContextImpl.call_updateCharacterBounds(instance, rangeStart, characterBounds);
    }

    pub fn call_updateText(instance: *runtime.Instance, rangeStart: u32, rangeEnd: u32, text: DOMString) anyerror!void {
        
        return try EditContextImpl.call_updateText(instance, rangeStart, rangeEnd, text);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try EditContextImpl.call_addEventListener(instance, type_, callback, options);
    }

};
