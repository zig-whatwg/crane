//! THE BUILD SIDE OF THE PLATFORM PROTOCOL (docs/platform-protocol.md 10).
//!
//! What is one platform's in the build - which operating systems it answers
//! for, the extra kit parts it builds in and the system libraries each links -
//! is declared by the platform's adapter, in a build file beside its code,
//! `adapters/<platform>/platform_build.zig`, and never by the root build.zig
//! (the user, 2026-11-12: no engine or platform code in build.zig), as the
//! engine's adapters declare theirs (src/runtime/engine_build_protocol.zig).
//! This file is the protocol's part: the list of adapters, the platforms a
//! module graph binds (`Platform`) and the protocol's own options
//! (-Dplatform, -Dplatform-module, -Dplatform-without, -Dplatform-static:
//! `choose`), which adapter the tests bind (`tests_platform`), the
//! conformance test's bindings (`conformance`), the interface every
//! adapter's build file exports with the check that holds each to it, and
//! the words the build-neutrality lint looks for. The root build names no
//! platform and no library.
//!
//! What an adapter's build file exports (`checkAdapter` holds each one to
//! exactly these types):
//!
//!   pub fn ownsTarget(target: std.Target) bool
//!   pub fn kitParts(target: std.Target) []const KitPart
//!   pub const facts: Facts = .{ ... };
//!
//! and, asked of the adapter that answers for the target's operating system
//! (`ownsTarget`) whichever platform a graph binds - its "OS side":
//!
//!   pub const Options = struct { ... };     // its own -D options
//!   pub fn declareOptions(b: *std.Build) Options
//!   pub fn resolve(b: *std.Build, target: std.Build.ResolvedTarget, options: Options, probe: *std.Build.Step.Compile) void
//!   pub fn forwarded(b: *std.Build, options: Options) []const []const u8
//!   pub fn prepareC(target: std.Build.ResolvedTarget) ?kit.PrepareC
//!   pub fn linkArtifact(module: *std.Build.Module, target: std.Build.ResolvedTarget) void
//!   pub fn afterTestBuild(b: *std.Build, test_exe: *std.Build.Step.Compile, run: *std.Build.Step.Run, name: []const u8) void
//!   pub fn needsStandIns(target: std.Build.ResolvedTarget) bool
//!   pub fn addStandIns(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget) void
//!
//! and, asked of the adapter a graph binds:
//!
//!   pub fn bind(impl: *std.Build.Module, target: std.Build.ResolvedTarget, request: BindRequest) void
//!
//! A part is `src/platform/kit/<name>/root.zig`, a module the adapter
//! imports as `kit_<name>`, made with the platform facade and the platform
//! options as every kit part is, and linked against `system_libraries`.
//! kit/sqlite is the first (the user's ruling, 2026-11-21: SQLite on every
//! platform with a profile directory). A third-party platform
//! (-Dplatform-module) declares none here.
//!
//! Run by `zig build`'s configure step, not compiled into Crane: std and
//! build files only. (tools/lint_build_neutral.zig does not count it: it is
//! where the build side meets the adapters.)
const std = @import("std");

/// The platform adapters, by their -Dplatform name: each one's build file. A
/// new adapter is a directory, a build file and a line here; Zig imports by
/// a literal path only, so one file has to list them, and it is this one.
pub const adapters = .{
    .darwin = @import("adapters/darwin/platform_build.zig"),
    .linux = @import("adapters/linux/platform_build.zig"),
    .testing = @import("adapters/testing/platform_build.zig"),
};

/// The kit's build side: the C libraries the platform kit builds and links,
/// its options and its C header translations (kit/kit_build.zig). Every
/// platform composes the kit, so the root build reaches it here.
pub const kit = @import("kit/kit_build.zig");

/// The platform a module graph is built for (docs/platform-protocol.md 1.1):
/// a listed adapter, by its -Dplatform name, or `external` - the
/// implementation -Dplatform-module names. The values -Dplatform takes: the
/// list's names, in its order, then `external`.
pub const Platform = platform: {
    const listed = std.meta.fieldNames(@TypeOf(adapters));
    var names: [listed.len + 1][]const u8 = undefined;
    for (listed, 0..) |name, i| names[i] = name;
    names[listed.len] = "external";
    const frozen = names;
    const Tag = std.math.IntFittingRange(0, frozen.len - 1);
    break :platform @Enum(Tag, .exhaustive, &frozen, &std.simd.iota(Tag, frozen.len));
};

/// The adapter the test executables bind, and the WPT runners whose build
/// asks for the tests' graph (tests/wpt_runner/build_mode.zig
/// `PlatformGraph`): the build machine's real OS services plus test
/// capabilities (docs/platform-protocol.md 9). It answers for no target, so
/// a product binds it only when -Dplatform asks.
pub const tests_platform: Platform = .testing;

