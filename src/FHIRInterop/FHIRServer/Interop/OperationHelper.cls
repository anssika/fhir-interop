Include Ensemble

/// <p>Shared dispatch logic for the journaled FHIR interop operations.</p>
/// <p><class>FHIRInterop.FHIRServer.Interop.Operation</class> and
/// <class>FHIRInterop.FHIRServer.Interop.HTTPOperation</class> extend different HS
/// parents (<class>HS.FHIRServer.Interop.Operation</class> vs
/// <class>HS.FHIRServer.Interop.HTTPOperation</class>) that share no common FHIR
/// ancestor, so they cannot share a superclass. They delegate here instead so the
/// unwrap / dispatch / re-wrap / QuickStream-cleanup logic lives in exactly one place.</p>
Class FHIRInterop.FHIRServer.Interop.OperationHelper [ Abstract ]
{

/// <p>pOperation is the calling business operation; its DispatchRequest is resolved
/// dynamically (both HS parents expose it with an identical signature).</p>
ClassMethod DispatchInterop(pOperation As Ens.BusinessOperation, interopRequest As FHIRInterop.FHIRServer.Interop.Request, Output interopResponse As FHIRInterop.FHIRServer.Interop.Response) As %Status
{
	#Dim status As %Status = $$$OK
	#Dim exception As %Exception.AbstractException

	#Dim request As HS.FHIRServer.Interop.Request = $$$NULLOREF
	#Dim response As HS.FHIRServer.Interop.Response = $$$NULLOREF

	Try {
		Set request = interopRequest.ToHSRequest()
		Set status = pOperation.DispatchRequest(request, .response)
		// We do not check status here, because we do not want to return early here,
		// because we want to clear the QuickStreams of both the request and the response.
		// So we continue, make noise of all errors, and return the status after clearing the QuickStreams at the end of this method.

		If ($IsObject(response)) {
			Set interopResponse = ##class(FHIRInterop.FHIRServer.Interop.Response).FromHSResponse(response)
		}
	} Catch exception {
		If ($$$ISERR(status)) {
			// Do not hide the error that happened earlier
			$$$LOGERROR("Call of DispatchRequest() returned error status (before of this exception): " _ ##class(%SYSTEM.Status).GetErrorText(status))
		}
		Set status = exception.AsStatus()
	}

	// Clear the QuickStreams of both the request and the response.
	// The QuickStreams are stored in global ^CacheTemp.HS.Stream
	Do ..ClearQuickStream(request)
	Do ..ClearQuickStream(response)

	Return status
}

/// <p>Clear the transient QuickStream behind an HS request/response, if any.</p>
ClassMethod ClearQuickStream(pMessage As %RegisteredObject)
{
	If '$IsObject(pMessage) || (pMessage.QuickStreamId = "") Return
	#Dim quickStream As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%OpenId(pMessage.QuickStreamId)
	If $IsObject(quickStream) Do quickStream.Clear(1)
}

}
