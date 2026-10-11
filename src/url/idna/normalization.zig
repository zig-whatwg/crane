//! Unicode NFC for UTS #46 Processing step 2. Mapping/case folding is a
//! separate step: normalization itself preserves case (UAX #15 section 1.3).
const std = @import("std");
const infra = @import("infra");
const unicode_data = @import("unicode_data.zig");

/// Canonically decompose, reorder and compose UTF-8. Caller owns the result.
pub fn normalize(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var decomposed = infra.List(u21).init(allocator);
    defer decomposed.deinit();
    var it = (try std.unicode.Utf8View.init(input)).iterator();
    while (it.nextCodepoint()) |cp| try decomposeRecursive(allocator, cp, &decomposed);
    canonicalOrder(decomposed.toSliceMut());

    // Canonical composition checks every next character, including class-zero
    // characters (e.g. Bengali vowel-sign pairs), against the last starter.
    // An intervening character blocks if its class is >= the current class.
    var composed = infra.List(u21).init(allocator);
    defer composed.deinit();
    var starter: ?usize = null;
    var previous_cc: u8 = 0;
    for (decomposed.items()) |cp| {
        const cc = unicode_data.lookupCombiningClass(cp);
        if (starter) |index| {
            if (previous_cc == 0 or previous_cc < cc) {
                const first = composed.items()[index];
                const candidate = tryComposeHangul(first, cp) orelse unicode_data.lookupComposition(first, cp);
                if (candidate) |combined| {
                    if (!unicode_data.isCompositionExcluded(combined)) {
                        composed.toSliceMut()[index] = combined;
                        // Keep the class of the last *unconsumed* character.
                        continue;
                    }
                }
            }
        }
        if (cc == 0) starter = composed.len;
        try composed.append(cp);
        previous_cc = cc;
    }
    var result = infra.List(u8).init(allocator);
    defer result.deinit();
    for (composed.items()) |cp| {
        var buf: [4]u8 = undefined;
        const len = try std.unicode.utf8Encode(cp, &buf);
        try result.appendSlice(buf[0..len]);
    }
    return result.toOwnedSlice();
}

fn canonicalOrder(cps: []u21) void {
    if (cps.len < 2) return;
    for (1..cps.len) |index| {
        var i = index;
        const cc = unicode_data.lookupCombiningClass(cps[i]);
        if (cc == 0) continue;
        while (i > 0) : (i -= 1) {
            const previous_cc = unicode_data.lookupCombiningClass(cps[i - 1]);
            if (previous_cc <= cc) break;
            std.mem.swap(u21, &cps[i - 1], &cps[i]);
        }
    }
}
/// Hangul syllable decomposition constants
const HANGUL_SBASE: u21 = 0xAC00;
const HANGUL_LBASE: u21 = 0x1100;
const HANGUL_VBASE: u21 = 0x1161;
const HANGUL_TBASE: u21 = 0x11A7;
const HANGUL_LCOUNT: u21 = 19;
const HANGUL_VCOUNT: u21 = 21;
const HANGUL_TCOUNT: u21 = 28;
const HANGUL_NCOUNT: u21 = HANGUL_VCOUNT * HANGUL_TCOUNT; // 588
const HANGUL_SCOUNT: u21 = HANGUL_LCOUNT * HANGUL_NCOUNT; // 11172

/// Recursively decompose a code point
fn decomposeRecursive(allocator: std.mem.Allocator, cp: u21, output: *infra.List(u21)) !void {
    // Hangul syllable decomposition (algorithmic)
    if (cp >= HANGUL_SBASE and cp < HANGUL_SBASE + HANGUL_SCOUNT) {
        const s_index = cp - HANGUL_SBASE;
        const l = HANGUL_LBASE + s_index / HANGUL_NCOUNT;
        const v = HANGUL_VBASE + (s_index % HANGUL_NCOUNT) / HANGUL_TCOUNT;
        const t = HANGUL_TBASE + s_index % HANGUL_TCOUNT;

        try output.append(l);
        try output.append(v);
        if (t != HANGUL_TBASE) {
            try output.append(t);
        }
        return;
    }

    if (unicode_data.lookupDecomposition(cp)) |decomp| {
        // Has decomposition - recursively decompose each part
        for (decomp) |dcp| {
            try decomposeRecursive(allocator, dcp, output);
        }
    } else {
        // No decomposition - add as-is
        try output.append(cp);
    }
}

/// Try to compose two Hangul jamo
fn tryComposeHangul(first: u21, second: u21) ?u21 {
    // L + V => LV
    if (first >= HANGUL_LBASE and first < HANGUL_LBASE + HANGUL_LCOUNT and
        second >= HANGUL_VBASE and second < HANGUL_VBASE + HANGUL_VCOUNT)
    {
        const l_index = first - HANGUL_LBASE;
        const v_index = second - HANGUL_VBASE;
        return HANGUL_SBASE + (l_index * HANGUL_VCOUNT + v_index) * HANGUL_TCOUNT;
    }

    // LV + T => LVT
    if (first >= HANGUL_SBASE and first < HANGUL_SBASE + HANGUL_SCOUNT and
        (first - HANGUL_SBASE) % HANGUL_TCOUNT == 0 and
        second > HANGUL_TBASE and second < HANGUL_TBASE + HANGUL_TCOUNT)
    {
        return first + (second - HANGUL_TBASE);
    }

    return null;
}