/// One extra kit part a platform builds in.
pub const KitPart = struct {
    /// Its directory under src/platform/kit/, and the `kit_<name>` import.
    name: []const u8,
    /// The system libraries it links (linkSystemLibrary).
    system_libraries: []const []const u8 = &.{},
};

/// What the neutral build asks about an adapter.
pub const Facts = struct {
    /// The cross-target checks this adapter offers: the root build makes a
    /// step for each (`cross_checks`).
    checks: []const CrossCheck = &.{},
    /// A target this adapter answers for, for a check that needs one (the
    /// option-ownership check configures under it); null for an adapter that
    /// answers for none.
    example_target: ?[]const u8 = null,
    /// The object format of the systems this adapter answers for, and a
    /// target whose objects have it, for the root build's tools that parse
    /// objects (`object_format_fixtures`); null when it declares none.
    object_format: ?ObjectFormatFixture = null,
    /// The words that name this platform or an operating system it answers
    /// for: what `zig build lint-build` looks for (its `--platform=` keys)
    /// in the root build.zig and the neutral files it imports, written as
    /// tools/lint_build_neutral.zig reads a key (`word:<text>` a whole word,
    /// `.<name>` an enum literal, else the text anywhere).
    words: []const []const u8,
};

// The build side's conformance check, as the engine's is: an adapter whose
// build file lacks a declaration, or declares one with another type, does
// not configure - and the error names both.
comptime {
    for (std.meta.fieldNames(@TypeOf(adapters))) |name| checkAdapter(name, @field(adapters, name));
}

fn checkAdapter(comptime name: []const u8, comptime A: type) void {
    const who = "platform adapter '" ++ name ++ "' (src/platform/adapters/" ++ name ++ "/platform_build.zig)";
    conforms(who, A, "ownsTarget", fn (std.Target) bool);
    conforms(who, A, "kitParts", fn (std.Target) []const KitPart);
    // hasdecl: A is each listed adapter's build file (`adapters`), whose
    // Options is pub - this check exists to fail the configure when it is not.
    if (!@hasDecl(A, "Options") or @TypeOf(A.Options) != type) @compileError(who ++ " lacks `pub const Options = struct { ... };`");
    conforms(who, A, "declareOptions", fn (*std.Build) A.Options);
    conforms(who, A, "resolve", fn (*std.Build, std.Build.ResolvedTarget, A.Options, *std.Build.Step.Compile) void);
    conforms(who, A, "forwarded", fn (*std.Build, A.Options) []const []const u8);
    conforms(who, A, "prepareC", fn (std.Build.ResolvedTarget) ?kit.PrepareC);
    conforms(who, A, "linkArtifact", fn (*std.Build.Module, std.Build.ResolvedTarget) void);
    conforms(who, A, "afterTestBuild", fn (*std.Build, *std.Build.Step.Compile, *std.Build.Step.Run, []const u8) void);
    conforms(who, A, "needsStandIns", fn (std.Build.ResolvedTarget) bool);
    conforms(who, A, "addStandIns", fn (*std.Build, *std.Build.Module, std.Build.ResolvedTarget) void);
    conforms(who, A, "bind", fn (*std.Build.Module, std.Build.ResolvedTarget, BindRequest) void);
    // hasdecl: A is each listed adapter's build file (`adapters`), whose
    // `facts` is pub - this check exists to fail the configure when it is not.
    if (!@hasDecl(A, "facts") or @TypeOf(A.facts) != Facts) @compileError(who ++ " lacks `pub const facts: platform_build.Facts`");
}

fn conforms(comptime who: []const u8, comptime A: type, comptime decl: []const u8, comptime Expected: type) void {
    if (!@hasDecl(A, decl)) @compileError(who ++ " lacks `" ++ decl ++ "`: " ++ @typeName(Expected));
    const Actual = @TypeOf(@field(A, decl));
    if (Actual != Expected) @compileError(who ++ ": `" ++ decl ++ "` is " ++ @typeName(Actual) ++ "; the build protocol's is " ++ @typeName(Expected));
}

/// The platform a target gets when -Dplatform does not say: the first
/// listed adapter that answers for its operating system; null where Crane
/// has no built-in platform (pass -Dplatform-module).
pub fn defaultFor(target: std.Target) ?Platform {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        if (@field(adapters, name).ownsTarget(target)) return @field(Platform, name);
    }
    return null;
}

/// The adapter that answers for the target's operating system - its "OS
/// side", whichever platform a module graph binds (docs/platform-protocol.md
/// 9: the testing platform is the build machine's real OS services plus test
/// capabilities): darwin for macOS and iOS, linux for Linux. What the root
/// build keeps of it once it is chosen (`chooseOs`).
pub const OsSide = struct {
    /// The adapter that answers for the target's OS; null when none does.
    owner: ?Platform,
    /// The names of the -D options it declared, in its order.
    option_names: []const []const u8,
    /// The arguments a sub-build of the root build for another target of the
    /// same OS side takes from this one (check-ios's -Dios-sdk).
    forwarded: []const []const u8,
};

