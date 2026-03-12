public inherited sharing class MinimalMcpExample {
    public static McpServer buildServer() {
        McpToolDefinition sumTool = new McpToolDefinition('math.sum', 'Adds two integers.', MinimalMcpExampleSumArguments.class);
        sumTool.inputSchema = new Map<String, Object>{
            'type' => 'object',
            'properties' => new Map<String, Object>{
                'a' => new Map<String, Object>{ 'type' => 'integer' },
                'b' => new Map<String, Object>{ 'type' => 'integer' }
            },
            'required' => new List<Object>{ 'a', 'b' }
        };

        McpResourceDefinition secretResource = new McpResourceDefinition('mcp://secret/one', 'Secret Integer One');
        secretResource.description = 'Returns constant 1.';

        McpResourceTemplateDefinition secretTemplate = new McpResourceTemplateDefinition(
            'secret-sum',
            'mcp://templates/secret-sum{?value}',
            MinimalMcpExampleSecretTemplateArguments.class
        );
        secretTemplate.description = 'Adds argument value with the secret resource integer.';

        return new McpServer('Minimal MCP Example', '1.0.0')
            .registerTool(sumTool, new SumTool())
            .registerResource(secretResource, new SecretResource())
            .registerResourceTemplate(secretTemplate, new SecretTemplate());
    }

    public class SumTool implements McpToolExecutor {
        public McpToolResult execute(JsonRpcParamsBase arguments, McpRequestContext context) {
            MinimalMcpExampleSumArguments typed = (MinimalMcpExampleSumArguments) arguments;

            McpToolResult result = new McpToolResult();
            result.content.add(new McpTextContent(String.valueOf(typed.a + typed.b)));
            return result;
        }
    }

    public class SecretResource implements McpResourceExecutor {
        public McpResourceResult read(String resourceUri, McpRequestContext context) {
            McpResourceResult result = new McpResourceResult();
            result.contents.add(new McpResourceContentItem(resourceUri, '1', 'application/json'));
            return result;
        }
    }

    public class SecretTemplate implements McpResourceTemplateExecutor {
        public McpResourceResult resolve(JsonRpcParamsBase arguments, McpRequestContext context) {
            MinimalMcpExampleSecretTemplateArguments typed = (MinimalMcpExampleSecretTemplateArguments) arguments;

            McpResourceResult result = new McpResourceResult();
            result.contents.add(new McpResourceContentItem('mcp://templates/secret-sum', String.valueOf(typed.value + 1), 'application/json'));
            return result;
        }
    }
}

class MinimalMcpExampleSumArguments extends JsonRpcParamsBase {
    public Integer a;
    public Integer b;

    public override void validate() {
        if (this.a == null || this.b == null) {
            throw new McpExceptions.InvalidParamsException('math.sum requires integer a and b.');
        }
    }
}

class MinimalMcpExampleSecretTemplateArguments extends JsonRpcParamsBase {
    public Integer value;

    public override void validate() {
        if (this.value == null) {
            throw new McpExceptions.InvalidParamsException('secret-sum requires integer value.');
        }
    }
}
