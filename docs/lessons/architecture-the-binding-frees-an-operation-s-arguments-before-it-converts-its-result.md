# Architecture: The binding frees an operation's arguments before it converts its result

**Date**: 2026-09-30
**Lesson**: `callMethodWithArgs` releases each converted argument in a `defer` inside the block that calls the impl, and converts the impl's return value after that block. A result that borrows an argument - a slice of a string argument, a dictionary member - is read after it was freed.

**Why**: The argument cleanup is scoped to the call, which is right for everything the impl consumes; nothing marks a return value as borrowing from the arguments, so the compiler cannot help.

**What Happened**: `URLPattern.exec` returned `inputs[0]` as the argument's own string. In a single run the freed bytes were still mapped and the subtests just failed (urlpattern.any.js passed 164 of 740); in a sweep the DebugAllocator had returned the page to the OS and urlpattern.https.any.js died with SIGSEGV in `hasSurrogateCodePoint` under URLPatternResult conversion. A 300 KB input - larger than the allocator's largest bucket, so unmapped on free - made it crash alone (crane/c2-urlpattern-exec-inputs.html). The rest of the result had been copied into the process-global ArenaAllocator, which is never reset: every exec() leaked its result until exit.

**Fix**: the result's strings are copies in a per-pattern arena (reset by the next exec(), freed with the pattern). urlpattern.https.any.js CRASH -> OK 318; urlpattern.any.js 164 -> 318.

**Takeaway**: **An impl's return value must not point into its arguments. Copy into memory that outlives the call - and a crash that needs a sweep to show is often a use-after-free that needs a large allocation to unmap.**
