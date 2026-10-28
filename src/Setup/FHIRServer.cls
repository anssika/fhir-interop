Class Setup.FHIRServer
{

/// Throws an exeception on any error
ClassMethod AddServer(namespace As %String, fhirBase As %String, serviceConfigName As %String = "")
{
	$$$ThrowOnError(##class(HS.Util.Installer.Foundation).Install(namespace, .vars))

	New $Namespace
	Set $Namespace = namespace

	Do ##class(HS.FHIRServer.Installer).InstallNamespace(namespace)
	Do ##class(HS.FHIRServer.Installer).InstallInstance(fhirBase,
														"HS.FHIRServer.Storage.JsonAdvSQL.InteractionsStrategy",
														"hl7.fhir.r4.core@4.0.1",,,,,,
														fhirBase)

	// Get FHIR server's configuration object (needed when calling method UpdateInstance)
	Set strategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(fhirBase)
	Set configData = strategy.GetServiceConfigData()
	// Stringify configData for the call to update FHIR Server
	Set jsonConfigData = configData.AsJSONString()
	// Update FHIR Server - to set the serviceConfigName
	Do ##class(HS.FHIRServer.Installer).UpdateInstance(fhirBase, jsonConfigData, 1, serviceConfigName, "", fhirBase)
}

}
