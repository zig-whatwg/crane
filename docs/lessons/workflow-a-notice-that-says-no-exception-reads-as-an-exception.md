# A notice that says "No EXCEPTION" reads as an exception

**Category:** Workflow
**Date:** 2026-11-08
**Lane:** integrator (generation 209's sweep; perf2 batch 6)

## What happened

To make clear that perf2's running chat.local job was NOT exempt from a closing, the integrator wrote a correction line that began "No EXCEPTION: perf2's running chat.local test job ... stops for the sweep". perf2's notice watcher looked for lines containing "EXCEPTION" and its lane name, and read this one as an exemption, so it kept the job running until the integrator messaged it directly.

## The rule

Write the word EXCEPTION only on a real exemption line, in the form `EXCEPTION: <lane>'s running <job> keeps running`. To say a job is not exempt, say nothing (no exception line means it stops) or write "<lane>'s running <job> stops" without the word.

## How to check

Before posting a CLOSING NOTICE or a correction, grep the lines for "EXCEPTION": each match must be an exemption.