/// Ask the adapter that answers for `target`'s operating system to declare
/// its options - only that adapter, so another's do not exist in this build
/// and the configure refuses them, as it refuses any -D nothing declared -
/// and to read what it needs of the machine (`probe`: the root build's
/// tools/build_probe.zig, which asks at make time). Called once, where the
/// root build's option order puts those options. A target no listed adapter
/// answers for has no OS side: no options, nothing read.
pub fn chooseOs(b: *std.Build, target: std.Build.ResolvedTarget, probe: *std.Build.Step.Compile) OsSide {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        const A = @field(adapters, name);
        if (A.ownsTarget(target.result)) {
            // What the adapter declares is what the options map gains.
            const declared_before = b.available_options_map.count();
            const options = A.declareOptions(b);
            const option_names = b.allocator.dupe([]const u8, b.available_options_map.keys()[declared_before..]) catch @panic("OOM");
            A.resolve(b, target, options, probe);
            return .{ .owner = @field(Platform, name), .option_names = option_names, .forwarded = A.forwarded(b, options) };
        }
    }
    return .{ .owner = null, .option_names = &.{}, .forwarded = &.{} };
}

/// The rule that an OS side's option belongs to it, run: for every OTHER
/// listed adapter that names a target it answers for (`Facts.example_target`),
/// one configure of this build root under that target with each option this
/// build's OS side declared - the configure itself must refuse every one
/// ("invalid option"), since only the adapter that answers for the target's
/// OS declares its options (the integrator's ruling, 2026-11-24: -Dios-sdk
/// exists only where darwin answers). Each of `dependants` depends on them.
/// Nothing is compiled: the configure fails before any step runs. An OS side
/// with no option has nothing another build could be given. The engine
/// protocol's check, for the platform.
pub fn addOptionOwnershipChecks(b: *std.Build, os_side: OsSide, dependants: []const *std.Build.Step) void {
    if (os_side.option_names.len == 0) return;
    const owner = os_side.owner orelse return;
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |other| {
        if (@field(adapters, other).facts.example_target) |other_target| {
            if (@field(Platform, other) != owner) {
                const check = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "--list-steps", b.fmt("-Dtarget={s}", .{other_target}) });
                check.setName(b.fmt("the {t} OS side's options are refused under -Dtarget={s}", .{ owner, other_target }));
                for (os_side.option_names) |option| {
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
}

/// What C compiled or translated for `target` needs beyond what Zig finds
/// by itself (kit.PrepareC), as the adapter that answers for its operating
/// system says; null when it needs nothing or no listed adapter answers.
pub fn prepareC(target: std.Build.ResolvedTarget) ?kit.PrepareC {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        const A = @field(adapters, name);
        if (A.ownsTarget(target.result)) return A.prepareC(target);
    }
    return null;
}

/// What a finished program or library (crane's library and executable)
/// links on `target`'s operating system, as the adapter that answers for it
/// says.
pub fn linkArtifact(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        const A = @field(adapters, name);
        if (A.ownsTarget(target.result)) return A.linkArtifact(module, target);
    }
}

/// What a test executable's run (`run`, the launcher's) needs beside the
/// executable for its reports - debug information packaged as the
/// executable's OS keeps it - as the adapter that answers for the
/// executable's target says.
pub fn afterTestBuild(b: *std.Build, test_exe: *std.Build.Step.Compile, run: *std.Build.Step.Run, name: []const u8) void {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |adapter| {
        const A = @field(adapters, adapter);
        if (A.ownsTarget(test_exe.rootModuleTarget())) return A.afterTestBuild(b, test_exe, run, name);
    }
}

/// Whether a compile for `target` finds no system library its graph names
/// on this machine - no sysroot here - so that a compile-only check needs
/// stand-ins for them (`addStandIns`) and nothing for the target can be
/// linked here, as the adapter that answers for its OS says.
pub fn needsStandIns(target: std.Build.ResolvedTarget) bool {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        const A = @field(adapters, name);
        if (A.ownsTarget(target.result)) return A.needsStandIns(target);
    }
    return false;
}

/// Put the stand-ins for `target`'s system libraries on `module`, the root
/// module of a compile that links nothing (`needsStandIns`); nothing when
/// the target needs none.
pub fn addStandIns(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        const A = @field(adapters, name);
        if (A.ownsTarget(target.result)) return A.addStandIns(b, module, target);
    }
}

/// A check of the root build for targets of another system than the
/// machine's, which an adapter offers (`Facts.checks`): one top-level step,
/// one `zig build <sub_step> -Dtarget=<target> <args> -j2` of the root per
/// target, one after the other; nothing runs.
pub const CrossCheck = struct {
    /// The top-level step and its description.
    step: []const u8,
    description: []const u8,
    /// The root build's step each sub-build runs.
    sub_step: []const u8,
    targets: []const []const u8,
    /// The sub-build's arguments after its -Dtarget.
    args: []const []const u8 = &.{},
    /// Also pass the sub-build what this build's OS side forwards
    /// (`OsSide.forwarded`).
    forward_options: bool = false,
};

