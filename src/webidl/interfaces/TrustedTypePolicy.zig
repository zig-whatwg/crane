//! Generated from: trusted-types.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TrustedTypePolicyImpl = @import("impls").TrustedTypePolicy;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TrustedHTML = @import("interfaces").TrustedHTML;
const TrustedScript = @import("interfaces").TrustedScript;
const TrustedScriptURL = @import("interfaces").TrustedScriptURL;
const DOMString = @import("typedefs").DOMString;

pub const TrustedTypePolicy = struct {
    pub const Meta = struct {
        pub const name = "TrustedTypePolicy";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createHTML", "call_createHTML", 1 },
            .{ "createScript", "call_createScript", 1 },
            .{ "createScriptURL", "call_createScriptURL", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createHTML",
            "createScript",
            "createScriptURL",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: runtime.DOMString = undefined,
            _internal: ?*TrustedTypePolicyImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_name = &get_name,

        .call_createHTML = &call_createHTML,
        .call_createScript = &call_createScript,
        .call_createScriptURL = &call_createScriptURL,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("TrustedTypePolicy has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TrustedTypePolicyImpl, "init") and @hasDecl(TrustedTypePolicyImpl, "initOwn")) @compileError("TrustedTypePolicyImpl defines both init and initOwn");
        if (comptime @hasDecl(TrustedTypePolicyImpl, "init")) return TrustedTypePolicyImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TrustedTypePolicyImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TrustedTypePolicyImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TrustedTypePolicyImpl, "init")) return false;
        if (comptime @hasDecl(TrustedTypePolicyImpl, "construction_args")) {
            inline for (TrustedTypePolicyImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TrustedTypePolicyImpl, "deinit") and @hasDecl(TrustedTypePolicyImpl, "deinitOwn")) @compileError("TrustedTypePolicyImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TrustedTypePolicyImpl, "deinit")) return TrustedTypePolicyImpl.deinit(instance);
        if (comptime @hasDecl(TrustedTypePolicyImpl, "deinitOwn")) TrustedTypePolicyImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TrustedTypePolicy")) {
            if (comptime @hasDecl(impls.TrustedTypePolicy, "installHooks")) impls.TrustedTypePolicy.installHooks();
        }
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TrustedTypePolicyImpl.get_name(instance);
    }

    pub fn call_createHTML(instance: *runtime.Instance, input: runtime.DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
        return try TrustedTypePolicyImpl.call_createHTML(instance, input, arguments);
    }

    pub fn call_createScript(instance: *runtime.Instance, input: runtime.DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
        return try TrustedTypePolicyImpl.call_createScript(instance, input, arguments);
    }

    pub fn call_createScriptURL(instance: *runtime.Instance, input: runtime.DOMString, arguments: []const runtime.JSValue) anyerror!*runtime.Instance {
        return try TrustedTypePolicyImpl.call_createScriptURL(instance, input, arguments);
    }
};
