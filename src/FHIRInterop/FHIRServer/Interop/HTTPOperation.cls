/// <p>An alternative implementation of the operation class for using journaled alternatives of message classes
/// <class>HS.FHIRServer.Interop.Request</class> and <class>HS.FHIRServer.Interop.Response</class></p>
///
Class FHIRInterop.FHIRServer.Interop.HTTPOperation Extends HS.FHIRServer.Interop.HTTPOperation
{

XData MessageMap
{
<MapItems>
	<MapItem MessageType="FHIRInterop.FHIRServer.Interop.Request">
		<Method>DispatchRequestInterop</Method>
	</MapItem>
</MapItems>
}

Method DispatchRequestInterop(interopRequest As FHIRInterop.FHIRServer.Interop.Request, Output interopResponse As FHIRInterop.FHIRServer.Interop.Response) As %Status
{
	Return ##class(FHIRInterop.FHIRServer.Interop.OperationHelper).DispatchInterop($this, interopRequest, .interopResponse)
}
}
