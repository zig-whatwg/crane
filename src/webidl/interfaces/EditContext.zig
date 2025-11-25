//! Generated from: edit-context.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EditContextImpl = @import("impls").EditContext;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const DOMRect = @import("interfaces").DOMRect;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const HTMLElement = @import("interfaces").HTMLElement;
const EditContextInit = @import("dictionaries").EditContextInit;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const EditContext = struct {
    pub const Meta = struct {
        pub const name = "EditContext";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "text", "get_text", null },
            .{ "selectionStart", "get_selectionStart", null },
            .{ "selectionEnd", "get_selectionEnd", null },
            .{ "characterBoundsRangeStart", "get_characterBoundsRangeStart", null },
            .{ "ontextupdate", "get_ontextupdate", "set_ontextupdate" },
            .{ "ontextformatupdate", "get_ontextformatupdate", "set_ontextformatupdate" },
            .{ "oncharacterboundsupdate", "get_oncharacterboundsupdate", "set_oncharacterboundsupdate" },
            .{ "oncompositionstart", "get_oncompositionstart", "set_oncompositionstart" },
            .{ "oncompositionend", "get_oncompositionend", "set_oncompositionend" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "updateText", "call_updateText", 3 },
            .{ "updateSelection", "call_updateSelection", 2 },
            .{ "updateControlBounds", "call_updateControlBounds", 1 },
            .{ "updateSelectionBounds", "call_updateSelectionBounds", 1 },
            .{ "updateCharacterBounds", "call_updateCharacterBounds", 2 },
            .{ "attachedElements", "call_attachedElements", 0 },
            .{ "characterBounds", "call_characterBounds", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "updateText",
            "updateSelection",
            "updateControlBounds",
            "updateSelectionBounds",
            "updateCharacterBounds",
            "attachedElements",
            "characterBounds",
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
            .{ "text", "get_text", null },
            .{ "selectionStart", "get_selectionStart", null },
            .{ "selectionEnd", "get_selectionEnd", null },
            .{ "characterBoundsRangeStart", "get_characterBoundsRangeStart", null },
            .{ "ontextupdate", "get_ontextupdate", "set_ontextupdate" },
            .{ "ontextformatupdate", "get_ontextformatupdate", "set_ontextformatupdate" },
            .{ "oncharacterboundsupdate", "get_oncharacterboundsupdate", "set_oncharacterboundsupdate" },
            .{ "oncompositionstart", "get_oncompositionstart", "set_oncompositionstart" },
            .{ "oncompositionend", "get_oncompositionend", "set_oncompositionend" },
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
            text: runtime.DOMString = undefined,
            selectionStart: u32 = undefined,
            selectionEnd: u32 = undefined,
            characterBoundsRangeStart: u32 = undefined,
            ontextupdate: EventHandler = undefined,
            ontextformatupdate: EventHandler = undefined,
            oncharacterboundsupdate: EventHandler = undefined,
            oncompositionstart: EventHandler = undefined,
            oncompositionend: EventHandler = undefined,
            _internal: ?*EditContextImpl.InternalState = null,
        },
    );

    const delegates = .{

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

        .call_attachedElements = &call_attachedElements,
        .call_characterBounds = &call_characterBounds,
        .call_updateCharacterBounds = &call_updateCharacterBounds,
        .call_updateControlBounds = &call_updateControlBounds,
        .call_updateSelection = &call_updateSelection,
        .call_updateSelectionBounds = &call_updateSelectionBounds,
        .call_updateText = &call_updateText,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EditContextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EditContextImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: EditContextInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try EditContextImpl.call_constructor(allocator, ctx, options);
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

    pub fn call_characterBounds(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try EditContextImpl.call_characterBounds(instance);
    }

    pub fn call_updateSelectionBounds(instance: *runtime.Instance, selectionBounds: *runtime.Instance) anyerror!void {
        
        return try EditContextImpl.call_updateSelectionBounds(instance, selectionBounds);
    }

    pub fn call_attachedElements(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try EditContextImpl.call_attachedElements(instance);
    }

    pub fn call_updateControlBounds(instance: *runtime.Instance, controlBounds: *runtime.Instance) anyerror!void {
        
        return try EditContextImpl.call_updateControlBounds(instance, controlBounds);
    }

    pub fn call_updateCharacterBounds(instance: *runtime.Instance, rangeStart: u32, characterBounds: *const anyopaque) anyerror!void {
        
        return try EditContextImpl.call_updateCharacterBounds(instance, rangeStart, characterBounds);
    }

    pub fn call_updateText(instance: *runtime.Instance, rangeStart: u32, rangeEnd: u32, text: DOMString) anyerror!void {
        
        return try EditContextImpl.call_updateText(instance, rangeStart, rangeEnd, text);
    }

};
