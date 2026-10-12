//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XSLTProcessorImpl = @import("impls").XSLTProcessor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DocumentFragment = @import("interfaces").DocumentFragment;
const Document = @import("interfaces").Document;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const XSLTProcessor = struct {
    pub const Meta = struct {
        pub const name = "XSLTProcessor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
            .{ "importStylesheet", "call_importStylesheet", 1 },
            .{ "transformToFragment", "call_transformToFragment", 2 },
            .{ "transformToDocument", "call_transformToDocument", 1 },
            .{ "setParameter", "call_setParameter", 3 },
            .{ "getParameter", "call_getParameter", 2 },
            .{ "removeParameter", "call_removeParameter", 2 },
            .{ "clearParameters", "call_clearParameters", 0 },
            .{ "reset", "call_reset", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "importStylesheet",
            "transformToFragment",
            "transformToDocument",
            "setParameter",
            "getParameter",
            "removeParameter",
            "clearParameters",
            "reset",
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
            _internal: ?*XSLTProcessorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_clearParameters = &call_clearParameters,
        .call_getParameter = &call_getParameter,
        .call_importStylesheet = &call_importStylesheet,
        .call_removeParameter = &call_removeParameter,
        .call_reset = &call_reset,
        .call_setParameter = &call_setParameter,
        .call_transformToDocument = &call_transformToDocument,
        .call_transformToFragment = &call_transformToFragment,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XSLTProcessor has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XSLTProcessorImpl, "init") and @hasDecl(XSLTProcessorImpl, "initOwn")) @compileError("XSLTProcessorImpl defines both init and initOwn");
        if (comptime @hasDecl(XSLTProcessorImpl, "init")) return XSLTProcessorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XSLTProcessorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XSLTProcessorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XSLTProcessorImpl, "init")) return false;
        if (comptime @hasDecl(XSLTProcessorImpl, "construction_args")) {
            inline for (XSLTProcessorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XSLTProcessorImpl, "deinit") and @hasDecl(XSLTProcessorImpl, "deinitOwn")) @compileError("XSLTProcessorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XSLTProcessorImpl, "deinit")) return XSLTProcessorImpl.deinit(instance);
        if (comptime @hasDecl(XSLTProcessorImpl, "deinitOwn")) XSLTProcessorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XSLTProcessor")) {
            if (comptime @hasDecl(impls.XSLTProcessor, "installHooks")) impls.XSLTProcessor.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try XSLTProcessorImpl.call_constructor(ctx);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_transformToDocument(instance: *runtime.Instance, source: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = XSLTProcessorImpl.call_transformToDocument(instance, source) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        runtime.CEReactions.end(ce_scope);
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
    }

    pub fn call_setParameter(instance: *runtime.Instance, namespaceURI: DOMString, localName: DOMString, value: runtime.JSValue) anyerror!void {
        return try XSLTProcessorImpl.call_setParameter(instance, namespaceURI, localName, value);
    }

    pub fn call_clearParameters(instance: *runtime.Instance) anyerror!void {
        return try XSLTProcessorImpl.call_clearParameters(instance);
    }

    pub fn call_removeParameter(instance: *runtime.Instance, namespaceURI: DOMString, localName: DOMString) anyerror!void {
        return try XSLTProcessorImpl.call_removeParameter(instance, namespaceURI, localName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_transformToFragment(instance: *runtime.Instance, source: *runtime.Instance, output: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = XSLTProcessorImpl.call_transformToFragment(instance, source, output) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        runtime.CEReactions.end(ce_scope);
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
    }

    pub fn call_getParameter(instance: *runtime.Instance, namespaceURI: DOMString, localName: DOMString) anyerror!runtime.JSValue {
        return try XSLTProcessorImpl.call_getParameter(instance, namespaceURI, localName);
    }

    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        return try XSLTProcessorImpl.call_reset(instance);
    }

    pub fn call_importStylesheet(instance: *runtime.Instance, style: *runtime.Instance) anyerror!void {
        return try XSLTProcessorImpl.call_importStylesheet(instance, style);
    }

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "call_setParameter", 0b1 },
        .{ "call_removeParameter", 0b1 },
        .{ "call_getParameter", 0b1 },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "call_transformToDocument",
        "call_transformToFragment",
    };
};
