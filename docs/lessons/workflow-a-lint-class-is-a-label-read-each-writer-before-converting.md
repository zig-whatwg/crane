# Workflow: A lint class is a label - read each variable's writers before converting the class

**Date**: 2026-11-03
**Lesson**: The global-state baseline's class "P-res" was briefed as "105 registration lists"; read writer by writer it was 72 hook tables (3 of them registries), 16 genuine process resources that no hook type can freeze, 1 variable nothing wrote, and 16 keys in other lanes' files or C++.

**Why**: A class in a baseline (`P-res`, `H`, `I/engine`) was assigned once, by whoever inventoried the variable, from its declaration and a guess at its use. Nothing re-checks it as the code moves. A brief that counts a class ("convert the 105 P-res lists") inherits the guess, and a scripted conversion of the whole class would have turned a mutex, a curl reference count and the process Io into "frozen after start" slots - each of them written at run time, so each would have panicked the first time a Browser started after the process did.

**What Happened**: Lane hookfreeze2 listed every P-res key's declaration and every write to it before converting anything:
- most were src/dom hook tables (`?Implementation`, a struct of optional function pointers) that the instances inventory had filed as P-res rather than H;
- the registries were few (adopting_steps, finish_parsing_children, bfcache's owner steps, update_the_rendering's and extract_origin's indexed arrays);
- the resources stayed, each with a reviewed `// process-wide:` line saying why one per process holds with many Browsers and what makes its writes safe (a lock, an atomic, init-once): curl's global init and its mutex, host.zig's Io, atomic id and seed counters, the WPT runner's diagnostics switches (set BEFORE crane.Process starts, so a Hook would refuse them), the UA sheets (freed at the end);
- `template_registry.snapshot_mode` had no writer anywhere: a constant;
- `StorageManager.permission_callback` had no installer at all: deleted, its answer passed in by the caller.
The same scripted rewrite also changed `implementation` inside eleven test names and a panic message (`"without an installed implementation.get() ..."`): a name rewrite does not know where string literals are.

**Fix**:
1. Before converting a class, print each key's declaration and grep every write to it (`<name> =`, `<name>.<field> =`, `&<name>`, the install function's callers), and classify by what the writes ARE: once at start (a hook), at run time under a lock or atomically (a resource), never (a constant), or never installed (delete it).
2. Report the real split to the integrator before converting, so the lint rule that depends on it (gstate4's hard rule) is built on the facts.
3. After a scripted rewrite, also grep the changed lines for the new form inside double quotes and revert those.

**Takeaway**: **A baseline's class is a label from an old inventory, not a description: classify each variable by its writers before converting a class, and say the real split before the rewrite.**
