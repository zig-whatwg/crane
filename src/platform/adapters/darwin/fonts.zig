//! The darwin platform's fonts (decision 20): CoreText, on macOS and iOS.
//!
//! A web font is sanitized by kit/sfnt first, as on every platform (Blink
//! runs OTS before CoreText on macOS; WebKit gives CoreText's parser the
//! bytes), which also supplies its names, weight, slope and width - the
//! font's own, where CTFontCopyFamilyName would localize them. CoreText then
//! takes the chosen face (CTFontManagerCreateFontDescriptorFromData; NULL is
//! Corrupt, as Blink's "Unable to instantiate font face") and gives its
//! metrics, as Safari and Chrome on macOS take them from CoreText: a CTFont
//! at a size of its units per em reads in font units. A metric is present
//! where the font has the table or glyph for it - an x-height or cap-height
//! when the font has the OS/2 value or the 'x' or 'H' glyph, an advance when
//! the cmap maps the character, a vertical advance only with vhea - so
//! CoreText's synthesized values never pass for the font's.
//!
//! Installed faces come from CoreText's font matching: a family's faces
//! (CTFontDescriptorCreateMatchingFontDescriptors), the closest to the
//! request by CSS Fonts 4 5.2's order (style, then width, then weight;
//! style by class - a request's oblique angle is not matched); a
//! local() name as a PostScript or full name (CTFontDescriptorCreateWith
//! NameAndSize, kept only when the face has that name, CoreText matching
//! being looser). Their names are CoreText's (CTFontCopyName, unlocalized),
//! their traits their OS/2 table's.
//!
//! | Generic family | Face (WebKit's default font settings) |
//! |---|---|
//! | serif | Times |
//! | sans-serif | Helvetica |
//! | monospace | Courier |
//! | cursive | Apple Chancery |
//! | fantasy | Papyrus |
//! | system-ui, ui-sans-serif | the system UI font (CTFontCreateUIFontForLanguage, kCTFontUIFontSystem) |
//! | emoji | Apple Color Emoji |
//! | math | STIX Two Math |
//! | fangsong, ui-serif, ui-monospace, ui-rounded | none (CoreText's design variants are not public C API) |
//!
//! The system font keywords follow WebKit's SystemFontDatabaseCoreText:
//! caption, icon and message-box the system font; menu the menu item font;
//! small-caption the small system font; status-bar the label font; each at
//! its CoreText point size, taken as CSS px (as WebKit and Chrome do).

const std = @import("std");
const platform = @import("platform");
const sfnt = @import("kit_sfnt");

// ---------------------------------------------------------------------------
// CoreFoundation and CoreText (CTFont.h, CTFontDescriptor.h,
// CTFontManager.h of the macOS and iOS SDKs)
// ---------------------------------------------------------------------------

const CFTypeRef = *const anyopaque;
const CFIndex = isize;
const CFRange = extern struct { location: CFIndex, length: CFIndex };
const CGSize = extern struct { width: f64, height: f64 };
const kCFStringEncodingUTF8: u32 = 0x08000100;

extern "c" fn CFRelease(cf: CFTypeRef) void;
extern "c" fn CFDataCreate(allocator: ?CFTypeRef, bytes: [*]const u8, length: CFIndex) ?CFTypeRef;
extern "c" fn CFDataGetBytePtr(data: CFTypeRef) [*]const u8;
extern "c" fn CFDataGetLength(data: CFTypeRef) CFIndex;
extern "c" fn CFStringCreateWithBytes(allocator: ?CFTypeRef, bytes: [*]const u8, length: CFIndex, encoding: u32, external: u8) ?CFTypeRef;
extern "c" fn CFStringGetLength(string: CFTypeRef) CFIndex;
extern "c" fn CFStringGetBytes(string: CFTypeRef, range: CFRange, encoding: u32, loss_byte: u8, external: u8, buffer: ?[*]u8, max: CFIndex, used: ?*CFIndex) CFIndex;
extern "c" fn CFArrayGetCount(array: CFTypeRef) CFIndex;
extern "c" fn CFArrayGetValueAtIndex(array: CFTypeRef, index: CFIndex) CFTypeRef;
extern "c" fn CFDictionaryCreate(allocator: ?CFTypeRef, keys: [*]const CFTypeRef, values: [*]const CFTypeRef, count: CFIndex, key_callbacks: *const anyopaque, value_callbacks: *const anyopaque) ?CFTypeRef;
extern "c" fn CFSetCreate(allocator: ?CFTypeRef, values: [*]const CFTypeRef, count: CFIndex, callbacks: *const anyopaque) ?CFTypeRef;
extern "c" const kCFTypeDictionaryKeyCallBacks: u8;
extern "c" const kCFTypeDictionaryValueCallBacks: u8;
extern "c" const kCFTypeSetCallBacks: u8;

