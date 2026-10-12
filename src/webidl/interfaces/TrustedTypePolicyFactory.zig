//! Generated from: trusted-types.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TrustedTypePolicyFactoryImpl = @import("impls").TrustedTypePolicyFactory;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const TrustedTypePolicyOptions = @import("dictionaries").TrustedTypePolicyOptions;
const TrustedHTML = @import("interfaces").TrustedHTML;
const TrustedScript = @import("interfaces").TrustedScript;
const TrustedTypePolicy = @import("interfaces").TrustedTypePolicy;
const DOMString = @import("typedefs").DOMString;

pub const TrustedTypePolicyFactory = struct {
    pub const Meta = struct {
        pub const name = "TrustedTypePolicyFactory";
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
            .{ "emptyHTML", "get_emptyHTML", null },
            .{ "emptyScript", "get_emptyScript", null },
            .{ "defaultPolicy", "get_defaultPolicy", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createPolicy", "call_createPolicy", 1 },
            .{ "isHTML", "call_isHTML", 1 },
            .{ "isScript", "call_isScript", 1 },
            .{ "isScriptURL", "call_isScriptURL", 1 },
            .{ "getAttributeType", "call_getAttributeType", 2 },
            .{ "getPropertyType", "call_getPropertyType", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createPolicy",
            "isHTML",
            "isScript",
            "isScriptURL",
            "getAttributeType",
            "getPropertyType",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "emptyHTML", "get_emptyHTML", null },
            .{ "emptyScript", "get_emptyScript", null },
            .{ "defaultPolicy", "get_defaultPolicy", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            emptyHTML: *runtime.Instance = undefined,
            emptyScript: *runtime.Instance = undefined,
            defaultPolicy: ?*runtime.Instance = null,
            _internal: ?*TrustedTypePolicyFactoryImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_defaultPolicy = &get_defaultPolicy,
        .get_emptyHTML = &get_emptyHTML,
        .get_emptyScript = &get_emptyScript,

        .call_createPolicy = &call_createPolicy,
        .call_getAttributeType = &call_getAttributeType,
        .call_getPropertyType = &call_getPropertyType,
        .call_isHTML = &call_isHTML,
        .call_isScript = &call_isScript,
        .call_isScriptURL = &call_isScriptURL,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("TrustedTypePolicyFactory has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(TrustedTypePolicyFactoryImpl, "init") and @hasDecl(TrustedTypePolicyFactoryImpl, "initOwn")) @compileError("TrustedTypePolicyFactoryImpl defines both init and initOwn");
        if (comptime @hasDecl(TrustedTypePolicyFactoryImpl, "init")) return TrustedTypePolicyFactoryImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TrustedTypePolicyFactoryImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TrustedTypePolicyFactoryImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TrustedTypePolicyFactoryImpl, "init")) return false;
        if (comptime @hasDecl(TrustedTypePolicyFactoryImpl, "construction_args")) {
            inline for (TrustedTypePolicyFactoryImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TrustedTypePolicyFactoryImpl, "deinit") and @hasDecl(TrustedTypePolicyFactoryImpl, "deinitOwn")) @compileError("TrustedTypePolicyFactoryImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TrustedTypePolicyFactoryImpl, "deinit")) return TrustedTypePolicyFactoryImpl.deinit(instance);
        if (comptime @hasDecl(TrustedTypePolicyFactoryImpl, "deinitOwn")) TrustedTypePolicyFactoryImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "TrustedTypePolicyFactory")) {
            if (comptime @hasDecl(impls.TrustedTypePolicyFactory, "installHooks")) impls.TrustedTypePolicyFactory.installHooks();
        }
    }

    pub fn get_emptyHTML(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TrustedTypePolicyFactoryImpl.get_emptyHTML(instance);
    }

    pub fn get_emptyScript(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TrustedTypePolicyFactoryImpl.get_emptyScript(instance);
    }

    pub fn get_defaultPolicy(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TrustedTypePolicyFactoryImpl.get_defaultPolicy(instance);
    }

    pub fn call_getPropertyType(instance: *runtime.Instance, tagName: DOMString, property: DOMString, elementNs: webidl.Opt(?DOMString)) anyerror!?DOMString {
        return try TrustedTypePolicyFactoryImpl.call_getPropertyType(instance, tagName, property, elementNs);
    }

    pub fn call_createPolicy(instance: *runtime.Instance, policyName: DOMString, policyOptions: webidl.Opt(TrustedTypePolicyOptions)) anyerror!*runtime.Instance {
        return try TrustedTypePolicyFactoryImpl.call_createPolicy(instance, policyName, policyOptions);
    }

    pub fn call_isHTML(instance: *runtime.Instance, value: runtime.JSValue) anyerror!bool {
        return try TrustedTypePolicyFactoryImpl.call_isHTML(instance, value);
    }

    pub fn call_isScript(instance: *runtime.Instance, value: runtime.JSValue) anyerror!bool {
        return try TrustedTypePolicyFactoryImpl.call_isScript(instance, value);
    }

    pub fn call_getAttributeType(instance: *runtime.Instance, tagName: DOMString, attribute: DOMString, elementNs: webidl.Opt(?DOMString), attrNs: webidl.Opt(?DOMString)) anyerror!?DOMString {
        return try TrustedTypePolicyFactoryImpl.call_getAttributeType(instance, tagName, attribute, elementNs, attrNs);
    }

    pub fn call_isScriptURL(instance: *runtime.Instance, value: runtime.JSValue) anyerror!bool {
        return try TrustedTypePolicyFactoryImpl.call_isScriptURL(instance, value);
    }
};
