Class FHIRINTEROPPKG.FoundationProduction Extends Ens.Production [ Not ProcedureBlock ]
{

XData ProductionDefinition
{
<Production Name="FHIRINTEROPPKG.FoundationProduction" LogGeneralTraceEvents="false">
  <Description></Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="Service" Category="" ClassName="FHIRInterop.Ex.Service" PoolSize="1" Enabled="true" Foreground="false" Comment="Creates messages for some FHIR interactions when started" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="TargetConfigName">To_FHIR_Server</Setting>
    <Setting Target="Adapter" Name="CallInterval">360000</Setting>
  </Item>
  <Item Name="To_FHIR_Server" Category="" ClassName="FHIRInterop.FHIRServer.Interop.HTTPOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="Credentials">FHIR_Server</Setting>
    <Setting Target="Adapter" Name="HTTPPort">52773</Setting>
    <Setting Target="Adapter" Name="HTTPServer">localhost</Setting>
    <Setting Target="Adapter" Name="URL">/fhir/r4</Setting>
  </Item>
</Production>
}

}
