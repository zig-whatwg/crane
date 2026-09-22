//! V8's `String::WriteUtf8` writes a terminating NUL and COUNTS it in its
//! return value (unless NO_NULL_TERMINATION is passed). A caller that slices
//! the buffer with that count gets "name\0", which matches nothing: every
//! lookup through WindowProperties - `window.<id>`, a bare `<id>` identifier,
//! `'<id>' in window` - searched for a name ending in NUL and never found it.
//! `helpers.writtenUtf8` is the one place that turns "what WriteUtf8
//! returned" into the string that was written.

const std = @import("std");
const testing = std.testing;
const v8 = @import("v8");
const writtenUtf8 = v8.helpers.writtenUtf8;

test "the NUL WriteUtf8 counts is not part of the name" {
    const buf = "byId\x00";
    try testing.expectEqualStrings("byId", writtenUtf8(buf, 5).?);
}

test "a count without a NUL (NO_NULL_TERMINATION) is taken as is" {
    const buf = "byId";
    try testing.expectEqualStrings("byId", writtenUtf8(buf, 4).?);
}

test "the empty string is written as a lone NUL and is a valid name" {
    const buf = "\x00";
    try testing.expectEqualStrings("", writtenUtf8(buf, 1).?);
}

test "a failed or empty write is no name" {
    const buf = "x";
    try testing.expect(writtenUtf8(buf, 0) == null);
    try testing.expect(writtenUtf8(buf, -1) == null);
}

test "a count beyond the buffer is no name" {
    const buf = "ab";
    try testing.expect(writtenUtf8(buf, 3) == null);
}
