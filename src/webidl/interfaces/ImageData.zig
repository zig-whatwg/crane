//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ImageDataImpl = @import("impls").ImageData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PredefinedColorSpace = @import("enums").PredefinedColorSpace;
const ImageDataArray = @import("typedefs").ImageDataArray;
const ImageDataSettings = @import("dictionaries").ImageDataSettings;
const ImageDataPixelFormat = @import("enums").ImageDataPixelFormat;

pub const ImageData = struct {
    pub const Meta = struct {
        pub const name = "ImageData";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "data", "get_data", null },
            .{ "pixelFormat", "get_pixelFormat", null },
            .{ "colorSpace", "get_colorSpace", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "data", "get_data", null },
            .{ "pixelFormat", "get_pixelFormat", null },
            .{ "colorSpace", "get_colorSpace", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            width: u32 = undefined,
            height: u32 = undefined,
            data: typedefs.ImageDataArray = undefined,
            pixelFormat: enums.ImageDataPixelFormat = undefined,
            colorSpace: enums.PredefinedColorSpace = undefined,
            _internal: ?*ImageDataImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_colorSpace = &get_colorSpace,
        .get_data = &get_data,
        .get_height = &get_height,
        .get_pixelFormat = &get_pixelFormat,
        .get_width = &get_width,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ImageData has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ImageDataImpl, "init") and @hasDecl(ImageDataImpl, "initOwn")) @compileError("ImageDataImpl defines both init and initOwn");
        if (comptime @hasDecl(ImageDataImpl, "init")) return ImageDataImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ImageDataImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ImageDataImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ImageDataImpl, "init")) return false;
        if (comptime @hasDecl(ImageDataImpl, "construction_args")) {
            inline for (ImageDataImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ImageDataImpl, "deinit") and @hasDecl(ImageDataImpl, "deinitOwn")) @compileError("ImageDataImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ImageDataImpl, "deinit")) return ImageDataImpl.deinit(instance);
        if (comptime @hasDecl(ImageDataImpl, "deinitOwn")) ImageDataImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ImageData")) {
            if (comptime @hasDecl(impls.ImageData, "installHooks")) impls.ImageData.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: ImageData is [Serializable].

    /// ImageData's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").ImageData.serializationSteps(value, serialized);
    }

    /// ImageData's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").ImageData.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// ImageData, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// ImageData's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "ImageData")) break :blk false;
        break :blk @hasDecl(impls.ImageData, "serializationSteps") and @hasDecl(impls.ImageData, "deserializationSteps");
    };

    pub const constructor_required_arguments: usize = 2;

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(sw, sh, settings)
        unsigned_long_unsigned_long_ImageDataSettings: struct {
            sw: u32,
            sh: u32,
            settings: webidl.Opt(ImageDataSettings),
        },
        /// constructor(data, sw, sh, settings)
        ImageDataArray_unsigned_long_unsigned_long_ImageDataSettings: struct {
            data: ImageDataArray,
            sw: u32,
            sh: webidl.Opt(u32),
            settings: webidl.Opt(ImageDataSettings),
        },
    };

    /// WebIDL overload set of the constructor: one entry per variant of
    /// ConstructorArgs, in its order, for the overload resolution algorithm
    /// (webidl.overload_resolution) the binding runs to pick the variant.
    pub const constructor_overloads = &[_]webidl.overload_resolution.Overload{
        .{ .function = "unsigned_long_unsigned_long_ImageDataSettings", .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        .{ .function = "ImageDataArray_unsigned_long_unsigned_long_ImageDataSettings", .args = &.{ .{ .kinds = &.{ .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "Float16Array" } } }, .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric}, .optionality = .optional }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try ImageDataImpl.call_constructor(ctx, args);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try ImageDataImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try ImageDataImpl.get_height(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!ImageDataArray {
        return try ImageDataImpl.get_data(instance);
    }

    pub fn get_pixelFormat(instance: *runtime.Instance) anyerror!ImageDataPixelFormat {
        return try ImageDataImpl.get_pixelFormat(instance);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!PredefinedColorSpace {
        return try ImageDataImpl.get_colorSpace(instance);
    }
};
