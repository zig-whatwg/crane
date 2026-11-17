# Testing: A cost pair against a console from another mirror can read layout as cost - build a control of the base code in the tip's mirror

**Date**: 2026-11-16
**Lesson**: Two release consoles built on the same host with the same command, from different mirrors (another path, another cache), are still two layouts. When a row is over the bar while the instructions are equal, build a control: the BASE code, in the TIP's mirror, with the same command. Then time control against base and tip against control before calling the row a cost.

**Why**: A frozen console is one build's layout (lesson testing-a-frozen-console-is-one-builds-layout: rebuild both sides on the timing host). Building on the same host is not enough. The paths compiled into the binary (source paths in panic and debug data, the mirror's own directory), the order in which a cold or warm cache compiles and links, and every other input of a whole-program ReleaseSafe build can move a hot loop to another alignment. A loop of about 230 ms per sample then moves by about 5% with no change in the work it does. A pair whose base is someone else's frozen console (a perf round's) compares two build environments as well as two trees.

**What Happened**: Lane impls8's cost window on chat.local compared the tip's console, built in mirror impls8-c, with perf round 10's frozen console of main 2cb7fd076dd, built in mirror integrate (same host, same command, the base the integrator chose). The commit difference was 0ad1551d706 against 530fdac447d, and 530fdac447d differs from 2cb7fd076dd only in report.zig. Over all four series, events.dispatch had equal instructions (1.000-1.001), but its time contradicted itself:
- full suite x7: 0.971 (the tip faster, 7 of 7);
- ring-off suite x7: 0.995;
- three events-page series x15: 1.046, 1.041 and 1.043 (the tip slower, 15 of 15 pairs in the alternating one, 235-243 against 226-230 ms per sample).

The control was main 530fdac447d's console, built in impls8-c with the identical command. Control against round 10's base: 1.054 (243.6 against 231.1 ms median, instructions 1.000). Tip against control: 0.997 (240.1 against 240.7 ms, instructions 1.000). Main's own code, built where the tip was built, was as slow as the tip on that row. impls8's code changed nothing there.

**Fix**:
1. A row over the bar at equal instructions (within about 0.5%) is a layout question first. Do not profile, bisect or align before the control.
2. Build the control: the base commit, in the tip's mirror (same path, same cache), with exactly the tip's console command. One way is to check the base commit out in the lane worktree, start the console job, and check the branch back out once the job prints its pid (crane-remote has synced the tree by then).
3. Time two alternating series of the row's page: control against the frozen base, and tip against control. If tip ~ control, it is the build; report it as a measured build-layout effect. If control ~ base and the tip is still over the bar, the code is the cause: bisect with tip consoles built in the same mirror.
4. Delete the control console afterwards. Never write into the frozen base's directory.

**Takeaway**: **Same host and same command still make two layouts when the mirrors differ: at equal instructions over the bar, time a control of the base code built in the tip's mirror before calling the row a cost.**
