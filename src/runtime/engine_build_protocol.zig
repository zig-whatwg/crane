//! THE BUILD SIDE OF THE ENGINE PROTOCOL (docs/engine-protocol.md, 7b).
//!
//! What is one engine's in the build - its `-D` options today; its sources,
//! link inputs, startup data and tests as the migration goes
//! (tmp/plans/build-protocol-design.md) - is declared by the engine's
//! adapter, in a build file beside its code,
//! `engines/<engine>/engine_build.zig`, and never by the root build.zig (the
//! user, 2026-11-12: "I don't want any of the v8 code in build.zig, the valid
//! flags should be in the js engine protocol"). This file is the protocol's
//! part: the list of adapters, `-Dengine`, the interface every adapter's
//! build file exports with the check that holds each to it, and the handle
//! the root build.zig asks. The root build names no adapter and no adapter's
//! option.
//!
//! What an adapter's build file exports (`checkAdapter` holds each one to
//! exactly these types, as engine_protocol.zig holds an adapter's
//! operations):
//!
//!   pub const Options = struct { ... };       // what the command line gave
//!   pub fn declareOptions(b: *std.Build, target: std.Build.ResolvedTarget) Options
//!   pub fn apply(options: Options, adapter_options: *std.Build.Step.Options) void
//!   pub fn applyTransitional(options: Options, shared: *std.Build.Step.Options) void
//!   pub fn isDefaultFor(target: std.Target) bool
//!   pub const Resolved = struct { ... };      // what this build links
//!   pub fn resolve(b: *std.Build, target: std.Build.ResolvedTarget, options: Options) Resolution(Resolved)
//!   pub const facts: Facts = .{ ... };
//!
//! An adapter that is not the build's engine is never asked to declare its
//! options, so they do not exist in that build: the configure step refuses
//! them by itself, as it refuses any `-D` nothing declared.
//!
//! Run by `zig build`'s configure step, not compiled into Crane: std and
//! build files only.
//!
//! (The list names each adapter's directory, so tools/lint_engine_boundary.zig
//! exempts this one file, and tools/lint_build_neutral.zig does not count it:
//! it is where the build side meets the adapters.)

const std = @import("std");

/// The engine adapters, by their `-Dengine` name: each one's build file. A
/// new adapter is a directory, a build file and a line here; Zig imports by
/// a literal path only, so one file has to list them, and it is this one.
pub const adapters = .{
    .v8 = @import("engines/v8/engine_build.zig"),
    .jsc = @import("engines/jsc/engine_build.zig"),
    .quickjs = @import("engines/quickjs/engine_build.zig"),
};

/// The values `-Dengine` takes: the list's own names.
pub const Name = std.meta.FieldEnum(@TypeOf(adapters));

/// What an adapter's `resolve` answers.
pub fn Resolution(comptime Resolved: type) type {
    return union(enum) {
        /// What this build links.
        ready: Resolved,
        /// The adapter cannot be built for this target, with these options or
        /// on this machine: the reason, as the user reads it. The build still
        /// configures; each step that needs the engine fails with it.
        unavailable: []const u8,
    };
}

/// What the neutral build asks about an adapter. It grows with the
/// migration: the adapter module's root file, the modules it imports, its
/// test directory.
pub const Facts = struct {
    /// The words that name this engine: what `zig build lint-build` looks for
    /// in the root build.zig and the neutral files it imports.
    words: []const []const u8,
};

// The build side's conformance check, as engine_protocol.zig's is for
// operations: an adapter whose build file lacks a declaration, or declares
// one with another type, does not configure - and the error names both.
comptime {
    for (std.meta.fieldNames(@TypeOf(adapters))) |name| checkAdapter(name, @field(adapters, name));
}

fn checkAdapter(comptime name: []const u8, comptime A: type) void {
    const who = "engine adapter '" ++ name ++ "' (src/runtime/engines/" ++ name ++ "/engine_build.zig)";
    for ([_][]const u8{ "Options", "Resolved" }) |decl| {
        if (!@hasDecl(A, decl) or @TypeOf(@field(A, decl)) != type) @compileError(who ++ " lacks `pub const " ++ decl ++ " = struct { ... };`");
    }
    conforms(who, A, "declareOptions", fn (*std.Build, std.Build.ResolvedTarget) A.Options);
    conforms(who, A, "apply", fn (A.Options, *std.Build.Step.Options) void);
    conforms(who, A, "applyTransitional", fn (A.Options, *std.Build.Step.Options) void);
    conforms(who, A, "isDefaultFor", fn (std.Target) bool);
    conforms(who, A, "resolve", fn (*std.Build, std.Build.ResolvedTarget, A.Options) Resolution(A.Resolved));
    if (!@hasDecl(A, "facts") or @TypeOf(A.facts) != Facts) @compileError(who ++ " lacks `pub const facts: engine_build.Facts`");
}

fn conforms(comptime who: []const u8, comptime A: type, comptime decl: []const u8, comptime Expected: type) void {
    if (!@hasDecl(A, decl)) @compileError(who ++ " lacks `" ++ decl ++ "`: " ++ @typeName(Expected));
    const Actual = @TypeOf(@field(A, decl));
    if (Actual != Expected) @compileError(who ++ ": `" ++ decl ++ "` is " ++ @typeName(Actual) ++ "; the build protocol's is " ++ @typeName(Expected));
}

