//! Current resident set size, for measuring whether memory is actually reclaimed.
//!
//! Phase 6's exit criterion is "RSS flat across 10,000 `document.createElement` +
//! discard cycles". That cannot be checked from outside the process - the runner
//! does one file and exits - and it cannot be checked with peak RSS either, because
//! peak only ever rises. Answering it needs CURRENT resident bytes, sampled
//! repeatedly inside one process.
//!
//! ## Why this is worth its own file
//!
//! Every RSS claim made about this codebase so far has had to be retracted at least
//! once, because the number came from `ls -l` on a binary or from `ps` against a
//! process built in a different optimisation mode. A single function that reads the
//! kernel's own accounting removes one whole class of that error.
//!
//! ## What the number means
//!
//! Resident bytes: physical pages currently backing this process. It falls when
//! pages are returned to the OS, which is exactly the signal a GC has to produce.
//! It does NOT fall when an allocator merely marks memory reusable, so a "flat RSS"
//! result is a strong claim and a rising one is unambiguous.
//!
//! On macOS `task_vm_info.resident_size` is the same figure Activity Monitor shows.
//! On Linux it is field 2 of `/proc/self/statm`, in pages.

const std = @import("std");
const builtin = @import("builtin");

/// Current resident set size in bytes, or null where the platform has no cheap
/// answer.
///
/// Null rather than an error: a caller measuring memory wants to say "not measured"
/// and carry on, not to fail. Callers MUST distinguish null from zero - the same
/// trap as reporting ownership violations without the check count.
pub fn residentBytes() ?usize {
    return switch (builtin.os.tag) {
        .macos, .ios, .tvos, .watchos, .visionos => darwinResident(),
        .linux => linuxResident(),
        else => null,
    };
}

fn darwinResident() ?usize {
    const c = std.c;
    var info: c.task_vm_info_data_t = undefined;
    var count: c.mach_msg_type_number_t = c.TASK.VM.INFO_COUNT;
    const rc = c.task_info(
        c.mach_task_self(),
        c.TASK.VM.INFO,
        @ptrCast(&info),
        &count,
    );
    // KERN_SUCCESS. `task_info` returns a bare kern_return_t here, not an enum.
    if (rc != 0) return null;
    return @intCast(info.resident_size);
}

fn linuxResident() ?usize {
    // statm's second field is resident pages. Read with a plain syscall rather than
    // std.Io: this is called from measurement loops that must not perturb the thing
    // being measured, and a procfs read has no meaningful failure mode beyond
    // "no answer".
    var buf: [128]u8 = undefined;
    const fd = std.posix.open("/proc/self/statm", .{ .ACCMODE = .RDONLY }, 0) catch return null;
    defer std.posix.close(fd);
    const n = std.posix.read(fd, &buf) catch return null;
    if (n == 0) return null;

    var it = std.mem.tokenizeScalar(u8, buf[0..n], ' ');
    _ = it.next() orelse return null; // total program size
    const resident_pages_str = it.next() orelse return null;
    const pages = std.fmt.parseInt(usize, resident_pages_str, 10) catch return null;
    return pages *| std.heap.pageSize();
}

/// Bytes currently held by malloc, or null where unavailable.
///
/// Separates "the C++ heap is growing" from "V8's own page allocator is growing".
/// Both show up identically in RSS, and they need completely different fixes: the
/// first is a missing `delete`, the second is V8 not returning pages. Without this
/// the two are indistinguishable and the search goes nowhere.
pub fn mallocInUseBytes() ?usize {
    if (builtin.os.tag != .macos) return null;
    const stats = mstats();
    return stats.bytes_used;
}

/// Total bytes malloc has taken from the OS, in use or not.
///
/// The pair matters. `bytes_used` climbing means something is leaking; `bytes_total`
/// climbing while `bytes_used` stays flat means the heap is FRAGMENTING - memory is
/// freed but the pages are not returned, so RSS keeps rising with nothing leaked.
/// Those need opposite fixes, and resident memory alone cannot tell them apart.
pub fn mallocHeapBytes() ?usize {
    if (builtin.os.tag != .macos) return null;
    const stats = mstats();
    return stats.bytes_total;
}

