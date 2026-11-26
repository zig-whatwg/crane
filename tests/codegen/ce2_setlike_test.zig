//! WebIDL 3.7.11 & 3.7.12: setlike and maplike declarations' members are the
//! binding's, never generated operations. Codegen writes `Meta.setlike` /
//! `Meta.maplike` and the `setlikeEntries` / `maplikeEntries` delegate for
//! EVERY setlike and maplike interface in the IDL — with no per-interface
//! allowlists, resolving typedefs (`UUID` -> `DOMString`), and supporting
//! string, primitive, interface, sequence, object, and DataView types.

const std = @import("std");
const codegen = @import("codegen");
const setlike = codegen.setlike;
const maplike = codegen.maplike;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

test "a setlike declaration adds no member to the merged model" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const parsed = try codegen.idl_parser.Parser.parse(arena.allocator(),
        \\[Exposed=Window] interface CustomStateSet { setlike<DOMString>; };
    );
    var model = try codegen.ir.IR.init(testing.allocator);
    defer model.deinit();
    try model.addInterface(parsed.interfaces[0], "ce2.idl");
    try model.finish();
    const members = model.interfaces.get("CustomStateSet").?.members.items;
    try testing.expectEqual(@as(usize, 1), members.len);
    try testing.expect(members[0].type == .setlike);
    try testing.expectEqualStrings("DOMString", members[0].setlike.?.value_type.type);
    try testing.expect(!members[0].setlike.?.readonly);
}

test "Meta.setlike records the value type and readonly" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try setlike.writeMeta(&buffer.writer, .{ .value_type = .{ .type = "DOMString" } });
    try testing.expect(contains(buffer.written(), "pub const setlike = .{ .value_type = \"DOMString\", .readonly = false };"));
    buffer.clearRetainingCapacity();
    try setlike.writeMeta(&buffer.writer, .{ .value_type = .{ .type = "DOMString" }, .readonly = true });
    try testing.expect(contains(buffer.written(), ".readonly = true };"));
}

test "the generated interface hands the impl's set entries to the binding" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try setlike.writeEntriesDelegate(&buffer.writer, "CustomStateSetImpl", .{ .value_type = .{ .type = "DOMString" } });
    const out = buffer.written();
    try testing.expect(contains(out, "pub fn setlikeEntries(instance: *runtime.Instance) ?*webidl.setlike.Strings {"));
    try testing.expect(contains(out, "return CustomStateSetImpl.setlikeEntries(instance);"));
}

test "setlike entriesType supports strings, primitives, and interfaces" {
    try testing.expectEqualStrings("webidl.setlike.Strings", try setlike.entriesType(.{ .type = "DOMString" }));
    try testing.expectEqualStrings("webidl.setlike.Strings", try setlike.entriesType(.{ .type = "USVString" }));
    try testing.expectEqualStrings("webidl.setlike.Strings", try setlike.entriesType(.{ .type = "ByteString" }));
    try testing.expectEqualStrings("webidl.setlike.Strings", try setlike.entriesType(.{ .type = "CSSOMString" }));
    try testing.expectEqualStrings("webidl.setlike.PlatformObjects", try setlike.entriesType(.{ .type = "FontFace" }));
    try testing.expectEqualStrings("webidl.setlike.PlatformObjects", try setlike.entriesType(.{ .type = "XRAnchor" }));
    try testing.expectEqualStrings("webidl.setlike.SetEntries(i32)", try setlike.entriesType(.{ .type = "long" }));
    try testing.expectEqualStrings("webidl.setlike.SetEntries(u16)", try setlike.entriesType(.{ .type = "unsigned short" }));
    try testing.expectEqualStrings("webidl.setlike.SetEntries(bool)", try setlike.entriesType(.{ .type = "boolean" }));
    try testing.expectError(error.UnsupportedSetlikeValueType, setlike.entriesType(.{ .type = "DOMString", .nullable = true }));
    try testing.expectError(error.UnsupportedSetlikeValueType, setlike.entriesType(.{ .type = "FontFace", .nullable = true }));
}

