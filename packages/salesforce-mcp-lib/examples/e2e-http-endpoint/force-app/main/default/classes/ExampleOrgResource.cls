/**
 * Example resource exposing org information.
 */
public with sharing class ExampleOrgResource extends McpResourceDefinition {
    public ExampleOrgResource() {
        this.uri = 'salesforce://org/info';
        this.name = 'Org Information';
        this.description = 'Basic information about the connected Salesforce org';
        this.mimeType = 'application/json';
    }
    public override McpResourceResult read() {
        Organization org = [SELECT Name, OrganizationType, IsSandbox FROM Organization LIMIT 1];
        McpResourceResult result = new McpResourceResult();
        McpResourceContentItem item = new McpResourceContentItem();
        item.uri = this.uri;
        item.mimeType = this.mimeType;
        item.text = JSON.serialize(org);
        result.contents = new List<McpResourceContentItem>{ item };
        return result;
    }
}
