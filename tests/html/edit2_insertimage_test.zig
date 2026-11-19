//! Lane edit2, group 6: insertImage puts the img between the inline
//! elements around the insertion point, splitting them and dropping the
//! ones the deletion emptied (src/html/execcommand/insert_content.zig
//! splitInlinesForInsertion; editing/run/insertimage.html, PPP unless
//! marked, wpt.fyi 2358bd4835).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

const image_cases = [_]harness.Case{
    .{ .input = "foo<b>[bar]</b>baz", .commands = &.{.{ "insertimage", "/img/lion.svg" }}, .expected = "foo<img src=\"/img/lion.svg\">baz" },
    .{ .input = "foo<span>{bar}</span>baz", .commands = &.{.{ "insertimage", "/img/lion.svg" }}, .expected = "foo<img src=\"/img/lion.svg\">baz" },
    .{ .input = "<b>foo[bar</b><i>baz]quz</i>", .commands = &.{.{ "insertimage", "/img/lion.svg" }}, .expected = "<b>foo</b><img src=\"/img/lion.svg\"><i>quz</i>" },
    .{ .input = "<span>foo[</span><span>]bar</span>", .commands = &.{.{ "insertimage", "/img/lion.svg" }}, .expected = "<span>foo</span><img src=\"/img/lion.svg\"><span>bar</span>" },
    .{ .input = "<div><b>A[]B</b></div>", .commands = &.{.{ "insertimage", "/img/lion.svg" }}, .expected = "<div><b>A</b><img src=\"/img/lion.svg\"><b>B</b></div>" },
    // Firefox and Safari: the br stays in its b.
    .{ .input = "<div><b>{}<br></b></div>", .commands = &.{.{ "insertimage", "/img/lion.svg" }}, .expected = "<div><img src=\"/img/lion.svg\"><b><br></b></div>" },
    .{ .input = "foo[]bar", .commands = &.{.{ "insertimage", "/img/lion.svg" }}, .expected = "foo<img src=\"/img/lion.svg\">bar" },
};

fn imageCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &image_cases);
}

test "insertImage inserts between the inline elements around the point, as the browsers do" {
    try helpers.onFreshThread(imageCases);
}

/// insertHTML of a list into an empty list item gives the list its items
/// (inserthtml.html; all three).
const list_cases = [_]harness.Case{
    .{ .input = "<ul id=\"old\"><li id=\"li0\">{}<br></ul>", .commands = &.{.{ "inserthtml", "<ul id=\"new\"><li id=\"li1\">abc</li><li id=\"li2\">def</li></ul>" }}, .expected = "<ul id=\"old\"><li id=\"li1\">abc</li><li id=\"li2\">def</li></ul>" },
    .{ .input = "<ul id=\"old\"><li id=\"li0\">{}<br></ul>", .commands = &.{.{ "inserthtml", "<ol id=\"new\"><li id=\"li1\">abc</li><li id=\"li2\">def</li></ol>" }}, .expected = "<ul id=\"old\"><li id=\"li1\">abc</li><li id=\"li2\">def</li></ul>" },
};

fn listCases() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    try harness.runCases(page, &list_cases);
}

test "insertHTML of a list into an empty list item gives the list its items" {
    try helpers.onFreshThread(listCases);
}
