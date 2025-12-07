//! WebIDL dictionary: JsonLdOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");
const callbacks = @import("callbacks");

pub const JsonLdOptions = struct {
    base: ?runtime.USVString = null,
    compactArrays: ?bool = null,
    compactToRelative: ?bool = null,
    documentLoader: ?callbacks.LoadDocumentCallback = null,
    expandContext: ?*const anyopaque = null,
    extractAllScripts: ?bool = null,
    frameExpansion: ?bool = null,
    ordered: ?bool = null,
    processingMode: ?runtime.USVString = null,
    produceGeneralizedRdf: ?bool = null,
    rdfDirection: ?runtime.USVString = null,
    useNativeTypes: ?bool = null,
    useRdfType: ?bool = null,
    embed: ?*const anyopaque = null,
    explicit: ?bool = null,
    omitDefault: ?bool = null,
    omitGraph: ?bool = null,
    requireAll: ?bool = null,
    frameDefault: ?bool = null,
};
