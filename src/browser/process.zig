//! crane.Process: what is the same for every Browser, started once, before
//! any Browser exists (docs/instances.md; the instances design, 4.1 and 4.6).
//!
//! It starts the engine - V8's platform and flags, and the snapshot agents
//! are made from, validated against the external references this build
//! registers - and installs every src/dom hook, exactly once: the generated
//! `interfaces.process_hooks.install()` and `mixins.process_hooks.install()` reach each impl's
//! `installHooks` through its own generated file, and the browser layer's
//! (Context.installHooks) follow. Hooks are function tables identical for
//! every instance; written while the process starts and read without a lock
//! after, they are never null on an instance's thread and never depend on
//! which page ran first (docs/lessons/architecture-a-threadlocal-hook-installed-by-the-first-owner.md).
//! Blink's CoreInitializer installs core's hooks the same way, once, before
//! any frame exists.
//!
//! A host starts the process itself (`init`, and `deinit` after its last
//! Browser). `Browser.init` still calls `ensureStarted` for hosts that do
//! not yet - a compatibility path that keeps the process started until it
//! exits (removed when the host API lands, design batch B6).
//!
//! Not here yet, and why (both listed for later batches): curl's global init
//! is made together with the connection-pool share, which must close with
//! the last Browser - a connection only closed by the process exiting ends
//! with a bare FIN, and WPT's h2 server spins on it - so it stays in Browser
//! until B3 splits them; and the engine adapter's wrapper type registry is
//! still built lazily inside the adapter (B2).

const std = @import("std");
const engine = @import("engine");
const host = @import("host");
const process_start = @import("dom").process_start;

const log = std.log.scoped(.process);

pub const Options = struct {
    /// The snapshot agents are made from. Null: the first of
    /// DEFAULT_SNAPSHOT_PATHS the engine takes. Empty: none.
    snapshot_path: ?[]const u8 = null,
};

pub const Error = error{
    /// `init` ran already, or is running on another thread.
    ProcessAlreadyStarted,
    /// `deinit` ran: V8 cannot start its platform twice in one process.
    ProcessEnded,
    /// The engine would not start.
    EngineStartFailed,
};

/// Where a snapshot is looked for, first to last. The build's own output
/// comes first: a `whatwg_snapshot.bin` in the current directory - one that
/// was tracked in git from January to September 2026 - won over it, and
/// every run from the repository root restored that stale snapshot against
/// the running build's callback table. A candidate the engine refuses (no
/// build stamp, not a valid blob, another build's external references) is
/// skipped, not taken because it exists.
pub const DEFAULT_SNAPSHOT_PATHS = [_][]const u8{
    "zig-out/bin/whatwg_snapshot.bin", // Zig build output (highest priority)
    "whatwg_snapshot.bin", // Current directory
    "../whatwg_snapshot.bin", // Parent directory (for tests run from subdirs)
};

/// The process, started. Held by the host from `init` to `deinit`.
pub const Process = struct {
    /// The snapshot's bytes, lent to the engine until `deinit`: V8
    /// deserializes from them lazily. Owned by `allocator`.
    snapshot: ?[]u8,

    /// The process's own allocations (the snapshot): not any Browser's.
    const allocator = std.heap.page_allocator;

    /// Start the process: the engine, then every hook. Once per process,
    /// on one thread, before any Browser exists.
    pub fn init(options: Options) Error!Process {
        if (!process_start.begin()) {
            return if (process_start.get().phase == .ended) error.ProcessEnded else error.ProcessAlreadyStarted;
        }
        var start: EngineStart = .{};
        startEngine(&start, options.snapshot_path);
        if (start.snapshot == null) engine.initializeEngine(.{}) catch {
            process_start.end();
            return error.EngineStartFailed;
        };
        installHooks();
        process_start.finish(start.snapshot != null);
        return .{ .snapshot = start.snapshot };
    }

    /// End the process, after its last Browser: the engine forgets the
    /// snapshot, which is freed. V8 keeps its platform until exit.
    pub fn deinit(self: *Process) void {
        engine.deinitializeEngine();
        if (self.snapshot) |bytes| allocator.free(bytes);
        self.snapshot = null;
        process_start.end();
    }

    /// For hosts that do not start the process themselves (Browser.init):
    /// start it if nothing has, or wait for a start under way. The process
    /// then stays started until it exits - its snapshot is never freed.
    pub fn ensureStarted(options: Options) Error!void {
        switch (process_start.get().phase) {
            .running => return,
            .ended => return error.ProcessEnded,
            .not_started, .starting => {},
        }
        _ = init(options) catch |err| switch (err) {
            error.ProcessAlreadyStarted => switch (process_start.waitUntilStarted()) {
                .running => return,
                .ended, .not_started => return error.ProcessEnded,
                .starting => unreachable,
            },
            else => return err,
        };
    }

    /// Whether agents can be made from a snapshot.
    pub fn hasSnapshot() bool {
        return process_start.get().has_snapshot;
    }
};

