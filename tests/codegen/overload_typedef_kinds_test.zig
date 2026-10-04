//! The overload tables see through typedefs, and an overloaded constructor
//! has one.
//!
//! WebIDL's overload resolution algorithm (3.6) picks an overload by the
//! TYPE at the distinguishing argument index, and a typedef is only a name
//! for its type: CanvasImageSource is a union of six interfaces, GLenum is
//! `unsigned long`, ImageDataArray is `(Uint8ClampedArray or Float16Array)`.
//! The type registry registered every typedef without its type, so the
//! tables classified each one as `.other` - a category step 12 never
//! matches: `drawImage(image, ...)` could not tell its overloads apart by
//! the image, and `bufferData(target, 1024, usage)` found no overload for a
//! number.
//!
//! An overloaded constructor took a different path altogether: the binding
//! tried its variants in order until one converted, so a conversion that
//! threw in one variant was left pending while the next was tried, and a
//! dictionary argument (OfflineAudioContext(contextOptions)) was taken for
//! a list of arguments. Codegen now writes the constructors' overload set
//! (`constructor_overloads`, in ConstructorArgs' order) for the same
//! algorithm the operations use.

const std = @import("std");
const codegen = @import("codegen");
const types = codegen.types;
const writer = codegen.writer;
const testing = std.testing;

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

const idl =
    \\typedef (HTMLImageElement or SVGImageElement) HTMLOrSVGImageElement;
    \\typedef (HTMLOrSVGImageElement or ImageBitmap) CanvasImageSource;
    \\typedef unsigned long GLenum;
    \\typedef long long GLsizeiptr;
    \\typedef (Uint8ClampedArray or Float16Array) ImageDataArray;
    \\interface HTMLImageElement {};
    \\interface SVGImageElement {};
    \\interface ImageBitmap {};
    \\dictionary ImageDataSettings {};
    \\interface Ctx {
    \\  undefined drawImage(CanvasImageSource image, double dx, double dy);
    \\  undefined drawImage(CanvasImageSource image, double dx, double dy, double dw, double dh);
    \\  undefined bufferData(GLenum target, GLsizeiptr size, GLenum usage);
    \\  undefined bufferData(GLenum target, AllowSharedBufferSource? data, GLenum usage);
    \\};
    \\interface ImageData {
    \\  constructor(unsigned long sw, unsigned long sh, optional ImageDataSettings settings = {});
    \\  constructor(ImageDataArray data, unsigned long sw, optional unsigned long sh, optional ImageDataSettings settings = {});
    \\};
    \\dictionary OfflineAudioContextOptions { required unsigned long length; };
    \\interface OfflineAudioContext {
    \\  constructor(OfflineAudioContextOptions contextOptions);
    \\  constructor(unsigned long numberOfChannels, unsigned long length, float sampleRate);
    \\};
;

const Model = struct {
    file: types.IDLFile,
    model: codegen.ir.IR,
};

fn build(a: std.mem.Allocator) !Model {
    const file = try codegen.idl_parser.Parser.parse(a, idl);
    var model = try codegen.ir.IR.init(a);
    for (file.typedefs) |t| try model.addTypedef(t, "test.idl");
    for (file.dictionaries) |d| try model.addDictionary(d, "test.idl");
    for (file.interfaces) |iface| try model.addInterface(iface, "test.idl");
    return .{ .file = file, .model = model };
}

fn interfaceNamed(file: types.IDLFile, name: []const u8) types.Interface {
    for (file.interfaces) |iface| {
        if (std.mem.eql(u8, iface.name, name)) return iface;
    }
    unreachable;
}

test "a typedef is registered with the type it names" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const m = try build(arena.allocator());
    const glenum = m.model.type_registry.resolve("GLenum").?;
    try testing.expectEqualStrings("unsigned long", glenum.underlying_type.?.type);
    const source = m.model.type_registry.resolve("CanvasImageSource").?;
    try testing.expect(source.underlying_type.?.unionTypes != null);
}

