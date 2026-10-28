Class FHIRSERVERPKG.FoundationProduction Extends Ens.Production [ Not ProcedureBlock ]
{

XData ProductionDefinition
{
<Production Name="FHIRSERVERPKG.FoundationProduction" LogGeneralTraceEvents="false">
  <Description></Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="FHIR_Repository" Category="" ClassName="FHIRInterop.FHIRServer.Interop.Operation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="FHIR_API" Category="" ClassName="FHIRInterop.FHIRServer.Interop.Service" PoolSize="0" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="TargetConfigName">FHIR_Repository</Setting>
  </Item>
</Production>
}

}
