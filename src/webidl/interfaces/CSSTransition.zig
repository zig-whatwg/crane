//! Generated from: css-transitions-2.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSTransitionImpl = @import("impls").CSSTransition;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Animation = @import("interfaces").Animation;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AnimationPlayState = @import("enums").AnimationPlayState;
const CSSOMString = @import("typedefs").CSSOMString;
const AnimationTrigger = @import("interfaces").AnimationTrigger;
const AnimationTimeline = @import("interfaces").AnimationTimeline;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const AnimationEffect = @import("interfaces").AnimationEffect;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AnimationReplaceState = @import("enums").AnimationReplaceState;
const EventListener = @import("interfaces").EventListener;
const CSSNumberish = @import("typedefs").CSSNumberish;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const CSSTransition = struct {
    pub const Meta = struct {
        pub const name = "CSSTransition";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Animation.State;
        pub const ParentInterface = Animation;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "transitionProperty", "get_transitionProperty", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "cancel",
            "finish",
            "play",
            "pause",
            "updatePlaybackRate",
            "reverse",
            "persist",
            "commitStyles",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "transitionProperty", "get_transitionProperty", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            transitionProperty: typedefs.CSSOMString = undefined,
            _internal: ?*CSSTransitionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_transitionProperty = &get_transitionProperty,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSTransition has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSTransitionImpl, "init") and @hasDecl(CSSTransitionImpl, "initOwn")) @compileError("CSSTransitionImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSTransitionImpl, "init")) return CSSTransitionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSTransitionImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSTransitionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSTransitionImpl, "init")) return false;
        if (comptime @hasDecl(CSSTransitionImpl, "construction_args")) {
            inline for (CSSTransitionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSTransitionImpl, "deinit") and @hasDecl(CSSTransitionImpl, "deinitOwn")) @compileError("CSSTransitionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSTransitionImpl, "deinit")) return CSSTransitionImpl.deinit(instance);
        if (comptime @hasDecl(CSSTransitionImpl, "deinitOwn")) CSSTransitionImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSTransition")) {
            if (comptime @hasDecl(impls.CSSTransition, "installHooks")) impls.CSSTransition.installHooks();
        }
    }

    pub fn get_transitionProperty(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSTransitionImpl.get_transitionProperty(instance);
    }
};