/// Every listed adapter's cross-target checks, in the list's order.
pub const cross_checks: []const CrossCheck = checks: {
    var checks: []const CrossCheck = &.{};
    for (std.meta.fieldNames(@TypeOf(adapters))) |name| checks = checks ++ @field(adapters, name).facts.checks;
    break :checks checks;
};

/// An object format, by the name the root build's fixtures use for it
/// ("elf", "mach_o"), and a target triple whose objects have it.
pub const ObjectFormatFixture = struct {
    name: []const u8,
    target: []const u8,
};

/// Every object format the listed adapters declare, sorted by name, so the
/// fixtures are made in one order whatever the list's.
pub const object_format_fixtures: []const ObjectFormatFixture = formats: {
    var formats: []const ObjectFormatFixture = &.{};
    for (std.meta.fieldNames(@TypeOf(adapters))) |name| {
        const format = @field(adapters, name).facts.object_format orelse continue;
        var at: usize = 0;
        while (at < formats.len and std.mem.order(u8, formats[at].name, format.name) == .lt) at += 1;
        formats = formats[0..at] ++ &[_]ObjectFormatFixture{format} ++ formats[at..];
    }
    break :formats formats;
};

/// Whether two targets are one system to run on: the same CPU architecture
/// and operating system (the root build joins test executables only of one).
pub fn sameSystem(a: std.Target, b: std.Target) bool {
    return a.cpu.arch == b.cpu.arch and a.os.tag == b.os.tag;
}

/// What a binding asks of the adapter it binds (`bind`).
pub const BindRequest = struct {
    /// The font_decoding capability is compiled in (-Dplatform-without
    /// does not name it).
    font_decoding: bool,
};

/// What the implementation of `platform`, bound to a graph for `target`,
/// links of its own (`impl` is its module); a third party's
/// (`external`) declares nothing here.
pub fn bind(platform: Platform, impl: *std.Build.Module, target: std.Build.ResolvedTarget, request: BindRequest) void {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        if (platform == @field(Platform, name)) return @field(adapters, name).bind(impl, target, request);
    }
}

/// The capabilities -Dplatform-without may name: src/platform/protocol.zig's
/// Capabilities fields. The facade checks the names again at compile time;
/// this list only makes a typo fail before any compile starts.
pub const capability_names = [_][]const u8{
    "image_decoding",
    "image_encoding",
    "font_decoding",
    "brotli",
    "deflate_decoding",
    "persistent_storage",
    "file_urls",
    "system_trust_store",
    "http2",
    "http3",
    "thread_qos",
    "resident_memory",
    "layout",
    "os_permissions",
    "simple_dialogs",
    "printing",
    "file_picker",
    "windows",
    "media_decoding",
    "pdf_viewer",
    "webcodecs",
    "media_capabilities",
    "encrypted_media",
    "camera",
    "microphone",
    "screen_capture",
    "audio_output",
    "speech_synthesis",
    "speech_recognition",
    "clipboard",
    "notifications",
    "push",
    "background_sync",
    "background_fetch",
    "geolocation",
    "sensors",
    "device_orientation",
    "usb",
    "hid",
    "serial",
    "bluetooth",
    "nfc",
    "midi",
    "gamepad",
    "payment",
    "webauthn",
    "identity_credentials",
    "share",
    "contacts",
    "fullscreen",
    "pointer_lock",
    "keyboard_lock",
    "wake_lock",
    "idle_detection",
    "battery",
    "vibration",
    "badging",
    "eyedropper",
    "local_fonts",
    "keyboard_map",
    "screen_details",
    "presentation",
    "remote_playback",
    "picture_in_picture",
    "media_session",
    "network_information",
    "compute_pressure",
    "device_posture",
    "virtual_keyboard",
    "protocol_handlers",
    "address_space",
    "devtools_transport",
};

/// The link-plan items -Dplatform-static may name (contract section 10): a
/// platform compiles the kit's static implementation of each instead of
/// linking the system library. `all` names every one.
pub const static_items = [_][]const u8{ "sqlite", "zlib", "brotli", "crypto", "trust_store", "curl", "nghttp2", "all" };

/// -Dplatform's description: the list's names.
const platform_help: []const u8 = help: {
    const names = std.meta.fieldNames(@TypeOf(adapters));
    var text: []const u8 = "The platform: ";
    for (names, 0..) |name, i| text = text ++ (if (i == 0) "" else if (i + 1 == names.len) " or " else ", ") ++ name;
    break :help text ++ " (default: from the target)";
};

