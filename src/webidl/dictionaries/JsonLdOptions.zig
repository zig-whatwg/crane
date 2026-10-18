//! WebIDL dictionary: JsonLdOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");
const callbacks = @import("callbacks");

pub const JsonLdOptions = struct {
    base: ?runtime.USVString = null,
    compactArrays: ?bool = null,
    compactToRelative: ?bool = null,
    documentLoader: ?callbacks.LoadDocumentCallback = null,
    expandContext: ?runtime.JSValue = null,
    extractAllScripts: ?bool = null,
    frameExpansion: ?bool = null,
    ordered: ?bool = null,
    processingMode: ?runtime.USVString = null,
    produceGeneralizedRdf: ?bool = null,
    rdfDirection: ?runtime.USVString = null,
    useNativeTypes: ?bool = null,
    useRdfType: ?bool = null,
    embed: ?runtime.JSValue = null,
    explicit: ?bool = null,
    omitDefault: ?bool = null,
    omitGraph: ?bool = null,
    requireAll: ?bool = null,
    frameDefault: ?bool = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{"embed"};

    /// Optional members' IDL default values: a member the value leaves
    /// unset is written with its default when converted to script.
    pub const member_defaults = .{
        .{ "base", .null },
        .{ "compactArrays", .{ .boolean = true } },
        .{ "compactToRelative", .{ .boolean = true } },
        .{ "documentLoader", .null },
        .{ "expandContext", .null },
        .{ "extractAllScripts", .{ .boolean = false } },
        .{ "frameExpansion", .{ .boolean = false } },
        .{ "ordered", .{ .boolean = false } },
        .{ "processingMode", .{ .string = "json-ld-1.2" } },
        .{ "produceGeneralizedRdf", .{ .boolean = true } },
        .{ "rdfDirection", .null },
        .{ "useNativeTypes", .{ .boolean = false } },
        .{ "useRdfType", .{ .boolean = false } },
        .{ "embed", .{ .string = "@once" } },
        .{ "explicit", .{ .boolean = false } },
        .{ "omitDefault", .{ .boolean = false } },
        .{ "requireAll", .{ .boolean = false } },
        .{ "frameDefault", .{ .boolean = false } },
    };

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "base", "documentLoader", "expandContext", "rdfDirection" };
};
