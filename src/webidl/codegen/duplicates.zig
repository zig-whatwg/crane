//! Which of several non-partial definitions of one name is THE definition.
//!
//! WebIDL allows one definition per name; specs/idl (webref's raw ed/idl) has
//! names that several specs define, and one file that repeats its own
//! definitions. Codegen never picks one by the order files are read in. A
//! duplicate resolves by exactly one of these rules, and any other duplicate
//! fails codegen:
//!
//! 1. `definers`: the file of the spec that defines the name. Taken from
//!    webref's curated data published from the snapshot's own raw commit -
//!    https://github.com/w3c/webref, branch `curated`, commit
//!    eb12bb138ce8ea9cd5c9073f12376e9b7f4cfc93 ("Curated data generated from
//!    raw data at 08fb1a310e343019f154e18521e1612ad6d149c0", the commit
//!    specs/idl is pinned to): ed/idlnamesparsed/<Name>.json, `defined.href`,
//!    mapped to its spec's IDL file through ed/index.json. idlnames lists
//!    exactly one definition per name, which is what it is for.
//! 2. `self_repeating_files`: a file that defines a name more than once on
//!    its own uses its first definition (by position in the file). Only the
//!    files listed may.
//!
//! When webref's snapshot is updated (specs/idl/WEBREF.md), re-derive the
//! table from the curated commit generated from the new raw commit.

const std = @import("std");

/// Name -> the file that defines it, for every name specs/idl defines in more
/// than one file. Rationale per group:
pub const definers = std.StaticStringMap([]const u8).initComptime(.{
    // Web Animations Level 2 redefines these with its additions; idlnames
    // takes level 2 for the event and its init, and level 1 for FillMode.
    .{ "AnimationPlaybackEvent", "web-animations-2.idl" },
    .{ "AnimationPlaybackEventInit", "web-animations-2.idl" },
    .{ "FillMode", "web-animations.idl" },
    // CSS Fonts 5 supersedes CSS Fonts 4 (css-fonts.idl) for these.
    .{ "CSSFontFaceDescriptors", "css-fonts-5.idl" },
    .{ "CSSFontFaceRule", "css-fonts-5.idl" },
    // DOM Level 2 Style (DOM-Style.idl, discontinued) also defines the CSSOM
    // names; CSSOM and CSS Conditional are their definers today.
    .{ "CSSImportRule", "cssom.idl" },
    .{ "CSSMediaRule", "css-conditional.idl" },
    .{ "CSSPageRule", "cssom.idl" },
    .{ "CSSRule", "cssom.idl" },
    .{ "CSSRuleList", "cssom.idl" },
    .{ "CSSStyleDeclaration", "cssom.idl" },
    .{ "CSSStyleRule", "cssom.idl" },
    .{ "CSSStyleSheet", "cssom.idl" },
    .{ "ElementCSSInlineStyle", "cssom.idl" },
    .{ "LinkStyle", "cssom.idl" },
    .{ "MediaList", "cssom.idl" },
    .{ "StyleSheet", "cssom.idl" },
    .{ "StyleSheetList", "cssom.idl" },
    // DOM-Style.idl's module-scoped `typedef dom::Element Element;` and the
    // like import DOM's interfaces; DOM defines them.
    .{ "DOMImplementation", "dom.idl" },
    .{ "Element", "dom.idl" },
    .{ "Node", "dom.idl" },
    // The modern-algorithms draft extends these WebCrypto enums.
    .{ "KeyFormat", "webcrypto-modern-algos.idl" },
    .{ "KeyUsage", "webcrypto-modern-algos.idl" },
    // Shared Storage restates them to add [Exposed=SharedStorageWorklet];
    // Web Locks defines them.
    .{ "Lock", "web-locks.idl" },
    .{ "LockManager", "web-locks.idl" },
    // Portals (discontinued) widens HTML's union with its own types.
    .{ "MessageEventSource", "html.idl" },
    // Device Attributes restates the interface Managed Configuration defines.
    .{ "NavigatorManagedData", "managed-configuration.idl" },
    // SVG 2 (SVG.idl) vs SVG Paths, which defines it.
    .{ "SVGPathElement", "svg-paths.idl" },
});

/// Files that repeat their own definitions. DOM-Style.idl is DOM Level 2
/// Style as reffy extracted it: each interface inline in its section and
/// again in the spec's module-scoped "IDL Definitions" appendix. Its first
/// occurrence is used.
pub const self_repeating_files = [_][]const u8{"DOM-Style.idl"};

/// One non-partial definition of `name`: the file it is in and its position
/// there (the order of add calls for that file).
pub const Candidate = struct {
    file: []const u8,
    position: u32,
};

/// The index into `candidates` (two or more non-partial definitions of
/// `name`) of THE definition, or error.DuplicateDefinition when no rule
/// covers them - with a message when `report` is set.
pub fn resolve(name: []const u8, candidates: []const Candidate, report: bool) error{DuplicateDefinition}!usize {
    std.debug.assert(candidates.len > 1);
    const definer: ?[]const u8 = definers.get(name);

    var chosen: ?usize = null;
    for (candidates, 0..) |candidate, i| {
        if (definer) |file| {
            if (!std.mem.eql(u8, candidate.file, file)) continue;
        } else if (!std.mem.eql(u8, candidate.file, candidates[0].file)) {
            // No definer named, and the definitions are in different files.
            return fail(report, name, candidates, "it is defined in more than one file and duplicates.zig names no definer");
        }
        if (chosen) |c| {
            if (!isSelfRepeating(candidate.file)) {
                return fail(report, name, candidates, "a file defines it twice and is not in duplicates.self_repeating_files");
            }
            if (candidate.position < candidates[c].position) chosen = i;
        } else chosen = i;
    }
    return chosen orelse fail(report, name, candidates, "duplicates.zig names a definer file that does not define it");
}

fn isSelfRepeating(file: []const u8) bool {
    for (self_repeating_files) |f| if (std.mem.eql(u8, f, file)) return true;
    return false;
}

fn fail(report: bool, name: []const u8, candidates: []const Candidate, why: []const u8) error{DuplicateDefinition} {
    if (!report) return error.DuplicateDefinition;
    std.debug.print("  error: duplicate definition of {s}: {s}. Defined in:", .{ name, why });
    for (candidates) |candidate| std.debug.print(" {s}#{d}", .{ candidate.file, candidate.position });
    std.debug.print("\n  Name its definer in src/webidl/codegen/duplicates.zig (webref's ed/idlnames says which).\n", .{});
    return error.DuplicateDefinition;
}
