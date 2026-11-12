//! A runner thread's alternate signal stack (lane tls1): where the fault
//! handler runs when the thread's own stack is what ran out, so a stack
//! overflow on one of the runner's own threads - a slot's, a watchdog's - is
//! still reported.
//!
//! The ROOT decides, as it decides `std_options`. The runner's root
//! (main.zig) sets `std_options.signal_stack_size = null` - std's own stack
//! is a 256 KB thread-local every thread that touches a thread-local pays
//! for - and supplies the platform's instead (`attachThreadSignalStack`,
//! which is platform.attachSignalStack). The unit tests of the runner's
//! std-only modules have another root, the test runner, which keeps std's
//! stack and declares nothing: there this does nothing, and those modules
//! stay free of the platform module.

const root = @import("root");

/// What `detach` takes; 0: nothing was attached.
pub const Handle = usize;

/// First in a runner thread's entry.
pub fn attach() Handle {
    return if (@hasDecl(root, "attachThreadSignalStack")) root.attachThreadSignalStack() else 0;
}

/// On the same thread, before it ends.
pub fn detach(handle: Handle) void {
    if (@hasDecl(root, "detachThreadSignalStack")) root.detachThreadSignalStack(handle);
}
