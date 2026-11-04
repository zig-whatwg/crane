//! A hook slot (`Hook(T)`) and a registration list (`List(T, capacity)`):
//! the `process` module's (src/process/hook.zig), re-exported so that a
//! src/dom hook module keeps `const Hook = @import("hook.zig").Hook;`. The
//! type lives in that leaf module because modules below dom (the runtime
//! tier, the V8 adapter, fetch, hr_time) declare hook slots too.

const process = @import("process");

pub const Hook = process.hook.Hook;
pub const List = process.hook.List;
