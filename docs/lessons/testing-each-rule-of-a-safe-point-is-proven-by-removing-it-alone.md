# Testing: Each rule of a safe point is proven by removing it alone

**Date**: 2026-11-12
**Lesson**: A mechanism made of several guards ("not beneath itself", "not while an exception is pending", "compare with the innermost, not the outermost", "not under a binding") has one test per guard, and each test is shown RED with only that guard removed - the whole change reversed proves the feature, not the guards.

**Why**: The RED of a feature commit is the tree without the feature. Every guard inside the feature is then absent together with the thing it guards, so a test that would pass with the guard deleted still goes from red to green. A guard nobody has seen fail is a comment. The guards of a safe point are exactly the lines a later simplification removes.

**What Happened**: Lane v8up b6c built two safe points for queued wrapper finalizers (the depth-zero binding exit, and a binding's return into a callback's script for objects made since the callback began). Reversing each commit gave RED 5 of 7 and 4 of 12. Six guards were then removed one at a time, on the pool mirror only, with the filtered test run after each:
- no `finalizers_running` check at the depth-zero entry: "expected 1, found 4" (three finalizers ran beneath the first);
- no `HasPendingException` check there: the script's catch block never ran (expected "TypeError", found "no exception");
- the same two at the callback entry: an object freed beneath the finalizer the pump was running; one freed at a throwing constructor's exit;
- the stamp compared with the outermost callback instead of the innermost: "af" expected, "ff" found (an object older than the nested listener freed inside it);
- a fresh run allowed at an exit under a binding: "aa" expected, "ff" found (freed inside an init dictionary's getter).
Each failure named the hazard the guard exists for. One test (`finalizers never run at a non-zero depth`) turned out to pin less than its name said once the second safe point existed, and was renamed.

**Fix**: In the red/green job, after GREEN: keep a copy of the file, delete ONE guard with an exact-match edit that asserts a single occurrence (`assert s.count(a) == 1`), run the one test that pins it (`-Dtest-filter`), require a non-zero exit, restore, repeat (.v8up/job-b6c-rg.sh, job-b6c-fresh-rg.sh). The edits live on the pool mirror only and the next sync restores the tree. Quote each guard's own failure line in the commit message.

**Takeaway**: **Count the guards in a change and show one RED per guard, each with that guard alone removed. If removing a guard fails no test, either the guard is dead or its test is missing - find out which before the gate.**