const kCTFontOrientationHorizontal: u32 = 1;
const kCTFontOrientationVertical: u32 = 2;
const kCTFontUIFontSystem: u32 = 2;
const kCTFontUIFontSmallSystem: u32 = 4;
const kCTFontUIFontLabel: u32 = 10;
const kCTFontUIFontMenuItem: u32 = 12;

extern "c" fn CTFontManagerCreateFontDescriptorFromData(data: CFTypeRef) ?CFTypeRef;
extern "c" fn CTFontCreateWithFontDescriptor(descriptor: CFTypeRef, size: f64, matrix: ?*const anyopaque) ?CFTypeRef;
extern "c" fn CTFontCreateUIFontForLanguage(ui_type: u32, size: f64, language: ?CFTypeRef) ?CFTypeRef;
extern "c" fn CTFontCreateCopyWithAttributes(font: CFTypeRef, size: f64, matrix: ?*const anyopaque, attributes: ?CFTypeRef) ?CFTypeRef;
extern "c" fn CTFontGetUnitsPerEm(font: CFTypeRef) c_uint;
extern "c" fn CTFontGetSize(font: CFTypeRef) f64;
extern "c" fn CTFontGetAscent(font: CFTypeRef) f64;
extern "c" fn CTFontGetDescent(font: CFTypeRef) f64;
extern "c" fn CTFontGetLeading(font: CFTypeRef) f64;
extern "c" fn CTFontGetXHeight(font: CFTypeRef) f64;
extern "c" fn CTFontGetCapHeight(font: CFTypeRef) f64;
extern "c" fn CTFontGetGlyphsForCharacters(font: CFTypeRef, characters: [*]const u16, glyphs: [*]u16, count: CFIndex) bool;
extern "c" fn CTFontGetAdvancesForGlyphs(font: CFTypeRef, orientation: u32, glyphs: [*]const u16, advances: ?[*]CGSize, count: CFIndex) f64;
extern "c" fn CTFontCopyTable(font: CFTypeRef, table: u32, options: u32) ?CFTypeRef;
extern "c" fn CTFontCopyName(font: CFTypeRef, key: CFTypeRef) ?CFTypeRef;
extern "c" fn CTFontCopyFamilyName(font: CFTypeRef) CFTypeRef;
extern "c" fn CTFontDescriptorCreateWithAttributes(attributes: CFTypeRef) CFTypeRef;
extern "c" fn CTFontDescriptorCreateWithNameAndSize(name: CFTypeRef, size: f64) CFTypeRef;
extern "c" fn CTFontDescriptorCreateMatchingFontDescriptors(descriptor: CFTypeRef, mandatory: ?CFTypeRef) ?CFTypeRef;
extern "c" const kCTFontFamilyNameAttribute: CFTypeRef;
extern "c" const kCTFontNameAttribute: CFTypeRef;
extern "c" const kCTFontFamilyNameKey: CFTypeRef;
extern "c" const kCTFontStyleNameKey: CFTypeRef;
extern "c" const kCTFontFullNameKey: CFTypeRef;
extern "c" const kCTFontPostScriptNameKey: CFTypeRef;

fn tag(comptime text: *const [4]u8) u32 {
    return std.mem.readInt(u32, text, .big);
}

fn cfString(text: []const u8) ?CFTypeRef {
    return CFStringCreateWithBytes(null, text.ptr, @intCast(text.len), kCFStringEncodingUTF8, 0);
}

/// `string` as UTF-8, OWNED by `allocator`.
fn utf8(allocator: std.mem.Allocator, string: CFTypeRef) error{OutOfMemory}![]u8 {
    const range: CFRange = .{ .location = 0, .length = CFStringGetLength(string) };
    var needed: CFIndex = 0;
    _ = CFStringGetBytes(string, range, kCFStringEncodingUTF8, '?', 0, null, 0, &needed);
    const out = try allocator.alloc(u8, @intCast(needed));
    _ = CFStringGetBytes(string, range, kCFStringEncodingUTF8, '?', 0, out.ptr, needed, null);
    return out;
}

