//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PluginImpl = @import("impls").Plugin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MimeType = @import("interfaces").MimeType;
const DOMString = @import("typedefs").DOMString;

pub const Plugin = struct {
    pub const Meta = struct {
        pub const name = "Plugin";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyUnenumerableNamedProperties" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "description", "get_description", null },
            .{ "filename", "get_filename", null },
            .{ "length", "get_length", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "namedItem", "call_namedItem", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "namedItem",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "description", "get_description", null },
            .{ "filename", "get_filename", null },
            .{ "length", "get_length", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_item" },
            .named_getter = .{ .function = "call_namedItem" },
            .supported_property_name = .{ .function = "isSupportedPropertyName", .implemented = @hasDecl(PluginImpl, "isSupportedPropertyName") },
            .legacy_unenumerable_named_properties = true,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.DOMString = undefined,
            description: typedefs.DOMString = undefined,
            filename: typedefs.DOMString = undefined,
            length: u32 = undefined,
            _internal: ?*PluginImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_description = &get_description,
        .get_filename = &get_filename,
        .get_length = &get_length,
        .get_name = &get_name,

        .call_item = &call_item,
        .call_namedItem = &call_namedItem,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Plugin has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PluginImpl, "init") and @hasDecl(PluginImpl, "initOwn")) @compileError("PluginImpl defines both init and initOwn");
        if (comptime @hasDecl(PluginImpl, "init")) return PluginImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(PluginImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try PluginImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PluginImpl, "init")) return false;
        if (comptime @hasDecl(PluginImpl, "construction_args")) {
            inline for (PluginImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PluginImpl, "deinit") and @hasDecl(PluginImpl, "deinitOwn")) @compileError("PluginImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PluginImpl, "deinit")) return PluginImpl.deinit(instance);
        if (comptime @hasDecl(PluginImpl, "deinitOwn")) PluginImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Plugin")) {
            if (comptime @hasDecl(impls.Plugin, "installHooks")) impls.Plugin.installHooks();
        }
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PluginImpl.get_name(instance);
    }

    pub fn get_description(instance: *runtime.Instance) anyerror!DOMString {
        return try PluginImpl.get_description(instance);
    }

    pub fn get_filename(instance: *runtime.Instance) anyerror!DOMString {
        return try PluginImpl.get_filename(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try PluginImpl.get_length(instance);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: DOMString) anyerror!?*runtime.Instance {
        return try PluginImpl.call_namedItem(instance, name);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
        return try PluginImpl.call_item(instance, index);
    }

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return PluginImpl.getSupportedPropertyNames(instance, allocator);
    }

    /// Whether `name` is one of the supported property names (WebIDL 3.9.7
    /// step 1, asked for one name), answered without building the list. Gated:
    /// error.NotImplemented until the impl declares it, and
    /// Meta.special_operations.supported_property_name says whether it does -
    /// without it the binding searches getSupportedPropertyNames' list.
    pub fn isSupportedPropertyName(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
        if (comptime @hasDecl(PluginImpl, "isSupportedPropertyName")) {
            return try PluginImpl.isSupportedPropertyName(instance, name);
        } else {
            return error.NotImplemented;
        }
    }
};
