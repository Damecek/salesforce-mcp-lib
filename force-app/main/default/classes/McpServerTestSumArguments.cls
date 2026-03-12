@IsTest
public class McpServerTestSumArguments extends JsonRpcParamsBase {
    public Integer a;
    public Integer b;

    public override void validate() {
        if (this.a == null || this.b == null) {
            throw new McpExceptions.InvalidParamsException('math.sum requires integer a and b.');
        }
    }
}
