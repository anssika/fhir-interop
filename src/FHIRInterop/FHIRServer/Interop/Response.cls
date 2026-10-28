/// <p>A journaled alternative to class <class>HS.FHIRServer.Interop.Response</class></p>
/// 
/// <p>To use this class, you need to extend classes <class>HS.FHIRServer.Interop.Service</class> 
/// and <class>HS.FHIRServer.Interop.Operation</class> and possibly other interoperability classes accordingly</p>
/// 
/// <p>For some insight on the use of class <class>HS.FHIRServer.Interop.Response</class>, take a look at the source code of class <class>HS.FHIRServer.RestHandler</class></p>
/// 
Class FHIRInterop.FHIRServer.Interop.Response Extends HS.Util.EnsResponse [ StorageStrategy = "" ]
{

Property Response As HS.FHIRServer.API.Data.Response;

/// Response payload.
Property Payload As %Stream.GlobalCharacter;

/// HTTP response Charset value.
Property CharSet As %String;

/// HTTP response Content-Type header.
Property ContentType As %String(MAXLEN = 8192);

ClassMethod FromHSResponse(response As HS.FHIRServer.Interop.Response) As FHIRInterop.FHIRServer.Interop.Response
{
	#Dim interopResponse As FHIRInterop.FHIRServer.Interop.Response = ..%New()

	Set interopResponse.Response = response.Response
	If (response.QuickStreamId '= "") {
		Set tQuickStream = ##class(HS.SDA3.QuickStream).%OpenId(response.QuickStreamId)
		If '$IsObject(tQuickStream) {
			// (at lease today) HS.SDA3.QuickStream.%OpenId returns a live
			// object even for an unresolvable id (so an absent payload reads as empty, not
			// NULLOREF), meaning this guard rarely if ever fires.
			$$$ThrowStatus($$$ERROR($$$GeneralError, "Could not open response QuickStream with id '" _ response.QuickStreamId _ "'"))
		}
		Do interopResponse.Payload.CopyFrom(tQuickStream)
	}
	Set interopResponse.CharSet = response.CharSet
	Set interopResponse.ContentType = response.ContentType

	Return interopResponse
}

Method ToHSResponse() As HS.FHIRServer.Interop.Response
{
	#Dim response As HS.FHIRServer.Interop.Response = ##class(HS.FHIRServer.Interop.Response).%New()

	Set response.Response = ..Response
	If ($IsObject(..Payload) && (..Payload.Size)) {
		#Dim tQuickStream As HS.SDA3.QuickStream = ##class(HS.SDA3.QuickStream).%New()
		Do tQuickStream.CopyFrom(..Payload)
		Set response.QuickStreamId = tQuickStream.%Id()
	}
	Set response.CharSet = ..CharSet
	Set response.ContentType = ..ContentType

	Return response
}

Storage Default
{
<Data name="ResponseDefaultData">
<Subscript>"Response"</Subscript>
<Value name="1">
<Value>Response</Value>
</Value>
<Value name="2">
<Value>Payload</Value>
</Value>
<Value name="3">
<Value>CharSet</Value>
</Value>
<Value name="4">
<Value>ContentType</Value>
</Value>
</Data>
<DefaultData>ResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
