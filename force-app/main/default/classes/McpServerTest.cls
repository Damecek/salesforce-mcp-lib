@IsTest
private class McpServerTest {
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

    private class PromptExample implements McpPromptExecutor {
        public Object resolve(Map<String, Object> arguments, McpRequestContext context) {
            String target = String.valueOf(arguments.get('target'));
            return new Map<String, Object>{
                'messages' => new List<Object>{
                    new Map<String, Object>{
                        'role' => 'user',
                        'content' => new List<Object>{
                            new Map<String, Object>{
                                'type' => 'text',
                                'text' => 'Hello ' + target
                            }
                        }
                    }
                }
            };
        }
    }

    private static McpServer buildServer() {
        McpToolDefinition toolDef = new McpToolDefinition('math.sum', 'Sums two integers.');
        toolDef.inputSchema = new Map<String, Object>{
            'type' => 'object'
        };

        McpResourceDefinition resourceDef = new McpResourceDefinition('mcp://secret/one', 'Secret One');
        resourceDef.description = 'Returns constant secret integer 1.';

        McpResourceTemplateDefinition templateDef = new McpResourceTemplateDefinition('secret-sum', 'mcp://templates/secret-sum{?value}');
        templateDef.description = 'Adds provided value to secret resource value.';

        McpPromptDefinition promptDef = new McpPromptDefinition('greet-target', 'Greets a named target.');

        McpServer server = new McpServer('Test MCP', '1.2.3');
        server
            .registerTool(toolDef, new SumTool())
            .registerResource(resourceDef, new SecretResource())
            .registerResourceTemplate(templateDef, new SecretTemplate())
            .registerPrompt(promptDef, new PromptExample());

        return server;
    }

    @IsTest
    static void testInitializeAndLists() {
        McpServer server = buildServer();

        Map<String, Object> request = new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 1,
            'method' => 'initialize',
            'params' => new Map<String, Object>()
        };

        JsonRpcExecutionResult result = server.execute(JSON.serialize(request));
        System.assertEquals(true, result.hasResponse);

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(result.toJson());
        Map<String, Object> responseResult = (Map<String, Object>) payload.get('result');
        if (responseResult == null) {
            System.assertEquals(null, payload.get('error'), 'initialize should not return JSON-RPC error.');
            System.assert(false, 'initialize did not return result payload.');
        }
        System.assertEquals('2025-06-18', responseResult.get('protocolVersion'));

        List<Map<String, Object>> listCalls = new List<Map<String, Object>>{
            new Map<String, Object>{ 'jsonrpc' => '2.0', 'id' => 2, 'method' => 'tools/list', 'params' => new Map<String, Object>() },
            new Map<String, Object>{ 'jsonrpc' => '2.0', 'id' => 3, 'method' => 'resources/list', 'params' => new Map<String, Object>() },
            new Map<String, Object>{ 'jsonrpc' => '2.0', 'id' => 4, 'method' => 'resources/templates/list', 'params' => new Map<String, Object>() },
            new Map<String, Object>{ 'jsonrpc' => '2.0', 'id' => 5, 'method' => 'prompts/list', 'params' => new Map<String, Object>() }
        };

        JsonRpcExecutionResult listResult = server.execute(JSON.serialize(listCalls));
        List<Object> listPayload = (List<Object>) JSON.deserializeUntyped(listResult.toJson());
        System.assertEquals(4, listPayload.size());
    }

    @IsTest
    static void testCallReadTemplateAndPrompt() {
        McpServer server = buildServer();

        List<Map<String, Object>> calls = new List<Map<String, Object>>{
            new Map<String, Object>{
                'jsonrpc' => '2.0',
                'id' => 11,
                'method' => 'tools/call',
                'params' => new Map<String, Object>{
                    'name' => 'math.sum',
                    'arguments' => new Map<String, Object>{ 'a' => 2, 'b' => 3 }
                }
            },
            new Map<String, Object>{
                'jsonrpc' => '2.0',
                'id' => 12,
                'method' => 'resources/read',
                'params' => new Map<String, Object>{ 'uri' => 'mcp://secret/one' }
            },
            new Map<String, Object>{
                'jsonrpc' => '2.0',
                'id' => 13,
                'method' => 'resources/templates/call',
                'params' => new Map<String, Object>{
                    'name' => 'secret-sum',
                    'arguments' => new Map<String, Object>{ 'value' => 5 }
                }
            },
            new Map<String, Object>{
                'jsonrpc' => '2.0',
                'id' => 14,
                'method' => 'prompts/get',
                'params' => new Map<String, Object>{
                    'name' => 'greet-target',
                    'arguments' => new Map<String, Object>{ 'target' => 'agent' }
                }
            }
        };

        JsonRpcExecutionResult result = server.execute(JSON.serialize(calls));
        List<Object> payload = (List<Object>) JSON.deserializeUntyped(result.toJson());
        System.assertEquals(4, payload.size());
    }

    @IsTest
    static void testErrorsAreMapped() {
        McpServer server = buildServer();

        Map<String, Object> missingToolCall = new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 20,
            'method' => 'tools/call',
            'params' => new Map<String, Object>{
                'name' => 'missing.tool',
                'arguments' => new Map<String, Object>()
            }
        };

        JsonRpcExecutionResult result = server.execute(JSON.serialize(missingToolCall));
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(result.toJson());
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(-32601, error.get('code'));
    }

    @IsTest
    static void testNotificationHasNoResponse() {
        McpServer server = buildServer();

        Map<String, Object> notification = new Map<String, Object>{
            'jsonrpc' => '2.0',
            'method' => 'tools/list',
            'params' => new Map<String, Object>()
        };

        JsonRpcExecutionResult result = server.execute(JSON.serialize(notification));
        System.assertEquals(false, result.hasResponse);
        System.assertEquals(null, result.toJson());
    }
}