// ---------------------------------------------------------------------------
// Metrics
// ---------------------------------------------------------------------------

/// What the font's own tables say it has, so CoreText's values are
/// reported only for those.
const Presence = struct {
    x_height: bool,
    cap_height: bool,
    vertical: bool,
};

fn glyphFor(font: CFTypeRef, code_point: u16) ?u16 {
    var glyph: [1]u16 = .{0};
    if (!CTFontGetGlyphsForCharacters(font, &.{code_point}, &glyph, 1) or glyph[0] == 0) return null;
    return glyph[0];
}

fn advance(font: CFTypeRef, glyph: u16, orientation: u32) f32 {
    var size: [1]CGSize = undefined;
    // CoreText gives a vertical advance as the size's width too (measured:
    // CSSHWOrientationTest.otf's '0', vmtx 1000, reads 1000 by 0).
    _ = CTFontGetAdvancesForGlyphs(font, orientation, &.{glyph}, &size, 1);
    return units(size[0].width);
}

/// A CoreText metric in font units. CoreText's scaling leaves float noise
/// (Ahem's ascent of 800 reads 800.0031 at 1000 points): rounded to 1/16 of
/// a unit, below any precision a font stores.
fn units(value: f64) f32 {
    return @floatCast(@round(value * 16) / 16);
}

/// `font`'s metrics in font units: CoreText's, at a size of its units per
/// em.
fn metricsOf(font: CFTypeRef, presence: Presence) platform.FontMetrics {
    const upem = CTFontGetUnitsPerEm(font);
    const sized = CTFontCreateCopyWithAttributes(font, @floatFromInt(upem), null, null) orelse font;
    defer if (sized != font) CFRelease(sized);
    var m: platform.FontMetrics = .{
        .units_per_em = @intCast(@min(upem, std.math.maxInt(u16))),
        .ascent = units(CTFontGetAscent(sized)),
        .descent = units(CTFontGetDescent(sized)),
        .line_gap = units(CTFontGetLeading(sized)),
        .x_height = .{},
        .cap_height = .{},
        .zero_advance = .{},
        .zero_vertical_advance = .{},
        .ideographic_advance = .{},
        .ideographic_vertical_advance = .{},
    };
    const x_height = units(CTFontGetXHeight(sized));
    if (x_height > 0 and (presence.x_height or glyphFor(sized, 'x') != null)) m.x_height = .of(x_height);
    const cap_height = units(CTFontGetCapHeight(sized));
    if (cap_height > 0 and (presence.cap_height or glyphFor(sized, 'H') != null)) m.cap_height = .of(cap_height);
    if (glyphFor(sized, '0')) |glyph| {
        m.zero_advance = .of(advance(sized, glyph, kCTFontOrientationHorizontal));
        if (presence.vertical) m.zero_vertical_advance = .of(advance(sized, glyph, kCTFontOrientationVertical));
    }
    if (glyphFor(sized, 0x6C34)) |glyph| {
        m.ideographic_advance = .of(advance(sized, glyph, kCTFontOrientationHorizontal));
        if (presence.vertical) m.ideographic_vertical_advance = .of(advance(sized, glyph, kCTFontOrientationVertical));
    }
    return m;
}

// ---------------------------------------------------------------------------
// Web fonts
// ---------------------------------------------------------------------------

pub fn decodeFont(allocator: std.mem.Allocator, bytes: platform.Bytes, postscript_name: platform.Str, limits: platform.FontLimits) platform.FontError!platform.DecodedFont {
    const decoded = try sfnt.decode(allocator, bytes.slice(), postscript_name.slice(), limits, .{ .standalone = true });
    var font = decoded.font;
    errdefer font.deinit(allocator);
    const standalone = decoded.standalone.?;
    defer allocator.free(standalone);
    const data = CFDataCreate(null, standalone.ptr, @intCast(standalone.len)) orelse return error.OutOfMemory;
    defer CFRelease(data);
    const descriptor = CTFontManagerCreateFontDescriptorFromData(data) orelse return error.Corrupt;
    defer CFRelease(descriptor);
    const ct_font = CTFontCreateWithFontDescriptor(descriptor, 0, null) orelse return error.Corrupt;
    defer CFRelease(ct_font);
    const own = font.metrics;
    font.metrics = metricsOf(ct_font, .{
        .x_height = own.x_height.present,
        .cap_height = own.cap_height.present,
        // kit/sfnt reports a vertical advance only from vhea/vmtx.
        .vertical = own.zero_vertical_advance.present or own.ideographic_vertical_advance.present or hasTable(ct_font, "vhea"),
    });
    return font;
}

