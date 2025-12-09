//! Reverse Index for Encoding Lookups
//!
//! This module provides O(log n) reverse lookups for encoding indexes.
//! Instead of linear O(n) scans through forward indexes (code_point = INDEX[pointer]),
//! we build sorted reverse indexes at runtime initialization for binary search.
//!
//! Performance improvement: ~500-1000x for encoding operations after initialization.
//!
//! Usage:
//!   // At startup (once)
//!   reverse_index.init();
//!
//!   // For lookups (O(log n))
//!   const ptr = reverse_index.jis0208.findPointer(0x3042);

const std = @import("std");

// Import forward indexes
const jis0208_index = @import("japanese/jis0208_index.zig");
const jis0212_index = @import("japanese/jis0212_index.zig");
const big5_index = @import("chinese/big5_index.zig");
const gb18030_index = @import("chinese/gb18030_index.zig");
const euc_kr_index = @import("korean/euc_kr_index.zig");

/// Entry in reverse lookup table
pub const Entry = struct {
    code_point: u21,
    pointer: u16,

    fn lessThan(_: void, a: Entry, b: Entry) bool {
        return a.code_point < b.code_point;
    }
};

/// A reverse index that maps code points to pointers
pub const ReverseIndex = struct {
    entries: []Entry,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ReverseIndex) void {
        self.allocator.free(self.entries);
        self.entries = &[_]Entry{};
    }

    /// Find pointer for a code point using binary search.
    /// Returns the FIRST occurrence if there are duplicates.
    pub fn findPointer(self: *const ReverseIndex, code_point: u21) ?u16 {
        if (self.entries.len == 0) return null;

        var left: usize = 0;
        var right: usize = self.entries.len;

        while (left < right) {
            const mid = left + (right - left) / 2;
            const mid_cp = self.entries[mid].code_point;

            if (mid_cp == code_point) {
                // Found it - but check for earlier duplicates (return first occurrence)
                var result_idx = mid;
                while (result_idx > 0 and self.entries[result_idx - 1].code_point == code_point) {
                    result_idx -= 1;
                }
                return self.entries[result_idx].pointer;
            } else if (mid_cp < code_point) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        return null;
    }

    /// Find the LAST pointer for a code point (for encodings that need last occurrence)
    pub fn findLastPointer(self: *const ReverseIndex, code_point: u21) ?u16 {
        if (self.entries.len == 0) return null;

        var left: usize = 0;
        var right: usize = self.entries.len;
        var result: ?u16 = null;

        while (left < right) {
            const mid = left + (right - left) / 2;
            const mid_cp = self.entries[mid].code_point;

            if (mid_cp == code_point) {
                result = self.entries[mid].pointer;
                // Continue searching right for later occurrences
                left = mid + 1;
            } else if (mid_cp < code_point) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        return result;
    }

    /// Find pointer with a minimum value constraint (for Big5 exclude_below logic)
    pub fn findPointerAbove(self: *const ReverseIndex, code_point: u21, min_pointer: u16) ?u16 {
        if (self.entries.len == 0) return null;

        var left: usize = 0;
        var right: usize = self.entries.len;

        // First find the first occurrence using lower bound
        while (left < right) {
            const mid = left + (right - left) / 2;
            const mid_cp = self.entries[mid].code_point;

            if (mid_cp < code_point) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        // Now scan forward through all occurrences of this code point
        while (left < self.entries.len and self.entries[left].code_point == code_point) {
            if (self.entries[left].pointer >= min_pointer) {
                return self.entries[left].pointer;
            }
            left += 1;
        }

        return null;
    }

    /// Find the last pointer above a minimum (for Big5 special cases)
    pub fn findLastPointerAbove(self: *const ReverseIndex, code_point: u21, min_pointer: u16) ?u16 {
        if (self.entries.len == 0) return null;

        var left: usize = 0;
        var right: usize = self.entries.len;
        var result: ?u16 = null;

        while (left < right) {
            const mid = left + (right - left) / 2;
            const mid_cp = self.entries[mid].code_point;

            if (mid_cp == code_point) {
                if (self.entries[mid].pointer >= min_pointer) {
                    result = self.entries[mid].pointer;
                }
                // Continue searching right for later occurrences
                left = mid + 1;
            } else if (mid_cp < code_point) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        return result;
    }
};

/// Build a reverse index from a forward index
fn buildReverseIndex(allocator: std.mem.Allocator, forward_index: []const u21) !ReverseIndex {
    // Count non-zero entries
    var count: usize = 0;
    for (forward_index) |cp| {
        if (cp != 0) count += 1;
    }

    // Allocate and populate
    const entries = try allocator.alloc(Entry, count);
    errdefer allocator.free(entries);

    var idx: usize = 0;
    for (forward_index, 0..) |cp, i| {
        if (cp != 0) {
            entries[idx] = .{
                .code_point = cp,
                .pointer = @intCast(i),
            };
            idx += 1;
        }
    }

    // Sort by code_point for binary search
    std.mem.sort(Entry, entries, {}, Entry.lessThan);

    return ReverseIndex{
        .entries = entries,
        .allocator = allocator,
    };
}

// Global reverse indexes - initialized once at startup
var jis0208: ReverseIndex = .{ .entries = &[_]Entry{}, .allocator = undefined };
var jis0212: ReverseIndex = .{ .entries = &[_]Entry{}, .allocator = undefined };
var big5: ReverseIndex = .{ .entries = &[_]Entry{}, .allocator = undefined };
var gb18030: ReverseIndex = .{ .entries = &[_]Entry{}, .allocator = undefined };
var euc_kr: ReverseIndex = .{ .entries = &[_]Entry{}, .allocator = undefined };

var initialized = false;
var init_allocator: std.mem.Allocator = undefined;

/// Initialize all reverse indexes. Call once at startup.
/// Uses a page allocator for the lifetime of the program.
pub fn init() void {
    if (initialized) return;

    // Use page allocator - these live for the entire program
    init_allocator = std.heap.page_allocator;

    jis0208 = buildReverseIndex(init_allocator, &jis0208_index.INDEX) catch {
        return; // Failed to init, will fall back to linear scan
    };
    jis0212 = buildReverseIndex(init_allocator, &jis0212_index.INDEX) catch {
        return;
    };
    big5 = buildReverseIndex(init_allocator, &big5_index.INDEX) catch {
        return;
    };
    gb18030 = buildReverseIndex(init_allocator, &gb18030_index.INDEX) catch {
        return;
    };
    euc_kr = buildReverseIndex(init_allocator, &euc_kr_index.INDEX) catch {
        return;
    };

    initialized = true;
}

/// Cleanup all reverse indexes (optional, for clean shutdown)
pub fn deinit() void {
    if (!initialized) return;

    jis0208.deinit();
    jis0212.deinit();
    big5.deinit();
    gb18030.deinit();
    euc_kr.deinit();

    initialized = false;
}

/// Check if reverse indexes are initialized
pub fn isInitialized() bool {
    return initialized;
}

// ============================================================================
// Public lookup functions - fallback to linear scan if not initialized
// ============================================================================

/// Find JIS X 0208 pointer for code point
pub fn findJis0208Pointer(code_point: u21) ?u16 {
    if (initialized) {
        return jis0208.findPointer(code_point);
    }
    // Fallback to linear scan
    return linearScan(&jis0208_index.INDEX, code_point);
}

/// Find JIS X 0212 pointer for code point
pub fn findJis0212Pointer(code_point: u21) ?u16 {
    if (initialized) {
        return jis0212.findPointer(code_point);
    }
    return linearScan(&jis0212_index.INDEX, code_point);
}

/// Find Big5 pointer for code point (first occurrence)
pub fn findBig5Pointer(code_point: u21) ?u16 {
    if (initialized) {
        return big5.findPointer(code_point);
    }
    return linearScan(&big5_index.INDEX, code_point);
}

/// Find Big5 pointer above minimum (for special ranges)
pub fn findBig5PointerAbove(code_point: u21, min_pointer: u16) ?u16 {
    if (initialized) {
        return big5.findPointerAbove(code_point, min_pointer);
    }
    return linearScanAbove(&big5_index.INDEX, code_point, min_pointer);
}

/// Find GB18030 pointer for code point
pub fn findGb18030Pointer(code_point: u21) ?u16 {
    if (initialized) {
        return gb18030.findPointer(code_point);
    }
    return linearScan(&gb18030_index.INDEX, code_point);
}

/// Find EUC-KR pointer for code point
pub fn findEucKrPointer(code_point: u21) ?u16 {
    if (initialized) {
        return euc_kr.findPointer(code_point);
    }
    return linearScan(&euc_kr_index.INDEX, code_point);
}

// ============================================================================
// Fallback linear scan functions (same as original implementations)
// ============================================================================

fn linearScan(index: []const u21, code_point: u21) ?u16 {
    for (index, 0..) |cp, i| {
        if (cp == code_point) return @intCast(i);
    }
    return null;
}

fn linearScanAbove(index: []const u21, code_point: u21, min_pointer: u16) ?u16 {
    for (index[min_pointer..], min_pointer..) |cp, i| {
        if (cp == code_point) return @intCast(i);
    }
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "reverse index initialization and lookup" {
    const testing = std.testing;

    // Initialize
    init();
    defer deinit();

    try testing.expect(isInitialized());

    // Test JIS X 0208 lookup - 0x3000 (ideographic space) should be at pointer 0
    try testing.expectEqual(@as(?u16, 0), findJis0208Pointer(0x3000));

    // Test hiragana 'a' (あ) - 0x3042
    const hiragana_a_ptr = findJis0208Pointer(0x3042);
    try testing.expect(hiragana_a_ptr != null);

    // Verify round-trip
    if (hiragana_a_ptr) |ptr| {
        try testing.expectEqual(@as(u21, 0x3042), jis0208_index.INDEX[ptr]);
    }

    // Test non-existent code point
    try testing.expectEqual(@as(?u16, null), findJis0208Pointer(0x0001));
}

test "big5 reverse index with minimum pointer" {
    const testing = std.testing;

    init();
    defer deinit();

    // Test that findBig5PointerAbove works
    const result = findBig5PointerAbove(0x3000, 0);
    try testing.expect(result != null);
}

test "gb18030 reverse index lookup" {
    const testing = std.testing;

    init();
    defer deinit();

    // Test a common Chinese character - 中 (0x4E2D)
    const result = findGb18030Pointer(0x4E2D);
    try testing.expect(result != null);

    // Verify round-trip
    if (result) |ptr| {
        try testing.expectEqual(@as(u21, 0x4E2D), gb18030_index.INDEX[ptr]);
    }
}

test "fallback to linear scan when not initialized" {
    const testing = std.testing;

    // Ensure not initialized
    deinit();
    try testing.expect(!isInitialized());

    // Should still work via linear scan
    const result = findJis0208Pointer(0x3000);
    try testing.expectEqual(@as(?u16, 0), result);
}
