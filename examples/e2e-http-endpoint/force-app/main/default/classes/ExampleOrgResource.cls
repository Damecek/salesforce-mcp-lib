/**
 * Example resource exposing basic org information. Cached by clients for one minute.
 */
public with sharing class ExampleOrgResource extends McpResource {
    public ExampleOrgResource() {
        super('salesforce://org/info', 'org_info');
        title('Org information')
            .description('Basic information about the connected Salesforce org')
            .mimeType('application/json');
    }

    public override McpResourceResult read(McpRequest request) {
        Organization org = [SELECT Name, OrganizationType, IsSandbox FROM Organization WITH USER_MODE LIMIT 1];
        return McpResourceResult.of(McpResourceContents.text(getUri(), 'application/json', JSON.serialize(org)))
            .cache(60000, McpServer.CACHE_PRIVATE);
    }
}