/// macOS `struct mstats` from <malloc/malloc.h>.
const MStats = extern struct {
    bytes_total: usize,
    chunks_used: usize,
    bytes_used: usize,
    chunks_free: usize,
    bytes_free: usize,
};

extern "c" fn mstats() MStats;

/// A before/after resident-memory reading.
///
/// Holds both samples rather than only the delta so a caller can report "not
/// measured" separately from "no change", and so an absolute figure is available -
/// a 2 MB growth means something different at 50 MB than at 2 GB.
pub const Sample = struct {
    before: ?usize,
    after: ?usize,

    pub fn start() Sample {
        return .{ .before = residentBytes(), .after = null };
    }

    pub fn finish(self: *Sample) void {
        self.after = residentBytes();
    }

    /// Bytes gained, or null if either end was unmeasured.
    ///
    /// Signed: RSS falling is the result a working collector produces, and an
    /// unsigned delta would report a 4 GB gain instead.
    pub fn delta(self: Sample) ?i128 {
        const b = self.before orelse return null;
        const a = self.after orelse return null;
        return @as(i128, @intCast(a)) - @as(i128, @intCast(b));
    }

    pub fn measured(self: Sample) bool {
        return self.before != null and self.after != null;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "resident size is available on this platform" {
    // Not `if (residentBytes()) |_| {}` - on the platforms Crane targets this must
    // actually work, and a silent null is how a measurement harness ends up
    // reporting nothing while looking healthy.
    switch (builtin.os.tag) {
        .macos, .ios, .tvos, .watchos, .visionos, .linux => {
            const rss = residentBytes() orelse return error.ResidentSizeUnavailable;
            // A live process with V8 or even just a test binary is far above this;
            // the bound only catches "returned a plausible-looking zero".
            try testing.expect(rss > 64 * 1024);
        },
        else => {},
    }
}

test "resident size tracks a large allocation" {
    // The measurement has to MOVE, or a flat reading later proves nothing. Touch
    // every page: allocating without writing may not fault pages in, and untouched
    // pages are not resident.
    const before = residentBytes() orelse return;

    const size = 64 * 1024 * 1024;
    const buf = try testing.allocator.alloc(u8, size);
    defer testing.allocator.free(buf);
    var i: usize = 0;
    while (i < buf.len) : (i += std.heap.pageSize()) buf[i] = 1;
    std.mem.doNotOptimizeAway(buf.ptr);

    const after = residentBytes() orelse return;

    // Half the allocation, to leave room for page-accounting differences without
    // letting a no-op implementation pass.
    try testing.expect(after > before + size / 2);
}

test "a sample reports measured/unmeasured rather than a bare zero" {
    var s = Sample.start();
    s.finish();

    if (s.measured()) {
        try testing.expect(s.delta() != null);
    } else {
        // Only reachable on a platform with no implementation, where the delta must
        // be null rather than 0 - a zero would read as "nothing leaked".
        try testing.expectEqual(@as(?i128, null), s.delta());
    }
}

test "delta is signed so reclamation is representable" {
    const s: Sample = .{ .before = 100 * 1024 * 1024, .after = 40 * 1024 * 1024 };
    try testing.expectEqual(@as(?i128, -60 * 1024 * 1024), s.delta());
}

test "an unmeasured end makes the whole sample unmeasured" {
    const a: Sample = .{ .before = null, .after = 1024 };
    const b: Sample = .{ .before = 1024, .after = null };
    try testing.expectEqual(@as(?i128, null), a.delta());
    try testing.expectEqual(@as(?i128, null), b.delta());
    try testing.expect(!a.measured());
    try testing.expect(!b.measured());
}
