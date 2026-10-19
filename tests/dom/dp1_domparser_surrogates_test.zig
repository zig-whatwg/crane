//! DOMParser's XML input is scalar text; the binding's DOMString retains code units.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

test "dp1 XML DOMParser replaces lone surrogates in its owned input" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const parser = try interfaces.DOMParser.call_constructor(&context);
    defer interfaces.DOMParser.deinit(parser);

    // WTF-8 preserves the lone high and low UTF-16 code units. The valid
    // surrogate pair is already one supplementary code point in UTF-8.
    var source = "<root a='\xed\xa0\x80'><![CDATA[x\xed\xb0\x80y\xf0\x9f\x94\xa5]]></root>".*;
    const document = try interfaces.DOMParser.call_parseFromString(parser, .{
        .domstring = runtime.DOMString.initInterned(&source),
    }, ._text_xml_);
    defer interfaces.XMLDocument.deinit(document);
    const maybe_root = try interfaces.Document.get_documentElement(document);
    try std.testing.expect(maybe_root != null);
    const root = maybe_root.?;
    const maybe_attribute = try interfaces.Element.call_getAttribute(root, runtime.DOMString.initInterned("a"));
    try std.testing.expect(maybe_attribute != null);
    var attribute = maybe_attribute.?;
    defer attribute.deinit(allocator);
    try std.testing.expectEqualStrings("\xef\xbf\xbd", attribute.asSlice());
    var content = (try interfaces.Node.get_textContent(root)).?;
    defer content.deinit(allocator);
    try std.testing.expectEqualStrings("x\xef\xbf\xbdy\xf0\x9f\x94\xa5", content.asSlice());
    try std.testing.expectEqual(@as(u8, 0xed), source[9]);
}
