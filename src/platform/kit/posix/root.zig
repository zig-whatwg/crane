//! kit/posix: clocks, randomness, threads, files and process identity over
//! libc - the OS services every platform needs, for any platform to use
//! (docs/platform-protocol.md section 1).
//!
//! Step 0 of the platform protocol: these are today's implementations behind
//! protocol functions. The clocks are src/platform/clock.zig's (module
//! `clock`), the files go through the process Io of src/platform/host.zig
//! (module `host`) and resident memory is src/platform/memory.zig's (module
//! `memory`); their callers keep importing those modules until the recipes'
//! later steps move them (step 1 the clock, step 3 the files).

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");
const clock = @import("clock");
const host = @import("host");
const memory = @import("memory");

const Str = platform.Str;
const Bytes = platform.Bytes;
const Error = platform.Error;

// ---------------------------------------------------------------------------
// 6.1 Process and identity
// ---------------------------------------------------------------------------

/// The process Io (host.zig) is the one per-process service today: it starts
/// on first use, so initializing it here only moves that moment earlier.
pub fn initializePlatform(options: *const platform.PlatformOptions) Error!void {
    _ = options;
    _ = host.io();
}

pub fn deinitializePlatform() void {}

/// $HOME/<relative>, OWNED; null with no HOME.
fn homeRelative(allocator: std.mem.Allocator, relative: []const u8) Error!?[]u8 {
    const home = std.c.getenv("HOME") orelse return null;
    return std.fs.path.join(allocator, &.{ std.mem.span(home), relative }) catch error.OutOfMemory;
}

/// macOS: ~/Library/Application Support/Crane; iOS: null (the app passes its
/// container); elsewhere $XDG_DATA_HOME/crane, else ~/.local/share/crane.
pub fn defaultDataDirectory(allocator: std.mem.Allocator) Error!?[]u8 {
    switch (builtin.os.tag) {
        .ios, .tvos, .watchos, .visionos => return null,
        .macos => return homeRelative(allocator, "Library/Application Support/Crane"),
        else => {
            if (std.c.getenv("XDG_DATA_HOME")) |xdg| {
                const base = std.mem.span(xdg);
                if (base.len != 0) return std.fs.path.join(allocator, &.{ base, "crane" }) catch error.OutOfMemory;
            }
            return homeRelative(allocator, ".local/share/crane");
        },
    }
}

/// Today's answer everywhere: navigator.language is "en-US"
/// (src/webidl/impls/Navigator.zig). Reading the OS's list is a later step.
pub fn preferredLanguages(allocator: std.mem.Allocator) Error![]Str {
    const list = try allocator.alloc(Str, 1);
    errdefer allocator.free(list);
    const tag = try allocator.dupe(u8, "en-US");
    list[0] = Str.from(tag);
    return list;
}

/// $TZ when set, else the zoneinfo name /etc/localtime links to, else "UTC".
pub fn defaultTimeZone(allocator: std.mem.Allocator) Error![]u8 {
    if (std.c.getenv("TZ")) |tz| {
        var zone = std.mem.span(tz);
        if (zone.len > 0 and zone[0] == ':') zone = zone[1..];
        if (zone.len != 0) return allocator.dupe(u8, zone);
    }
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const n = std.c.readlink("/etc/localtime", &buffer, buffer.len);
    if (n > 0) {
        const target = buffer[0..@intCast(n)];
        if (std.mem.indexOf(u8, target, "zoneinfo/")) |at| return allocator.dupe(u8, target[at + "zoneinfo/".len ..]);
    }
    return allocator.dupe(u8, "UTC");
}

pub fn logicalProcessorCount() u32 {
    const count = std.Thread.getCpuCount() catch 1;
    return @intCast(@max(1, @min(count, std.math.maxInt(u32))));
}

pub fn deviceMemoryGiB() f64 {
    const bytes = std.process.totalSystemMemory() catch return 0;
    return @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0 * 1024.0);
}

pub fn residentMemory() ?platform.MemoryReading {
    const bytes = memory.residentBytes() orelse return null;
    return .{ .resident_bytes = bytes };
}

// ---------------------------------------------------------------------------
// 6.2 Clocks: today's src/platform/clock.zig
// ---------------------------------------------------------------------------

pub fn monotonicNow() platform.Instant {
    return .{ .ns = @intCast(@max(0, clock.monotonicNanos())) };
}

pub fn wallNow() platform.WallTime {
    return .{ .ns_since_epoch = @intCast(clock.wallNanos()) };
}

