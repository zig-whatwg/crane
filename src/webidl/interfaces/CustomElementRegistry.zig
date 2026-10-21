//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CustomElementRegistryImpl = @import("impls").CustomElementRegistry;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ElementDefinitionOptions = @import("dictionaries").ElementDefinitionOptions;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;
const CustomElementConstructor = @import("callbacks").CustomElementConstructor;

pub const CustomElementRegistry = struct {
    pub const Meta = struct {
        pub const name = "CustomElementRegistry";
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
            .{ "define", "call_define", 2 },
            .{ "get", "call_get", 1 },
            .{ "getName", "call_getName", 1 },
            .{ "whenDefined", "call_whenDefined", 1 },
            .{ "upgrade", "call_upgrade", 1 },
            .{ "initialize", "call_initialize", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "define",
            "get",
            "getName",
            "whenDefined",
            "upgrade",
            "initialize",
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
            _internal: ?*CustomElementRegistryImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_define = &call_define,
        .call_get = &call_get,
        .call_getName = &call_getName,
        .call_initialize = &call_initialize,
        .call_upgrade = &call_upgrade,
        .call_whenDefined = &call_whenDefined,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CustomElementRegistry has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CustomElementRegistryImpl, "init") and @hasDecl(CustomElementRegistryImpl, "initOwn")) @compileError("CustomElementRegistryImpl defines both init and initOwn");
        if (comptime @hasDecl(CustomElementRegistryImpl, "init")) return CustomElementRegistryImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(CustomElementRegistryImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try CustomElementRegistryImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CustomElementRegistryImpl, "init")) return false;
        if (comptime @hasDecl(CustomElementRegistryImpl, "construction_args")) {
            inline for (CustomElementRegistryImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CustomElementRegistryImpl, "deinit") and @hasDecl(CustomElementRegistryImpl, "deinitOwn")) @compileError("CustomElementRegistryImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CustomElementRegistryImpl, "deinit")) return CustomElementRegistryImpl.deinit(instance);
        if (comptime @hasDecl(CustomElementRegistryImpl, "deinitOwn")) CustomElementRegistryImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CustomElementRegistry")) {
            if (comptime @hasDecl(impls.CustomElementRegistry, "installHooks")) impls.CustomElementRegistry.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CustomElementRegistryImpl.call_constructor(ctx);
    }

    pub fn call_whenDefined(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
        return try CustomElementRegistryImpl.call_whenDefined(instance, name);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
        return try CustomElementRegistryImpl.call_get(instance, name);
    }

    pub fn call_getName(instance: *runtime.Instance, constructor: CustomElementConstructor) anyerror!?runtime.DOMString {
        return try CustomElementRegistryImpl.call_getName(instance, constructor);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_define(instance: *runtime.Instance, name: runtime.DOMString, constructor: CustomElementConstructor, options: webidl.Opt(ElementDefinitionOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try CustomElementRegistryImpl.call_define(instance, name, constructor, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_initialize(instance: *runtime.Instance, root: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try CustomElementRegistryImpl.call_initialize(instance, root);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_upgrade(instance: *runtime.Instance, root: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try CustomElementRegistryImpl.call_upgrade(instance, root);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_initialize", 0, "Node" },
        .{ "call_upgrade", 0, "Node" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_whenDefined",
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "call_define",
        "call_initialize",
        "call_upgrade",
    };
};
