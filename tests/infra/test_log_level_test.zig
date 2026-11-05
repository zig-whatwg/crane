//! The Crane test runner's log levels (tests/test_runner/runner.zig; lane
//! compiletime1). A test executable compiles its `std.log` calls at .info,
//! so no `log.debug` site - hundreds of them in the generic binding code - is
//! analysed or emitted, and prints at .warn while a test runs, as it always
//! has. -Dtest-log-level=<level> compiles and prints at that level, for a
//! local diagnosis. The defaults are pinned here; with the option, the levels
//! are the option's.
const std = @import("std");
const runner = @import("root");

test "a test executable compiles its logs at info and prints at warn, unless -Dtest-log-level says otherwise" {
    const option: ?std.log.Level = runner.test_log_level_option;
    try std.testing.expectEqual(option orelse .info, std.options.log_level);
    try std.testing.expectEqual(option orelse .warn, std.testing.log_level);
    if (option == null) {
        // A debug log is compiled out; info and above are compiled.
        try std.testing.expect(!std.log.logEnabled(.debug, .test_log_level));
        try std.testing.expect(std.log.logEnabled(.info, .test_log_level));
        try std.testing.expect(std.log.logEnabled(.err, .default));
    }
}