pub fn sleepThread(nanoseconds: u64) void {
    clock.sleep(nanoseconds);
}

// ---------------------------------------------------------------------------
// 6.3 Randomness
// ---------------------------------------------------------------------------

extern "c" fn getentropy(buffer: [*]u8, length: usize) c_int;

/// getentropy(2), today's source (src/file/blob_url_store.zig), in its
/// 256-byte maximum chunks. The OS failing to supply entropy is fatal.
pub fn fillRandom(bytes: []u8) void {
    var rest = bytes;
    while (rest.len > 0) {
        const n = @min(rest.len, 256);
        if (getentropy(rest.ptr, n) != 0) @panic("platform.fillRandom: the OS supplied no entropy");
        rest = rest[n..];
    }
}

// ---------------------------------------------------------------------------
// 6.4 Threads
// ---------------------------------------------------------------------------

const Start = struct {
    entry: *const fn (?*anyopaque) callconv(.c) void,
    context: ?*anyopaque,
    name: [16:0]u8,
};

fn threadMain(start: *Start) void {
    const entry = start.entry;
    const context = start.context;
    if (start.name[0] != 0) {
        if (builtin.os.tag.isDarwin()) {
            _ = std.c.pthread_setname_np(&start.name);
        } else if (builtin.os.tag == .linux) {
            _ = std.c.pthread_setname_np(std.c.pthread_self(), &start.name);
        }
    }
    std.heap.c_allocator.destroy(start);
    entry(context);
}

/// A std.Thread; `qos` is ignored (thread_qos is unsupported until built).
pub fn spawnThread(options: platform.ThreadOptions, entry: *const fn (?*anyopaque) callconv(.c) void, context: ?*anyopaque) Error!platform.Thread {
    const start = std.heap.c_allocator.create(Start) catch return error.OutOfMemory;
    errdefer std.heap.c_allocator.destroy(start);
    start.* = .{ .entry = entry, .context = context, .name = [_:0]u8{0} ** 16 };
    const name = options.name.slice();
    @memcpy(start.name[0..@min(name.len, 15)], name[0..@min(name.len, 15)]);
    const thread = std.heap.c_allocator.create(std.Thread) catch return error.OutOfMemory;
    errdefer std.heap.c_allocator.destroy(thread);
    const config: std.Thread.SpawnConfig = if (options.stack_size != 0) .{ .stack_size = options.stack_size } else .{};
    thread.* = std.Thread.spawn(config, threadMain, .{start}) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.Busy,
    };
    return .{ .handle = @intFromPtr(thread) };
}

pub fn joinThread(thread: platform.Thread) void {
    const handle: *std.Thread = @ptrFromInt(thread.handle);
    handle.join();
    std.heap.c_allocator.destroy(handle);
}

// ---------------------------------------------------------------------------
// 6.5 Files: the process Io (host.zig)
// ---------------------------------------------------------------------------

fn fileError(err: anyerror) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.FileNotFound, error.NotDir => error.NotFound,
        error.AccessDenied, error.PermissionDenied, error.ReadOnlyFileSystem => error.AccessDenied,
        error.PathAlreadyExists => error.AlreadyExists,
        error.NoSpaceLeft, error.DiskQuota => error.NoSpace,
        error.Canceled => error.Canceled,
        error.FileBusy, error.DeviceBusy => error.Busy,
        else => error.Io,
    };
}

fn fileKind(kind: std.Io.File.Kind) platform.FileKind {
    return switch (kind) {
        .file => .file,
        .directory => .directory,
        .sym_link => .sym_link,
        else => .other,
    };
}

pub fn makeDirectoryPath(path: Str) Error!void {
    std.Io.Dir.cwd().createDirPath(host.io(), path.slice()) catch |err| return fileError(err);
}

pub fn readFile(allocator: std.mem.Allocator, path: Str, limit: usize) Error![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(host.io(), path.slice(), allocator, .limited(limit)) catch |err| return fileError(err);
}

pub fn writeFileAtomic(path: Str, bytes: Bytes) Error!void {
    var name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var nonce: [8]u8 = undefined;
    fillRandom(&nonce);
    const temporary = std.fmt.bufPrint(&name_buffer, "{s}.{x}.tmp", .{ path.slice(), std.mem.readInt(u64, &nonce, .little) }) catch return error.Io;
    const cwd = std.Io.Dir.cwd();
    cwd.writeFile(host.io(), .{ .sub_path = temporary, .data = bytes.slice() }) catch |err| return fileError(err);
    cwd.rename(temporary, cwd, path.slice(), host.io()) catch |err| {
        cwd.deleteFile(host.io(), temporary) catch {};
        return fileError(err);
    };
}

