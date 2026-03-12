@IsTest
public class McpServerTestPromptArguments extends JsonRpcParamsBase {
    public String target;

    public override void validate() {
        if (String.isBlank(this.target)) {
            throw new McpExceptions.InvalidParamsException('greet-target requires non-empty target.');
        }
    }
}
