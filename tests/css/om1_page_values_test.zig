//! CSS Paged Media 3 §§4.2–4.3, 7; CSSOM §6.4.7.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn selectors(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css, "page_values")) return std.testing.expect(false);
    const Case = struct { input: []const u8, expected: ?[]const u8 };
    for ([_]Case{
        .{ .input = "", .expected = "" },
        .{ .input = " \n/**/ ", .expected = "" },
        .{ .input = ":left", .expected = ":left" },
        .{ .input = "named:First", .expected = "named:first" },
        .{ .input = "named:first:left:right:first", .expected = "named:first:left:right:first" },
        .{ .input = "named/**/:first", .expected = "named:first" },
        .{ .input = "  name1,  name2  ", .expected = "name1, name2" },
        .{ .input = "name1\\{\\}name2", .expected = "name1\\{\\}name2" },
        .{ .input = "\\61 :\\66 irst", .expected = "a:first" },
        .{ .input = "a,", .expected = null },
        .{ .input = ",a", .expected = null },
        .{ .input = ",", .expected = null },
        .{ .input = "named :first", .expected = null },
        .{ .input = ":first :left", .expected = null },
        .{ .input = ": first", .expected = null },
        .{ .input = "named::first", .expected = null },
        .{ .input = ":nth(2)", .expected = null },
        .{ .input = ":notapagepseudo", .expected = null },
        .{ .input = "a > b", .expected = null },
        .{ .input = "1", .expected = null },
    }) |case| {
        const result = try css.page_values.selectors(allocator, case.input);
        defer if (result) |text| allocator.free(text);
        if (case.expected) |expected| {
            try std.testing.expectEqualStrings(expected, result orelse return error.TestUnexpectedResult);
        } else try std.testing.expect(result == null);
    }
}

test "page selector lists preserve case and pseudo order without accepting internal whitespace" {
    try std.testing.checkAllAllocationFailures(a, selectors, .{});
}

fn descriptors(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css, "page_values")) return std.testing.expect(false);
    const model = css.page_values;
    const Case = struct { kind: model.Descriptor, input: []const u8, expected: ?[]const u8 };
    for ([_]Case{
        .{ .kind = .size, .input = "640px 480px", .expected = "640px 480px" },
        .{ .kind = .size, .input = "8.5in 11in", .expected = "8.5in 11in" },
        .{ .kind = .size, .input = "auto", .expected = "auto" },
        .{ .kind = .size, .input = "A5", .expected = "a5" },
        .{ .kind = .size, .input = "A4", .expected = "a4" },
        .{ .kind = .size, .input = "A3", .expected = "a3" },
        .{ .kind = .size, .input = "B5", .expected = "b5" },
        .{ .kind = .size, .input = "B4", .expected = "b4" },
        .{ .kind = .size, .input = "JIS-B5 landscape", .expected = "jis-b5 landscape" },
        .{ .kind = .size, .input = "JIS-B4", .expected = "jis-b4" },
        .{ .kind = .size, .input = "letter portrait", .expected = "letter" },
        .{ .kind = .size, .input = "legal landscape", .expected = "legal landscape" },
        .{ .kind = .size, .input = "ledger", .expected = "ledger" },
        .{ .kind = .size, .input = "216mm", .expected = "216mm" },
        .{ .kind = .size, .input = "1em 2ex", .expected = "1em 2ex" },
        .{ .kind = .size, .input = "50%", .expected = null },
        .{ .kind = .size, .input = "10px 50%", .expected = null },
        .{ .kind = .size, .input = "min-content", .expected = null },
        .{ .kind = .size, .input = "max-content", .expected = null },
        .{ .kind = .size, .input = "fit-content(100px)", .expected = null },
        .{ .kind = .size, .input = "min-content max-content", .expected = null },
        .{ .kind = .size, .input = "-1px", .expected = null },
        .{ .kind = .size, .input = "10px 20px 30px", .expected = null },
        .{ .kind = .size, .input = "a4 landscape portrait", .expected = null },
        .{ .kind = .size, .input = "a4 a3", .expected = null },
        .{ .kind = .size, .input = "auto landscape", .expected = null },
        .{ .kind = .size, .input = "landscape A4", .expected = "a4 landscape" },
        .{ .kind = .size, .input = "1px 1px", .expected = "1px" },
        .{ .kind = .size, .input = "calc(1cm + 1cm)", .expected = "calc(75.5906px)" },
        .{ .kind = .size, .input = "initial", .expected = "initial" },
        .{ .kind = .size, .input = "inherit", .expected = "inherit" },
        .{ .kind = .size, .input = "revert-layer", .expected = "revert-layer" },
        .{ .kind = .page_orientation, .input = "ROTATE-LEFT", .expected = "rotate-left" },
        .{ .kind = .page_orientation, .input = "rotate-right", .expected = "rotate-right" },
        .{ .kind = .page_orientation, .input = "upright", .expected = "upright" },
        .{ .kind = .page_orientation, .input = "upright rotate-left", .expected = null },
        .{ .kind = .marks, .input = "crop cross", .expected = null },
        .{ .kind = .marks, .input = "initial", .expected = null },
        .{ .kind = .bleed, .input = "-1mm", .expected = null },
        .{ .kind = .bleed, .input = "auto", .expected = null },
    }) |case| {
        const result = try model.descriptor(allocator, case.kind, case.input);
        defer if (result) |text| allocator.free(text);
        if (case.expected) |expected| {
            try std.testing.expectEqualStrings(expected, result orelse return error.TestUnexpectedResult);
        } else try std.testing.expect(result == null);
    }
}