/// What the command line chose for the platform protocol (`choose`).
pub const Choice = struct {
    /// The platform the target's own graph binds: `external` with
    /// -Dplatform-module, else -Dplatform, else the adapter that answers for
    /// the target (`defaultFor`).
    platform: Platform,
    /// -Dplatform-module: the third-party implementation's root file.
    module_path: ?[]const u8,
    /// -Dplatform-without: the capabilities compiled out, as given.
    without: []const []const u8,
    /// -Dplatform-static: the link-plan items compiled from the kit.
    static: []const []const u8,
};

/// Declare the platform protocol's options - -Dplatform-without,
/// -Dplatform-module, -Dplatform, -Dplatform-static, in that order - and
/// answer what they chose. Called once. A name neither list holds, a target
/// no adapter answers for with no -Dplatform-module, or -Dplatform=external
/// without one stops the configure with the reason.
pub fn choose(b: *std.Build, target: std.Build.ResolvedTarget) Choice {
    checkListIsComplete(b);
    const without = optionList(b, "platform-without", b.option([]const u8, "platform-without", "Capabilities to compile out (comma-separated; src/platform/protocol.zig Capabilities)"), &capability_names);
    const module_path = b.option([]const u8, "platform-module", "A third-party platform: the root file of an implementation of src/platform/protocol.zig");
    const asked = b.option(Platform, "platform", platform_help);
    const platform: Platform = if (module_path != null) .external else asked orelse defaultFor(target.result) orelse {
        std.debug.print("Error: no built-in platform for {s}; pass -Dplatform-module=<path>\n", .{@tagName(target.result.os.tag)});
        std.process.exit(1);
    };
    if (asked == .external and module_path == null) {
        std.debug.print("Error: -Dplatform=external needs -Dplatform-module=<path>\n", .{});
        std.process.exit(1);
    }
    const static = optionList(b, "platform-static", b.option([]const u8, "platform-static", "Link-plan items to compile statically instead of linking the system library (comma-separated, or all)"), &static_items);
    return .{ .platform = platform, .module_path = module_path, .without = without, .static = static };
}

/// Whether `name` is a listed adapter's name.
fn isListed(name: []const u8) bool {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |listed| {
        if (std.mem.eql(u8, listed, name)) return true;
    }
    return false;
}

/// Fail the configure when a directory under src/platform/adapters/ is not a
/// listed adapter. The list is what -Dplatform offers, what the conformance
/// check holds to the interface, what the conformance test binds and what
/// the build-neutrality lint takes its platform words from: an adapter's
/// directory it lacks would be none of these, silently. (A listed adapter
/// without its directory or its build file cannot happen: the list imports
/// the file.) The engine protocol's check, for the platform.
///
/// What it reads - the directory's entries, by name and kind - is a tracked
/// input of Zig's configure cache (`dependOnDirectoryContents` records
/// exactly those), so a new directory there configures again and fails here,
/// and an unchanged one leaves the cached configuration in use.
fn checkListIsComplete(b: *std.Build) void {
    const io = b.graph.io;
    const adapters_path = "src/platform/adapters";
    b.dependOnDirectoryContents(b.path(adapters_path));
    var dir = b.root.root_dir.handle.openDir(io, adapters_path, .{ .iterate = true }) catch |err|
        std.debug.panic("the platform build protocol cannot open {s} to check its list of adapters: {t}", .{ adapters_path, err });
    defer dir.close(io);
    var entries = dir.iterate();
    while (entries.next(io) catch |err| std.debug.panic("the platform build protocol cannot read {s}: {t}", .{ adapters_path, err })) |entry| {
        if (entry.kind != .directory or isListed(entry.name)) continue;
        std.debug.panic(
            "{s}/{s}/ is a platform adapter the build protocol does not list: give it a platform_build.zig (the interface: src/platform/platform_build_protocol.zig) and a line in that file's `adapters`",
            .{ adapters_path, entry.name },
        );
    }
}

/// A comma-separated option as a list of names, each checked against `valid`.
fn optionList(b: *std.Build, option: []const u8, value: ?[]const u8, valid: []const []const u8) []const []const u8 {
    const text = value orelse return &.{};
    var names: std.ArrayList([]const u8) = .empty;
    var it = std.mem.tokenizeScalar(u8, text, ',');
    while (it.next()) |raw| {
        const name = std.mem.trim(u8, raw, " ");
        for (valid) |v| {
            if (std.mem.eql(u8, v, name)) break;
        } else {
            std.debug.print("Error: -D{s} names '{s}', which is not one of: ", .{ option, name });
            for (valid, 0..) |v, i| std.debug.print("{s}{s}", .{ if (i == 0) "" else ", ", v });
            std.debug.print("\n", .{});
            std.process.exit(1);
        }
        names.append(b.allocator, b.dupe(name)) catch @panic("OOM");
    }
    return names.items;
}

