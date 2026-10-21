//! Generated from: mediaqueries-5.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PreferenceObjectImpl = @import("impls").PreferenceObject;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const PreferenceObject = struct {
    pub const Meta = struct {
        pub const name = "PreferenceObject";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "override", "get_override", null },
            .{ "value", "get_value", null },
            .{ "validValues", "get_validValues", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clearOverride", "call_clearOverride", 0 },
            .{ "requestOverride", "call_requestOverride", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clearOverride",
            "requestOverride",
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
            .{ "override", "get_override", null },
            .{ "value", "get_value", null },
            .{ "validValues", "get_validValues", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            override: ?runtime.DOMString = null,
            value: runtime.DOMString = undefined,
            validValues: runtime.JSValue = undefined,
            onchange: typedefs.EventHandler = undefined,
            _internal: ?*PreferenceObjectImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onchange = &get_onchange,
        .get_override = &get_override,
        .get_validValues = &get_validValues,
        .get_value = &get_value,

        .set_onchange = &set_onchange,

        .call_clearOverride = &call_clearOverride,
        .call_requestOverride = &call_requestOverride,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("PreferenceObject has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PreferenceObjectImpl, "init") and @hasDecl(PreferenceObjectImpl, "initOwn")) @compileError("PreferenceObjectImpl defines both init and initOwn");
        if (comptime @hasDecl(PreferenceObjectImpl, "init")) return PreferenceObjectImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PreferenceObjectImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PreferenceObjectImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PreferenceObjectImpl, "init")) return false;
        if (comptime @hasDecl(PreferenceObjectImpl, "construction_args")) {
            inline for (PreferenceObjectImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PreferenceObjectImpl, "deinit") and @hasDecl(PreferenceObjectImpl, "deinitOwn")) @compileError("PreferenceObjectImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PreferenceObjectImpl, "deinit")) return PreferenceObjectImpl.deinit(instance);
        if (comptime @hasDecl(PreferenceObjectImpl, "deinitOwn")) PreferenceObjectImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PreferenceObject")) {
            if (comptime @hasDecl(impls.PreferenceObject, "installHooks")) impls.PreferenceObject.installHooks();
        }
    }

    pub fn get_override(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try PreferenceObjectImpl.get_override(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try PreferenceObjectImpl.get_value(instance);
    }

    pub fn get_validValues(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PreferenceObjectImpl.get_validValues(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PreferenceObjectImpl, "get_onchange")) return try PreferenceObjectImpl.get_onchange(instance);
        return event_handlers.value(EventHandler, instance, "onchange");
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PreferenceObjectImpl, "set_onchange")) return try PreferenceObjectImpl.set_onchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onchange", value);
    }

    pub fn call_requestOverride(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!runtime.JSValue {
        return try PreferenceObjectImpl.call_requestOverride(instance, value);
    }

    pub fn call_clearOverride(instance: *runtime.Instance) anyerror!void {
        return try PreferenceObjectImpl.call_clearOverride(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onchange"};

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_requestOverride",
    };
};
