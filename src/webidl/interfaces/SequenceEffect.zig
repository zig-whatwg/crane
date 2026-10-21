//! Generated from: web-animations-2.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SequenceEffectImpl = @import("impls").SequenceEffect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GroupEffect = @import("interfaces").GroupEffect;
const AnimationEffect = @import("interfaces").AnimationEffect;
const AnimationNodeList = @import("interfaces").AnimationNodeList;
const EffectTiming = @import("dictionaries").EffectTiming;

pub const SequenceEffect = struct {
    pub const Meta = struct {
        pub const name = "SequenceEffect";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = GroupEffect.State;
        pub const ParentInterface = GroupEffect;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clone", "call_clone", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clone",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "prepend",
            "append",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*SequenceEffectImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_clone = &call_clone,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SequenceEffect has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SequenceEffectImpl, "init") and @hasDecl(SequenceEffectImpl, "initOwn")) @compileError("SequenceEffectImpl defines both init and initOwn");
        if (comptime @hasDecl(SequenceEffectImpl, "init")) return SequenceEffectImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SequenceEffectImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SequenceEffectImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SequenceEffectImpl, "init")) return false;
        if (comptime @hasDecl(SequenceEffectImpl, "construction_args")) {
            inline for (SequenceEffectImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SequenceEffectImpl, "deinit") and @hasDecl(SequenceEffectImpl, "deinitOwn")) @compileError("SequenceEffectImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SequenceEffectImpl, "deinit")) return SequenceEffectImpl.deinit(instance);
        if (comptime @hasDecl(SequenceEffectImpl, "deinitOwn")) SequenceEffectImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SequenceEffect")) {
            if (comptime @hasDecl(impls.SequenceEffect, "installHooks")) impls.SequenceEffect.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, children: ?runtime.JSValue, timing: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SequenceEffectImpl.call_constructor(ctx, children, timing);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "AnimationEffect" },
    };

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SequenceEffectImpl.call_clone(instance);
    }
};