/// Every listed adapter's words, comma-separated: the engine keys of
/// `zig build lint-build`, from the list itself - so the root build.zig spells
/// no engine to look for one, and a new adapter is covered the day it is
/// listed.
pub const lint_words: []const u8 = words: {
    var text: []const u8 = "";
    for (std.meta.fieldNames(@TypeOf(adapters))) |name| {
        for (@field(adapters, name).facts.words) |word| text = text ++ (if (text.len == 0) "" else ",") ++ word;
    }
    break :words text;
};

/// What `choose` keeps of the chosen adapter `A`.
fn StateOf(comptime A: type) type {
    return struct {
        options: A.Options,
        resolution: Resolution(A.Resolved),
    };
}

/// The build's engine: the chosen adapter, behind functions with no adapter
/// type in them.
pub const Engine = struct {
    /// The adapter this build binds.
    name: Name,
    /// Why this build's engine cannot be built for this target, with these
    /// options or on this machine; null when it can.
    unavailable: ?[]const u8,
    /// The step that fails with `unavailable`: every artifact that needs the
    /// engine depends on it (`failModule`). Null when the engine can be built.
    unavailable_step: ?*std.Build.Step,
    /// The chosen adapter's `StateOf`.
    state: *const anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        apply: *const fn (state: *const anyopaque, adapter_options: *std.Build.Step.Options) void,
        applyTransitional: *const fn (state: *const anyopaque, shared: *std.Build.Step.Options) void,
    };

    /// The adapter's own options module: its compile-time values, which only
    /// the engine adapter's module imports, as "adapter_options".
    pub fn adapterOptions(engine: *const Engine, b: *std.Build) *std.Build.Step.Options {
        const adapter_options = b.addOptions();
        engine.vtable.apply(engine.state, adapter_options);
        return adapter_options;
    }

    /// TRANSITIONAL (batch E5 of tmp/plans/build-protocol-design.md ends it):
    /// what the shared `build_options` still carries of the engine, written by
    /// the adapter with the names, the values and the order they always had.
    /// Call it where the root build.zig wrote them: after the module's
    /// neutral fields.
    pub fn applyTransitional(engine: *const Engine, shared: *std.Build.Step.Options) void {
        engine.vtable.applyTransitional(engine.state, shared);
    }

    /// Make every compile that takes `module` fail with the reason this
    /// build's engine cannot be built, and add nothing else to it: the module
    /// gets one empty C file that only a step depending on the failing one
    /// can produce. Only for an engine that is `unavailable`.
    pub fn failModule(engine: *const Engine, b: *std.Build, module: *std.Build.Module) void {
        const marker = b.addWriteFiles();
        marker.step.dependOn(engine.unavailable_step.?);
        module.addCSourceFile(.{ .file = marker.add("engine_unavailable.c", ""), .flags = &.{} });
    }

    /// TRANSITIONAL (batch E2 ends it, when the link lines that read it leave
    /// the root build.zig for the adapter): what the adapter `name` resolved,
    /// when it is this build's engine and can be built.
    pub fn resolvedOf(engine: *const Engine, comptime name: Name) ?*const @field(adapters, @tagName(name)).Resolved {
        if (engine.name != name) return null;
        const state: *const StateOf(@field(adapters, @tagName(name))) = @ptrCast(@alignCast(engine.state));
        return switch (state.resolution) {
            .ready => |*resolved| resolved,
            .unavailable => null,
        };
    }
};

fn vtableOf(comptime A: type) *const Engine.VTable {
    const State = StateOf(A);
    const functions = struct {
        fn apply(state: *const anyopaque, adapter_options: *std.Build.Step.Options) void {
            const typed: *const State = @ptrCast(@alignCast(state));
            A.apply(typed.options, adapter_options);
        }
        fn applyTransitional(state: *const anyopaque, shared: *std.Build.Step.Options) void {
            const typed: *const State = @ptrCast(@alignCast(state));
            A.applyTransitional(typed.options, shared);
        }
        const table: Engine.VTable = .{ .apply = apply, .applyTransitional = applyTransitional };
    };
    return &functions.table;
}

/// The engine of a build for `target` when -Dengine does not say: the first
/// listed adapter that claims the target.
fn defaultFor(target: std.Target) Name {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        if (@field(adapters, name).isDefaultFor(target)) return @field(Name, name);
    }
    std.debug.panic("no engine adapter is the default for a {t} target: pass -Dengine", .{target.os.tag});
}

/// Declare `-Dengine`, ask ONLY the chosen adapter to declare its options
/// and to resolve what it links, and hand back the build's engine. Called
/// once, before anything links the engine.
pub fn choose(b: *std.Build, target: std.Build.ResolvedTarget) Engine {
    const name = b.option(Name, "engine", "The JavaScript engine: the adapter this build binds (default: the target's)") orelse defaultFor(target.result);
    switch (name) {
        inline else => |tag| {
            const A = @field(adapters, @tagName(tag));
            const state = b.allocator.create(StateOf(A)) catch @panic("OOM");
            const options = A.declareOptions(b, target);
            state.* = .{ .options = options, .resolution = A.resolve(b, target, options) };
            const unavailable: ?[]const u8 = switch (state.resolution) {
                .ready => null,
                .unavailable => |reason| reason,
            };
            return .{
                .name = tag,
                .unavailable = unavailable,
                .unavailable_step = if (unavailable) |reason| &b.addFail(reason).step else null,
                .state = state,
                .vtable = vtableOf(A),
            };
        },
    }
}
