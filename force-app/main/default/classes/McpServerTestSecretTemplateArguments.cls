@IsTest
public class McpServerTestSecretTemplateArguments extends JsonRpcParamsBase {
    public Integer value;

    public override void validate() {
        if (this.value == null) {
            throw new McpExceptions.InvalidParamsException('secret-sum requires integer value.');
        }
    }
}
