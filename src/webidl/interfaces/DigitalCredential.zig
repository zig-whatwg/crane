//! Generated from: digital-credentials.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DigitalCredentialImpl = @import("impls").DigitalCredential;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Credential = @import("interfaces").Credential;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const DigitalCredential = struct {
    pub const Meta = struct {
        pub const name = "DigitalCredential";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Credential.State;
        pub const ParentInterface = Credential;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "protocol", "get_protocol", null },
            .{ "data", "get_data", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "userAgentAllowsProtocol", "call_static_userAgentAllowsProtocol", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toJSON",
            "userAgentAllowsProtocol",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "isConditionalMediationAvailable",
            "willRequestConditionalCreation",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "protocol", "get_protocol", null },
            .{ "data", "get_data", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            protocol: typedefs.DOMString = undefined,
            data: runtime.JSValue = undefined,
            cached_data: ?runtime.JSValue = null,
            _internal: ?*DigitalCredentialImpl.InternalState = null,
        },
    );

    // ========================================
    // ToJSON Struct ([Default] toJSON result)
    // ========================================

    /// ToJSON result struct for DigitalCredential
    /// Generated from [Default] toJSON extended attribute
    pub const DigitalCredentialToJSON = struct {
        id: runtime.USVString,
        type: runtime.DOMString,
        protocol: runtime.DOMString,
        data: runtime.JSValue,

        pub const default_to_json = true;
    };

    const delegates = .{
        .get_data = &get_data,
        .get_protocol = &get_protocol,

        .call_toJSON = &call_toJSON,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("DigitalCredential has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(DigitalCredentialImpl, "init") and @hasDecl(DigitalCredentialImpl, "initOwn")) @compileError("DigitalCredentialImpl defines both init and initOwn");
        if (comptime @hasDecl(DigitalCredentialImpl, "init")) return DigitalCredentialImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(DigitalCredentialImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try DigitalCredentialImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DigitalCredentialImpl, "init")) return false;
        if (comptime @hasDecl(DigitalCredentialImpl, "construction_args")) {
            inline for (DigitalCredentialImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(DigitalCredentialImpl, "deinit") and @hasDecl(DigitalCredentialImpl, "deinitOwn")) @compileError("DigitalCredentialImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(DigitalCredentialImpl, "deinit")) return DigitalCredentialImpl.deinit(instance);
        if (comptime @hasDecl(DigitalCredentialImpl, "deinitOwn")) DigitalCredentialImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DigitalCredential")) {
            if (comptime @hasDecl(impls.DigitalCredential, "installHooks")) impls.DigitalCredential.installHooks();
        }
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!DOMString {
        return try DigitalCredentialImpl.get_protocol(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try DigitalCredentialImpl.get_data(instance);
    }

    pub fn call_static_userAgentAllowsProtocol(instance: *runtime.Instance, protocol: DOMString) anyerror!bool {
        return try DigitalCredentialImpl.call_static_userAgentAllowsProtocol(instance, protocol);
    }

    /// Extended attributes: [Default]
    pub fn call_toJSON(instance: *runtime.Instance) anyerror!DigitalCredentialToJSON {
        return try DigitalCredentialImpl.call_toJSON(instance);
    }
};
