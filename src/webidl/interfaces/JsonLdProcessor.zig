//! Generated from: json-ld-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const JsonLdProcessorImpl = @import("impls").JsonLdProcessor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const RdfDataset = @import("interfaces").RdfDataset;
const JsonLdOptions = @import("dictionaries").JsonLdOptions;
const JsonLdInput = @import("typedefs").JsonLdInput;
const JsonLdRecord = @import("typedefs").JsonLdRecord;
const JsonLdContext = @import("typedefs").JsonLdContext;

pub const JsonLdProcessor = struct {
    pub const Meta = struct {
        pub const name = "JsonLdProcessor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "JsonLd" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .JsonLd = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "compact", "call_static_compact", 1 },
            .{ "expand", "call_static_expand", 1 },
            .{ "flatten", "call_static_flatten", 1 },
            .{ "fromRdf", "call_static_fromRdf", 1 },
            .{ "toRdf", "call_static_toRdf", 1 },
            .{ "frame", "call_static_frame", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "compact",
            "expand",
            "flatten",
            "fromRdf",
            "toRdf",
            "frame",
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
            _internal: ?*JsonLdProcessorImpl.InternalState = null,
        },
    );

    const delegates = .{
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
            if (comptime !takesConstructionArg(field.name)) @compileError("JsonLdProcessor has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(JsonLdProcessorImpl, "init") and @hasDecl(JsonLdProcessorImpl, "initOwn")) @compileError("JsonLdProcessorImpl defines both init and initOwn");
        if (comptime @hasDecl(JsonLdProcessorImpl, "init")) return JsonLdProcessorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(JsonLdProcessorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try JsonLdProcessorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(JsonLdProcessorImpl, "init")) return false;
        if (comptime @hasDecl(JsonLdProcessorImpl, "construction_args")) {
            inline for (JsonLdProcessorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(JsonLdProcessorImpl, "deinit") and @hasDecl(JsonLdProcessorImpl, "deinitOwn")) @compileError("JsonLdProcessorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(JsonLdProcessorImpl, "deinit")) return JsonLdProcessorImpl.deinit(instance);
        if (comptime @hasDecl(JsonLdProcessorImpl, "deinitOwn")) JsonLdProcessorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "JsonLdProcessor")) {
            if (comptime @hasDecl(impls.JsonLdProcessor, "installHooks")) impls.JsonLdProcessor.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try JsonLdProcessorImpl.call_constructor(ctx);
    }

    pub fn call_static_compact(instance: *runtime.Instance, input: JsonLdInput, context: webidl.Opt(JsonLdContext), options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        return try JsonLdProcessorImpl.call_static_compact(instance, input, context, options);
    }

    pub fn call_static_fromRdf(instance: *runtime.Instance, input: *runtime.Instance, options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        return try JsonLdProcessorImpl.call_static_fromRdf(instance, input, options);
    }

    pub fn call_static_toRdf(instance: *runtime.Instance, input: JsonLdInput, options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        return try JsonLdProcessorImpl.call_static_toRdf(instance, input, options);
    }

    pub fn call_static_expand(instance: *runtime.Instance, input: JsonLdInput, options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        return try JsonLdProcessorImpl.call_static_expand(instance, input, options);
    }

    pub fn call_static_frame(instance: *runtime.Instance, input: JsonLdInput, frame: JsonLdInput, options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        return try JsonLdProcessorImpl.call_static_frame(instance, input, frame, options);
    }

    pub fn call_static_flatten(instance: *runtime.Instance, input: JsonLdInput, context: webidl.Opt(JsonLdContext), options: webidl.Opt(JsonLdOptions)) anyerror!runtime.JSValue {
        return try JsonLdProcessorImpl.call_static_flatten(instance, input, context, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_static_compact",
        "call_static_fromRdf",
        "call_static_toRdf",
        "call_static_expand",
        "call_static_frame",
        "call_static_flatten",
    };
};
