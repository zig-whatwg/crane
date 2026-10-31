//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StylePropertyMapImpl = @import("impls").StylePropertyMap;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const USVString = @import("typedefs").USVString;

pub const StylePropertyMap = struct {
    pub const Meta = struct {
        pub const name = "StylePropertyMap";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = StylePropertyMapReadOnly.State;
        pub const ParentInterface = StylePropertyMapReadOnly;
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
            .{ "set", "call_set", 1 },
            .{ "append", "call_append", 1 },
            .{ "delete", "call_delete", 1 },
            .{ "clear", "call_clear", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "set",
            "append",
            "delete",
            "clear",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "get",
            "getAll",
            "has",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*StylePropertyMapImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_append = &call_append,
        .call_clear = &call_clear,
        .call_delete = &call_delete,
        .call_set = &call_set,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("StylePropertyMap has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(StylePropertyMapImpl, "init") and @hasDecl(StylePropertyMapImpl, "initOwn")) @compileError("StylePropertyMapImpl defines both init and initOwn");
        if (comptime @hasDecl(StylePropertyMapImpl, "init")) return StylePropertyMapImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(StylePropertyMapImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try StylePropertyMapImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(StylePropertyMapImpl, "init")) return false;
        if (comptime @hasDecl(StylePropertyMapImpl, "construction_args")) {
            inline for (StylePropertyMapImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(StylePropertyMapImpl, "deinit") and @hasDecl(StylePropertyMapImpl, "deinitOwn")) @compileError("StylePropertyMapImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(StylePropertyMapImpl, "deinit")) return StylePropertyMapImpl.deinit(instance);
        if (comptime @hasDecl(StylePropertyMapImpl, "deinitOwn")) StylePropertyMapImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "StylePropertyMap")) {
            if (comptime @hasDecl(impls.StylePropertyMap, "installHooks")) impls.StylePropertyMap.installHooks();
        }
    }

    pub fn call_set(instance: *runtime.Instance, property: runtime.USVString, values: []const runtime.JSValue) anyerror!void {
        return try StylePropertyMapImpl.call_set(instance, property, values);
    }

    pub fn call_delete(instance: *runtime.Instance, property: runtime.USVString) anyerror!void {
        return try StylePropertyMapImpl.call_delete(instance, property);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try StylePropertyMapImpl.call_clear(instance);
    }

    pub fn call_append(instance: *runtime.Instance, property: runtime.USVString, values: []const runtime.JSValue) anyerror!void {
        return try StylePropertyMapImpl.call_append(instance, property, values);
    }
};
