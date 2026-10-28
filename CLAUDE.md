# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An InterSystems IRIS for Health package providing **journaled, mirrorable, resendable
alternatives** to `HS.FHIRServer.Interop.Request`/`Response`. The stock HS classes carry the
FHIR payload as a `QuickStreamId` pointing at a non-journaled `HS.SDA3.QuickStream` that is
cleared once the session ends — so the message cannot be mirrored or resent, and its payload is
invisible in the Message Viewer. The classes here instead store the payload inline as a
`%Stream.GlobalCharacter` property on the persistent message, which journals and mirrors normally
and stays visible in the portal.

## Architecture

The package replaces three links in the FHIR interop message chain. Each custom class extends its
`HS.FHIRServer.Interop.*` counterpart and translates between the HS QuickStream-based messages and
the inline-payload messages at the boundaries:

- **`FHIRInterop.FHIRServer.Interop.Request` / `Response`** — the persistent message classes.
  `FromHSRequest`/`FromHSResponse` copy the QuickStream payload *into* the inline `Payload` stream;
  `ToHSRequest`/`ToHSResponse` copy it back *out* into a fresh QuickStream. Each defines its own
  `Storage Default` with an explicit data map (`StorageStrategy = ""`).
- **`...Interop.Service`** — overrides `SendRequestSync` to wrap the HS request as an interop
  request before dispatch and unwrap the interop response afterward.
- **`...Interop.Operation` / `HTTPOperation`** — add a `MessageMap` routing
  `FHIRInterop.FHIRServer.Interop.Request` to `DispatchRequestInterop`, which delegates to
  `FHIRInterop.FHIRServer.Interop.OperationHelper.DispatchInterop($this, ...)`. That helper unwraps
  to an HS request, calls the operation's `DispatchRequest`, re-wraps the response, and then
  **clears the transient QuickStreams** (in `^CacheTemp.HS.Stream`) it created. The two operations
  exist separately because they extend different HS parents (`...Interop.Operation` vs
  `...Interop.HTTPOperation`, which share no common FHIR ancestor) — one for the in-process
  repository operation, one for the HTTP-adapter operation — but their dispatch logic lives once,
  in `OperationHelper`.
- **`...Interop.OperationHelper`** — abstract; holds the single copy of the dispatch logic shared
  by both operations above.

Payload conversion is the whole point: the inline `Payload` is the durable copy; QuickStreams
exist only momentarily to satisfy the unmodified HS code on either side of the custom links.

### Demonstration environment (not part of the reusable package)

The container builds three namespaces wired together to exercise the classes end to end:

- **FHIRSERVER** — hosts an R4 FHIR server (installed by `Setup.FHIRServer.AddServer`) plus
  `FHIRSERVERPKG.FoundationProduction`: a `FHIR_API` service → `FHIR_Repository` operation, both
  using the custom interop classes.
- **FHIRINTEROP** — runs `FHIRINTEROPPKG.FoundationProduction`: `FHIRInterop.Ex.Service` (a timer
  service that issues a sample Patient GET) → `FHIRInterop.FHIRServer.Interop.HTTPOperation` that
  posts over HTTP to the FHIRSERVER endpoint using the `FHIR_Server` credential.
- **TEST** — scratch namespace that also gets the `FHIRInterop` classes imported.

When reusing the package in another project, copy only the `FHIRInterop/FHIRServer/Interop/*`
classes and substitute them for the stock HS classes; the `Ex`, `Setup`, `*PKG` code is demo scaffolding.

## Build & run

The build is baked into the image; there is no local compile step outside the container.

```bash
docker compose build     # Dockerfile runs build/build.sh at image-build time
docker compose up -d      # starts container, runs startup/startup.sh via -a
```

- **`build/build.cpf`** (merged at build via `ISC_CPF_MERGE_FILE`) creates the three
  databases/namespaces and sets the superuser password hash to `sys`.
- **`build/build.script`** imports `.cls` sources into each namespace (`%SYSTEM.OBJ.Import` with
  `"ck"` = compile + keep source) and installs the FHIR server. Edit this when adding source
  directories or changing which namespace gets which classes.
- **`startup/startup.script`** (run on every container start) unexpires passwords, sets the
  `FHIR_Server` credential, and starts both productions via `Ens.Director.StartProduction`.

Access after `up`:
- Management Portal: http://localhost:58050/csp/sys/ (user `superuser` / pw `sys`), e.g.
  namespace `FHIRINTEROP`.
- Terminal: `docker exec -it fhir-interop iris session iris`

Port mapping: host `58050` → container `52773` (web); `58051-58059` passed through.

> Do not `docker compose down`/`stop`/`kill` without asking first — see the container-safety rule
> in the global instructions.

## Working with the ObjectScript

- When writing or reviewing `.cls` code, the `iris-agentic-dev` MCP skills
  (`objectscript-guardrails`, `objectscript-conventions`, `net-http-patterns`, etc.) are the
  authoritative style/correctness gates — prefer them over ad-hoc judgment.
- After editing a class, recompile it *inside the running container* (the source bind-mount means
  the host files are live) — re-importing via the MCP `iris_compile`/`iris_execute` tools or
  `%SYSTEM.OBJ.Import` is faster than rebuilding the image. Rebuild the image only when changing
  databases/namespaces (`build.cpf`) or the import layout (`build.script`).
- The `Request`/`Response` `Storage Default` blocks are hand-written; if you add a persistent
  property, extend the data map accordingly.
