/**
 * @description JSON-RPC params DTO for resources/read.
 */
public inherited sharing class McpResourcesReadRpcParams extends JsonRpcParamsBase {
    public String uri;

    public override void validate() {
        if (String.isBlank(this.uri)) {
            throw new McpExceptions.InvalidParamsException('resources/read requires non-empty uri.');
        }
    }
}
