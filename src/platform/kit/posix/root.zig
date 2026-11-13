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
// <time.h>, translated by build.zig (addCImport) with the target's libc headers,
// the iPhoneOS SDK's for aarch64-ios.
const c_time = @import("c_time");
const signal_stack = @import("signal_stack.zig");

const log = std.log.scoped(.platform);

const Str = platform.Str;
const Bytes = platform.Bytes;
const Error = platform.Error;

// ---------------------------------------------------------------------------
// 6.1 Process and identity
// ---------------------------------------------------------------------------

/// The process Io (host.zig) starts on first use, so initializing it here
/// only moves that moment earlier. And the process's soft descriptor limit is
/// raised (`raiseDescriptorLimit`).
pub fn initializePlatform(options: *const platform.PlatformOptions) Error!void {
    _ = options;
    _ = host.io();
    raiseDescriptorLimit(descriptor_limit);
}

/// The soft RLIMIT_NOFILE the platform's start asks for: Chromium's number.
///
/// A process inherits macOS's soft limit of 256 (Linux distributions start
/// at 1024), and a page's connections hold descriptors - each WebSocket a
/// curl multi handle's wakeup pipe and a socket while it connects - while
/// mbedTLS on macOS opens /dev/urandom to seed every TLS connection
/// (library/entropy_poll.c: no getrandom there). At 256 a burst of sockets
/// left a wss:// handshake without the descriptor its seed needed: curl 35
/// "CTR_DRBG - The entropy source failed" (lane flaky5,
/// websockets/Create-blocked-port.any.js ?wss "Basic check").
///
/// Browsers raise it at start, as here. Chromium's
/// BrowserMainLoop::EarlyInitialization calls base::IncreaseFdLimitTo(8192)
/// on Apple platforms, Linux, ChromeOS and Android ("the default limit on
/// Apple is low (256), so bump it up", crbug.com/539567); Gecko's
/// XRE_mainInit calls mozilla::startup::IncreaseDescriptorLimits on Unix.
const descriptor_limit: std.c.rlim_t = 8192;

