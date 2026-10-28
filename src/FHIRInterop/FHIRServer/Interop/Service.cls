Include HS.FHIRServer

/// <p>An alternative implementation of the service class for using journaled alternatives of message classes
/// <class>HS.FHIRServer.Interop.Request</class> and <class>HS.FHIRServer.Interop.Response</class></p>
/// 
Class FHIRInterop.FHIRServer.Interop.Service Extends HS.FHIRServer.Interop.Service
{

/// Use this method to dispatch a business invocation synchronously
Method SendRequestSync(targetDispatchName As %String, request As %Library.Persistent, ByRef response As %Library.Persistent, timeout As %Numeric = -1, description As %String = "", ByRef sendSyncHandling As %String) As %Status
{
	#Dim status As %Status = $$$OK
	#Dim exception As %Exception.AbstractException

	#Dim interopRequest As FHIRInterop.FHIRServer.Interop.Request
	#Dim interopResponse As FHIRInterop.FHIRServer.Interop.Response

	Try {
		Set interopRequest = ##class(FHIRInterop.FHIRServer.Interop.Request).FromHSRequest(request)

		// Now dispatch, passing through all parameters from the caller
		Set status = ##Super(targetDispatchName, interopRequest, .interopResponse, timeout, description, .sendSyncHandling)
		If ($$$ISERR(status)) return status

		If ($IsObject($Get(interopResponse))) {
			Set response = interopResponse.ToHSResponse()
		}

	} Catch exception {
		Set status = exception.AsStatus()
	}

	Return status
}

}