test "maplike writeMeta and writeEntriesDelegate cover all IDL key/value combinations" {
    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();

    // 1. String -> Interface (HighlightRegistry)
    const hl: codegen.types.Maplike = .{ .key_type = .{ .type = "DOMString" }, .value_type = .{ .type = "Highlight" } };
    try maplike.writeMeta(&buffer.writer, hl);
    try maplike.writeEntriesDelegate(&buffer.writer, "HighlightRegistryImpl", hl);
    try testing.expect(contains(buffer.written(), "pub const maplike = .{ .key_type = \"DOMString\", .value_type = \"Highlight\", .readonly = false };"));
    try testing.expect(contains(buffer.written(), "pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.PlatformObjects {"));

    // 2. CSSOMString -> sequence<unsigned long> (CSSFontFeatureValuesMap)
    buffer.clearRetainingCapacity();
    const css_map: codegen.types.Maplike = .{
        .key_type = .{ .type = "CSSOMString" },
        .value_type = .{ .type = "sequence", .generic = "unsigned long" },
    };
    try maplike.writeMeta(&buffer.writer, css_map);
    try maplike.writeEntriesDelegate(&buffer.writer, "CSSFontFeatureValuesMapImpl", css_map);
    try testing.expect(contains(buffer.written(), "pub const maplike = .{ .key_type = \"CSSOMString\", .value_type = \"sequence<unsigned long>\", .readonly = false };"));
    try testing.expect(contains(buffer.written(), "pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.View([]const u8, []const u32) {"));

    // 3. DOMString -> unsigned long long (EventCounts)
    buffer.clearRetainingCapacity();
    const ec: codegen.types.Maplike = .{
        .key_type = .{ .type = "DOMString" },
        .value_type = .{ .type = "unsigned long long" },
        .readonly = true,
    };
    try maplike.writeMeta(&buffer.writer, ec);
    try maplike.writeEntriesDelegate(&buffer.writer, "EventCountsImpl", ec);
    try testing.expect(contains(buffer.written(), "pub const maplike = .{ .key_type = \"DOMString\", .value_type = \"unsigned long long\", .readonly = true };"));
    try testing.expect(contains(buffer.written(), "pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.MapEntries([]const u8, u64) {"));

    // 4. DOMString -> DOMString (KeyboardLayoutMap)
    buffer.clearRetainingCapacity();
    const kl: codegen.types.Maplike = .{
        .key_type = .{ .type = "DOMString" },
        .value_type = .{ .type = "DOMString" },
        .readonly = true,
    };
    try maplike.writeEntriesDelegate(&buffer.writer, "KeyboardLayoutMapImpl", kl);
    try testing.expect(contains(buffer.written(), "pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.MapEntries([]const u8, []const u8) {"));

    // 5. unsigned short -> BluetoothDataFilter
    buffer.clearRetainingCapacity();
    const bmdf: codegen.types.Maplike = .{
        .key_type = .{ .type = "unsigned short" },
        .value_type = .{ .type = "BluetoothDataFilter" },
        .readonly = true,
    };
    try maplike.writeMeta(&buffer.writer, bmdf);
    try maplike.writeEntriesDelegate(&buffer.writer, "BluetoothManufacturerDataFilterImpl", bmdf);
    try testing.expect(contains(buffer.written(), "pub const maplike = .{ .key_type = \"unsigned short\", .value_type = \"BluetoothDataFilter\", .readonly = true };"));
    try testing.expect(contains(buffer.written(), "pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.View(u16, *anyopaque) {"));

    // 6. DOMString -> object (RTCStatsReport)
    buffer.clearRetainingCapacity();
    const rtc: codegen.types.Maplike = .{
        .key_type = .{ .type = "DOMString" },
        .value_type = .{ .type = "object" },
        .readonly = true,
    };
    try maplike.writeEntriesDelegate(&buffer.writer, "RTCStatsReportImpl", rtc);
    try testing.expect(contains(buffer.written(), "pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.View([]const u8, *anyopaque) {"));

    // 7. unsigned short -> DataView (BluetoothManufacturerDataMap)
    buffer.clearRetainingCapacity();
    const bmdm: codegen.types.Maplike = .{
        .key_type = .{ .type = "unsigned short" },
        .value_type = .{ .type = "DataView" },
        .readonly = true,
    };
    try maplike.writeEntriesDelegate(&buffer.writer, "BluetoothManufacturerDataMapImpl", bmdm);
    try testing.expect(contains(buffer.written(), "pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.View(u16, *anyopaque) {"));
}

test "setlike and maplike have no per-interface implemented allowlists" {
    try testing.expect(!@hasDecl(setlike, "implemented"));
    try testing.expect(!@hasDecl(maplike, "implemented"));
}

test "every generated setlike and maplike interface emits Meta and entries delegate" {
    const io = testing.io;
    const setlike_names = [_][]const u8{
        "CustomStateSet",
        "FontFaceSet",
        "FontFaceVariations",
        "GPUSupportedFeatures",
        "Highlight",
        "ViewTransitionTypeSet",
        "WGSLLanguageFeatures",
        "XRAnchorSet",
        "XRMeshSet",
        "XRPlaneSet",
    };
    for (setlike_names) |name| {
        const path = try std.fmt.allocPrint(testing.allocator, "src/webidl/interfaces/{s}.zig", .{name});
        defer testing.allocator.free(path);
        const content = try std.Io.Dir.cwd().readFileAlloc(io, path, testing.allocator, .limited(2 * 1024 * 1024));
        defer testing.allocator.free(content);
        try testing.expect(contains(content, "pub const setlike = .{"));
        try testing.expect(contains(content, "pub fn setlikeEntries("));
        try testing.expect(!contains(content, "_skipped"));
    }

    const maplike_names = [_][]const u8{
        "AttributionAggregationServices",
        "AudioParamMap",
        "BluetoothManufacturerDataFilter",
        "BluetoothManufacturerDataMap",
        "BluetoothServiceDataFilter",
        "BluetoothServiceDataMap",
        "CSSFontFeatureValuesMap",
        "EventCounts",
        "HighlightRegistry",
        "KeyboardLayoutMap",
        "MIDIInputMap",
        "MIDIOutputMap",
        "NamedFlowMap",
        "RTCStatsReport",
    };
    for (maplike_names) |name| {
        const path = try std.fmt.allocPrint(testing.allocator, "src/webidl/interfaces/{s}.zig", .{name});
        defer testing.allocator.free(path);
        const content = try std.Io.Dir.cwd().readFileAlloc(io, path, testing.allocator, .limited(2 * 1024 * 1024));
        defer testing.allocator.free(content);
        try testing.expect(contains(content, "pub const maplike = .{"));
        try testing.expect(contains(content, "pub fn maplikeEntries("));
        try testing.expect(!contains(content, "_skipped"));
    }
}
