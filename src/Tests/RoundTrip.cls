/// <p>Unit tests for the payload round-trip through the journaled FHIR interop
/// message classes — the core value of the package.</p>
///
/// <p>Each test builds a stock <class>HS.FHIRServer.Interop.Request</class> /
/// <class>Response</class> carrying a QuickStream payload, converts it into the inline
/// <class>FHIRInterop.FHIRServer.Interop.Request</class> / <class>Response</class> via
/// <method>FromHSRequest</method> / <method>FromHSResponse</method>, converts it back
/// out via <method>ToHSRequest</method> / <method>ToHSResponse</method>, and asserts the
/// payload survived byte-for-byte along with the carried metadata.</p>
///
/// <p>This package lives at the repository root, outside <b>FHIRInterop</b>, so reusers
/// import only the <b>FHIRInterop</b> package and get no test code. Run manually, e.g.:</p>
/// <example>
/// Set ^UnitTestRoot = "/opt/fhir-interop/src"
/// Do ##class(%UnitTest.Manager).RunTest("Tests", "/nodelete")
/// </example>
/// <p>or point %UnitTest at this single class directly.</p>
Class Tests.RoundTrip Extends %UnitTest.TestCase
{

/// Request payload survives From/To conversion byte-for-byte, and the carried
/// API.Data.Request is preserved.
Method TestRequestRoundTrip()
{
	#Dim payload As %String = "{""resourceType"":""Patient"",""id"":""123""}"

	#Dim hsRequest As HS.FHIRServer.Interop.Request = ..MakeHSRequest(payload, "GET", "/Patient/123")

	#Dim interop As FHIRInterop.FHIRServer.Interop.Request
	Set interop = ##class(FHIRInterop.FHIRServer.Interop.Request).FromHSRequest(hsRequest)

	// Inline payload matches the source
	Do $$$AssertEquals(interop.Payload.Size, $Length(payload), "inline Payload size matches source")
	Do $$$AssertEquals(..ReadAll(interop.Payload), payload, "inline Payload content matches source")

	// And it round-trips back out into a fresh QuickStream
	#Dim backOut As HS.FHIRServer.Interop.Request = interop.ToHSRequest()
	Do $$$AssertNotEquals(backOut.QuickStreamId, "", "ToHSRequest produced a QuickStream")
	Do $$$AssertTrue(..QuickStreamEquals(backOut.QuickStreamId, payload), "round-tripped QuickStream matches source payload")

	// The carried API.Data.Request survives
	Do $$$AssertTrue($IsObject(backOut.Request), "Request object preserved")
	Do $$$AssertEquals(backOut.Request.RequestMethod, "GET", "Request.RequestMethod preserved")
	Do $$$AssertEquals(backOut.Request.RequestPath, "/Patient/123", "Request.RequestPath preserved")
}

/// Response payload survives From/To conversion, and CharSet / ContentType carry through.
Method TestResponseRoundTrip()
{
	#Dim payload As %String = "{""resourceType"":""Bundle"",""type"":""searchset""}"

	#Dim hsResponse As HS.FHIRServer.Interop.Response = ..MakeHSResponse(payload)
	Set hsResponse.CharSet = "UTF-8"
	Set hsResponse.ContentType = "application/fhir+json"

	#Dim interop As FHIRInterop.FHIRServer.Interop.Response
	Set interop = ##class(FHIRInterop.FHIRServer.Interop.Response).FromHSResponse(hsResponse)

	Do $$$AssertEquals(..ReadAll(interop.Payload), payload, "inline Payload content matches source")
	Do $$$AssertEquals(interop.CharSet, "UTF-8", "CharSet carried into interop response")
	Do $$$AssertEquals(interop.ContentType, "application/fhir+json", "ContentType carried into interop response")

	#Dim backOut As HS.FHIRServer.Interop.Response = interop.ToHSResponse()
	Do $$$AssertTrue(..QuickStreamEquals(backOut.QuickStreamId, payload), "round-tripped QuickStream matches source payload")
	Do $$$AssertEquals(backOut.CharSet, "UTF-8", "CharSet carried back out")
	Do $$$AssertEquals(backOut.ContentType, "application/fhir+json", "ContentType carried back out")
}

/// An HS request with no QuickStream yields an empty inline payload and produces no
/// QuickStream on the way back out (guards the size>0 branch in ToHSRequest).
Method TestEmptyPayload()
{
	#Dim hsRequest As HS.FHIRServer.Interop.Request = ##class(HS.FHIRServer.Interop.Request).%New()
	Set hsRequest.Request = ##class(HS.FHIRServer.API.Data.Request).%New()
	// QuickStreamId left ""

	#Dim interop As FHIRInterop.FHIRServer.Interop.Request
	Set interop = ##class(FHIRInterop.FHIRServer.Interop.Request).FromHSRequest(hsRequest)
	Do $$$AssertEquals(interop.Payload.Size, 0, "empty source yields empty inline Payload")

	#Dim backOut As HS.FHIRServer.Interop.Request = interop.ToHSRequest()
	Do $$$AssertEquals(backOut.QuickStreamId, "", "no QuickStream created for empty payload")
}

/// A multi-megabyte, multi-chunk payload survives byte-for-byte (guards against naive
/// single-Read truncation at the max string length).
///
/// <p>The baseline is the QuickStream <b>as reopened by id</b>, not the in-memory stream
/// before <method>%Save</method>: <class>HS.SDA3.QuickStream</class> reports a slightly
/// smaller <var>Size</var> after a save/reopen cycle (it drops a trailing partial
/// buffer), and the package only ever receives already-saved QuickStreams. The package's
/// contract is therefore reopened-source == round-tripped, which is what we assert.</p>
Method TestLargePayload()
{
	// ~2.5 MB built from a repeated chunk, written straight to the source QuickStream
	#Dim chunk As %String = ""
	For i=1:1:1000 { Set chunk = chunk _ "0123456789" }  // 10 KB
	#Dim quickStream As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%New()
	For i=1:1:250 { Do quickStream.Write(chunk) }        // ~2.5 MB
	Do quickStream.%Save()

	#Dim hsRequest As HS.FHIRServer.Interop.Request = ##class(HS.FHIRServer.Interop.Request).%New()
	Set hsRequest.Request = ##class(HS.FHIRServer.API.Data.Request).%New()
	Set hsRequest.QuickStreamId = quickStream.%Id()

	// Baseline = the source as the package will see it (reopened by id)
	#Dim source As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%OpenId(quickStream.%Id())
	#Dim expectedSize As %Integer = source.Size
	Do $$$AssertTrue(expectedSize > 1000000, "fixture is comfortably multi-chunk (>1MB)")

	#Dim interop As FHIRInterop.FHIRServer.Interop.Request
	Set interop = ##class(FHIRInterop.FHIRServer.Interop.Request).FromHSRequest(hsRequest)
	Do $$$AssertEquals(interop.Payload.Size, expectedSize, "large inline Payload size matches source")

	#Dim backOut As HS.FHIRServer.Interop.Request = interop.ToHSRequest()
	#Dim roundTripped As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%OpenId(backOut.QuickStreamId)
	Do $$$AssertEquals(roundTripped.Size, expectedSize, "large round-tripped QuickStream size matches source")
	Do $$$AssertTrue(..StreamsEqual(source, roundTripped), "large payload equal byte-for-byte")
}

/// Multi-byte UTF-8 content survives the %Stream.GlobalCharacter round-trip unmangled.
Method TestUnicodePayload()
{
	#Dim payload As %String = "{""name"":""Åsa Þórðardóttir — 日本語 — café""}"

	#Dim hsRequest As HS.FHIRServer.Interop.Request = ..MakeHSRequest(payload, "POST", "/Patient")

	#Dim interop As FHIRInterop.FHIRServer.Interop.Request
	Set interop = ##class(FHIRInterop.FHIRServer.Interop.Request).FromHSRequest(hsRequest)
	Do $$$AssertEquals(..ReadAll(interop.Payload), payload, "unicode payload preserved inline")

	#Dim backOut As HS.FHIRServer.Interop.Request = interop.ToHSRequest()
	Do $$$AssertTrue(..QuickStreamEquals(backOut.QuickStreamId, payload), "unicode payload round-trips unmangled")
}

/// Documents current behavior for a QuickStreamId that resolves to no stored data.
///
/// <p>NOTE: <method>HS.SDA3.QuickStream.%OpenId</method> returns a <b>live, empty</b>
/// stream object (not <var>null</var>) for an id with no stored data, so the
/// <code>'$IsObject</code> guard in <method>FromHSRequest</method> never fires and the
/// method does <b>not</b> throw — it silently produces an empty inline payload. This
/// test pins that current behavior. Whether an unresolvable id *should* raise is a
/// separate robustness question (see FINDINGS.md item 6).</p>
Method TestMissingQuickStream()
{
	#Dim hsRequest As HS.FHIRServer.Interop.Request = ##class(HS.FHIRServer.Interop.Request).%New()
	Set hsRequest.Request = ##class(HS.FHIRServer.API.Data.Request).%New()
	Set hsRequest.QuickStreamId = "nonexistent-id-99999"

	#Dim threw As %Boolean = 0
	#Dim interop As FHIRInterop.FHIRServer.Interop.Request
	#Dim exception As %Exception.AbstractException
	Try {
		Set interop = ##class(FHIRInterop.FHIRServer.Interop.Request).FromHSRequest(hsRequest)
	} Catch exception {
		Set threw = 1
	}
	Do $$$AssertTrue('threw, "FromHSRequest does not throw on an unresolvable QuickStreamId (current behavior)")
	Do $$$AssertEquals(interop.Payload.Size, 0, "unresolvable QuickStreamId yields an empty inline payload")
}

// ---- fixtures / helpers -------------------------------------------------------------

/// Build a stock HS interop request carrying <var>pPayload</var> in a saved QuickStream.
ClassMethod MakeHSRequest(pPayload As %String, pMethod As %String, pPath As %String) As HS.FHIRServer.Interop.Request [ Private ]
{
	#Dim quickStream As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%New()
	Do quickStream.Write(pPayload)
	Do quickStream.%Save()

	#Dim hsRequest As HS.FHIRServer.Interop.Request = ##class(HS.FHIRServer.Interop.Request).%New()
	Set hsRequest.Request = ##class(HS.FHIRServer.API.Data.Request).%New()
	Set hsRequest.Request.RequestMethod = pMethod
	Set hsRequest.Request.RequestPath = pPath
	Set hsRequest.QuickStreamId = quickStream.%Id()
	Return hsRequest
}

/// Build a stock HS interop response carrying <var>pPayload</var> in a saved QuickStream.
ClassMethod MakeHSResponse(pPayload As %String) As HS.FHIRServer.Interop.Response [ Private ]
{
	#Dim quickStream As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%New()
	Do quickStream.Write(pPayload)
	Do quickStream.%Save()

	#Dim hsResponse As HS.FHIRServer.Interop.Response = ##class(HS.FHIRServer.Interop.Response).%New()
	Set hsResponse.Response = ##class(HS.FHIRServer.API.Data.Response).%New()
	Set hsResponse.QuickStreamId = quickStream.%Id()
	Return hsResponse
}

/// Read a stream from the start into a single string (for small payloads only).
ClassMethod ReadAll(pStream As %Stream.Object) As %String [ Private ]
{
	Do pStream.Rewind()
	#Dim out As %String = ""
	While 'pStream.AtEnd { Set out = out _ pStream.Read(32000) }
	Return out
}

/// True if the QuickStream with <var>pQuickStreamId</var> holds exactly <var>pExpected</var>.
ClassMethod QuickStreamEquals(pQuickStreamId As %String, pExpected As %String) As %Boolean [ Private ]
{
	#Dim quickStream As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%OpenId(pQuickStreamId)
	If '$IsObject(quickStream) Return 0
	Return ..ReadAll(quickStream) = pExpected
}

/// True if two streams are byte-for-byte equal, compared in fixed-size chunks so it
/// holds for payloads larger than the max string length.
ClassMethod StreamsEqual(pA As %Stream.Object, pB As %Stream.Object) As %Boolean [ Private ]
{
	If pA.Size '= pB.Size Return 0
	Do pA.Rewind(), pB.Rewind()
	While 'pA.AtEnd {
		If pA.Read(32000) '= pB.Read(32000) Return 0
	}
	Return pB.AtEnd
}

}
