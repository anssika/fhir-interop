Class FHIRInterop.Ex.Service Extends Ens.BusinessService
{

/// A timer-only inbound adapter — it drives OnProcessInput on an interval while the host is enabled.
Parameter ADAPTER = "Ens.InboundAdapter";

/// Config name of the HTTP operation that performs the GET/DELETE (see Test.Production).
Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "To_FHIR_Server" ];

/// Settings exposed in the Management Portal (the operator's demo controls).
Parameter SETTINGS = "TargetConfigName:Basic";

Parameter FHIRENDPOINT = "/fhir/r4";

/// SSN of the example patient
Parameter PATIENTSSN = "050841-098Y";

/// Called each poll while the host is enabled. Acts once the first time, then stays quiet.
Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
	$$$LOGINFO("OnProcessInput starts")
    #Dim status As %Status = $$$OK

	#Dim request As FHIRInterop.FHIRServer.Interop.Request

	// Check if the patient already exists
	Set request = ##class(FHIRInterop.FHIRServer.Interop.Request).%New()

 	//Set request.Request.SessionApplication = ..#FHIRENDPOINT
	Set request.Request.RequestMethod = "GET"
	Set request.Request.RequestPath = "Patient"
	Set request.Request.QueryString = "identifier=" _ ..#PATIENTSSN
	Set request.Request.RequestFormatCode = "JSON"
	Set request.Request.ResponseFormatCode = "JSON"
	
    Set tStatus = ..SendRequestSync(..TargetConfigName, request, .response, 5)
	If ($$$ISERR(tStatus)) Return tStatus
	If ('$IsObject(response)) {
		Return $$$ERROR($$$GeneralError, "No response (timeout) from " _ ..TargetConfigName)
	}

	If (response.Response.Status >= 300) {
		$$$LOGERROR("Call to " _ ..TargetConfigName _ " returned status " _ response.Response.Status _ ". Returning that (error) FHIR response...")
	}

    Return status
}

}