/// Every src/dom hook, once (process_start: the hook modules assert it).
fn installHooks() void {
    @import("interfaces").process_hooks.install();
    @import("mixins").process_hooks.install();
    @import("Context.zig").installHooks();
}

/// The engine, started with the snapshot of the first candidate it takes
/// (engine.initializeEngine refuses a blob this build cannot restore).
const EngineStart = struct {
    /// The accepted snapshot's bytes, OWNED by Process.allocator.
    snapshot: ?[]u8 = null,

    /// Start the engine with the snapshot at `path`, if it reads and the
    /// engine takes it.
    fn offer(self: *EngineStart, path: []const u8) bool {
        const bytes = readSnapshot(Process.allocator, path) orelse return false;
        engine.initializeEngine(.{ .snapshot = bytes }) catch {
            Process.allocator.free(bytes);
            return false;
        };
        self.snapshot = bytes;
        return true;
    }
};

/// Start the engine with the configured snapshot, or the first of
/// DEFAULT_SNAPSHOT_PATHS the engine takes; an empty configured path means
/// none. `start.snapshot` is null when no snapshot was taken, and the engine
/// is not started then.
fn startEngine(start: *EngineStart, config_path: ?[]const u8) void {
    if (config_path) |path| {
        if (path.len > 0) _ = start.offer(path);
        return;
    }
    _ = firstUsableSnapshot(start, &DEFAULT_SNAPSHOT_PATHS, EngineStart.offer);
}

/// The first of `candidates` that `usable` accepts, in order, or null.
fn firstUsableSnapshot(
    context: anytype,
    candidates: []const []const u8,
    comptime usable: fn (@TypeOf(context), []const u8) bool,
) ?[]const u8 {
    for (candidates) |path| {
        if (usable(context, path)) return path;
    }
    return null;
}

/// The file's bytes, or null when it cannot be read. OWNED by `allocator`.
fn readSnapshot(allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
    const io = host.io();
    const file = host.cwd().openFile(io, path, .{}) catch return null;
    defer file.close(io);
    const stat = file.stat(io) catch return null;
    const bytes = allocator.alloc(u8, stat.size) catch return null;
    const read = file.readPositionalAll(io, bytes, 0) catch {
        allocator.free(bytes);
        return null;
    };
    if (read != stat.size) {
        allocator.free(bytes);
        return null;
    }
    return bytes;
}

test "the build's own snapshot is looked for first, and a refused candidate is skipped" {
    try std.testing.expectEqualStrings("zig-out/bin/whatwg_snapshot.bin", DEFAULT_SNAPSHOT_PATHS[0]);
    const Only = struct {
        fn accepts(accepted: []const u8, path: []const u8) bool {
            return std.mem.eql(u8, accepted, path);
        }
    };
    // The build output is refused here, so the next candidate is taken.
    try std.testing.expectEqualStrings(
        "whatwg_snapshot.bin",
        firstUsableSnapshot(@as([]const u8, "whatwg_snapshot.bin"), &DEFAULT_SNAPSHOT_PATHS, Only.accepts).?,
    );
    try std.testing.expectEqualStrings(
        "zig-out/bin/whatwg_snapshot.bin",
        firstUsableSnapshot(@as([]const u8, "zig-out/bin/whatwg_snapshot.bin"), &DEFAULT_SNAPSHOT_PATHS, Only.accepts).?,
    );
    try std.testing.expect(firstUsableSnapshot(@as([]const u8, "nowhere.bin"), &DEFAULT_SNAPSHOT_PATHS, Only.accepts) == null);
}
