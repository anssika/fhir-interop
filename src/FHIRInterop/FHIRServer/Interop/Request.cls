/// <p>A journaled alternative to class <class>HS.FHIRServer.Interop.Request</class></p>
/// 
/// <p>To use this class, you need to extend classes <class>HS.FHIRServer.Interop.Service</class> 
/// and <class>HS.FHIRServer.Interop.Operation</class> and possibly other interoperability classes accordingly</p>
/// 
/// <p>For some insight on the use of class <class>HS.FHIRServer.Interop.Response</class>, take a look at the source code of class <class>HS.FHIRServer.RestHandler</class></p>
Class FHIRInterop.FHIRServer.Interop.Request Extends HS.Util.EnsRequest [ StorageStrategy = "" ]
{

Property Request As HS.FHIRServer.API.Data.Request;

/// Request payload.
Property Payload As %Stream.GlobalCharacter;

Parameter RESPONSECLASSNAME = "FHIRInterop.FHIRServer.Interop.Response";

ClassMethod FromHSRequest(request As HS.FHIRServer.Interop.Request) As FHIRInterop.FHIRServer.Interop.Request
{
	#Dim interopRequest As FHIRInterop.FHIRServer.Interop.Request = ..%New()

	Set interopRequest.Request = request.Request
	If (request.QuickStreamId '= "") {
		#Dim tQuickStream As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%OpenId(request.QuickStreamId)
		If '$IsObject(tQuickStream) {
			// (at lease today) HS.SDA3.QuickStream.%OpenId returns a live
			// object even for an unresolvable id (so an absent payload reads as empty, not
			// NULLOREF), meaning this guard rarely if ever fires.
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Could not open request QuickStream with id '" _ request.QuickStreamId _ "'"))
		}
		Do interopRequest.Payload.CopyFrom(tQuickStream)
	}

	Return interopRequest
}

Method ToHSRequest() As HS.FHIRServer.Interop.Request
{
	#Dim request As HS.FHIRServer.Interop.Request = ##class(HS.FHIRServer.Interop.Request).%New()

	Set request.Request = ..Request
	If ($IsObject(..Payload) && (..Payload.Size)) {
		#Dim tQuickStream As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%New()
		Do tQuickStream.CopyFrom(..Payload)
		Set request.QuickStreamId = tQuickStream.%Id()
	}

	Return request
}

Storage Default
{
<Data name="RequestDefaultData">
<Subscript>"Request"</Subscript>
<Value name="1">
<Value>Request</Value>
</Value>
<Value name="2">
<Value>Payload</Value>
</Value>
</Data>
<DefaultData>RequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
