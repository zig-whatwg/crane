//! Generated from: speech-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechGrammarImpl = @import("impls").SpeechGrammar;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const SpeechGrammar = struct {
    pub const Meta = struct {
        pub const name = "SpeechGrammar";
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
            .{ "src", "get_src", "set_src" },
            .{ "weight", "get_weight", "set_weight" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "src", "get_src", "set_src" },
            .{ "weight", "get_weight", "set_weight" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            src: runtime.DOMString = undefined,
            weight: f32 = undefined,
            _internal: ?*SpeechGrammarImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_src = &get_src,
        .get_weight = &get_weight,

        .set_src = &set_src,
        .set_weight = &set_weight,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SpeechGrammar has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SpeechGrammarImpl, "init") and @hasDecl(SpeechGrammarImpl, "initOwn")) @compileError("SpeechGrammarImpl defines both init and initOwn");
        if (comptime @hasDecl(SpeechGrammarImpl, "init")) return SpeechGrammarImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SpeechGrammarImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SpeechGrammarImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SpeechGrammarImpl, "init")) return false;
        if (comptime @hasDecl(SpeechGrammarImpl, "construction_args")) {
            inline for (SpeechGrammarImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SpeechGrammarImpl, "deinit") and @hasDecl(SpeechGrammarImpl, "deinitOwn")) @compileError("SpeechGrammarImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SpeechGrammarImpl, "deinit")) return SpeechGrammarImpl.deinit(instance);
        if (comptime @hasDecl(SpeechGrammarImpl, "deinitOwn")) SpeechGrammarImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SpeechGrammar")) {
            if (comptime @hasDecl(impls.SpeechGrammar, "installHooks")) impls.SpeechGrammar.installHooks();
        }
    }

    pub fn get_src(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SpeechGrammarImpl.get_src(instance);
    }

    pub fn set_src(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try SpeechGrammarImpl.set_src(instance, value);
    }

    pub fn get_weight(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechGrammarImpl.get_weight(instance);
    }

    pub fn set_weight(instance: *runtime.Instance, value: f32) anyerror!void {
        try SpeechGrammarImpl.set_weight(instance, value);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_weight", 0b1 },
    };
};
