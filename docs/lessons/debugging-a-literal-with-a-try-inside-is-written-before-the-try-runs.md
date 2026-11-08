# Debugging: A literal with a `try` inside is written before the `try` runs

**Date**: 2026-11-08
**Lesson**: `x = .{ .field = try make() }` builds the literal in place, so a union `x` already has its new tag (an optional `x` is already non-null) when `make()` fails - and a `defer` or `errdefer` that releases `x` releases a payload that was never written.

**Why**: Zig's result-location semantics point each field of an aggregate literal at its place in the destination before the field's expression runs: Sema makes an initializing pointer to the union field, which sets the tag, or to the optional's payload, which sets the flag. A `try` (or an `orelse return`) inside the literal then leaves through the destination's cleanup with the destination half-made. What the payload holds is whatever bytes were there - target-dependent: a union initialized to a void arm stored zeros on aarch64 macOS and Zig's undefined byte 0xAA on x86-64 Linux.

**What Happened**: Eight css and custom-element tests passed on macOS for months and crashed on server1, the first x86-64 Linux host (lane linux1, 2026-11-08): shape_commands' `result.arc = .{ ..., .rotation = try a.rotation.compute(ctx) }` under `errdefer result.release()` read a Rotation tag of 0xAA ("index out of bounds: index 170, len 2"); motion_values' `data = .{ .ray = try consumeRay(...) orelse return null }` under `defer data.release()` released a ray position of 0xAAAA... (a GP fault) for every invalid `ray()`; reaction.zig's `owned.args = .{ .attribute_changed = try copyAttributeArgs(...) }` made `owned.deinit()` free a `local_name` it never owned (the fault was at a heap address - most likely a name copyAttributeArgs's own errdefer had already freed). A probe on chat2 (aarch64 Debug) showed the tag set before the `try` on macOS too: after a failed `u = .{ .some = try fail() }`, `activeTag(u)` was `.some`. A test that filled the stack with 0xAA first still passed on macOS - the zeros came from the destination's own initialization, not from the stack.

**Fix**: Make the value first, store it whole:

```zig
// Before: the tag is .ray before consumeRay runs.
data = .{ .ray = try consumeRay(options, stream) orelse return null };
// After:
const ray = try consumeRay(options, stream) orelse return null;
data = .{ .ray = ray };
```

A slot bounded by a counter is safe (`items[made] = .{ .x = try f() }; made += 1;` with a cleanup over `items[0..made]`), because the cleanup never reads the slot being made.

**Takeaway**: **Never put a `try` (or `orelse return`) inside a literal assigned to something a `defer`/`errdefer` releases - make each owned value into a local, then assign.** A passing test on one target proves nothing about the half-written payload: grep for `= .{ ... try` under a release, and test on x86-64 as well as arm64.