pub fn deleteFile(path: Str) Error!void {
    std.Io.Dir.cwd().deleteFile(host.io(), path.slice()) catch |err| return fileError(err);
}

pub fn deleteTree(path: Str) Error!void {
    std.Io.Dir.cwd().deleteTree(host.io(), path.slice()) catch |err| return fileError(err);
}

pub fn fileInfo(path: Str) Error!platform.FileInfo {
    const stat = std.Io.Dir.cwd().statFile(host.io(), path.slice(), .{}) catch |err| return fileError(err);
    return .{
        .size = stat.size,
        .modified = .{ .ns_since_epoch = @intCast(stat.mtime.nanoseconds) },
        .kind = fileKind(stat.kind),
    };
}

pub fn listDirectory(allocator: std.mem.Allocator, path: Str) Error![]platform.DirEntry {
    const io = host.io();
    var dir = std.Io.Dir.cwd().openDir(io, path.slice(), .{ .iterate = true }) catch |err| return fileError(err);
    defer dir.close(io);
    var entries: std.ArrayList(platform.DirEntry) = .empty;
    errdefer {
        for (entries.items) |entry| allocator.free(entry.name.slice());
        entries.deinit(allocator);
    }
    var it = dir.iterate();
    while (it.next(io) catch |err| return fileError(err)) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        entries.append(allocator, .{ .name = Str.from(name), .kind = fileKind(entry.kind) }) catch {
            allocator.free(name);
            return error.OutOfMemory;
        };
    }
    return entries.toOwnedSlice(allocator);
}

/// statvfs(3)'s f_blocks / f_bavail in f_frsize units.
pub fn volumeSpace(path: Str) Error!platform.VolumeSpace {
    var buffer: [std.fs.max_path_bytes + 1]u8 = undefined;
    if (path.len >= buffer.len) return error.Io;
    @memcpy(buffer[0..path.len], path.slice());
    buffer[path.len] = 0;
    var stats: Statvfs = undefined;
    if (statvfs(@ptrCast(&buffer), &stats) != 0) return error.Io;
    const unit: u64 = stats.f_frsize;
    return .{ .total = @as(u64, stats.f_blocks) * unit, .available = @as(u64, stats.f_bavail) * unit };
}

const Statvfs = if (builtin.os.tag.isDarwin()) extern struct {
    f_bsize: c_ulong,
    f_frsize: c_ulong,
    f_blocks: u32,
    f_bfree: u32,
    f_bavail: u32,
    f_files: u32,
    f_ffree: u32,
    f_favail: u32,
    f_fsid: c_ulong,
    f_flag: c_ulong,
    f_namemax: c_ulong,
} else extern struct {
    f_bsize: c_ulong,
    f_frsize: c_ulong,
    f_blocks: u64,
    f_bfree: u64,
    f_bavail: u64,
    f_files: u64,
    f_ffree: u64,
    f_favail: u64,
    f_fsid: c_ulong,
    f_flag: c_ulong,
    f_namemax: c_ulong,
    __f_spare: [6]c_int,
};

extern "c" fn statvfs(path: [*:0]const u8, buf: *Statvfs) c_int;

// ---------------------------------------------------------------------------
// Identity: today's strings (src/webidl/impls/Navigator.zig,
// src/fetch/internal/user_agent.zig)
// ---------------------------------------------------------------------------

/// The identity today's code answers on this target.
pub const identity: platform.Identity = .{
    .navigator_platform = Str.from(switch (builtin.os.tag) {
        .macos => "MacIntel",
        .linux => "Linux x86_64",
        .windows => "Win32",
        else => "Unknown",
    }),
    .ua_os_token = Str.from(switch (builtin.os.tag) {
        .macos => "Macintosh; Intel Mac OS X",
        .linux => "X11; Linux x86_64",
        .windows => "Windows NT 10.0; Win64; x64",
        else => "",
    }),
    .oscpu = Str.from(switch (builtin.os.tag) {
        .macos => "Intel Mac OS X",
        .linux => "Linux x86_64",
        .windows => "Windows NT 10.0; Win64; x64",
        else => "Unknown",
    }),
    .native_line_ending = Str.from(if (builtin.os.tag == .windows) "\r\n" else "\n"),
    .path_separator = std.fs.path.sep,
    .storage_engine = switch (builtin.os.tag) {
        .ios => .sqlite,
        .macos, .linux => .leveldb,
        else => .memory,
    },
};
