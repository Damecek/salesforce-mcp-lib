@IsTest
public class McpHttpTransportTestEchoArguments extends JsonRpcParamsBase {
    public String value;

    public override void validate() {
        if (String.isBlank(this.value)) {
            throw new McpExceptions.InvalidParamsException('echo.tool requires non-empty value.');
        }
    }
}
