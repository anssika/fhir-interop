/// <p>An alternative implementation of the RestClient class for using journaled alternatives of message classes
/// <class>HS.FHIRServer.Interop.Request</class> and <class>HS.FHIRServer.Interop.Response</class>.</p>
///
Class FHIRInterop.FHIRServer.RestClient.Interop Extends HS.FHIRServer.RestClient.Interop
{

/// Build the request message. Delegate to the parent to produce the HS QuickStream-based request,
/// then convert it into the journaled inline-payload request that the interop operation expects.
///
Method MakeRequest(pRequestMethod As %String, pPayload, pRequestPath As %String, pQueryString As %String, ByRef pHeaders) As %RegisteredObject
{
	#Dim hsRequest As HS.FHIRServer.Interop.Request = ##super(pRequestMethod, .pPayload, pRequestPath, pQueryString, .pHeaders)

	// Clear the ServiceName so the interop operation will use its adapter settings, not the Service Registry.
	//
	// The service name is a required parameter of method CreateInstance of the super class,
	// that is why it must be given when calling CreateInstance and we clear it here
	Do hsRequest.Request.AdditionalInfo.RemoveAt("ServiceName")

	Return ##class(FHIRInterop.FHIRServer.Interop.Request).FromHSRequest(hsRequest)
}

/// Build the client response. The interop operation returns a journaled response; convert it back
/// into the HS QuickStream-based response the parent knows how to read, then delegate.
Method MakeClientResponseFromResponse(pResponse As %RegisteredObject) As HS.FHIRServer.API.Data.RestClient.Response
{
	#Dim interopResponse As FHIRInterop.FHIRServer.Interop.Response = pResponse

	Return ##super(interopResponse.ToHSResponse())
}

}