test "page-specific descriptor grammars reuse CSS numbers and keep size separate from width" {
    try std.testing.checkAllAllocationFailures(a, descriptors, .{});
}

fn data(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css, "page_data")) return std.testing.expect(false);
    const Data = css.page_data.Data;
    const options: css.properties.ParseOptions = .{ .allocator = allocator };
    // Q47: parsed text AND CSSOM setters, ordinary properties and page
    // descriptors. The same grammar and serialization serve both paths.
    const Case = struct { name: []const u8, input: []const u8, expected: []const u8, priority: []const u8 = "" };
    for ([_]Case{
        .{ .name = "float", .input = "left", .expected = "left" },
        .{ .name = "display", .input = "block", .expected = "block" },
        .{ .name = "color", .input = "red", .expected = "red" },
        .{ .name = "background", .input = "blue", .expected = "blue" },
        .{ .name = "font-size", .input = "14px", .expected = "14px" },
        .{ .name = "width", .input = "3px", .expected = "3px" },
        // Q102 ROUTED: counter-increment:page must serialize as page 1 (WPT),
        // but BASE has no owning longhand. GENERATED CONTENT RESOLUTION owns it.
        .{ .name = "padding-top", .input = "3px", .expected = "3px" },
        .{ .name = "margin", .input = "2cm", .expected = "2cm" },
        .{ .name = "margin-top", .input = "1px", .expected = "1px" },
        .{ .name = "--x", .input = "2cm", .expected = "2cm" },
        .{ .name = "size", .input = "var(--x)", .expected = "var(--x)" },
        .{ .name = "size", .input = "calc(1cm + 1cm)", .expected = "calc(75.5906px)" },
        .{ .name = "size", .input = "initial", .expected = "initial" },
        .{ .name = "size", .input = "A4", .expected = "a4", .priority = "important" },
        .{ .name = "size", .input = "landscape A4", .expected = "a4 landscape" },
        .{ .name = "size", .input = "1px 1px", .expected = "1px" },
        .{ .name = "page-orientation", .input = "rotate-left", .expected = "rotate-left" },
        .{ .name = "marks", .input = "crop cross", .expected = "" },
        .{ .name = "bleed", .input = "-1mm", .expected = "" },
    }) |case| {
        const source = try std.fmt.allocPrint(allocator, "{s}: {s}{s};", .{ case.name, case.input, if (case.priority.len == 0) "" else " !important" });
        defer allocator.free(source);
        var parsed = try Data.parse(options, source);
        defer parsed.deinit();
        var set = Data.init(allocator);
        defer set.deinit();
        _ = try set.setProperty(options, case.name, case.input, case.priority);
        for ([_]*Data{ &parsed, &set }) |value| {
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(allocator);
            try value.getPropertyValue(case.name, &out);
            try std.testing.expectEqualStrings(case.expected, out.items);
            try std.testing.expectEqual(case.priority.len != 0, value.getPropertyPriority(case.name));
        }
    }

    var value = try Data.parse(options, "size: var(--x); --x: 2cm; margin: 1px; page-orientation: upright; marks: crop; bleed: auto");
    defer value.deinit();
    const pending_slot = @backingInt(css.page_values.Descriptor.size);
    try std.testing.expect(value.pending[pending_slot] != null);
    try std.testing.expect(value.pending[pending_slot].?.property == null);
    // This is page-owned metadata, never a typed style pending value.
    for (value.block.entries.items) |entry| if (entry == .typed) {
        try std.testing.expect(entry.typed.value != .value or entry.typed.value.value != .pending);
    };
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try value.block.serialize(&text);
    try std.testing.expectEqualStrings("size: var(--x); --x: 2cm; margin: 1px; page-orientation: upright;", text.items);
    // Variables1 §3 <var-args>: an empty first argument is malformed (Q107).
    try std.testing.expect(!try value.setProperty(options, "size", "var()", ""));
    try std.testing.expect(!try value.setProperty(options, "size", "a3", "invalid-priority"));
    try std.testing.expectEqualStrings("var(--x)", value.descriptorValue(.size));
    try std.testing.expect(try value.setProperty(options, "size", "a4", "important"));
    try std.testing.expect(value.pending[pending_slot] == null);
    try std.testing.expect(value.getPropertyPriority("SIZE"));
    try std.testing.expect(try value.setProperty(options, "size", "var(--y)", ""));
    text.clearRetainingCapacity();
    try std.testing.expect(try value.removeProperty("SIZE", &text));
    try std.testing.expectEqualStrings("var(--y)", text.items);
    try std.testing.expect(value.pending[pending_slot] == null);
    try std.testing.expect(try value.setProperty(options, "size", "var(--z)", ""));
    try std.testing.expect(try value.setProperty(options, "size", "", "invalid-priority"));
    try std.testing.expect(value.pending[pending_slot] == null);
    try value.setCssText(options, "size: var(--first) !important; color: blue; size: a3; --x: 1px !important; --x: 2px; size: var(--last) !important");
    text.clearRetainingCapacity();
    try value.block.serialize(&text);
    try std.testing.expectEqualStrings("color: blue; --x: 1px !important; size: var(--last) !important;", text.items);
    try value.setCssText(options, "size: a5");
    try std.testing.expect(value.pending[pending_slot] == null);
    try std.testing.expectEqualStrings("a5", value.descriptorValue(.size));
    try value.setCssText(options, "size: var(--open");
    try std.testing.expectEqualStrings("var(--open", value.descriptorValue(.size));

    // Variables1 §3 replacement step2 checks the name AFTER substitution.
    // Q107: a nonempty first argument is a real Pending at parse time.
    var from_parse = try Data.parse(options, "size: var(no-custom-name)");
    defer from_parse.deinit();
    var from_set = Data.init(allocator);
    defer from_set.deinit();
    try std.testing.expect(try from_set.setProperty(options, "size", "var(no-custom-name)", ""));
    for ([_]*Data{ &from_parse, &from_set }) |modern| {
        const pending = modern.pending[pending_slot] orelse return error.TestExpectedValue;
        try std.testing.expect(pending.property == null);
        try std.testing.expectEqualStrings("var(no-custom-name)", pending.text);
        try std.testing.expectEqualStrings("var(no-custom-name)", modern.descriptorValue(.size));
        try std.testing.expectEqual(@as(usize, 1), modern.block.entries.items.len);
        const entry = modern.block.entries.items[0];
        try std.testing.expect(entry == .unparsed);
        try std.testing.expectEqualStrings("size", entry.unparsed.name);
    }
}

test "page descriptors and real pending values are owned replaced and removed across every allocation failure" {
    try std.testing.checkAllAllocationFailures(a, data, .{});
}
