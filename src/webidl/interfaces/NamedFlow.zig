//! Generated from: css-regions.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NamedFlowImpl = @import("impls").NamedFlow;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Element = @import("interfaces").Element;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const CSSOMString = @import("typedefs").CSSOMString;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const NamedFlow = struct {
    pub const Meta = struct {
        pub const name = "NamedFlow";
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
            .{ "name", "get_name", null },
            .{ "overset", "get_overset", null },
            .{ "firstEmptyRegionIndex", "get_firstEmptyRegionIndex", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getRegions", "call_getRegions", 0 },
            .{ "getContent", "call_getContent", 0 },
            .{ "getRegionsByContent", "call_getRegionsByContent", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getRegions",
            "getContent",
            "getRegionsByContent",
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
            .{ "name", "get_name", null },
            .{ "overset", "get_overset", null },
            .{ "firstEmptyRegionIndex", "get_firstEmptyRegionIndex", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.CSSOMString = undefined,
            overset: bool = undefined,
            firstEmptyRegionIndex: i16 = undefined,
            _internal: ?*NamedFlowImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_firstEmptyRegionIndex = &get_firstEmptyRegionIndex,
        .get_name = &get_name,
        .get_overset = &get_overset,

        .call_getContent = &call_getContent,
        .call_getRegions = &call_getRegions,
        .call_getRegionsByContent = &call_getRegionsByContent,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("NamedFlow has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(NamedFlowImpl, "init") and @hasDecl(NamedFlowImpl, "initOwn")) @compileError("NamedFlowImpl defines both init and initOwn");
        if (comptime @hasDecl(NamedFlowImpl, "init")) return NamedFlowImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(NamedFlowImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try NamedFlowImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NamedFlowImpl, "init")) return false;
        if (comptime @hasDecl(NamedFlowImpl, "construction_args")) {
            inline for (NamedFlowImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(NamedFlowImpl, "deinit") and @hasDecl(NamedFlowImpl, "deinitOwn")) @compileError("NamedFlowImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(NamedFlowImpl, "deinit")) return NamedFlowImpl.deinit(instance);
        if (comptime @hasDecl(NamedFlowImpl, "deinitOwn")) NamedFlowImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NamedFlow")) {
            if (comptime @hasDecl(impls.NamedFlow, "installHooks")) impls.NamedFlow.installHooks();
        }
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try NamedFlowImpl.get_name(instance);
    }

    pub fn get_overset(instance: *runtime.Instance) anyerror!bool {
        return try NamedFlowImpl.get_overset(instance);
    }

    pub fn get_firstEmptyRegionIndex(instance: *runtime.Instance) anyerror!i16 {
        return try NamedFlowImpl.get_firstEmptyRegionIndex(instance);
    }

    pub fn call_getRegions(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NamedFlowImpl.call_getRegions(instance);
    }

    pub fn call_getRegionsByContent(instance: *runtime.Instance, node: *runtime.Instance) anyerror!runtime.JSValue {
        return try NamedFlowImpl.call_getRegionsByContent(instance, node);
    }

    pub fn call_getContent(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NamedFlowImpl.call_getContent(instance);
    }
};
