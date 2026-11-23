//! WebIDL dictionary: LanguageModelCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const LanguageModelTool = @import("LanguageModelTool.zig").LanguageModelTool;
const LanguageModelExpected = @import("LanguageModelExpected.zig").LanguageModelExpected;

pub const LanguageModelCreateCoreOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    topK: ?f64 = null,
    temperature: ?f64 = null,
    samplingMode: ?enums.LanguageModelSamplingMode = null,
    expectedInputs: ?[]const LanguageModelExpected = null,
    expectedOutputs: ?[]const LanguageModelExpected = null,
    tools: ?[]const LanguageModelTool = null,
};
