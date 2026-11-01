# Workflow: Stopping a pool job hands its cache to the auto-wipe

**Date**: 2026-11-01
**Lesson**: A crane-remote job that ends for any reason, killed included, releases its build slot and can trigger the selective cache wipe, which deletes the largest IDLE mirror cache: usually the cache of the job that just ended.

**Why**: crane-remote.sh's `finish_job` (the EXIT trap of the remote job wrapper) releases the slot, then arms `~/crane-cache-wipe.sh` when free disk is below `~/crane-wipe-threshold-gb` (300 GB by default). The wipe never touches a cache whose mirror holds a slot. The moment a job's slot is released its cache counts as idle, and a long job's cache is the largest one on the host.

**What Happened**: On 2026-11-01 the integrator stopped the cold `-Dtest-isolation=file` run on chat.local after 14.5 h, about 70% through (1,090 of 1,564 test files compiled and run, 0 failures). The aim was to free the host for Codex row 131's 30-minute timed cost window. The plan was to keep the mirror's cache and restart the run warm, so the finished work would be reused.
- The job's inner shell was SIGKILLed so it would not reach its own trailing `rm -rf` of the cache.
- The outer wrapper's `finish_job` still ran: the slot was released at 13:17:38 UTC with 164 GB free.
- The wipe armed itself and removed `main-iso` as the largest idle cache, about 220 GB.
- The 14.5 h of compile work was lost, and the run has to start cold again.

**Fix**:
1. To make room for a timed window beside a long build, prefer `kill -STOP` on the build's process group and `kill -CONT` after the window. Exclude the stopped processes in the window's clear check, and say so in the CLOSING NOTICE. A stopped test that measures wall time may fail after the resume; re-run any such test alone.
2. If the job must end and its cache must survive, stop the wipe first: raise `~/crane-wipe-threshold-gb` below the current free space, or start a placeholder job under the same mirror name so its cache still counts as held. Restore the threshold afterwards.
3. Before stopping any long job, read what its wrapper does on exit, not only its own command line.

**Takeaway**: **A pool job's cache outlives the job only while something holds its mirror's slot; killing the job is also deleting its cache when the host is low on disk.**
