# Workflow: A compile job that skips the lints finds them in the long gate

**Date**: 2026-11-24
**Lesson**: A lane's cheap pre-gate job (compile every test, run the changed tests) proves nothing about the lints, and the lints are steps of `zig build test`: a new `@hasDecl` probe, a new container-level `var` or a new engine reference fails the full gate an hour later, after every test has passed.

**Why**: `zig build check-tests` and a filtered `zig build test -Dtest-filter=...` say nothing reliable about the lint steps: the filtered run already exits 1 whenever one suite matches no test, so its rc is ignored and only the suite lines are read. The lints (`lint-hasdecl`, `lint-impls`, `lint-engine`, `lint-global-state`, `lint-platform`, `lint-refcount`, `lint-build`, `lint-stack-arrays`, ...) each run in seconds, as their own build steps.

**What Happened**: Lane bind1, B5 group 2b. tests/v8/dictionary_member_null_test.zig gained a second `@hasDecl(<generated dictionary>, "jsvalue_union_members")` probe; tools/hasdecl_baseline.txt allowed that file one unannotated probe. The group's job on chat2 (check-tests, the codegen tests, codegen-check, the red/green, the changed tests) was green. The merged-tree gate then ran 43 minutes and ended `843/845 steps succeeded (1 failed)` with 14,598 tests passed and none failed: the one failed step was `lint_hasdecl`. The fix was two comment lines and a baseline the tool lowered; the cost was a second round on a host other lanes were waiting for, and a branch tip that no longer matched the frozen runners by a test comment.

**Fix**:
1. Put the lints in the cheap job, before anything long: `zig build lint-hasdecl lint-impls lint-engine lint-global-state lint-platform lint-refcount lint-build lint-stack-arrays -j2`, and read each one's line.
2. A new `@hasDecl` / `@hasField` probe on a type the lint cannot resolve (a computed type, an `anytype`) takes its `// hasdecl: <which types reach it, and that they declare the name pub>` line when it is written - in a test file too.
3. When a file drops below its baseline, let the tool record it (`zig build lint-hasdecl -j2 -- --update` on the pool) and commit the baseline with the annotation; never edit a baseline by hand.
4. Read a gate as steps, not tests: "0 FAIL" with a non-zero rc is a failed step to name (see "A failed lint step hides among known test failures").

**Takeaway**: **Run every lint in the first cheap job of a group; a lint the diff trips costs seconds there and a full gate round anywhere later.**
