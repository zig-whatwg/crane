//! Generated from: wasm-js-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ExceptionImpl = @import("impls").Exception;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ExceptionOptions = @import("dictionaries").ExceptionOptions;
const Tag = @import("interfaces").Tag;
const DOMString = @import("typedefs").DOMString;

pub const Exception = struct {
    pub const Meta = struct {
        pub const name = "Exception";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "LegacyNamespace", .value = .{ .identifier = "WebAssembly" } },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "Worklet" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .Worklet = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "stack", "get_stack", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getArg", "call_getArg", 2 },
            .{ "is", "call_is", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getArg",
            "is",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "stack", "get_stack", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            stack: union(enum) {
                DOMString: runtime.DOMString,
                undefined: void,
            } = undefined,
            _internal: ?*ExceptionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_stack = &get_stack,

        .call_getArg = &call_getArg,
        .call_is = &call_is,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Exception has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ExceptionImpl, "init") and @hasDecl(ExceptionImpl, "initOwn")) @compileError("ExceptionImpl defines both init and initOwn");
        if (comptime @hasDecl(ExceptionImpl, "init")) return ExceptionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ExceptionImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ExceptionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ExceptionImpl, "init")) return false;
        if (comptime @hasDecl(ExceptionImpl, "construction_args")) {
            inline for (ExceptionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ExceptionImpl, "deinit") and @hasDecl(ExceptionImpl, "deinitOwn")) @compileError("ExceptionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ExceptionImpl, "deinit")) return ExceptionImpl.deinit(instance);
        if (comptime @hasDecl(ExceptionImpl, "deinitOwn")) ExceptionImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Exception")) {
            if (comptime @hasDecl(impls.Exception, "installHooks")) impls.Exception.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 2;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, exceptionTag: *runtime.Instance, payload: runtime.JSValue, options: webidl.Opt(ExceptionOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ExceptionImpl.call_constructor(ctx, exceptionTag, payload, options);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "Tag" },
    };

    pub fn get_stack(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ExceptionImpl.get_stack(instance);
    }

    pub fn call_getArg(instance: *runtime.Instance, exceptionTag: *runtime.Instance, index: u32) anyerror!runtime.JSValue {
        return try ExceptionImpl.call_getArg(instance, exceptionTag, index);
    }

    pub fn call_is(instance: *runtime.Instance, exceptionTag: *runtime.Instance) anyerror!bool {
        return try ExceptionImpl.call_is(instance, exceptionTag);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_getArg", 0, "Tag" },
        .{ "call_is", 0, "Tag" },
    };

    /// WebIDL [EnforceRange]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const enforce_range = .{
        .{ "call_getArg", 0b10 },
    };
};
