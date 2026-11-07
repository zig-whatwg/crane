# A lane agent that reuses a lane's name must not share a finishing agent's mirrors

**Category:** Workflow
**Date:** 2026-11-07
**Lane:** integrator (perf3 batch 2 -> batch 3, D1)

## What happened

perf3 batch 2 had merged, and its agent was still running its POST gate and its cleanup. The integrator started batch 3 (D1) as a fresh agent under the same lane name and told it that the pool mirrors `perf3` (chat.local) and `perf3-c3` (chat2) were "kept warm" for it. Batch 2's handoff told its own agent to delete those mirrors after the merge, and nobody told it otherwise. It deleted both mirrors and their caches at the end of its POST. D1's full `zig build test` was running in `~/crane-work/perf3` on chat.local at that moment; its tmp/ vanished and the job died. About 20 minutes of compile were lost, and D1 rebuilt the mirror cold.

## The rule

When a new agent takes over a lane while the previous agent of that lane is still running (finishing a POST, a report or cleanup):

1. Either give the new agent **fresh mirror names** (perf3-d1, perf3-d1c2), so the finishing agent's cleanup cannot touch them,
2. or tell the finishing agent, in so many words, **which mirrors, caches and bins it must NOT delete**, and wait for its acknowledgement before telling the new agent they are warm.

A handoff's "delete after the merge" line is an instruction the finishing agent will carry out; the integrator's later plans do not override it unless they are sent to that agent.

## How to check

Before spawning a successor in a lane, list the predecessor's state: is it still running (a task notification has not said "finished")? Which pool mirrors does its handoff say to delete? Resolve every overlap first.
