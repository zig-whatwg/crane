//! The testing platform's per-Browser random stream (docs/platform-protocol.md
//! 6.3, `fillBrowserRandom`): opt in with PlatformBrowserOptions.random_seed,
//! so a run replays from its seed.
//!
//! Per Browser, never per process. V8's --random-seed is process-wide: it
//! gives every context of every isolate the same Math.random sequence, which
//! V8's own status file works around ("all of them get the same random seed",
//! test/mjsunit/mjsunit.status, the isolates variant). Each seeded Browser
//! here draws from a stream of its own instead.
//!
//! The generator is SplitMix64 (Steele, Lea and Flood, "Fast splittable
//! pseudorandom number generators", OOPSLA 2014), written out rather than
//! taken from std.Random, whose default generator may change with the
//! toolchain: a seed must replay the same stream on every Zig version. Its
//! state only ever adds a constant, so a draw is one atomic add - lock-free
//! from any thread. Not cryptographic, and never used for cryptography (the
//! protocol keeps that on fillRandom).

const std = @import("std");

pub const SeededRandom = struct {
    /// 0: no stream (`fill` answers false), as V8's --random-seed=0 means
    /// "the system's randomness".
    seed: u64,
    state: std.atomic.Value(u64),

    pub fn init(seed: u64) SeededRandom {
        return .{ .seed = seed, .state = .init(seed) };
    }

    /// Fill `bytes` from the stream, 8 bytes per draw, little-endian; a
    /// draw's unused tail is dropped. False, `bytes` untouched, without a
    /// seed.
    pub fn fill(self: *SeededRandom, bytes: []u8) bool {
        if (self.seed == 0) return false;
        var rest = bytes;
        while (rest.len > 0) {
            var word: [8]u8 = undefined;
            std.mem.writeInt(u64, &word, self.next(), .little);
            const n = @min(rest.len, word.len);
            @memcpy(rest[0..n], word[0..n]);
            rest = rest[n..];
        }
        return true;
    }

    const golden_gamma: u64 = 0x9e3779b97f4a7c15;

    fn next(self: *SeededRandom) u64 {
        const z = self.state.fetchAdd(golden_gamma, .monotonic) +% golden_gamma;
        return mix(z);
    }

    fn mix(value: u64) u64 {
        var z = value;
        z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
        z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
        return z ^ (z >> 31);
    }
};

test "SplitMix64: the reference implementation's sequence from state 1234567" {
    // prng.di.unimi.it/splitmix64.c from x = 1234567.
    var random: SeededRandom = .init(1234567);
    try std.testing.expectEqual(@as(u64, 6457827717110365317), random.next());
    try std.testing.expectEqual(@as(u64, 3203168211198807973), random.next());
    try std.testing.expectEqual(@as(u64, 9817491932198370423), random.next());
}