/// Raise the soft descriptor limit to `wanted`, or to the hard limit when
/// that is lower, as base::IncreaseFdLimitTo does: a soft limit already at
/// `wanted` or above (unlimited included) is kept, and the hard limit - the
/// user's - is never changed. A failure leaves the limit as it was.
fn raiseDescriptorLimit(wanted: std.c.rlim_t) void {
    var limits: std.c.rlimit = undefined;
    const read = std.c.getrlimit(.NOFILE, &limits);
    if (read != 0) {
        log.warn("could not read the descriptor limit (RLIMIT_NOFILE): {t}", .{std.posix.errno(read)});
        return;
    }
    if (wanted <= limits.cur) return;
    const soft = if (limits.max != std.c.RLIM.INFINITY and limits.max < wanted) limits.max else wanted;
    if (soft <= limits.cur) return;
    const from = limits.cur;
    limits.cur = soft;
    const set = std.c.setrlimit(.NOFILE, &limits);
    if (set != 0) {
        log.warn("could not raise the soft descriptor limit from {d} to {d}: {t}", .{ from, soft, std.posix.errno(set) });
    }
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

/// The OS applies its historical local-zone rules. No embedded transition
/// table or UTC fallback. defaultTimeZone's existing regular-file fallback
/// can misidentify this zone as UTC; its repair is a queued PLATFORM item.
pub fn localDateTime(time: platform.WallTime) platform.LocalDateTime {
    // Floor, not truncate: the nanosecond before the epoch is in 1969.
    const seconds: c_time.time_t = @intCast(@divFloor(time.ns_since_epoch, std.time.ns_per_s));
    var fields: c_time.struct_tm = undefined;
    // POSIX permits localtime_r to rely on the caller having called tzset.
    // libc owns the zone data; the output is caller-owned, never a static tm.
    c_time.tzset();
    if (c_time.localtime_r(&seconds, &fields) == null) {
        // WallTime's range (1677-2262) fits these platforms' 64-bit time_t
        // and tm_year. Failure cannot be represented by this operation.
        @panic("localtime_r cannot represent WallTime");
    }
    return .{
        .year = fields.tm_year + 1900,
        .month = @intCast(fields.tm_mon + 1),
        .day = @intCast(fields.tm_mday),
        .hour = @intCast(fields.tm_hour),
        .minute = @intCast(fields.tm_min),
        .second = @intCast(fields.tm_sec),
    };
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

/// Every Browser reads the OS clocks above: no clock of its own.
pub fn browserClock(browser: *platform.BrowserPlatform) platform.BrowserClock {
    _ = browser;
    return .real;
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

/// No Browser has a random stream of its own: each consumer keeps its own
/// entropy.
pub fn fillBrowserRandom(browser: *platform.BrowserPlatform, bytes: []u8) bool {
    _ = .{ browser, bytes };
    return false;
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
    // Every thread the platform starts has its alternate signal stack
    // (signal_stack.zig), released when its entry returns.
    const stack = signal_stack.attach();
    defer signal_stack.detach(stack);
    entry(context);
}

/// A std.Thread; `qos` is ignored (thread_qos is unsupported until built).
pub fn spawnThread(options: platform.ThreadOptions, entry: *const fn (?*anyopaque) callconv(.c) void, context: ?*anyopaque) Error!platform.Thread {
    const start = std.heap.c_allocator.create(Start) catch return error.OutOfMemory;
    errdefer std.heap.c_allocator.destroy(start);
    start.* = .{ .entry = entry, .context = context, .name = @as([16:0]u8, @splat(0)) };
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

/// The calling thread's alternate signal stack, mapped with guard pages
/// (signal_stack.zig); 0 when the thread keeps one it already has.
pub fn attachSignalStack() platform.SignalStack {
    return .{ .handle = signal_stack.attach() };
}

pub fn detachSignalStack(stack: platform.SignalStack) void {
    signal_stack.detach(stack.handle);
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
// 6.11 Address space: mmap, mprotect, madvise and munmap, with each OS's own
// rules (docs/platform-protocol.md 6.11). PartitionAlloc's POSIX page
// allocator is the model throughout (base/allocator/partition_allocator/src/
// partition_alloc/page_allocator_internals_posix.h at Chromium 145): reserve
// inaccessible; commit by protection; decommit by discarding in place,
// before any protection change; never unmap a part while the range lives.
// ---------------------------------------------------------------------------

const is_darwin = builtin.os.tag.isDarwin();
const is_linux = builtin.os.tag == .linux;

pub fn pageSize() usize {
    return std.heap.pageSize();
}

/// darwin: the label's VM tag - VM_MEMORY_APPLICATION_SPECIFIC_1 (240) on -
/// passed in mmap's file descriptor as VM_MAKE_TAG does (tag << 24). vmmap
/// and footprint show "App-Specific Tag 1" to "4"; Chrome uses 251-255 and V8
/// 255 (PartitionAlloc's page_allocator.h). Elsewhere -1: anonymous memory.
fn mapTag(label: platform.AddressLabel) c_int {
    if (comptime !is_darwin) return -1;
    return @bitCast(@as(u32, 240 + @as(u32, @backingInt(label))) << 24);
}

/// Linux's VMA name for a label: /proc/<pid>/maps shows `[anon:<name>]`.
fn linuxName(label: platform.AddressLabel) [*:0]const u8 {
    return switch (label) {
        .node_cage => "crane-node-cage",
        .objects => "crane-objects",
        .bytes => "crane-bytes",
        .heap_metadata => "crane-heap",
    };
}

/// prctl's PR_SET_VMA and PR_SET_VMA_ANON_NAME (linux/prctl.h), which
/// std.os.linux.PR does not name at this Zig (lane h1: the deep review's Z12).
const PR_SET_VMA: c_int = 0x53564d41;
const PR_SET_VMA_ANON_NAME: c_ulong = 0;

fn addressError(err: std.c.E) Error {
    return switch (err) {
        .NOMEM => error.OutOfMemory,
        .ACCES, .PERM => error.AccessDenied,
        else => error.Io,
    };
}

fn lastError() std.c.E {
    return @fromBackingInt(@intCast(std.c._errno().*));
}

/// An inaccessible anonymous mapping of `length` bytes at `hint` (a hint, not
/// MAP_FIXED: the kernel may place it elsewhere), or the error the OS gave.
fn mapInaccessible(hint: usize, length: usize, label: platform.AddressLabel) Error!usize {
    const flags: std.c.MAP = if (comptime is_linux)
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true, .NORESERVE = true }
    else
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true };
    const at: ?*align(std.heap.page_size_min) anyopaque = if (hint == 0) null else @ptrFromInt(hint);
    const mapped = std.c.mmap(at, length, .{}, flags, mapTag(label), 0);
    if (mapped == std.c.MAP_FAILED) return addressError(lastError());
    return @intFromPtr(mapped);
}

fn unmap(base: usize, length: usize) void {
    if (length == 0) return;
    if (std.c.munmap(@ptrFromInt(base), length) != 0) @panic("platform: munmap of a reservation's own pages failed");
}

/// Linux's part of a label, applied once to the whole of a range: its VMA
/// name (Linux 5.17 and later with CONFIG_ANON_VMA_NAME; silently absent
/// otherwise, as in PartitionAlloc's NameRegion) and, for the node cage,
/// MADV_NOHUGEPAGE - a sparse pool of 16 KiB spans in 2 MiB super pages costs
/// a whole huge page per touched super page under THP `always`, and
/// khugepaged undoes span decommit (oss review R4, appendix P3: 512 kB live
/// cost 64 MiB). The advice holds through later mprotects (P3's nohuge case).
fn linuxLabel(base: usize, length: usize, label: platform.AddressLabel) void {
    if (comptime !is_linux) return;
    _ = std.c.prctl(PR_SET_VMA, PR_SET_VMA_ANON_NAME, @as(c_ulong, base), @as(c_ulong, length), linuxName(label));
    if (label == .node_cage) {
        if (std.c.madvise(@ptrFromInt(base), length, std.os.linux.MADV.NOHUGEPAGE) != 0) {
            log.debug("MADV_NOHUGEPAGE on {x}+{x}: {t}", .{ base, length, lastError() });
        }
    }
}

/// The highest address a random hint may name: 2^46, the half of a 47-bit
/// user space the kernel can fill (PartitionAlloc's ASLR mask on 64-bit), and
/// the lowest: 4 GiB, above darwin's page zero. A 39-bit or 42-bit kernel
/// ignores a hint above its range and places the mapping itself.
const hint_floor: u64 = 1 << 32;
const hint_ceiling: u64 = 1 << 46;

/// A random address `alignment_offset` above a multiple of `alignment` for a
/// reservation of `size`, or null where there is no such room.
fn randomHint(size: usize, alignment: usize, alignment_offset: usize) ?usize {
    if (comptime @sizeOf(usize) < 8) return null;
    const first: u64 = std.math.divCeil(u64, hint_floor, alignment) catch return null;
    if (@as(u64, size) + alignment > hint_ceiling) return null;
    const last: u64 = (hint_ceiling - size - alignment) / alignment;
    if (last <= first) return null;
    var bytes: [8]u8 = undefined;
    fillRandom(&bytes);
    const k = first + std.mem.readInt(u64, &bytes, .little) % (last - first);
    return @intCast(k * alignment + alignment_offset);
}

fn checkRange(range: platform.AddressRange, offset: usize, length: usize) void {
    const page = std.heap.pageSize();
    if (offset % page != 0 or length % page != 0 or length == 0 or offset > range.size or length > range.size - offset)
        @panic("platform: a page range outside its reservation, or not page-aligned");
}

/// Reserve: PartitionAlloc's AllocPagesWithAlignOffset - a few exact-size
/// hints at random aligned addresses (kExactSizeTries), so a reservation
/// leaves no holes behind and does not land where the last one was released
/// (oss R12, appendix P4: over-reserve-and-trim alone got the released
/// address back 7 of 7 times); then over-reserve by the alignment and trim.
/// ThreadSanitizer builds skip the hints: a hint can fall outside TSan's
/// application ranges, and TSan kills a process whose mapping lands there
/// (tsan_interceptors_posix.cpp; Ladybird's 07a1107b7053).
pub fn reserveAddressSpace(size: usize, alignment: usize, alignment_offset: usize, label: platform.AddressLabel) Error!platform.AddressRange {
    const page = std.heap.pageSize();
    if (size == 0 or size % page != 0 or alignment < page or !std.math.isPowerOfTwo(alignment) or
        alignment_offset >= alignment or alignment_offset % page != 0)
        @panic("platform.reserveAddressSpace: size, alignment or offset not page-aligned");

    if (!builtin.sanitize_thread) {
        var tries: usize = 0;
        while (tries < 3) : (tries += 1) {
            const hint = randomHint(size, alignment, alignment_offset) orelse break;
            const got = try mapInaccessible(hint, size, label);
            if (got % alignment == alignment_offset) {
                linuxLabel(got, size, label);
                return .{ .base = got, .size = size };
            }
            unmap(got, size);
        }
    }

    const total = std.math.add(usize, size, alignment - page) catch return error.OutOfMemory;
    const raw = try mapInaccessible(0, total, label);
    const base = raw + ((alignment_offset -% raw) & (alignment - 1));
    unmap(raw, base - raw);
    unmap(base + size, raw + total - (base + size));
    linuxLabel(base, size, label);
    return .{ .base = base, .size = size };
}

/// darwin: a fresh inaccessible mapping over the uncommitted part, with the
/// new tag (MAP_FIXED over the reservation's own pages, which XNU replaces in
/// one step and restores if it fails). Linux: the VMA name and the huge-page
/// advice (linuxLabel).
pub fn labelAddressSpace(range: platform.AddressRange, offset: usize, length: usize, label: platform.AddressLabel) void {
    checkRange(range, offset, length);
    const base = range.base + offset;
    if (comptime is_darwin) {
        const mapped = std.c.mmap(@ptrFromInt(base), length, .{}, .{ .TYPE = .PRIVATE, .ANONYMOUS = true, .FIXED = true }, mapTag(label), 0);
        if (mapped == std.c.MAP_FAILED) {
            log.debug("labelAddressSpace {x}+{x}: {t}", .{ base, length, lastError() });
        } else if (@intFromPtr(mapped) != base) {
            @panic("platform.labelAddressSpace: MAP_FIXED placed the part elsewhere");
        }
    } else {
        linuxLabel(base, length, label);
    }
}

/// mprotect read-write; darwin then MADV_FREE_REUSE, so a page decommitted
/// with MADV_FREE_REUSABLE counts in the footprint again (appendix P1: 64 of
/// 64 MiB stayed "reusable" when written again without it). PartitionAlloc's
/// RecommitSystemPagesInternal: "On macOS, to update accounting, we need to
/// make another syscall" (crbug.com/823915). Harmless on a page never
/// decommitted, so every commit makes it.
pub fn commitPages(range: platform.AddressRange, offset: usize, length: usize) Error!void {
    checkRange(range, offset, length);
    const at: *align(std.heap.page_size_min) anyopaque = @ptrFromInt(range.base + offset);
    if (std.c.mprotect(at, length, .{ .READ = true, .WRITE = true }) != 0) return addressError(lastError());
    if (comptime is_darwin) {
        if (std.c.madvise(at, length, std.c.MADV.FREE_REUSE) != 0) {
            log.debug("MADV_FREE_REUSE on {x}+{x}: {t}", .{ range.base + offset, length, lastError() });
        }
    }
}

/// darwin: MADV_FREE_REUSABLE - the footprint drops at once - falling back
/// to MADV_DONTNEED when it fails (EPERM on an inaccessible page or a range
/// with one in it; PartitionAlloc: it "sometimes fails"); Linux and other
/// POSIX systems: MADV_DONTNEED, so the next touch reads zero (never
/// MADV_FREE, which "makes our memory measurements less predictable").
pub fn decommitPages(range: platform.AddressRange, offset: usize, length: usize) Error!void {
    checkRange(range, offset, length);
    const at: *align(std.heap.page_size_min) anyopaque = @ptrFromInt(range.base + offset);
    if (comptime is_darwin) {
        if (std.c.madvise(at, length, std.c.MADV.FREE_REUSABLE) == 0) return;
        log.debug("MADV_FREE_REUSABLE on {x}+{x}: {t}; falling back to MADV_DONTNEED", .{ range.base + offset, length, lastError() });
    }
    if (std.c.madvise(at, length, std.c.MADV.DONTNEED) != 0) return addressError(lastError());
}

pub fn protectPages(range: platform.AddressRange, offset: usize, length: usize, access: platform.PageAccess) Error!void {
    checkRange(range, offset, length);
    const at: *align(std.heap.page_size_min) anyopaque = @ptrFromInt(range.base + offset);
    const prot: std.c.PROT = switch (access) {
        .none => .{},
        .read => .{ .READ = true },
        .read_write => .{ .READ = true, .WRITE = true },
    };
    if (std.c.mprotect(at, length, prot) != 0) return addressError(lastError());
}

pub fn releaseAddressSpace(range: platform.AddressRange) void {
    unmap(range.base, range.size);
}

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
