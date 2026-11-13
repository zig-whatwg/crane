# Architecture: A predicate that inspects sources answers wrong when the build compiles them apart

**Date**: 2026-11-13
**Lesson**: A build that asks "did I link X into this artifact?" by looking for X's source file among the artifact's own sources gets a silent "no" the day X is compiled apart, into a library beside the artifact; the build made the call, so it records the call and answers from the record.

**Why**: build.zig tells each test executable, in a generated `suite.zig`, whether it links the JavaScript engine (`pub const engine: ?type`) and whether it can run the many-Browsers variant's busy Browser (`pub const browser: ?type`). The Crane test runner acts on both: it starts the engine before the first thread exists (tests/test_runner/runner.zig, `engine.initializeBeforeThreadCreation`), adds the engine's live counters to the process-state digest it takes before and after every test (state.zig), and runs the busy Browser. The question was answered by `linksV8(module)`: is `v8_wrapper.cpp` among the root module's own C sources? That was true exactly when the build had linked V8 - until the V8 15.7 port (lane v8up b3e), where under `-Dsanitize-thread` the wrapper has to be compiled apart, as a static library with no instrumented module, because Zig puts its own libc++'s macros on every C++ file of an instrumented compilation. From then on the source was on the library's module, the predicate said "no", and the generated file said `engine = null`. Nothing failed: a null there means "this suite runs no engine", which is true of 129 suites.

**What Happened**: Lane build3 was moving the V8 link code out of build.zig into the V8 adapter's build file (the build migration, batch E2). The handoff carried one unchecked question: what does `linksV8` answer under `-Dsanitize-thread`? Read from the binary build configurations of main 6bb5b7d2cd7, which hold every generated file's text (the same on Linux and macOS):

| flags | suite.zig with an engine import | with a browser import |
|---|---:|---:|
| none | 10 | 0 |
| `-Dsanitize-thread` | 1 | 0 |
| `-Dmany-browsers` | 10 | 11 |
| `-Dmany-browsers -Dsanitize-thread` | 1 | 1 |

So since the port, verify mode's ThreadSanitizer run and the nightly sanitizer variant had tested 9 of the 10 engine-running test executables with no engine start before the first thread (V8 then starts on a later thread, the fallback without thread isolation) and with no engine counters in the state check, and the combined variant - the one that looks for races between two Browsers - had run with no second Browser at all, printing "this executable has no Browser" into a log nobody reads on a green run. The one executable that kept its engine is the one whose root module a product also links.

The move itself could not fix it: a move is proven by an identical configuration, and the sanitizer's flag set is one of the six compared. The predicate moved as it answered, with the defect named in a comment, and the fix was its own commit with its own proof.

**Fix**:
1. The protocol's `Engine.link(b, module, request)` (src/runtime/engine_build_protocol.zig) is the one place the build links the engine. It records the module; `Engine.isLinkedInto(module)` answers from that record. No adapter is asked and no source is inspected, so an adapter is free to compile its sources into the module or beside it.
2. A check holds the result, on the configurations themselves: `zig build check-suite-facts` (part of the whole test run) configures the build root once per flag set - nothing is built - and tools/configurations_agree.zig counts each fact's line in the generated files those configurations hold. The count must be the same with and without the sanitizer, and never zero. Before the fix it printed `(no flag): 10 / -Dsanitize-thread: 1`; after, 10 and 10, 11 and 11.
3. When a predicate exists only because a callee did not report what it did, give the callee the report. Inspection is for what somebody else decided.

**How to look for the next one**: any build predicate that reads `link_objects`, `import_table`, a file name or a path to decide a fact about an artifact is inferring. List what else can put that file somewhere else - a sanitizer, a compile-only check, an adapter that links a prebuilt - and compare the fact across the flag sets the gates use (the configurations are cheap: under a second each).

**Takeaway**: **A build knows what it linked because it made the call: record the call and answer from the record. A predicate that infers it from where a source file sits is right only until something compiles that file somewhere else - and a wrong "no" from it does not fail, it just makes a gate test less than its name says. Compare such facts across the gates' flag sets.**
