# fhir-interop — review findings

Review of the core package (`src/FHIRInterop/FHIRServer/Interop/*`) and repo hygiene.
Ranked by impact on maintainability / robustness. Refer to items by number.

Status legend: ☐ open · ☑ done · ⊘ won't do

---

## 1. ☑ `Operation` and `HTTPOperation` are byte-for-byte identical

**DONE (2026-10-28):** Extracted shared body into new
`FHIRInterop.FHIRServer.Interop.OperationHelper` (`DispatchInterop` +
`ClearQuickStream`). Both operations reduced to a one-line delegate; `MessageMap`
kept in each (framework metadata). Compiles in all three namespaces; `build.script`
unchanged (imports `*.cls`); verified live — a real FHIR searchset Bundle round-trips
intact through the refactored HTTPOperation. CLAUDE.md "intentionally identical" note
replaced with a pointer to the helper.

<details><summary>original finding</summary>


`DispatchRequestInterop` and the `MessageMap` XData are the same text in both
`Operation.cls` and `HTTPOperation.cls` (identical through all 56 lines). CLAUDE.md
enshrines this ("intentionally identical"). That's the problem, not the feature: any
fix to the QuickStream-cleanup logic or the error-handling subtlety ("do not hide the
earlier error") must be made twice, and the two copies will eventually drift.

They can't share an ObjectScript superclass because they extend different HS parents
(`...Interop.Operation` vs `...Interop.HTTPOperation`) and the body calls the inherited
`..DispatchRequest`. Fix: extract the body into one shared class method taking the
operation instance.

```objectscript
Class FHIRInterop.FHIRServer.Interop.Util
{
ClassMethod DispatchInterop(pOperation As Ens.BusinessOperation, interopRequest As ..Request, Output interopResponse As ..Response) As %Status
{
    // the single copy of the Try/Catch + QuickStream cleanup,
    // calling pOperation.DispatchRequest(request, .response)
}
}
```

Each operation's `DispatchRequestInterop` shrinks to:
`Return ##class(...Util).DispatchInterop($this, interopRequest, .interopResponse)`.
One source of truth; the "intentionally identical" note in CLAUDE.md goes away.

**Impact: high (one of the two that move the needle).**
</details>

---

## 2. ☑ The `Service` is less robust than the `Operation`

**DONE (2026-10-28):** Wrapped `Service.SendRequestSync` body (the `FromHSRequest`
unwrap, the `##Super` dispatch, and the `ToHSResponse` re-wrap) in the same Try/Catch
discipline the operations use — exceptions now become a `%Status`, with the
"don't hide the earlier error" LOGERROR guard. Compiles in all three namespaces;
FHIRSERVER production restarted and the FHIR_API -> FHIR_Repository round-trip
completes normally through the hardened path.

<details><summary>original finding</summary>

The operations wrap their conversions in `Try/Catch` and turn exceptions into a
`%Status`. `Service.SendRequestSync` does not — and `FromHSRequest` *throws*
(`$$$ThrowStatus`) when a QuickStream can't be opened. So an unopenable request
QuickStream surfaces as an unhandled exception on the service side but as a clean error
status on the operation side. Inconsistent, and the service path is the one the
RestHandler calls. It should have the same Try/Catch discipline.

**Impact: medium (correctness-flavored). Tightly related to #1.**
</details>

---

## 3. ☑ There are no tests

**DONE (2026-10-28):** Added `%UnitTest` suite `Tests.RoundTrip` in a root-level `Tests`
package (deliberately NOT under `FHIRInterop`, so reusers import only `FHIRInterop/` and
get no test code). Imported into the TEST namespace only (added to `build.script`).
6 tests / 22 assertions, all passing:
- `TestRequestRoundTrip` / `TestResponseRoundTrip` — payload byte-for-byte + carried
  `Request`/`Response` object; response also checks `CharSet` / `ContentType` both ways
- `TestEmptyPayload` — empty source → empty payload → no QuickStream back out
- `TestLargePayload` — ~2.5MB multi-chunk, byte-for-byte (baseline = reopened source)
- `TestUnicodePayload` — multi-byte UTF-8 unmangled
- `TestMissingQuickStream` — pins current behavior (see item 6 below)

Run manually:
```
docker exec -i fhir-interop iris session iris -U TEST
Set ^UnitTestRoot="/opt/fhir-interop/src"
Do ##class(%UnitTest.Manager).RunTest("Tests","/noload/nodelete")
```

Two things the writing surfaced, worth recording:
- **QuickStream save/reopen shrinks `.Size`.** An `HS.SDA3.QuickStream` reports a slightly
  smaller `Size` after a save+reopen cycle than in-memory before `%Save` (~4KB on 2.5MB —
  a dropped trailing partial buffer). This is HS behavior, outside this package; the
  package's real contract (reopened-source == round-tripped, byte-for-byte) holds. Tests
  baseline off the reopened source accordingly.
- **New finding #6** (silent empty payload on unresolvable QuickStreamId) — see below.

**Impact: high (single highest-leverage addition for robustness).**

---

## 4. ☐ Repo hygiene

- `iris-main.log` is committed — a runtime log in source control. Remove and gitignore.
- `README v01.md` sits next to `README.md` — looks like a leftover draft. Delete or fold in.

**Impact: low (tidying).**

---

## 5. ☑ Smaller things (style drift resolved 2026-10-28)

- `Response.ContentType` has `MAXLEN = 8192` but `CharSet` is left at the default
  `%String` length (50). Intentional? Probably fine, but make it a deliberate choice.
- Style drift the `objectscript-guardrails` / `objectscript-conventions` gates would
  flag. Verified instances (2026-10-28):
  - lowercase `if` mixed with `If` — was at `Request.cls:22/38` and `Response.cls:45`
    (the payload-copy guards). **FIXED** — all now `If`; grep confirms zero lowercase
    `if` left in code. Recompiled clean in FHIRSERVER / FHIRINTEROP / TEST.
  - (The `#dim` vs `#Dim` note originally cited `Service.cls:12`, but that file was
    rewritten in item #2 and now uses `#Dim` — no lowercase `#dim` remains anywhere.)
  - inconsistent parenthesization around `If`/`if` conditions.
  Cosmetic, but a reusable package benefits from one consistent voice.
- The hand-maintained `Storage Default` data maps are a documented footgun ("if you add
  a property, extend the map"). Can't fully avoid given `StorageStrategy=""`, but a
  one-line comment *inside* each Storage block (not just in CLAUDE.md) would put the
  warning where the mistake happens.

**Impact: low (tidying).**

---

## 6. ☑ Unresolvable QuickStreamId silently yields an empty payload

**RESOLVED (2026-10-28) — not a bug; guard kept + documented.** Investigation (throwaway
`Probe6` diagnostic, since removed) established: `%OpenId` returns a *live object* for a
bad id, `%ExistsId` returns 0 even for valid streams, and a freshly-reopened stream reads
`Size=0` until its writer is destroyed/flushed — so there is **no reliable way to tell a
missing stream from a legitimately-empty one** (empty bodies — GET, DELETE, 204 — are
valid). Earlier "Size=0 on valid data" scares were a probe artifact of holding the writer
alive; in the real flow HS flushes before dispatch and the package reads payloads
correctly (confirmed by the passing suite and the live 232-byte production round-trip).

Decision: **keep** the `'$IsObject` guard (don't remove working defensive code that may
matter if HS behavior changes) and add a comment in both `FromHSRequest` /
`FromHSResponse` explaining why it rarely fires today and why it stays.
`TestMissingQuickStream` pins the actual (empty-payload, no-throw) behavior.

<details><summary>original finding</summary>


Surfaced while writing the #3 tests. `FromHSRequest` / `FromHSResponse` guard the copy
with `If '$IsObject(tQuickStream) { $$$ThrowStatus(...) }` — but
`HS.SDA3.QuickStream.%OpenId(badId)` returns a **live, empty** stream object, not `null`,
for an id with no stored data. So the guard never fires: instead of raising "Could not
open QuickStream", the method silently produces an **empty inline payload** and the
message flows on as if it had no body.

In normal operation the HS framework always hands over a valid, saved QuickStream, so
this is a latent edge case, not an active bug. But if an id is ever stale/cleared, the
failure is silent data loss rather than an error — the opposite of what the existing
throw intends. `TestMissingQuickStream` currently pins the *actual* (silent) behavior.

Options if we want to close it:
- Check `tQuickStream.Size` / `%Exists(id)` and throw when the id resolves to nothing; or
- Decide empty-on-missing is acceptable and drop the now-dead `'$IsObject` guard + its
  error text (it implies a protection that doesn't exist).

**Impact: low-medium (latent robustness; silent vs. loud failure).**
</details>

---

## Suggested order

Start with **#1 + #2** together (tightly related). Then **#3** as a follow-up.
**#4 / #5** are tidying, do anytime. Recompile inside the running container per the
project workflow.
