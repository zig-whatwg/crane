//! Generated from: speech-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechSynthesisVoiceImpl = @import("impls").SpeechSynthesisVoice;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const SpeechSynthesisVoice = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesisVoice";
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
            .{ "voiceURI", "get_voiceURI", null },
            .{ "name", "get_name", null },
            .{ "lang", "get_lang", null },
            .{ "localService", "get_localService", null },
            .{ "default", "get_default", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "voiceURI", "get_voiceURI", null },
            .{ "name", "get_name", null },
            .{ "lang", "get_lang", null },
            .{ "localService", "get_localService", null },
            .{ "default", "get_default", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            voiceURI: typedefs.DOMString = undefined,
            name: typedefs.DOMString = undefined,
            lang: typedefs.DOMString = undefined,
            localService: bool = undefined,
            default: bool = undefined,
            _internal: ?*SpeechSynthesisVoiceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_default = &get_default,
        .get_lang = &get_lang,
        .get_localService = &get_localService,
        .get_name = &get_name,
        .get_voiceURI = &get_voiceURI,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SpeechSynthesisVoice has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SpeechSynthesisVoiceImpl, "init") and @hasDecl(SpeechSynthesisVoiceImpl, "initOwn")) @compileError("SpeechSynthesisVoiceImpl defines both init and initOwn");
        if (comptime @hasDecl(SpeechSynthesisVoiceImpl, "init")) return SpeechSynthesisVoiceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SpeechSynthesisVoiceImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SpeechSynthesisVoiceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SpeechSynthesisVoiceImpl, "init")) return false;
        if (comptime @hasDecl(SpeechSynthesisVoiceImpl, "construction_args")) {
            inline for (SpeechSynthesisVoiceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SpeechSynthesisVoiceImpl, "deinit") and @hasDecl(SpeechSynthesisVoiceImpl, "deinitOwn")) @compileError("SpeechSynthesisVoiceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SpeechSynthesisVoiceImpl, "deinit")) return SpeechSynthesisVoiceImpl.deinit(instance);
        if (comptime @hasDecl(SpeechSynthesisVoiceImpl, "deinitOwn")) SpeechSynthesisVoiceImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SpeechSynthesisVoice")) {
            if (comptime @hasDecl(impls.SpeechSynthesisVoice, "installHooks")) impls.SpeechSynthesisVoice.installHooks();
        }
    }

    pub fn get_voiceURI(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisVoiceImpl.get_voiceURI(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisVoiceImpl.get_name(instance);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisVoiceImpl.get_lang(instance);
    }

    pub fn get_localService(instance: *runtime.Instance) anyerror!bool {
        return try SpeechSynthesisVoiceImpl.get_localService(instance);
    }

    pub fn get_default(instance: *runtime.Instance) anyerror!bool {
        return try SpeechSynthesisVoiceImpl.get_default(instance);
    }
};
