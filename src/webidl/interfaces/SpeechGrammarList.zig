//! Generated from: speech-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechGrammarListImpl = @import("impls").SpeechGrammarList;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SpeechGrammar = @import("interfaces").SpeechGrammar;
const DOMString = @import("typedefs").DOMString;

pub const SpeechGrammarList = struct {
    pub const Meta = struct {
        pub const name = "SpeechGrammarList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "addFromURI", "call_addFromURI", 1 },
            .{ "addFromString", "call_addFromString", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "addFromURI",
            "addFromString",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_item" },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            _internal: ?*SpeechGrammarListImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,

        .call_addFromString = &call_addFromString,
        .call_addFromURI = &call_addFromURI,
        .call_item = &call_item,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("SpeechGrammarList has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(SpeechGrammarListImpl, "init") and @hasDecl(SpeechGrammarListImpl, "initOwn")) @compileError("SpeechGrammarListImpl defines both init and initOwn");
        if (comptime @hasDecl(SpeechGrammarListImpl, "init")) return SpeechGrammarListImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SpeechGrammarListImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SpeechGrammarListImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SpeechGrammarListImpl, "init")) return false;
        if (comptime @hasDecl(SpeechGrammarListImpl, "construction_args")) {
            inline for (SpeechGrammarListImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SpeechGrammarListImpl, "deinit") and @hasDecl(SpeechGrammarListImpl, "deinitOwn")) @compileError("SpeechGrammarListImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SpeechGrammarListImpl, "deinit")) return SpeechGrammarListImpl.deinit(instance);
        if (comptime @hasDecl(SpeechGrammarListImpl, "deinitOwn")) SpeechGrammarListImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SpeechGrammarList")) {
            if (comptime @hasDecl(impls.SpeechGrammarList, "installHooks")) impls.SpeechGrammarList.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechGrammarListImpl.call_constructor(ctx);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechGrammarListImpl.get_length(instance);
    }

    pub fn call_addFromString(instance: *runtime.Instance, string: runtime.DOMString, weight: webidl.Opt(f32)) anyerror!void {
        return try SpeechGrammarListImpl.call_addFromString(instance, string, weight);
    }

    pub fn call_addFromURI(instance: *runtime.Instance, src: runtime.DOMString, weight: webidl.Opt(f32)) anyerror!void {
        return try SpeechGrammarListImpl.call_addFromURI(instance, src, weight);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
        return try SpeechGrammarListImpl.call_item(instance, index);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_addFromString", 0b10 },
        .{ "call_addFromURI", 0b10 },
    };
};
