# Workflow: A time stamp needs the clock's answer before the message is written

**Date**: 2026-11-10
**Lesson**: "Take every time from `date -u` in the same call" fails when the date call and the message are sent in ONE batch of tool calls. The message is composed before the clock answers, so its stamp is a guess. Run `date` alone, read its output, then write the message that quotes it.

**Why**: An agent can issue several tool calls at once, and the arguments of all of them are written before any result comes back. A SendMessage issued beside the `date` call that was meant to stamp it cannot contain that call's output. A held-files line written by `echo "... $(date -u +%H:%M) ..."` does take the clock, because the stamp is computed inside the same command.

**What Happened**: Lane nd2 batch 2 stamped four messages to the integrator 6-29 minutes off (19:58 for 19:44, 20:31 for 20:02, 20:13 for 20:06, 21:01 for 21:00), each time after "running date in the same call". Twice the date call and the send were issued together. The integrator had to correct each one.

**Fix**:
1. Lines written to a file: compute the stamp inside the command (`$(date -u +%H:%M)`).
2. Messages: one call `date -u +%H:%M` on its own, wait for its result, then a separate call that sends the message with that exact text.
3. Never type a time from memory or estimate it.

**Takeaway**: **A stamp is only the clock's if the clock answered before the stamp was written. Batched calls do not share results.**
