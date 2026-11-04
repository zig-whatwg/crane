//! A joined test executable, as build.zig's -Dtest-binaries=v8 makes one: two
//! member suites in subdirectories, so their tests' names start with the
//! member's directory ("start.", "held."), and build.zig gives each member's
//! row to the Crane test runner by that prefix. `start` is a suite whose test
//! start makes the standalone runtime once for its process (tests-v8's
//! test_process.start; its row says .process_start); `held` is one whose tests
//! each make and end their own (the default, .per_test). Run - one process
//! per test - by tools/test_launcher/child.zig's tests. Not part of any suite:
//! build.zig compiles it only for the launcher's tests.

test {
    _ = @import("start/member.zig");
    _ = @import("held/member.zig");
}
