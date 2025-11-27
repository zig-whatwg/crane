//! WebIDL Namespace definitions
//! Auto-generated with manual additions for build-time gating

const build_options = @import("build_options");

pub const CSS = @import("CSS.zig").CSS;
pub const GPUBufferUsage = @import("GPUBufferUsage.zig").GPUBufferUsage;
pub const GPUColorWrite = @import("GPUColorWrite.zig").GPUColorWrite;
pub const GPUMapMode = @import("GPUMapMode.zig").GPUMapMode;
pub const GPUShaderStage = @import("GPUShaderStage.zig").GPUShaderStage;
pub const GPUTextureUsage = @import("GPUTextureUsage.zig").GPUTextureUsage;
pub const WebAssembly = @import("WebAssembly.zig").WebAssembly;
pub const console = @import("console.zig").console;

// WHATWG TestUtils Standard - Conditionally enabled via build option
// Per spec: "must not be enabled in the default shipping configuration of user agents"
// Enable with: zig build -Denable-test-utils=true
// See: https://testutils.spec.whatwg.org/
pub const TestUtils = if (build_options.enable_test_utils)
    @import("TestUtils.zig").TestUtils
else
    // Disabled marker - the REPL skips types without Meta
    void;
