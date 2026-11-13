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
    /// The names of the `-D` options the chosen adapter declared, in its
    /// order.
    option_names: []const []const u8,
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

    /// The rule that an option belongs to its adapter, run: for every OTHER
    /// listed adapter, one configure of this build root with `-Dengine=<it>`
    /// and each option this build's adapter declared - the configure step
    /// itself must refuse every one ("invalid option"), since only the chosen
    /// adapter is asked to declare. Each of `dependants` depends on them.
    /// Nothing is compiled: the configure fails before any step runs. An
    /// adapter with no option has nothing another build could be given.
    pub fn addOptionOwnershipChecks(engine: *const Engine, b: *std.Build, dependants: []const *std.Build.Step) void {
        if (engine.option_names.len == 0) return;
        inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |other| {
            if (!std.mem.eql(u8, other, @tagName(engine.name))) {
                const check = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "--list-steps", "-Dengine=" ++ other });
                check.setName(b.fmt("the {t} adapter's options are refused under -Dengine={s}", .{ engine.name, other }));
                for (engine.option_names) |option| {
                    check.addArg(b.fmt("-D{s}=1", .{option}));
                    check.expectStdErrMatch(b.fmt("invalid option: \"{s}\"", .{option}));
                }
                check.expectExitCode(1);
                // The parent's local cache; the global one travels in the
                // environment (the build command takes no --global-cache-dir).
                check.addArg("--cache-dir");
                check.addDirectoryArg2(std.Build.LazyPath.cache_root, .{ .make_absolute = true });
                check.setCwd(b.path("."));
                // The sub-configure decides; this step always asks it.
                check.has_side_effects = true;
                for (dependants) |dependant| dependant.dependOn(&check.step);
            }
        }
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

/// Whether `name` is a listed adapter's name.
fn isListed(name: []const u8) bool {
    return std.meta.stringToEnum(Name, name) != null;
}

/// Fail the configure when a directory under src/runtime/engines/ is not a
/// listed adapter. The list is what `-Dengine` offers, what the conformance
/// check holds to the interface and what the build-neutrality lint takes its
/// engine words from: an adapter's directory it lacks would be none of the
/// three, silently. (A listed adapter without its directory or its build
/// file cannot happen: the list imports the file.) The pattern of the root
/// build.zig's check that every test directory is a suite.
fn checkListIsComplete(b: *std.Build) void {
    // A configure-time read of the checkout the configure cache cannot track.
    b.graph.poisonCache();
    const io = b.graph.io;
    const engines_path = "src/runtime/engines";
    var engines = b.root.root_dir.handle.openDir(io, engines_path, .{ .iterate = true }) catch |err|
        std.debug.panic("the engine build protocol cannot open {s} to check its list of adapters: {t}", .{ engines_path, err });
    defer engines.close(io);
    var entries = engines.iterate();
    while (entries.next(io) catch |err| std.debug.panic("the engine build protocol cannot read {s}: {t}", .{ engines_path, err })) |entry| {
        if (entry.kind != .directory or isListed(entry.name)) continue;
        std.debug.panic(
            "{s}/{s}/ is an engine adapter the build protocol does not list: give it an engine_build.zig (the interface: src/runtime/engine_build_protocol.zig) and a line in that file's `adapters`",
            .{ engines_path, entry.name },
        );
    }
}

/// Declare `-Dengine`, ask ONLY the chosen adapter to declare its options
/// and to resolve what it links, and hand back the build's engine. Called
/// once, before anything links the engine.
pub fn choose(b: *std.Build, target: std.Build.ResolvedTarget) Engine {
    checkListIsComplete(b);
    const name = b.option(Name, "engine", "The JavaScript engine: the adapter this build binds (default: the target's)") orelse defaultFor(target.result);
    switch (name) {
        inline else => |tag| {
            const A = @field(adapters, @tagName(tag));
            const state = b.allocator.create(StateOf(A)) catch @panic("OOM");
            // What the adapter declares is what the options map gains.
            const declared_before = b.available_options_map.count();
            const options = A.declareOptions(b, target);
            const option_names = b.allocator.dupe([]const u8, b.available_options_map.keys()[declared_before..]) catch @panic("OOM");
            state.* = .{ .options = options, .resolution = A.resolve(b, target, options) };
            const unavailable: ?[]const u8 = switch (state.resolution) {
                .ready => null,
                .unavailable => |reason| reason,
            };
            return .{
                .name = tag,
                .unavailable = unavailable,
                .unavailable_step = if (unavailable) |reason| &b.addFail(reason).step else null,
                .option_names = option_names,
                .state = state,
                .vtable = vtableOf(A),
            };
        },
    }
}
