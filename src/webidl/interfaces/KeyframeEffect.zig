//! Generated from: web-animations.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const KeyframeEffectImpl = @import("impls").KeyframeEffect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AnimationEffect = @import("interfaces").AnimationEffect;
const Element = @import("interfaces").Element;
const IterationCompositeOperation = @import("enums").IterationCompositeOperation;
const CSSOMString = @import("typedefs").CSSOMString;
const GroupEffect = @import("interfaces").GroupEffect;
const EffectTiming = @import("dictionaries").EffectTiming;
const KeyframeEffectOptions = @import("dictionaries").KeyframeEffectOptions;
const ComputedEffectTiming = @import("dictionaries").ComputedEffectTiming;
const CompositeOperation = @import("enums").CompositeOperation;
const OptionalEffectTiming = @import("dictionaries").OptionalEffectTiming;

pub const KeyframeEffect = struct {
    pub const Meta = struct {
        pub const name = "KeyframeEffect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = AnimationEffect.State;
        pub const ParentInterface = AnimationEffect;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "target", "get_target", "set_target" },
            .{ "pseudoElement", "get_pseudoElement", "set_pseudoElement" },
            .{ "composite", "get_composite", "set_composite" },
            .{ "iterationComposite", "get_iterationComposite", "set_iterationComposite" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getKeyframes", "call_getKeyframes", 0 },
            .{ "setKeyframes", "call_setKeyframes", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getKeyframes",
            "setKeyframes",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "getTiming",
            "getComputedTiming",
            "updateTiming",
            "before",
            "after",
            "replace",
            "remove",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "target", "get_target", "set_target" },
            .{ "pseudoElement", "get_pseudoElement", "set_pseudoElement" },
            .{ "composite", "get_composite", "set_composite" },
            .{ "iterationComposite", "get_iterationComposite", "set_iterationComposite" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            target: ?*runtime.Instance = null,
            pseudoElement: ?typedefs.CSSOMString = null,
            composite: enums.CompositeOperation = undefined,
            iterationComposite: enums.IterationCompositeOperation = undefined,
            _internal: ?*KeyframeEffectImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_composite = &get_composite,
        .get_iterationComposite = &get_iterationComposite,
        .get_pseudoElement = &get_pseudoElement,
        .get_target = &get_target,

        .set_composite = &set_composite,
        .set_iterationComposite = &set_iterationComposite,
        .set_pseudoElement = &set_pseudoElement,
        .set_target = &set_target,

        .call_getKeyframes = &call_getKeyframes,
        .call_setKeyframes = &call_setKeyframes,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("KeyframeEffect has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(KeyframeEffectImpl, "init") and @hasDecl(KeyframeEffectImpl, "initOwn")) @compileError("KeyframeEffectImpl defines both init and initOwn");
        if (comptime @hasDecl(KeyframeEffectImpl, "init")) return KeyframeEffectImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(KeyframeEffectImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try KeyframeEffectImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(KeyframeEffectImpl, "init")) return false;
        if (comptime @hasDecl(KeyframeEffectImpl, "construction_args")) {
            inline for (KeyframeEffectImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(KeyframeEffectImpl, "deinit") and @hasDecl(KeyframeEffectImpl, "deinitOwn")) @compileError("KeyframeEffectImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(KeyframeEffectImpl, "deinit")) return KeyframeEffectImpl.deinit(instance);
        if (comptime @hasDecl(KeyframeEffectImpl, "deinitOwn")) KeyframeEffectImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "KeyframeEffect")) {
            if (comptime @hasDecl(impls.KeyframeEffect, "installHooks")) impls.KeyframeEffect.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(target, keyframes, options)
        Element_object_union: struct {
            target: ?*runtime.Instance,
            keyframes: ?runtime.JSValue,
            options: webidl.Opt(runtime.JSValue),
        },
        /// constructor(source)
        KeyframeEffect: *runtime.Instance,
    };

    /// WebIDL overload set of the constructor: one entry per variant of
    /// ConstructorArgs, in its order, for the overload resolution algorithm
    /// (webidl.overload_resolution) the binding runs to pick the variant.
    pub const constructor_overloads = &[_]webidl.overload_resolution.Overload{
        .{ .function = "Element_object_union", .args = &.{ .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Element")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Element.State) } else .other)}, .nullable = true }, .{ .kinds = &.{.object}, .nullable = true }, .{ .kinds = &.{ .numeric, .dictionary }, .optionality = .optional } } },
        .{ .function = "KeyframeEffect", .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "KeyframeEffect")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").KeyframeEffect.State) } else .other)} }} },
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try KeyframeEffectImpl.call_constructor(ctx, args);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "Element_object_union", 0, "Element" },
        .{ "KeyframeEffect", 0, "KeyframeEffect" },
    };

    pub fn get_target(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try KeyframeEffectImpl.get_target(instance);
    }

    pub fn set_target(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try KeyframeEffectImpl.set_target(instance, value);
    }

    pub fn get_pseudoElement(instance: *runtime.Instance) anyerror!?CSSOMString {
        return try KeyframeEffectImpl.get_pseudoElement(instance);
    }

    pub fn set_pseudoElement(instance: *runtime.Instance, value: ?CSSOMString) anyerror!void {
        try KeyframeEffectImpl.set_pseudoElement(instance, value);
    }

    pub fn get_composite(instance: *runtime.Instance) anyerror!CompositeOperation {
        return try KeyframeEffectImpl.get_composite(instance);
    }

    pub fn set_composite(instance: *runtime.Instance, value: CompositeOperation) anyerror!void {
        try KeyframeEffectImpl.set_composite(instance, value);
    }

    pub fn get_iterationComposite(instance: *runtime.Instance) anyerror!IterationCompositeOperation {
        return try KeyframeEffectImpl.get_iterationComposite(instance);
    }

    pub fn set_iterationComposite(instance: *runtime.Instance, value: IterationCompositeOperation) anyerror!void {
        try KeyframeEffectImpl.set_iterationComposite(instance, value);
    }

    pub fn call_setKeyframes(instance: *runtime.Instance, keyframes: ?runtime.JSValue) anyerror!void {
        return try KeyframeEffectImpl.call_setKeyframes(instance, keyframes);
    }

    pub fn call_getKeyframes(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try KeyframeEffectImpl.call_getKeyframes(instance);
    }

    /// WebIDL `object` arguments (or sequences of `object`): a value that is
    /// not an Object throws a TypeError (bit i = argument i).
    pub const object_arguments = .{
        .{ "call_setKeyframes", 0b1 },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_target", 0, "Element" },
    };
};
