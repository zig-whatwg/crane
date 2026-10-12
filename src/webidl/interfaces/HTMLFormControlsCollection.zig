//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLFormControlsCollectionImpl = @import("impls").HTMLFormControlsCollection;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLCollection = @import("interfaces").HTMLCollection;
const Element = @import("interfaces").Element;
const RadioNodeList = @import("interfaces").RadioNodeList;
const DOMString = @import("typedefs").DOMString;

pub const HTMLFormControlsCollection = struct {
    pub const Meta = struct {
        pub const name = "HTMLFormControlsCollection";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLCollection.State;
        pub const ParentInterface = HTMLCollection;
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
            .{ "namedItem", "call_namedItem", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "namedItem",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "item",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_item" },
            .named_getter = .{ .function = "call_namedItem" },
            .legacy_unenumerable_named_properties = true,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*HTMLFormControlsCollectionImpl.InternalState = null,
        },
    );

    const delegates = .{
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
            if (comptime !takesConstructionArg(field.name)) @compileError("HTMLFormControlsCollection has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(HTMLFormControlsCollectionImpl, "init") and @hasDecl(HTMLFormControlsCollectionImpl, "initOwn")) @compileError("HTMLFormControlsCollectionImpl defines both init and initOwn");
        if (comptime @hasDecl(HTMLFormControlsCollectionImpl, "init")) return HTMLFormControlsCollectionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(HTMLFormControlsCollectionImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try HTMLFormControlsCollectionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HTMLFormControlsCollectionImpl, "init")) return false;
        if (comptime @hasDecl(HTMLFormControlsCollectionImpl, "construction_args")) {
            inline for (HTMLFormControlsCollectionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HTMLFormControlsCollectionImpl, "deinit") and @hasDecl(HTMLFormControlsCollectionImpl, "deinitOwn")) @compileError("HTMLFormControlsCollectionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HTMLFormControlsCollectionImpl, "deinit")) return HTMLFormControlsCollectionImpl.deinit(instance);
        if (comptime @hasDecl(HTMLFormControlsCollectionImpl, "deinitOwn")) HTMLFormControlsCollectionImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLFormControlsCollection")) {
            if (comptime @hasDecl(impls.HTMLFormControlsCollection, "installHooks")) impls.HTMLFormControlsCollection.installHooks();
        }
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: DOMString) anyerror!?runtime.JSValue {
        return try HTMLFormControlsCollectionImpl.call_namedItem(instance, name);
    }

    pub const call_item = HTMLCollection.call_item;

    pub const get_length = HTMLCollection.get_length;

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return HTMLFormControlsCollectionImpl.getSupportedPropertyNames(instance, allocator);
    }
};
