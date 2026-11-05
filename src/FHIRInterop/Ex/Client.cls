Include HS.FHIRServer

/// <p>Demonstrates issuing the same FHIR interaction as <class>FHIRInterop.Ex.Service</class>, but
/// from standalone application code (a plain class method) rather than from a business service's
/// <method>OnProcessInput</method>.</p>
///
/// <p>Instead of hand-building a <class>FHIRInterop.FHIRServer.Interop.Request</class> and calling
/// <method>SendRequestSync</method>, this uses the journaled RestClient
/// <class>FHIRInterop.FHIRServer.RestClient.Interop</class>. Because no business host object is
/// supplied to <method>CreateInstance</method>, the client dispatches the request to the
/// <var>To_FHIR_Server</var> operation via <class>HS.HC.Util.BusinessService</class> (which must be
/// present in the production, and is).</p>
Class FHIRInterop.Ex.Client
{

/// Config name of the HTTP operation that performs the request (see FHIRINTEROPPKG.FoundationProduction).
Parameter TARGETCONFIGNAME = "To_FHIR_Server";

/// SSN of the example patient.
Parameter PATIENTSSN = "141140-213Z";

/// <p>Issue a GET Patient search by identifier against the FHIR server, the same interaction that
/// <class>FHIRInterop.Ex.Service</class> performs on its timer. Logs the outcome and returns the
/// client response object.</p>
ClassMethod DoFHIRInteractions() As HS.FHIRServer.API.Data.RestClient.Response
{
	#Dim clientResponse As HS.FHIRServer.API.Data.RestClient.Response

	// The first parameter is a required parameter - it is a service registry entry name
	#Dim client As FHIRInterop.FHIRServer.RestClient.Interop
	Set client = ##class(FHIRInterop.FHIRServer.RestClient.Interop).CreateInstance("< a non existing service registry entry name >", , , , , , ..#TARGETCONFIGNAME)

	Do client.SetResponseFormat($$$FHIRContentCodeJSON)

	/*
	 *	Search -interaction
	 */

	Set clientResponse = client.Search("GET", "Patient", "", "", "identifier=" _ ..#PATIENTSSN)
	Write "FHIR search returned status " _ clientResponse.Status, !
	Write "... and the following body (Payload): ", !, clientResponse.Payload.Read(), !

	// If the search found at least one Patient, the patient already exists; return that response.
	// The payload was fully read above, so rewind before parsing the searchset Bundle.
	Do clientResponse.Payload.Rewind()
	#Dim bundle As %DynamicObject = ##class(%DynamicObject).%FromJSON(clientResponse.Payload)
	If bundle.total > 0 {
		Write "The Patient was found --> Returning ...", !
		Return clientResponse
	}

	/*
	 *	Create -interaction (if the patient was not found)
	 */

	Do client.SetRequestFormat($$$FHIRContentCodeJSON)

	#Dim patient As %DynamicObject = {"resourceType":"Patient","name":[{"family":"Suominen","given":["Olavi"]}],"identifier":[{"value":(..#PATIENTSSN)}]}
	#Dim prettyPatient As %String
	$$$ThrowOnError(##class(%JSON.Formatter).%New().FormatToString(patient, .prettyPatient))

	Set clientResponse = client.Create("Patient", prettyPatient)
	Write "FHIR create returned status " _ clientResponse.Status, !
	If $IsObject(clientResponse.Payload) && (clientResponse.Payload.Size > 0) {
		Write "... and the following body (Payload): ", !, clientResponse.Payload.Read(), !
	}

	Return clientResponse
}

}
