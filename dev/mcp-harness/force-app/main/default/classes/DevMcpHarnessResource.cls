/**
 * Development harness status resource.
 */
public with sharing class DevMcpHarnessResource extends McpResource {
    public DevMcpHarnessResource() {
        super('dev://harness/status', 'harness_status');
        title('Harness status').description('Current status of the development harness').mimeType('application/json');
    }

    public override McpResourceResult read(McpRequest request) {
        String body = JSON.serialize(new Map<String, Object>{ 'status' => 'running', 'timestamp' => Datetime.now() });
        return McpResourceResult.of(McpResourceContents.text(getUri(), 'application/json', body));
    }
}
