//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XPathEvaluatorImpl = @import("impls").XPathEvaluator;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XPathEvaluatorBase = @import("mixins").XPathEvaluatorBase;
const XPathExpression = @import("interfaces").XPathExpression;
const XPathResult = @import("interfaces").XPathResult;
const XPathNSResolver = @import("interfaces").XPathNSResolver;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const XPathEvaluator = struct {
    pub const Meta = struct {
        pub const name = "XPathEvaluator";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            XPathEvaluatorBase,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createExpression", "call_createExpression", 1 },
            .{ "createNSResolver", "call_createNSResolver", 1 },
            .{ "evaluate", "call_evaluate", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createExpression",
            "createNSResolver",
            "evaluate",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

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
            _internal: ?*XPathEvaluatorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_createExpression = &call_createExpression,
        .call_createNSResolver = &call_createNSResolver,
        .call_evaluate = &call_evaluate,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XPathEvaluator has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XPathEvaluatorImpl, "init") and @hasDecl(XPathEvaluatorImpl, "initOwn")) @compileError("XPathEvaluatorImpl defines both init and initOwn");
        if (comptime @hasDecl(XPathEvaluatorImpl, "init")) return XPathEvaluatorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XPathEvaluatorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XPathEvaluatorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XPathEvaluatorImpl, "init")) return false;
        if (comptime @hasDecl(XPathEvaluatorImpl, "construction_args")) {
            inline for (XPathEvaluatorImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(XPathEvaluatorImpl, "deinit") and @hasDecl(XPathEvaluatorImpl, "deinitOwn")) @compileError("XPathEvaluatorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XPathEvaluatorImpl, "deinit")) return XPathEvaluatorImpl.deinit(instance);
        if (comptime @hasDecl(XPathEvaluatorImpl, "deinitOwn")) XPathEvaluatorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XPathEvaluator")) {
            if (comptime @hasDecl(impls.XPathEvaluator, "installHooks")) impls.XPathEvaluator.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XPathEvaluatorImpl.call_constructor(ctx);
    }

    pub fn call_createNSResolver(instance: *runtime.Instance, nodeResolver: *runtime.Instance) anyerror!*runtime.Instance {
        return try XPathEvaluatorImpl.call_createNSResolver(instance, nodeResolver);
    }

    pub fn call_evaluate(instance: *runtime.Instance, expression: DOMString, contextNode: *runtime.Instance, resolver: webidl.Opt(??*runtime.CallbackWrapper), @"type": webidl.Opt(u16), result: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
        return try XPathEvaluatorImpl.call_evaluate(instance, expression, contextNode, resolver, @"type", result);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createExpression(instance: *runtime.Instance, expression: DOMString, resolver: webidl.Opt(??*runtime.CallbackWrapper)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try XPathEvaluatorImpl.call_createExpression(instance, expression, resolver);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_createNSResolver", 0, "Node" },
        .{ "call_evaluate", 1, "Node" },
        .{ "call_evaluate", 4, "XPathResult" },
    };
};
