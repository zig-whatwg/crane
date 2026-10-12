//! Generated from: turtledove.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const InterestGroupBiddingScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupBiddingScriptRunnerGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const InterestGroupBiddingAndScoringScriptRunnerGlobalScope = @import("interfaces").InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
const ProtectedAudienceUtilities = @import("interfaces").ProtectedAudienceUtilities;
const RealTimeReporting = @import("interfaces").RealTimeReporting;
const GenerateBidOutput = @import("dictionaries").GenerateBidOutput;
const ForDebuggingOnly = @import("interfaces").ForDebuggingOnly;
const DOMString = @import("typedefs").DOMString;
const PrivateAggregation = @import("interfaces").PrivateAggregation;

pub const InterestGroupBiddingScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupBiddingScriptRunnerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = InterestGroupBiddingAndScoringScriptRunnerGlobalScope.State;
        pub const ParentInterface = InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupBiddingScriptRunnerGlobalScope" } },
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "InterestGroupScriptRunnerGlobalScope", "InterestGroupBiddingScriptRunnerGlobalScope" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupBiddingScriptRunnerGlobalScope = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setBid", "call_setBid", 0 },
            .{ "setPriority", "call_setPriority", 1 },
            .{ "setPrioritySignalsOverride", "call_setPrioritySignalsOverride", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setBid",
            "setPriority",
            "setPrioritySignalsOverride",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*InterestGroupBiddingScriptRunnerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_setBid = &call_setBid,
        .call_setPriority = &call_setPriority,
        .call_setPrioritySignalsOverride = &call_setPrioritySignalsOverride,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("InterestGroupBiddingScriptRunnerGlobalScope has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "init") and @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "initOwn")) @compileError("InterestGroupBiddingScriptRunnerGlobalScopeImpl defines both init and initOwn");
        if (comptime @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "init")) return InterestGroupBiddingScriptRunnerGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try InterestGroupBiddingScriptRunnerGlobalScopeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "init")) return false;
        if (comptime @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "construction_args")) {
            inline for (InterestGroupBiddingScriptRunnerGlobalScopeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "deinit") and @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "deinitOwn")) @compileError("InterestGroupBiddingScriptRunnerGlobalScopeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "deinit")) return InterestGroupBiddingScriptRunnerGlobalScopeImpl.deinit(instance);
        if (comptime @hasDecl(InterestGroupBiddingScriptRunnerGlobalScopeImpl, "deinitOwn")) InterestGroupBiddingScriptRunnerGlobalScopeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "InterestGroupBiddingScriptRunnerGlobalScope")) {
            if (comptime @hasDecl(impls.InterestGroupBiddingScriptRunnerGlobalScope, "installHooks")) impls.InterestGroupBiddingScriptRunnerGlobalScope.installHooks();
        }
    }

    pub fn call_setBid(instance: *runtime.Instance, oneOrManyBids: webidl.Opt(runtime.JSValue)) anyerror!bool {
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setBid(instance, oneOrManyBids);
    }

    pub fn call_setPriority(instance: *runtime.Instance, priority: f64) anyerror!void {
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPriority(instance, priority);
    }

    pub fn call_setPrioritySignalsOverride(instance: *runtime.Instance, key: DOMString, priority: webidl.Opt(?f64)) anyerror!void {
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPrioritySignalsOverride(instance, key, priority);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_setPriority", 0b1 },
        .{ "call_setPrioritySignalsOverride", 0b10 },
    };
};