/// One binding of the platform contract's test
/// (tests/platform/protocol_conformance_test.zig): the facade, one platform
/// and the kit, nothing of the engine, in an executable of its own named
/// `platform_protocol_<name>`.
pub const Conformance = struct {
    name: []const u8,
    platform: Platform,
    /// The capabilities compiled out of this binding.
    without: []const []const u8 = &.{},
    /// Bind the platform's own font operations and media decoding too
    /// (tests/platform/font_adapters.zig, tests/platform/
    /// media_decoding_test.zig): a built-in platform's own binding.
    fonts_and_media: bool = false,
    /// Run the kit parts' own test blocks with this binding - once in the
    /// whole list, since they do not depend on the platform they are bound
    /// with.
    kit_tests: bool = false,
};

/// The contract against every listed platform but the tests' own - which
/// tests/platform/'s executable binds - each with nothing compiled out, in
/// the list's order; then the bindings that compile capabilities out.
pub const conformance: []const Conformance = rows: {
    var rows: []const Conformance = &.{};
    for (std.meta.fieldNames(@TypeOf(adapters))) |name| {
        if (std.mem.eql(u8, name, @tagName(tests_platform))) continue;
        rows = rows ++ &[_]Conformance{.{ .name = name, .platform = @field(Platform, name), .fonts_and_media = true, .kit_tests = rows.len == 0 }};
    }
    break :rows rows ++ &compiled_out;
};

/// The contract with capabilities compiled out: the testing platform, and
/// darwin without its CoreText fonts (decision 20).
const compiled_out = [_]Conformance{
    .{ .name = "testing_without_camera_clipboard", .platform = .testing, .without = &.{ "camera", "clipboard" } },
    .{ .name = "testing_without_brotli_and_deflate_decoding", .platform = .testing, .without = &.{ "brotli", "deflate_decoding" } },
    .{ .name = "testing_without_image_decoding", .platform = .testing, .without = &.{"image_decoding"} },
    .{ .name = "testing_without_image_encoding", .platform = .testing, .without = &.{"image_encoding"} },
    .{ .name = "testing_without_font_decoding", .platform = .testing, .without = &.{"font_decoding"} },
    .{ .name = "darwin_without_font_decoding", .platform = .darwin, .without = &.{"font_decoding"} },
};

/// Every listed adapter's words, comma-separated: the platform keys of `zig
/// build lint-build`, from the list itself - so the root build.zig spells
/// no platform to look for one, and a new adapter is covered the day it is
/// listed.
pub const lint_words: []const u8 = words: {
    var text: []const u8 = "";
    for (std.meta.fieldNames(@TypeOf(adapters))) |name| {
        for (@field(adapters, name).facts.words) |word| text = text ++ (if (text.len == 0) "" else ",") ++ word;
    }
    break :words text;
};

/// What a branch on the target's operating system looks like in Zig: the
/// target keys of `zig build lint-build` (case kept). Such a branch belongs
/// to the adapter that answers for that system.
pub const lint_target_words: []const u8 = "os.tag,isDarwin,.abi ==";

/// The platform protocol's modules for one platform (docs/platform-protocol.md
/// section 1): the facade `platform` (src/platform/protocol.zig), the bound
/// implementation `platform_impl`, the kit parts it composes and this
/// binding's `platform_options`. The facade's comptime check holds the
/// implementation to the contract whenever the facade is compiled.
pub const Binding = struct {
    facade: *std.Build.Module,
    options: *std.Build.Module,
    /// The kit's network connection share (src/platform/kit/curl/share.zig), which
    /// `fetch` imports for a Browser's network context until transfers move
    /// behind the platform's port. A module of its own that imports nothing:
    /// a graph whose `fetch` is compiled beside the old platform root (tests/
    /// platform/retained_old_platform.zig) must not reach the facade's files.
    network_share: *std.Build.Module,
    /// kit/sfnt and kit/inflate, whose own test blocks the platform tests
    /// run (decision 20).
    kit_sfnt: *std.Build.Module,
    kit_inflate: *std.Build.Module,
    /// kit/media_decoding, the built-in media decoders (lane wptcfg D4),
    /// whose own test blocks the platform tests run.
    kit_media_decoding: *std.Build.Module,
    /// <time.h> translated (kit.cImport), which kit/posix imports as `c_time`;
    /// tests/platform takes the same module (one per header set per graph).
    c_time: *std.Build.Module,
    /// The kit parts whose own test blocks the platform tests run (kit
    /// `Modules.tested`).
    kit_tested: []const kit.Tested,
    /// The bound adapter's own module, whose test blocks the root of a test
    /// executable collects (lane core1).
    adapter: *std.Build.Module,
};

