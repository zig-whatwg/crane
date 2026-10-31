//! Generated from: touch-events.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TouchEventImpl = @import("impls").TouchEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const UIEvent = @import("interfaces").UIEvent;
const UIEventInit = @import("dictionaries").UIEventInit;
const Window = @import("interfaces").Window;
const TouchEventInit = @import("dictionaries").TouchEventInit;
const EventTarget = @import("interfaces").EventTarget;
const TouchList = @import("interfaces").TouchList;
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const TouchEvent = struct {
    pub const Meta = struct {
        pub const name = "TouchEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = UIEvent.State;
        pub const ParentInterface = UIEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "touches", "get_touches", null },
            .{ "targetTouches", "get_targetTouches", null },
            .{ "changedTouches", "get_changedTouches", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getModifierState", "call_getModifierState", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getModifierState",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "initUIEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "touches", "get_touches", null },
            .{ "targetTouches", "get_targetTouches", null },
            .{ "changedTouches", "get_changedTouches", null },
            .{ "altKey", "get_altKey", null },
            .{ "metaKey", "get_metaKey", null },
            .{ "ctrlKey", "get_ctrlKey", null },
            .{ "shiftKey", "get_shiftKey", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            touches: *runtime.Instance = undefined,
            targetTouches: *runtime.Instance = undefined,
            changedTouches: *runtime.Instance = undefined,
            altKey: bool = undefined,
            metaKey: bool = undefined,
            ctrlKey: bool = undefined,
            shiftKey: bool = undefined,
            _internal: ?*TouchEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_altKey = &get_altKey,
        .get_changedTouches = &get_changedTouches,
        .get_ctrlKey = &get_ctrlKey,
        .get_metaKey = &get_metaKey,
        .get_shiftKey = &get_shiftKey,
        .get_targetTouches = &get_targetTouches,
        .get_touches = &get_touches,

        .call_getModifierState = &call_getModifierState,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("TouchEvent has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(TouchEventImpl, "init") and @hasDecl(TouchEventImpl, "initOwn")) @compileError("TouchEventImpl defines both init and initOwn");
        if (comptime @hasDecl(TouchEventImpl, "init")) return TouchEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(TouchEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try TouchEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TouchEventImpl, "init")) return false;
        if (comptime @hasDecl(TouchEventImpl, "construction_args")) {
            inline for (TouchEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TouchEventImpl, "deinit") and @hasDecl(TouchEventImpl, "deinitOwn")) @compileError("TouchEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TouchEventImpl, "deinit")) return TouchEventImpl.deinit(instance);
        if (comptime @hasDecl(TouchEventImpl, "deinitOwn")) TouchEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TouchEvent")) {
            if (comptime @hasDecl(impls.TouchEvent, "installHooks")) impls.TouchEvent.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(TouchEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TouchEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_touches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TouchEventImpl.get_touches(instance);
    }

    pub fn get_targetTouches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TouchEventImpl.get_targetTouches(instance);
    }

    pub fn get_changedTouches(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TouchEventImpl.get_changedTouches(instance);
    }

    pub fn get_altKey(instance: *runtime.Instance) anyerror!bool {
        return try TouchEventImpl.get_altKey(instance);
    }

    pub fn get_metaKey(instance: *runtime.Instance) anyerror!bool {
        return try TouchEventImpl.get_metaKey(instance);
    }

    pub fn get_ctrlKey(instance: *runtime.Instance) anyerror!bool {
        return try TouchEventImpl.get_ctrlKey(instance);
    }

    pub fn get_shiftKey(instance: *runtime.Instance) anyerror!bool {
        return try TouchEventImpl.get_shiftKey(instance);
    }

    pub fn call_getModifierState(instance: *runtime.Instance, keyArg: runtime.DOMString) anyerror!bool {
        return try TouchEventImpl.call_getModifierState(instance, keyArg);
    }
};