test "an operation's overload table resolves typedef'd arguments to their types" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = try build(a);

    var ops: std.ArrayList(types.Operation) = .empty;
    for (interfaceNamed(m.file, "Ctx").members) |member| if (member.asOperation()) |o| try ops.append(a, o);

    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeDelegateFunctions(&buffer.writer, "CtxImpl", &m.model.type_registry, &.{}, ops.items, ops.items, .{ .model = &m.model });
    const out = buffer.written();

    // CanvasImageSource, through HTMLOrSVGImageElement, is its interfaces.
    try testing.expect(contains(out, "@import(\"interfaces\"), \"HTMLImageElement\")"));
    try testing.expect(contains(out, "@import(\"interfaces\"), \"SVGImageElement\")"));
    try testing.expect(contains(out, "@import(\"interfaces\"), \"ImageBitmap\")"));
    // GLenum and GLsizeiptr are numeric; no argument is left uncategorised.
    try testing.expect(!contains(out, ".kinds = &.{ .other }"));
    try testing.expect(contains(out, ".{ .function = \"call_bufferData\", .args = &.{ .{ .kinds = &.{ .numeric } }, .{ .kinds = &.{ .numeric } }, .{ .kinds = &.{ .numeric } } } }"));
}

test "an overloaded constructor writes its overload set in ConstructorArgs' order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = try build(a);

    var ctors: std.ArrayList(types.Constructor) = .empty;
    for (interfaceNamed(m.file, "ImageData").members) |member| if (member.asConstructor()) |c| try ctors.append(a, c);

    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeOverloadedConstructor(&buffer.writer, "ImageDataImpl", .{ .constructors = ctors.items }, &m.model.type_registry);
    const out = buffer.written();

    try testing.expect(contains(out, "pub const constructor_overloads = &[_]webidl.overload_resolution.Overload{"));
    const first = std.mem.indexOf(u8, out, ".{ .function = \"unsigned_long_unsigned_long_ImageDataSettings\"").?;
    const second = std.mem.indexOf(u8, out, ".{ .function = \"ImageDataArray_unsigned_long_unsigned_long_ImageDataSettings\"").?;
    try testing.expect(first < second);
    // ImageDataArray is its typed arrays; the optional arguments say so.
    try testing.expect(contains(out[second..], ".{ .kinds = &.{ .{ .typed_array = \"Uint8ClampedArray\" }, .{ .typed_array = \"Float16Array\" } } }"));
    try testing.expect(contains(out[first..second], ".{ .kinds = &.{ .dictionary }, .optionality = .optional }"));
}

test "a constructor's one dictionary argument is one argument in its overload set" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var m = try build(a);

    var ctors: std.ArrayList(types.Constructor) = .empty;
    for (interfaceNamed(m.file, "OfflineAudioContext").members) |member| if (member.asConstructor()) |c| try ctors.append(a, c);

    var buffer: std.Io.Writer.Allocating = .init(testing.allocator);
    defer buffer.deinit();
    try writer.writeOverloadedConstructor(&buffer.writer, "OfflineAudioContextImpl", .{ .constructors = ctors.items }, &m.model.type_registry);
    const out = buffer.written();

    try testing.expect(contains(out, ".{ .function = \"OfflineAudioContextOptions\", .args = &.{ .{ .kinds = &.{ .dictionary } } } }"));
    try testing.expect(contains(out, ".args = &.{ .{ .kinds = &.{ .numeric } }, .{ .kinds = &.{ .numeric } }, .{ .kinds = &.{ .numeric } } } }"));
}

test "two constructors with the same number of arguments are both kept; a restated one is one" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const file = try codegen.idl_parser.Parser.parse(a,
        \\interface MediaStreamTrack {};
        \\interface MediaStream {
        \\  constructor();
        \\  constructor(MediaStream stream);
        \\  constructor(sequence<MediaStreamTrack> tracks);
        \\  constructor(MediaStream stream);
        \\};
    );
    var ctors: std.ArrayList(types.Constructor) = .empty;
    for (interfaceNamed(file, "MediaStream").members) |member| if (member.asConstructor()) |c| try ctors.append(a, c);
    try testing.expectEqual(@as(usize, 4), ctors.items.len);

    // Keyed on the argument count, the sequence constructor was dropped as
    // a "duplicate" of the MediaStream one.
    try codegen.generator.deduplicateConstructors(a, &ctors);
    try testing.expectEqual(@as(usize, 3), ctors.items.len);
    try testing.expectEqual(@as(usize, 0), ctors.items[0].arguments.len);
    try testing.expectEqualStrings("MediaStream", ctors.items[1].arguments[0].idlType.type);
    try testing.expectEqualStrings("sequence", ctors.items[2].arguments[0].idlType.type);
}