pub const BindingOptions = struct {
    platform: Platform,
    /// -Dplatform-module's root, for `.external`.
    module_path: ?[]const u8 = null,
    without: []const []const u8 = &.{},
    static: []const []const u8 = &.{},
    http2: bool,
    /// The C libraries the kit built for the graph (kit.libraries).
    libraries: kit.Libraries,
    /// Register the facade by name (the public graph).
    public: bool = false,
    /// Today's bridges, which kit/posix wraps and the facade's TRANSITIONAL
    /// timer_backend reads.
    clock: *std.Build.Module,
    host: *std.Build.Module,
    memory: *std.Build.Module,
    /// MIME Sniffing's parser, which kit/media_decoding's canPlayType parses
    /// a type with: one parser in Crane, not a copy in the platform. Pure
    /// Zig over `infra` (whose only import is the clock bridge), so no part
    /// of it reaches back to the facade.
    mimesniff: *std.Build.Module,
};

pub fn binding(b: *std.Build, target: std.Build.ResolvedTarget, options: BindingOptions) Binding {
    const platform_options = b.addOptions();
    platform_options.addOption([]const u8, "platform_name", @tagName(options.platform));
    platform_options.addOption([]const []const u8, "platform_without", options.without);
    platform_options.addOption([]const []const u8, "platform_static", options.static);
    platform_options.addOption(bool, "http2", options.http2);
    const options_mod = platform_options.createModule();

    // Registered by name in the public graph (one name cannot be registered
    // twice), private otherwise: the root build's graphModule.
    const facade_options: std.Build.Module.CreateOptions = .{
        .root_source_file = b.path("src/platform/protocol.zig"),
        .target = target,
    };
    const facade = if (options.public) b.addModule("platform", facade_options) else b.createModule(facade_options);
    facade.addImport("platform_options", options_mod);
    // TRANSITIONAL: the re-exported timer_backend reads the clock bridge.
    facade.addImport("clock", options.clock);

    const impl_root: std.Build.LazyPath = switch (options.platform) {
        .external => .{ .cwd_relative = options.module_path.? },
        else => b.path(b.fmt("src/platform/adapters/{s}/protocol.zig", .{@tagName(options.platform)})),
    };
    const impl = b.createModule(.{ .root_source_file = impl_root, .target = target, .link_libc = true });
    impl.addImport("platform", facade);
    impl.addImport("platform_options", options_mod);
    facade.addImport("platform_impl", impl);

    // The kit's modules for this binding: the kit's build side.
    const parts = kit.modules(b, target, prepareC(target), .{
        .facade = facade,
        .options = options_mod,
        .impl = impl,
        .without = options.without,
        .libraries = options.libraries,
        .clock = options.clock,
        .host = options.host,
        .memory = options.memory,
        .mimesniff = options.mimesniff,
    });
    // The platform's own extra kit parts and the system libraries each links:
    // its adapter's declaration (kitParts) - the root build names none of
    // them.
    for (kitParts(@tagName(options.platform), target.result)) |part| {
        const module = b.createModule(.{
            .root_source_file = b.path(b.fmt("src/platform/kit/{s}/root.zig", .{part.name})),
            .target = target,
            .link_libc = true,
        });
        module.addImport("platform", facade);
        module.addImport("platform_options", options_mod);
        module.addImport("host", options.host);
        link(module, part);
        impl.addImport(b.fmt("kit_{s}", .{part.name}), module);
    }
    const font_decoding_enabled = for (options.without) |name| {
        if (std.mem.eql(u8, name, "font_decoding")) break false;
    } else true;
    // What the bound adapter's implementation links (platform_build.bind).
    bind(options.platform, impl, target, .{ .font_decoding = font_decoding_enabled });
    const kit_tested = b.allocator.dupe(kit.Tested, &parts.tested) catch @panic("OOM");
    return .{ .facade = facade, .options = options_mod, .network_share = parts.kit_curl_share, .kit_sfnt = parts.kit_sfnt, .kit_inflate = parts.kit_inflate, .kit_media_decoding = parts.kit_media_decoding, .c_time = parts.c_time, .kit_tested = kit_tested, .adapter = impl };
}

/// The extra kit parts of the platform named `platform_name` for `target`:
/// its adapter's declaration, none for a platform with no build file here.
pub fn kitParts(platform_name: []const u8, target: std.Target) []const KitPart {
    inline for (comptime std.meta.fieldNames(@TypeOf(adapters))) |name| {
        if (std.mem.eql(u8, name, platform_name)) return @field(adapters, name).kitParts(target);
    }
    return &.{};
}

/// Link `module`, part `part`'s module, against what the part declares.
pub fn link(module: *std.Build.Module, part: KitPart) void {
    for (part.system_libraries) |library| module.linkSystemLibrary(library, .{});
}

const testing = std.testing;

/// The build machine's target with its operating system set to `tag`.
fn targetFor(tag: std.Target.Os.Tag) std.Target {
    var target = @import("builtin").target;
    target.os.tag = tag;
    return target;
}

