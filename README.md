# fhir-interop

Journaled, mirrorable, resendable replacements for the InterSystems IRIS for Health
FHIR interoperability message classes — with the FHIR payload visible in the Message Viewer.

## Why This Package Exists

When an InterSystems FHIR implementation runs on an interoperability production, the request and
response messages (`HS.FHIRServer.Interop.Request` and `HS.FHIRServer.Interop.Response`) don't
carry the FHIR payload themselves. Instead they hold a `QuickStreamId` pointing at an
`HS.SDA3.QuickStream` object that holds the payload.

QuickStreams are fast, but they have shortcomings:

| QuickStream payload | This package's inline payload |
| --- | --- |
| Not journaled → not mirrored | Journaled and mirrored like any persistent message |
| Cleared when the session ends → message can't be resent | Persists → message can be resent later |
| Payload invisible in the Message Viewer | Payload visible in the Message Viewer |

This package provides drop-in alternatives, `FHIRInterop.FHIRServer.Interop.Request` and
`FHIRInterop.FHIRServer.Interop.Response`, that store the payload inline as a
`%Stream.GlobalCharacter` property, so the messages behave like most other IRIS interoperability
messages.

Because the payload representation changes, the package also ships modified versions of the
classes that create and consume these messages — use each in place of its stock counterpart:

- `FHIRInterop.FHIRServer.Interop.Service` instead of `HS.FHIRServer.Interop.Service`
- `FHIRInterop.FHIRServer.Interop.Operation` instead of `HS.FHIRServer.Interop.Operation`
- `FHIRInterop.FHIRServer.Interop.HTTPOperation` instead of `HS.FHIRServer.Interop.HTTPOperation`

## How It Works

The custom classes replace three links in the FHIR interop message chain. Each extends its stock
`HS.FHIRServer.Interop.*` counterpart and converts between the QuickStream-based messages (which
the unmodified HS code still expects) and the inline-payload messages at the boundaries:

```
Service.SendRequestSync ──▶ Operation / HTTPOperation ──▶ HS FHIR server
   wraps HS request as          unwraps to HS request,
   inline-payload request       dispatches, re-wraps response,
                                 clears the transient QuickStreams
```

The inline `Payload` is the durable copy; QuickStreams are created only momentarily to satisfy the
unmodified HS code on either side, then cleared.

## Using It in Your Own Project

Copy the classes under `src/FHIRInterop/FHIRServer/Interop/` into your project and use each in
place of its stock counterpart:

| Use this class | Instead of |
| --- | --- |
| `FHIRInterop.FHIRServer.Interop.Request` | `HS.FHIRServer.Interop.Request` |
| `FHIRInterop.FHIRServer.Interop.Response` | `HS.FHIRServer.Interop.Response` |
| `FHIRInterop.FHIRServer.Interop.Service` | `HS.FHIRServer.Interop.Service` |
| `FHIRInterop.FHIRServer.Interop.Operation` | `HS.FHIRServer.Interop.Operation` |
| `FHIRInterop.FHIRServer.Interop.HTTPOperation` | `HS.FHIRServer.Interop.HTTPOperation` |

Point your production's FHIR service and operation items at the `FHIRInterop.*` classes. The
`src/FHIRInterop/Ex/`, `src/Setup/`, and `src/*PKG/` code is demonstration scaffolding — you don't
need it.

## Try It Out

Requires Docker. The image is built on `intersystems/irishealth-community:2026.2`.

### 1. Clone the repository

```bash
git clone https://github.com/anssika/fhir-interop.git
cd fhir-interop
```

### 2. Build the image

```bash
docker compose build
```

### 3. Start the container

```bash
docker compose up -d
```

On startup the demo creates three namespaces and starts two productions. In the `FHIRINTEROP`
namespace, a timer service (`FHIRInterop.Ex.Service`) periodically issues a sample Patient `GET`
through the custom HTTP operation to a local R4 FHIR server running in the `FHIRSERVER` namespace.

### 4. See the payload in the Message Viewer

Open the Management Portal (credentials `superuser` / `sys`):

- http://localhost:58050/csp/sys/exp/%25CSP.Portal.Home.zen?$NAMESPACE=FHIRINTEROP

Navigate to **Interoperability → View → Messages** and open one of the messages — the FHIR payload
is visible directly, without having to route the message elsewhere to inspect it.

Terminal access:

```bash
docker exec -it fhir-interop iris session iris
```

### 5. Stop the container

```bash
docker compose down
```

> Note: `docker compose down` removes the container and its in-container state. Use
> `docker compose stop` if you want to keep it.

## Running the Tests

The package ships a `%UnitTest` suite, `Tests.RoundTrip`, that verifies the core guarantee —
that a FHIR payload survives the round-trip through the inline-payload message classes
byte-for-byte, along with the carried request/response metadata. It covers empty, small, large
(multi-megabyte, multi-chunk), and multi-byte UTF-8 payloads.

The tests live in the root-level `Tests` package, deliberately **outside** `FHIRInterop`, so when
you reuse the package you copy only `src/FHIRInterop/` and get no test code. In the demo
environment they are imported into the `TEST` namespace.

With the container running:

```bash
docker exec -it fhir-interop iris session iris -U TEST
```

Then, at the IRIS terminal prompt:

```objectscript
Set ^UnitTestRoot = "/opt/fhir-interop/src"
Do ##class(%UnitTest.Manager).RunTest("Tests", "/noload/nodelete")
```

`/noload` runs the already-compiled classes rather than re-importing from disk; `/nodelete` keeps
them afterward. A passing run ends with `All PASSED`; detailed results are also linked from the
`%UnitTest` portal URL printed at the end of the run.

## ToDo

Do some tests to ascertain that no quickstreams are left behind.
