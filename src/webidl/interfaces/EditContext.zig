//! Generated from: edit-context.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EditContextImpl = @import("impls").EditContext;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
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
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
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
        pub const lazy_properties = .{};

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
            ontextupdate: typedefs.EventHandler = undefined,
            ontextformatupdate: typedefs.EventHandler = undefined,
            oncharacterboundsupdate: typedefs.EventHandler = undefined,
            oncompositionstart: typedefs.EventHandler = undefined,
            oncompositionend: typedefs.EventHandler = undefined,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("EditContext has no construction argument '" ++ field_name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(EditContextImpl, "init") and @hasDecl(EditContextImpl, "initOwn")) @compileError("EditContextImpl defines both init and initOwn");
        if (comptime @hasDecl(EditContextImpl, "init")) return EditContextImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(EditContextImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try EditContextImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(EditContextImpl, "init")) return false;
        if (comptime @hasDecl(EditContextImpl, "construction_args")) {
            inline for (EditContextImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(EditContextImpl, "deinit") and @hasDecl(EditContextImpl, "deinitOwn")) @compileError("EditContextImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(EditContextImpl, "deinit")) return EditContextImpl.deinit(instance);
        if (comptime @hasDecl(EditContextImpl, "deinitOwn")) EditContextImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "EditContext")) {
            if (comptime @hasDecl(impls.EditContext, "installHooks")) impls.EditContext.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(EditContextInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try EditContextImpl.call_constructor(ctx, options);
    }

    pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
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

    const event_handlers = @import("dom").event_handlers;

    pub fn get_ontextupdate(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(EditContextImpl, "get_ontextupdate")) return try EditContextImpl.get_ontextupdate(instance);
        return event_handlers.value(EventHandler, instance, "ontextupdate");
    }

    pub fn set_ontextupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(EditContextImpl, "set_ontextupdate")) return try EditContextImpl.set_ontextupdate(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontextupdate", value);
    }

    pub fn get_ontextformatupdate(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(EditContextImpl, "get_ontextformatupdate")) return try EditContextImpl.get_ontextformatupdate(instance);
        return event_handlers.value(EventHandler, instance, "ontextformatupdate");
    }

    pub fn set_ontextformatupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(EditContextImpl, "set_ontextformatupdate")) return try EditContextImpl.set_ontextformatupdate(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ontextformatupdate", value);
    }

    pub fn get_oncharacterboundsupdate(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(EditContextImpl, "get_oncharacterboundsupdate")) return try EditContextImpl.get_oncharacterboundsupdate(instance);
        return event_handlers.value(EventHandler, instance, "oncharacterboundsupdate");
    }

    pub fn set_oncharacterboundsupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(EditContextImpl, "set_oncharacterboundsupdate")) return try EditContextImpl.set_oncharacterboundsupdate(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncharacterboundsupdate", value);
    }

    pub fn get_oncompositionstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(EditContextImpl, "get_oncompositionstart")) return try EditContextImpl.get_oncompositionstart(instance);
        return event_handlers.value(EventHandler, instance, "oncompositionstart");
    }

    pub fn set_oncompositionstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(EditContextImpl, "set_oncompositionstart")) return try EditContextImpl.set_oncompositionstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncompositionstart", value);
    }

    pub fn get_oncompositionend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(EditContextImpl, "get_oncompositionend")) return try EditContextImpl.get_oncompositionend(instance);
        return event_handlers.value(EventHandler, instance, "oncompositionend");
    }

    pub fn set_oncompositionend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(EditContextImpl, "set_oncompositionend")) return try EditContextImpl.set_oncompositionend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncompositionend", value);
    }

    pub fn call_updateCharacterBounds(instance: *runtime.Instance, rangeStart: u32, characterBounds: runtime.JSValue) anyerror!void {
        return try EditContextImpl.call_updateCharacterBounds(instance, rangeStart, characterBounds);
    }

    pub fn call_updateControlBounds(instance: *runtime.Instance, controlBounds: *runtime.Instance) anyerror!void {
        return try EditContextImpl.call_updateControlBounds(instance, controlBounds);
    }

    pub fn call_attachedElements(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try EditContextImpl.call_attachedElements(instance);
    }

    pub fn call_updateSelectionBounds(instance: *runtime.Instance, selectionBounds: *runtime.Instance) anyerror!void {
        return try EditContextImpl.call_updateSelectionBounds(instance, selectionBounds);
    }

    pub fn call_updateSelection(instance: *runtime.Instance, start: u32, end: u32) anyerror!void {
        return try EditContextImpl.call_updateSelection(instance, start, end);
    }

    pub fn call_characterBounds(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try EditContextImpl.call_characterBounds(instance);
    }

    pub fn call_updateText(instance: *runtime.Instance, rangeStart: u32, rangeEnd: u32, text: runtime.DOMString) anyerror!void {
        return try EditContextImpl.call_updateText(instance, rangeStart, rangeEnd, text);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_ontextupdate", "set_ontextformatupdate", "set_oncharacterboundsupdate", "set_oncompositionstart", "set_oncompositionend" };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_updateCharacterBounds", 1, "DOMRect" },
        .{ "call_updateControlBounds", 0, "DOMRect" },
        .{ "call_updateSelectionBounds", 0, "DOMRect" },
    };
};
