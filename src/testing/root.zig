///! Testing module root
///!
///! This module provides testing infrastructure for the browser,
///! including the TestRunner API for WPT (Web Platform Tests).
pub const test_runner = @import("test_runner.zig");

pub const TestRunner = test_runner.TestRunner;
pub const TestStatus = test_runner.TestStatus;
pub const TestResult = test_runner.TestResult;
pub const HarnessStatus = test_runner.HarnessStatus;
pub const generateTestRunnerScript = test_runner.generateTestRunnerScript;
