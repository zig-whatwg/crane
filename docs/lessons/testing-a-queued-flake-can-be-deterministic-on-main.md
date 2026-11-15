# Testing: A queued "flake" can be deterministic on main - repeat it on main's own runner

**Date**: 2026-11-14
**Lesson**: Before an A/B difference is called a flake, repeat the file on main's current runner as well as on the generation's: a change merged after the generation can make the "flaky" result the only result.

**Why**: A lane's A/B compares its tip with a generation, and the tip carries every main merge since that generation. When a file differs, the lane often reruns it on the tip and the generation only. If main's own change moved the result, the generation always shows the old result, the tip always shows the new one, and a single passing rerun (under a different load) looks like noise.

**What Happened**: WebCryptoAPI/derive_bits_keys/derive_key_and_encrypt.https.any.js went from 6 passing subtests to 2 in nav2 batch 12's A/B against generation 224. It was queued as a FLAKE ("first attempt only; 3/3 reruns pass"). In lane ifr1 batch 1's window (tip 763b671ecaf, 2026-11-14) it gave 2 in the sweep, in 3/3 reruns, in the bug-finding run and in 10/10 repeats. Generation 224's runner gave 6 in 10/10. Main 9d486d67c80's runner without the lane's commits (nav4's frozen base) gave 2 in 10/10. So the result is deterministic on main since a merge after generation 224, not a flake and not the lane's change. The test defines its subtests after an asynchronous importKey, so its subtest count depends on whether the window's load event comes before the key imports finish (main's synchronous end-of-parse load, nav2 batch 12, is the likely cause).

**Fix**: For each A/B difference you cannot explain, run the file 10 times on three runners: the tip, the generation, and main's current runner (a frozen base from any lane's mirror, run read-only). Compare the three distributions:
1. tip = main != generation: main's change; report it to the integrator with the counts.
2. tip != main = generation: the lane's change.
3. all three mixed: a real flake; queue it with the counts.

**Takeaway**: **A difference that reproduces on main's own runner is main's, however it was queued: three runners, ten repeats each, before the word "flake".**
