/**
 * Development harness status resource.
 */
public class DevMcpHarnessResource extends McpResourceDefinition {
    public DevMcpHarnessResource() {
        this.uri = 'dev://harness/status';
        this.name = 'Harness Status';
        this.description = 'Current status of the development harness';
        this.mimeType = 'application/json';
    }
    public override McpResourceResult read() {
        McpResourceResult result = new McpResourceResult();
        McpResourceContentItem item = new McpResourceContentItem();
        item.uri = this.uri;
        item.mimeType = this.mimeType;
        item.text = '{"status":"running","timestamp":"' + String.valueOf(Datetime.now()) + '"}';
        result.contents = new List<McpResourceContentItem>{ item };
        return result;
    }
}
