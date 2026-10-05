//! [HTMLConstructor] reaches the binding as `html_constructor = true`.
//!
//! HTML 3.2.3 "HTML element constructors": an interface whose constructor
//! carries [HTMLConstructor] has HTML's overridden constructor steps, which
//! the binding runs across the engine seam (engine.HostHooks.htmlConstructor).
//! Before this the generated interface said nothing of it, and HTMLElement's
//! constructor made a plain element.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

fn render(constructors: []const types.Constructor) !std.Io.Writer.Allocating {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    errdefer buffer.deinit();
    try writer.writeHTMLConstructor(&buffer.writer, constructors);
    return buffer;
}

test "an [HTMLConstructor] constructor writes html_constructor = true" {
    var ext = [_]types.ExtendedAttribute{.{ .name = "HTMLConstructor" }};
    const constructors = [_]types.Constructor{.{ .extAttrs = &ext }};
    var buffer = try render(&constructors);
    defer buffer.deinit();
    try testing.expect(std.mem.indexOf(u8, buffer.written(), "pub const html_constructor = true;") != null);
}

test "a plain constructor, or none, writes nothing" {
    var ext = [_]types.ExtendedAttribute{.{ .name = "Exposed" }};
    const plain = [_]types.Constructor{.{ .extAttrs = &ext }};
    var buffer = try render(&plain);
    defer buffer.deinit();
    try testing.expectEqualStrings("", buffer.written());

    var none = try render(&.{});
    defer none.deinit();
    try testing.expectEqualStrings("", none.written());
}

/// Whether the committed generated interface `name` has the flag.
fn committedFlag(name: []const u8) !bool {
    const path = try std.fmt.allocPrint(testing.allocator, "src/webidl/interfaces/{s}.zig", .{name});
    defer testing.allocator.free(path);
    const text = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(16 << 20));
    defer testing.allocator.free(text);
    return std.mem.indexOf(u8, text, "pub const html_constructor = true;") != null;
}

test "the committed tree flags HTML's element interfaces and nothing else" {
    // html.idl: [HTMLConstructor] constructor() on HTMLElement and its
    // element interfaces.
    for ([_][]const u8{ "HTMLElement", "HTMLParagraphElement", "HTMLDivElement", "HTMLButtonElement", "HTMLImageElement", "HTMLAudioElement", "HTMLOptionElement" }) |name| {
        if (!try committedFlag(name)) {
            std.debug.print("{s} lacks html_constructor\n", .{name});
            return error.TestExpectedEqual;
        }
    }
    // HTMLUnknownElement has no constructor at all ("intentionally no
    // [HTMLConstructor]"); the others construct as their own constructors do.
    for ([_][]const u8{ "HTMLUnknownElement", "Element", "Event", "URL", "Document" }) |name| {
        if (try committedFlag(name)) {
            std.debug.print("{s} has html_constructor\n", .{name});
            return error.TestUnexpectedResult;
        }
    }
}