fn hasTable(font: CFTypeRef, comptime name: *const [4]u8) bool {
    const table = CTFontCopyTable(font, tag(name), 0) orelse return false;
    CFRelease(table);
    return true;
}

// ---------------------------------------------------------------------------
// Installed faces
// ---------------------------------------------------------------------------

/// An installed CoreText face, described: CoreText's names, its OS/2
/// table's traits, CoreText's metrics.
fn describeInstalled(allocator: std.mem.Allocator, font: CFTypeRef) platform.FontError!platform.DecodedFont {
    var names: [4][]u8 = .{ "", "", "", "" };
    defer for (names) |n| if (n.len > 0) allocator.free(n);
    for ([_]CFTypeRef{ kCTFontFamilyNameKey, kCTFontStyleNameKey, kCTFontFullNameKey, kCTFontPostScriptNameKey }, &names) |key, *out| {
        const name = CTFontCopyName(font, key) orelse continue;
        defer CFRelease(name);
        out.* = try utf8(allocator, name);
    }
    const traits = traitsOf(font);
    const presence: Presence = .{
        .x_height = false,
        .cap_height = false,
        .vertical = hasTable(font, "vhea"),
    };
    return sfnt.fromParts(allocator, names[0], names[1], names[2], names[3], traits, metricsOf(font, presence));
}

fn traitsOf(font: CFTypeRef) sfnt.Traits {
    const os2 = CTFontCopyTable(font, tag("OS/2"), 0) orelse return .{};
    defer CFRelease(os2);
    const data = CFDataGetBytePtr(os2)[0..@intCast(CFDataGetLength(os2))];
    return sfnt.traitsFromOs2(data) orelse .{};
}

/// The faces CoreText has for `family`, the one nearest `request` (CSS
/// Fonts 4 5.2: style, then width, then weight), or null.
fn familyFace(allocator: std.mem.Allocator, family: []const u8, request: platform.FontRequest) platform.FontError!?platform.DecodedFont {
    const name = cfString(family) orelse return error.OutOfMemory;
    defer CFRelease(name);
    const keys = [_]CFTypeRef{kCTFontFamilyNameAttribute};
    const values = [_]CFTypeRef{name};
    const attributes = CFDictionaryCreate(null, &keys, &values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks) orelse return error.OutOfMemory;
    defer CFRelease(attributes);
    const descriptor = CTFontDescriptorCreateWithAttributes(attributes);
    defer CFRelease(descriptor);
    const mandatory = CFSetCreate(null, &keys, 1, &kCFTypeSetCallBacks) orelse return error.OutOfMemory;
    defer CFRelease(mandatory);
    const matches = CTFontDescriptorCreateMatchingFontDescriptors(descriptor, mandatory) orelse return null;
    defer CFRelease(matches);
    var best: ?CFTypeRef = null;
    defer if (best) |b| CFRelease(b);
    var best_score: u64 = std.math.maxInt(u64);
    const count = CFArrayGetCount(matches);
    var i: CFIndex = 0;
    while (i < count) : (i += 1) {
        const font = CTFontCreateWithFontDescriptor(CFArrayGetValueAtIndex(matches, i), 0, null) orelse continue;
        // CoreText's family match is looser than CSS's: keep a face only
        // when its family is the one asked for, caselessly (5.1).
        const face_family = CTFontCopyName(font, kCTFontFamilyNameKey);
        const same = if (face_family) |f| blk: {
            defer CFRelease(f);
            const text = try utf8(allocator, f);
            defer allocator.free(text);
            break :blk sfnt.caseless.equal(text, family);
        } else false;
        if (!same) {
            CFRelease(font);
            continue;
        }
        const score = distance(traitsOf(font), request);
        if (score < best_score) {
            if (best) |b| CFRelease(b);
            best = font;
            best_score = score;
        } else {
            CFRelease(font);
        }
    }
    const font = best orelse return null;
    return try describeInstalled(allocator, font);
}

/// CSS Fonts 4 5.2's preference order as one number: a style mismatch
/// outweighs any width difference, which outweighs any weight difference.
fn distance(traits: sfnt.Traits, request: platform.FontRequest) u64 {
    const style: u64 = if (traits.style == request.style) 0 else if (request.style != .normal and traits.style != .normal) 1 else 2;
    const width: u64 = @intFromFloat(@abs(traits.stretch - request.stretch) * 10);
    const weight: u64 = @abs(@as(i32, traits.weight) - @as(i32, request.weight));
    return style << 40 | width << 20 | weight;
}

