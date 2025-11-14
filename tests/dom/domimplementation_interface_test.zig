//! Tests migrated from webidl/src/dom/DOMImplementation.zig
//! WebIDL interface tests

const std = @import("std");
const dom = @import("dom");

const source = @import("../../webidl/src/dom/DOMImplementation.zig");

test "isValidDoctypeName: empty string is valid" {
    try std.testing.expect(isValidDoctypeName(""));
}
test "isValidDoctypeName: normal name is valid" {
    try std.testing.expect(isValidDoctypeName("html"));
    try std.testing.expect(isValidDoctypeName("HTML"));
    try std.testing.expect(isValidDoctypeName("my-doctype"));
}
test "isValidDoctypeName: space is invalid" {
    try std.testing.expect(!isValidDoctypeName("html test"));
}
test "isValidDoctypeName: tab is invalid" {
    try std.testing.expect(!isValidDoctypeName("html\ttest"));
}
test "isValidDoctypeName: newline is invalid" {
    try std.testing.expect(!isValidDoctypeName("html\ntest"));
}
test "isValidDoctypeName: null is invalid" {
    try std.testing.expect(!isValidDoctypeName("html\x00test"));
}
test "isValidDoctypeName: > is invalid" {
    try std.testing.expect(!isValidDoctypeName("html>test"));
}