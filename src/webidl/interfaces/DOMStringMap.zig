//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMStringMapImpl = @import("impls").DOMStringMap;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const DOMStringMap = struct {
    pub const Meta = struct {
        pub const name = "DOMStringMap";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyOverrideBuiltIns" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .named_getter = .{ .function = "call_getter", .implemented = @hasDecl(DOMStringMapImpl, "call_getter") },
            .named_setter = .{ .function = "call_setter", .implemented = @hasDecl(DOMStringMapImpl, "call_setter") },
            .named_deleter = .{ .function = "call_deleter", .implemented = @hasDecl(DOMStringMapImpl, "call_deleter") },
            .legacy_override_built_ins = true,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*DOMStringMapImpl.InternalState = null,
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
            if (comptime !takesConstructionArg(field.name)) @compileError("DOMStringMap has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(DOMStringMapImpl, "init") and @hasDecl(DOMStringMapImpl, "initOwn")) @compileError("DOMStringMapImpl defines both init and initOwn");
        if (comptime @hasDecl(DOMStringMapImpl, "init")) return DOMStringMapImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(DOMStringMapImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try DOMStringMapImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DOMStringMapImpl, "init")) return false;
        if (comptime @hasDecl(DOMStringMapImpl, "construction_args")) {
            inline for (DOMStringMapImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(DOMStringMapImpl, "deinit") and @hasDecl(DOMStringMapImpl, "deinitOwn")) @compileError("DOMStringMapImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DOMStringMapImpl, "deinit")) return DOMStringMapImpl.deinit(instance);
        if (comptime @hasDecl(DOMStringMapImpl, "deinitOwn")) DOMStringMapImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DOMStringMap")) {
            if (comptime @hasDecl(impls.DOMStringMap, "installHooks")) impls.DOMStringMap.installHooks();
        }
    }

    pub fn call_getter(instance: *runtime.Instance, name: DOMString) anyerror!DOMString {
        if (comptime @hasDecl(DOMStringMapImpl, "call_getter")) {
            return try DOMStringMapImpl.call_getter(instance, name);
        } else {
            return error.NotImplemented;
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setter(instance: *runtime.Instance, name: DOMString, value: DOMString) anyerror!void {
        if (comptime @hasDecl(DOMStringMapImpl, "call_setter")) {
            // [CEReactions] - Trigger Custom Element lifecycle callbacks
            const ce_scope = runtime.CEReactions.begin(instance);
            defer runtime.CEReactions.end(ce_scope);

            return try DOMStringMapImpl.call_setter(instance, name, value);
        } else {
            return error.NotImplemented;
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleter(instance: *runtime.Instance, name: DOMString) anyerror!void {
        if (comptime @hasDecl(DOMStringMapImpl, "call_deleter")) {
            // [CEReactions] - Trigger Custom Element lifecycle callbacks
            const ce_scope = runtime.CEReactions.begin(instance);
            defer runtime.CEReactions.end(ce_scope);

            return try DOMStringMapImpl.call_deleter(instance, name);
        } else {
            return error.NotImplemented;
        }
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "call_setter",
        "call_deleter",
    };

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return DOMStringMapImpl.getSupportedPropertyNames(instance, allocator);
    }
};
