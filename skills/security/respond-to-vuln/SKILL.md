---
name: respond-to-vuln
description: Use when a newly discovered vulnerability or exploit alert needs to be run to ground and remediated across a fleet. Runs the loop end to end - identify the CVE, verify it on the affected hosts with layered evidence, scope the whole estate (catching vuln-scanner blind spots), package an executive brief plus an operational inventory, then run a verified check to closure. Triggers on an EDR/exploit detection, an autonomous-pentest finding, or a "we need to patch X everywhere" ask.
---

<what-to-do>

Run this loop for the vulnerability. Do the phases in order: each **produces** a concrete output, and the **into next** line names exactly what the following phase consumes, so the chain is explicit. Two rules hold throughout: **never record a claim as fact without corroboration** (two agreeing sources where it matters, and every human "it's done" verified against telemetry), and **push bulky data pulls into subagents** so the main thread stays legible.

1. **Identify.** From the finding, pin the exact software, version, and exploit vector, and map it to a CVE with a fixed build. Use the vendor advisory plus reputable analysis; verify, do not answer from memory. If a vendor docs portal exists, fetch it rather than guessing schema or fixed-build numbers.
   - *Produces:* named CVE(s); fixed/patched build number; whether exploitation is authenticated or unauthenticated; the software + version + vector fingerprint.
   - *Into next:* the software/version/vector fingerprint to hunt on the host; the fixed build is held for the phase 4 gate.

2. **Verify it is real, and whose it is.** Confirm on the affected host with the strongest evidence available, layered: endpoint telemetry (process tree, block/allow disposition, network/DNS callbacks) and on-disk truth (a read-only live-response file hash or version check). Separate authorized activity (a pentest) from an actual adversary. A single tool's silence is not proof.
   - *Input:* the fingerprint from phase 1.
   - *Produces:* confirmed affected host(s), each tagged with confidence (installed / running / hash-verified); an authorized-vs-adversary determination.
   - *Into next:* the exact component/binary identity (name, path, hash) to search for fleet-wide.

3. **Scope the estate.** Find everywhere the software runs, not just the alerting host: software inventory (installed), running-process telemetry (actually executing, with full paths), and one fleet-wide binary-name search to catch stragglers the server list missed. Diff against the vulnerability scanner and **expect gaps** - scanners routinely fail to inventory a product on every host, so a clean scanner is not a clean estate.
   - *Input:* the component/binary identity from phase 2.
   - *Produces:* the full affected-host list; an explicit note of what the scanner is missing.
   - *Into next:* the host list to baseline and to populate the inventory artifact.

4. **Define "fixed" and snapshot now.** Write the validation gate up front (hash changes / binary or service removed / CVE closes / installed build advances past the fix), then record current per-host state as the baseline to diff against later.
   - *Input:* the fixed build from phase 1; the host list from phase 3.
   - *Produces:* the validation gate; a per-host before-state baseline.
   - *Into next:* the gate and baseline become the inventory's validation section and the signal the watch re-tests.

5. **Package two views of the same verified data.** An **executive brief** (bottom line, current status, prioritized actions with owners) at decision altitude, and an **operational inventory** (per-host status, versions, CVEs with RCE flagged, a change log, the validation gates) at per-host / per-binary altitude. Publish both where the audience can act on them.
   - *Input:* everything above - CVE, host list, versions, confidence tags, gates.
   - *Produces:* the two published artifacts.
   - *Into next:* the inventory's change log is where the watch records every update.

6. **Decide the watch with the user, then set it up.** Do **not** assume ongoing monitoring or a cadence - both are the user's call. Ask them plainly: (a) do you want an ongoing watch at all, or a single confirmation pass? and (b) if ongoing, at what cadence? Then use whatever recurring/scheduling mechanism the harness provides to re-run a fixed check each cycle: re-read the coordination channel and re-test the fix signal, **verify** any reported "done" against telemetry or live-response before recording it, and log each observed change to the inventory change log (on a quiet cycle, report no-change and touch nothing).
   - *Input:* the fix signal and gate from phase 4; the coordination channel; the inventory from phase 5.
   - *Produces:* a living record until closure (or, if the user declines a watch, a single verified confirmation).
   - *Into next:* per-host verification results feed the closure check.

7. **Close.** When every affected host meets the gate and is independently verified, stop the watch and mark it resolved.
   - *Input:* per-host verification vs the gate.
   - *Produces:* resolution; the artifacts left in their final verified state.

</what-to-do>

<supporting-info>

## The evidence ladder

Rank every confirmation and label it, so readers know how far each claim is proven:

| Level | Source | Proves |
|---|---|---|
| Installed | software inventory | files on disk (may be stale / upgrade leftover) |
| Running | process telemetry | the component actually executed |
| Hash-verified | live-response file hash | the exact binary present on disk right now |
| Scanner-confirmed | vulnerability scanner | the scanner sees the CVE (subject to coverage gaps) |

The strongest single move for "is it really fixed" is a live-response hash or version read of the specific binary. **Absence of a process in telemetry is weak evidence**: a long-running service may not re-emit an event, and a removed one leaves none, so confirm on disk. Runtime telemetry often does not carry a file-version field, so per-binary version usually comes from the software inventory (installed version) or a live-response check.

## Cross-tool corroboration

Where an alert names an exploit and the EDR shows a block, line the two up: same host, same command, same second. One source is suggestive; two agreeing sources are conclusive. A pentest's "no impact / no proven weakness" can simply mean the EDR blocked the confirming step, not that the host was invulnerable - read the pentest's action log alongside the EDR side, not its findings list alone.

## Scanner blind spots

Treat the vulnerability scanner as one input, not the source of truth for scope. It commonly inventories the affected product on only a fraction of the hosts that run it, and may not flag the specific CVE at all. Software inventory plus running-process telemetry is the reliable scope; closing the scanner's coverage gap is itself a follow-up action worth listing.

## Compliance-term hygiene

Words like "incident" and "breach" carry formal response and notification weight. In audience-facing artifacts use neutral language ("exposure", "event", "exploit attempt") unless a formal process is actually being invoked.

## Why two artifacts, one data spine

The brief answers "what happened, what do we do" for a decision-maker; the inventory answers "which host, which binary, what version, confirmed how" for the people doing the work. Build both from the same verified data and keep them current in place as the watch surfaces changes, rather than shipping a one-time snapshot.

</supporting-info>
