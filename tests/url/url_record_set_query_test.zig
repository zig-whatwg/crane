//! `URLRecord.setQuery` is "set url's query" (URL § 4.1): the query becomes
//! the given string or null. A URL has a query iff it is non-null, so
//! setting one on a URL without a query must make `query()` return it - and
//! setting null must remove it, "?" and all.
//!
//! HTML form submission's "mutate action URL" and URLSearchParams' update
//! steps both set a query this way. Without `has_query` following the value,
//! the query was written into the buffer and then ignored: `query()` still
//! returned null, so the serialized URL had no "?" at all.

const std = @import("std");
const url_mod = @import("url");
const parser = url_mod.parser.basic_url_parser;

test "setting a query on a URL that has none gives it that query" {
    var url = try parser.parse(std.testing.allocator, "http://example.com/common/blank.html", null);
    defer url.deinit();
    try std.testing.expect(url.query() == null);

    try url.setQuery("input-0=%81%9A");
    try std.testing.expectEqualStrings("input-0=%81%9A", url.query().?);
}

test "setting a query replaces the old one and keeps the fragment" {
    var url = try parser.parse(std.testing.allocator, "http://example.com/p?old=1#frag", null);
    defer url.deinit();

    try url.setQuery("new=2");
    try std.testing.expectEqualStrings("new=2", url.query().?);
    try std.testing.expectEqualStrings("frag", url.fragment().?);
}

test "the empty string is a query; null is none" {
    var url = try parser.parse(std.testing.allocator, "http://example.com/p?a=b", null);
    defer url.deinit();

    try url.setQuery("");
    try std.testing.expectEqualStrings("", url.query().?);

    try url.setQuery(null);
    try std.testing.expect(url.query() == null);
}
