//! WebIDL dictionary: LanguageModelCreateCoreOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");
const LanguageModelTool = @import("LanguageModelTool.zig").LanguageModelTool;
const LanguageModelExpected = @import("LanguageModelExpected.zig").LanguageModelExpected;

pub const LanguageModelCreateCoreOptions = struct {
    topK: ?f64 = null,
    temperature: ?f64 = null,
    samplingMode: ?enums.LanguageModelSamplingMode = null,
    expectedInputs: ?[]const LanguageModelExpected = null,
    expectedOutputs: ?[]const LanguageModelExpected = null,
    tools: ?[]const LanguageModelTool = null,
};
