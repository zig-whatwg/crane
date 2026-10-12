//! Generated from: ua-client-hints.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorUADataImpl = @import("impls").NavigatorUAData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const UADataValues = @import("dictionaries").UADataValues;
const NavigatorUABrandVersion = @import("dictionaries").NavigatorUABrandVersion;
const UALowEntropyJSON = @import("dictionaries").UALowEntropyJSON;
const DOMString = @import("typedefs").DOMString;

pub const NavigatorUAData = struct {
    pub const Meta = struct {
        pub const name = "NavigatorUAData";
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
            .{ "brands", "get_brands", null },
            .{ "mobile", "get_mobile", null },
            .{ "platform", "get_platform", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getHighEntropyValues", "call_getHighEntropyValues", 1 },
            .{ "toJSON", "call_toJSON", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getHighEntropyValues",
            "toJSON",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "brands", "get_brands", null },
            .{ "mobile", "get_mobile", null },
            .{ "platform", "get_platform", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            brands: runtime.JSValue = undefined,
            mobile: bool = undefined,
            platform: typedefs.DOMString = undefined,
            _internal: ?*NavigatorUADataImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_brands = &get_brands,
        .get_mobile = &get_mobile,
        .get_platform = &get_platform,

        .call_getHighEntropyValues = &call_getHighEntropyValues,
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
            if (comptime !takesConstructionArg(field.name)) @compileError("NavigatorUAData has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(NavigatorUADataImpl, "init") and @hasDecl(NavigatorUADataImpl, "initOwn")) @compileError("NavigatorUADataImpl defines both init and initOwn");
        if (comptime @hasDecl(NavigatorUADataImpl, "init")) return NavigatorUADataImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(NavigatorUADataImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try NavigatorUADataImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NavigatorUADataImpl, "init")) return false;
        if (comptime @hasDecl(NavigatorUADataImpl, "construction_args")) {
            inline for (NavigatorUADataImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(NavigatorUADataImpl, "deinit") and @hasDecl(NavigatorUADataImpl, "deinitOwn")) @compileError("NavigatorUADataImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(NavigatorUADataImpl, "deinit")) return NavigatorUADataImpl.deinit(instance);
        if (comptime @hasDecl(NavigatorUADataImpl, "deinitOwn")) NavigatorUADataImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NavigatorUAData")) {
            if (comptime @hasDecl(impls.NavigatorUAData, "installHooks")) impls.NavigatorUAData.installHooks();
        }
    }

    pub fn get_brands(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigatorUADataImpl.get_brands(instance);
    }

    pub fn get_mobile(instance: *runtime.Instance) anyerror!bool {
        return try NavigatorUADataImpl.get_mobile(instance);
    }

    pub fn get_platform(instance: *runtime.Instance) anyerror!DOMString {
        return try NavigatorUADataImpl.get_platform(instance);
    }

    pub fn call_getHighEntropyValues(instance: *runtime.Instance, hints: runtime.JSValue) anyerror!runtime.JSValue {
        return try NavigatorUADataImpl.call_getHighEntropyValues(instance, hints);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!UALowEntropyJSON {
        return try NavigatorUADataImpl.call_toJSON(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getHighEntropyValues",
    };
};