test "Platform is -Dplatform's values: the listed adapters, in the list's order, then external" {
    const names = std.meta.fieldNames(Platform);
    try testing.expectEqual(@as(usize, 4), names.len);
    for ([_][]const u8{ "darwin", "linux", "testing", "external" }, names) |expected, name| try testing.expectEqualStrings(expected, name);
}

test "-Dplatform's description names the listed adapters" {
    try testing.expectEqualStrings("The platform: darwin, linux or testing (default: from the target)", platform_help);
}

test "a target gets the adapter that answers for its operating system, and none where no adapter does" {
    try testing.expectEqual(@as(?Platform, .darwin), defaultFor(targetFor(.macos)));
    try testing.expectEqual(@as(?Platform, .darwin), defaultFor(targetFor(.ios)));
    try testing.expectEqual(@as(?Platform, .linux), defaultFor(targetFor(.linux)));
    try testing.expectEqual(@as(?Platform, null), defaultFor(targetFor(.windows)));
    try testing.expectEqual(@as(?Platform, null), defaultFor(targetFor(.freestanding)));
}

test "the tests' platform is a listed adapter that answers for no target" {
    try testing.expect(tests_platform != .external);
    for ([_]std.Target.Os.Tag{ .macos, .ios, .linux, .windows }) |tag| {
        try testing.expect(defaultFor(targetFor(tag)) != tests_platform);
    }
}

test "the capability and link-plan names are each named once; `all` is the last link-plan item" {
    for ([_][]const []const u8{ &capability_names, &static_items }) |list| {
        try testing.expect(list.len > 0);
        for (list, 0..) |name, i| for (list[i + 1 ..]) |other| try testing.expect(!std.mem.eql(u8, name, other));
    }
    try testing.expectEqual(@as(usize, 72), capability_names.len);
    try testing.expectEqualStrings("devtools_transport", try last(&capability_names));
    try testing.expectEqualStrings("all", try last(&static_items));
}

fn last(list: []const []const u8) ![]const u8 {
    if (list.len == 0) return error.EmptyList;
    return list[list.len - 1];
}

test "the conformance bindings: each listed platform but the tests' own, then the compile-outs, in today's order" {
    const expected = [_]struct { []const u8, Platform, usize, bool, bool }{
        .{ "darwin", .darwin, 0, true, true },
        .{ "linux", .linux, 0, true, false },
        .{ "testing_without_camera_clipboard", .testing, 2, false, false },
        .{ "testing_without_brotli_and_deflate_decoding", .testing, 2, false, false },
        .{ "testing_without_image_decoding", .testing, 1, false, false },
        .{ "testing_without_image_encoding", .testing, 1, false, false },
        .{ "testing_without_font_decoding", .testing, 1, false, false },
        .{ "darwin_without_font_decoding", .darwin, 1, false, false },
    };
    try testing.expectEqual(expected.len, conformance.len);
    for (expected, 0..) |row, i| {
        const bound = conformance[i];
        try testing.expectEqualStrings(row[0], bound.name);
        try testing.expectEqual(row[1], bound.platform);
        try testing.expectEqual(row[2], bound.without.len);
        try testing.expectEqual(row[3], bound.fonts_and_media);
        try testing.expectEqual(row[4], bound.kit_tests);
        for (bound.without) |capability| {
            for (capability_names) |name| {
                if (std.mem.eql(u8, name, capability)) break;
            } else return error.NotACapability;
        }
    }
}

test "the object-format fixtures: ELF from linux, then Mach-O from darwin, sorted by format" {
    try testing.expectEqual(@as(usize, 2), object_format_fixtures.len);
    try testing.expectEqualStrings("elf", object_format_fixtures[0].name);
    try testing.expectEqualStrings("x86_64-linux-none", object_format_fixtures[0].target);
    try testing.expectEqualStrings("mach_o", object_format_fixtures[1].name);
    try testing.expectEqualStrings("aarch64-macos-none", object_format_fixtures[1].target);
}

test "the cross-target checks: darwin's check-ios, then linux's check-linux, in the list's order" {
    try testing.expectEqual(@as(usize, 2), cross_checks.len);
    try testing.expectEqualStrings("check-ios", cross_checks[0].step);
    try testing.expect(cross_checks[0].forward_options);
    try testing.expectEqualStrings("check-linux", cross_checks[1].step);
    try testing.expectEqual(@as(usize, 2), cross_checks[1].targets.len);
}

test "a listed adapter's name is listed; a third party's and an unknown name are not" {
    for ([_][]const u8{ "darwin", "linux", "testing" }) |name| try testing.expect(isListed(name));
    for ([_][]const u8{ "external", "windows", "", "Darwin" }) |name| try testing.expect(!isListed(name));
}

test "the lint's platform keys are the listed adapters' words; its target keys a branch on the OS" {
    try testing.expectEqualStrings("darwin,macos,word:ios,iphoneos,xcrun,homebrew,linux,.testing", lint_words);
    try testing.expectEqualStrings("os.tag,isDarwin,.abi ==", lint_target_words);
}