pub fn installedFontFace(allocator: std.mem.Allocator, family: platform.Str, request: platform.FontRequest) platform.FontError!?platform.DecodedFont {
    return familyFace(allocator, family.slice(), request);
}

pub fn localFontFace(allocator: std.mem.Allocator, face_name: platform.Str) platform.FontError!?platform.DecodedFont {
    const name = cfString(face_name.slice()) orelse return error.OutOfMemory;
    defer CFRelease(name);
    const descriptor = CTFontDescriptorCreateWithNameAndSize(name, 0);
    defer CFRelease(descriptor);
    const keys = [_]CFTypeRef{kCTFontNameAttribute};
    const mandatory = CFSetCreate(null, &keys, 1, &kCFTypeSetCallBacks) orelse return error.OutOfMemory;
    defer CFRelease(mandatory);
    const matches = CTFontDescriptorCreateMatchingFontDescriptors(descriptor, mandatory) orelse return null;
    defer CFRelease(matches);
    const count = CFArrayGetCount(matches);
    var i: CFIndex = 0;
    while (i < count) : (i += 1) {
        const font = CTFontCreateWithFontDescriptor(CFArrayGetValueAtIndex(matches, i), 0, null) orelse continue;
        defer CFRelease(font);
        // local() matches a full name or a PostScript name (4.3.3.1).
        for ([_]CFTypeRef{ kCTFontPostScriptNameKey, kCTFontFullNameKey }) |key| {
            const candidate = CTFontCopyName(font, key) orelse continue;
            defer CFRelease(candidate);
            const text = try utf8(allocator, candidate);
            defer allocator.free(text);
            if (sfnt.caseless.equal(text, face_name.slice())) return try describeInstalled(allocator, font);
        }
    }
    return null;
}

pub fn genericFontFace(allocator: std.mem.Allocator, generic: platform.GenericFontFamily, request: platform.FontRequest) platform.FontError!?platform.DecodedFont {
    const family: []const u8 = switch (generic) {
        .serif => "Times",
        .sans_serif => "Helvetica",
        .monospace => "Courier",
        .cursive => "Apple Chancery",
        .fantasy => "Papyrus",
        .emoji => "Apple Color Emoji",
        .math => "STIX Two Math",
        .system_ui, .ui_sans_serif => {
            const font = try uiFont(kCTFontUIFontSystem, 0, request.language.slice()) orelse return null;
            defer CFRelease(font);
            return try describeInstalled(allocator, font);
        },
        .fangsong, .ui_serif, .ui_monospace, .ui_rounded => return null,
    };
    return familyFace(allocator, family, request);
}

fn uiFont(ui_type: u32, size: f64, language: []const u8) error{OutOfMemory}!?CFTypeRef {
    const lang: ?CFTypeRef = if (language.len > 0) cfString(language) orelse return error.OutOfMemory else null;
    defer if (lang) |l| CFRelease(l);
    return CTFontCreateUIFontForLanguage(ui_type, size, lang);
}

pub fn systemFont(allocator: std.mem.Allocator, keyword: platform.SystemFontKeyword, language: platform.Str) platform.FontError!platform.SystemFont {
    const ui_type: u32 = switch (keyword) {
        .caption, .icon, .message_box => kCTFontUIFontSystem,
        .menu => kCTFontUIFontMenuItem,
        .small_caption => kCTFontUIFontSmallSystem,
        .status_bar => kCTFontUIFontLabel,
    };
    const font = try uiFont(ui_type, 0, language.slice()) orelse return .{
        // CSS Fonts 4 2.7: no preference - the initial values.
        .family = .{},
        .system_ui = false,
        .size = 0,
        .style = .normal,
        .weight = 400,
        .stretch = 100,
        .strings = .{},
    };
    defer CFRelease(font);
    const family = CTFontCopyFamilyName(font);
    defer CFRelease(family);
    const strings = try utf8(allocator, family);
    const traits = traitsOf(font);
    return .{
        .family = .from(strings),
        .system_ui = true,
        .size = @floatCast(CTFontGetSize(font)),
        .style = traits.style,
        .weight = traits.weight,
        .stretch = traits.stretch,
        .strings = .from(strings),
    };
}
