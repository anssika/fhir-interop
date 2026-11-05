Include (Ensemble, HS.FHIRServer)

/// <p>Integration tests for the journaled RestClient
/// <class>FHIRInterop.FHIRServer.RestClient.Interop</class> and its demo driver
/// <class>FHIRInterop.Ex.Client</class>.</p>
///
/// <p>Unlike <class>Tests.RoundTrip</class> (which exercises the message conversion in isolation),
/// these drive a <b>live</b> request end to end: RestClient -&gt; HS.HC.Util.BusinessService -&gt;
/// To_FHIR_Server operation -&gt; FHIR server -&gt; back. They therefore require the
/// <b>FHIRINTEROPPKG.FoundationProduction</b> production to be running and the target FHIR server
/// to be reachable; each test skips itself (passes with a logged note) if the production is down.</p>
///
/// <p>This package lives at the repository root, outside <b>FHIRInterop</b>, so reusers import only
/// the <b>FHIRInterop</b> package and get no test code. Run manually, e.g.:</p>
/// <example>
/// Set ^UnitTestRoot = "/opt/fhir-interop/src"
/// Do ##class(%UnitTest.Manager).RunTest("Tests", "/nodelete")
/// </example>
Class Tests.RestClient Extends %UnitTest.TestCase
{

/// Config name of the target operation (see FHIRINTEROPPKG.FoundationProduction).
Parameter TARGETCONFIGNAME = "To_FHIR_Server";

/// The demo client issues a Patient search and comes back with a 200 and a FHIR searchset Bundle.
Method TestClientSearch()
{
	If '..ProductionIsRunning() {
		Do $$$LogMessage("FHIRINTEROPPKG.FoundationProduction not running — skipping live test")
		Return
	}

	#Dim response As HS.FHIRServer.API.Data.RestClient.Response = ##class(FHIRInterop.Ex.Client).DoFHIRInteractions()

	Do $$$AssertTrue($IsObject(response), "client returned a response object")
	Do $$$AssertEquals(+response.Status, 200, "search returned HTTP 200")
	Do $$$AssertTrue($IsObject(response.Payload) && (response.Payload.Size > 0), "search returned a payload")

	Do response.Payload.Rewind()
	#Dim body As %String = response.Payload.Read(32000)
	Do $$$AssertTrue(body ["""resourceType"":""Bundle""", "payload is a FHIR Bundle")
	Do $$$AssertTrue(body ["""type"":""searchset""", "payload is a searchset Bundle")
}

/// A full create / read / delete round-trip through the journaled RestClient. This exercises the
/// inline request-<b>payload</b> path (the POST body) that a read-only search never touches, and
/// confirms the resource survives the round-trip to the FHIR server and back. Cleans up after itself.
Method TestRestClientCrud()
{
	If '..ProductionIsRunning() {
		Do $$$LogMessage("FHIRINTEROPPKG.FoundationProduction not running — skipping live test")
		Return
	}

	#Dim client As FHIRInterop.FHIRServer.RestClient.Interop
	Set client = ##class(FHIRInterop.FHIRServer.RestClient.Interop).CreateInstance("Tests.RestClient", , , , , , ..#TARGETCONFIGNAME)
	Do client.SetRequestFormat($$$FHIRContentCodeJSON)
	Do client.SetResponseFormat($$$FHIRContentCodeJSON)

	// Create
	#Dim patient As %String = "{""resourceType"":""Patient"",""name"":[{""family"":""RestClientTest""}]}"
	#Dim createResp As HS.FHIRServer.API.Data.RestClient.Response = client.Create("Patient", patient)
	Do $$$AssertEquals(+createResp.Status, 201, "create returned HTTP 201")
	Do $$$AssertNotEquals(createResp.Id, "", "create returned a resource id")
	#Dim resourceId As %String = createResp.Id

	// Read it back
	#Dim readResp As HS.FHIRServer.API.Data.RestClient.Response = client.Read("GET", "Patient", resourceId)
	Do $$$AssertEquals(+readResp.Status, 200, "read of created resource returned HTTP 200")
	Do readResp.Payload.Rewind()
	#Dim body As %String = readResp.Payload.Read(32000)
	Do $$$AssertTrue(body ["""family"":""RestClientTest""", "read payload carries the created content")
	Do $$$AssertTrue(body [ ("""id"":"""_resourceId_""""), "read payload carries the created id")

	// Delete to clean up
	#Dim deleteResp As HS.FHIRServer.API.Data.RestClient.Response = client.Delete("Patient", resourceId)
	Do $$$AssertTrue((+deleteResp.Status = 200) || (+deleteResp.Status = 204), "delete returned HTTP 200/204")
}

/// The whole point of the package: the message actually dispatched is the journaled
/// <class>FHIRInterop.FHIRServer.Interop.Request</class>, which persists (unlike the stock
/// QuickStream-backed request). Assert a new one landed in the message header table after a call.
Method TestDispatchIsJournaled()
{
	If '..ProductionIsRunning() {
		Do $$$LogMessage("FHIRINTEROPPKG.FoundationProduction not running — skipping live test")
		Return
	}

	#Dim before As %Integer = ..JournaledRequestCount()
	Do ##class(FHIRInterop.Ex.Client).DoFHIRInteractions()
	#Dim after As %Integer = ..JournaledRequestCount()

	Do $$$AssertTrue(after > before, "a FHIRInterop.FHIRServer.Interop.Request was journaled by the call")
}

// ---- helpers ------------------------------------------------------------------------

/// True if the demo production is the active, running production in this namespace.
ClassMethod ProductionIsRunning() As %Boolean [ Private ]
{
	#Dim state As %Integer = ##class(Ens.Director).GetProductionStatus(.name)
	Return (state = $$$eProductionStateRunning) && (name = "FHIRINTEROPPKG.FoundationProduction")
}

/// Count of journaled interop request messages dispatched so far.
ClassMethod JournaledRequestCount() As %Integer [ Private ]
{
	#Dim count As %Integer = 0
	&sql(SELECT COUNT(*) INTO :count FROM Ens.MessageHeader WHERE MessageBodyClassName = 'FHIRInterop.FHIRServer.Interop.Request')
	Return count
}

}
