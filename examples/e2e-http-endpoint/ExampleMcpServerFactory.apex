public inherited sharing class ExampleMcpServerFactory {
    public static McpServer build() {
        McpToolDefinition sumTool = new McpToolDefinition('math.sum', 'Adds two integers.');
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

        McpResourceTemplateDefinition secretTemplate = new McpResourceTemplateDefinition('secret-sum', 'mcp://templates/secret-sum{?value}');
        secretTemplate.description = 'Adds argument value with the secret resource integer.';

        return new McpServer('HTTP MCP Example', '1.0.0')
            .registerTool(sumTool, new SumTool())
            .registerResource(secretResource, new SecretResource())
            .registerResourceTemplate(secretTemplate, new SecretTemplate());
    }

    private class SumTool implements McpToolExecutor {
        public Object execute(Map<String, Object> arguments, McpRequestContext context) {
            Integer a = Integer.valueOf(String.valueOf(arguments.get('a')));
            Integer b = Integer.valueOf(String.valueOf(arguments.get('b')));
            return new Map<String, Object>{
                'type' => 'text',
                'text' => String.valueOf(a + b)
            };
        }
    }

    private class SecretResource implements McpResourceExecutor {
        public Object read(String resourceUri, McpRequestContext context) {
            return 1;
        }
    }

    private class SecretTemplate implements McpResourceTemplateExecutor {
        public Object resolve(Map<String, Object> arguments, McpRequestContext context) {
            Integer value = Integer.valueOf(String.valueOf(arguments.get('value')));
            return new Map<String, Object>{
                'contents' => new List<Object>{
                    new Map<String, Object>{
                        'uri' => 'mcp://templates/secret-sum',
                        'mimeType' => 'application/json',
                        'text' => String.valueOf(value + 1)
                    }
                }
            };
        }
    }
}
