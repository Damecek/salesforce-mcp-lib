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

        Map<String, Object> toolsResponse = (Map<String, Object>) listPayload[0];
        System.assertEquals(null, toolsResponse.get('error'));
        Map<String, Object> toolsResult = (Map<String, Object>) toolsResponse.get('result');
        List<Object> tools = (List<Object>) toolsResult.get('tools');
        System.assertEquals(1, tools.size());
        Map<String, Object> tool = (Map<String, Object>) tools[0];
        System.assertEquals('math.sum', tool.get('name'));

        Map<String, Object> resourcesResponse = (Map<String, Object>) listPayload[1];
        System.assertEquals(null, resourcesResponse.get('error'));
        Map<String, Object> resourcesResult = (Map<String, Object>) resourcesResponse.get('result');
        List<Object> resources = (List<Object>) resourcesResult.get('resources');
        System.assertEquals(1, resources.size());
        Map<String, Object> resource = (Map<String, Object>) resources[0];
        System.assertEquals('mcp://secret/one', resource.get('uri'));

        Map<String, Object> templatesResponse = (Map<String, Object>) listPayload[2];
        System.assertEquals(null, templatesResponse.get('error'));
        Map<String, Object> templatesResult = (Map<String, Object>) templatesResponse.get('result');
        List<Object> templates = (List<Object>) templatesResult.get('resourceTemplates');
        System.assertEquals(1, templates.size());
        Map<String, Object> template = (Map<String, Object>) templates[0];
        System.assertEquals('secret-sum', template.get('name'));

        Map<String, Object> promptsResponse = (Map<String, Object>) listPayload[3];
        System.assertEquals(null, promptsResponse.get('error'));
        Map<String, Object> promptsResult = (Map<String, Object>) promptsResponse.get('result');
        List<Object> prompts = (List<Object>) promptsResult.get('prompts');
        System.assertEquals(1, prompts.size());
        Map<String, Object> prompt = (Map<String, Object>) prompts[0];
        System.assertEquals('greet-target', prompt.get('name'));
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

        Map<String, Object> toolResponse = (Map<String, Object>) payload[0];
        System.assertEquals(null, toolResponse.get('error'));
        Map<String, Object> toolResult = (Map<String, Object>) toolResponse.get('result');
        List<Object> content = (List<Object>) toolResult.get('content');
        Map<String, Object> contentItem = (Map<String, Object>) content[0];
        System.assertEquals('5', contentItem.get('text'));

        Map<String, Object> resourceResponse = (Map<String, Object>) payload[1];
        System.assertEquals(null, resourceResponse.get('error'));
        Map<String, Object> resourceResult = (Map<String, Object>) resourceResponse.get('result');
        List<Object> contents = (List<Object>) resourceResult.get('contents');
        Map<String, Object> resourceContent = (Map<String, Object>) contents[0];
        System.assertEquals('mcp://secret/one', resourceContent.get('uri'));
        System.assertEquals('1', resourceContent.get('text'));

        Map<String, Object> templateResponse = (Map<String, Object>) payload[2];
        System.assertEquals(null, templateResponse.get('error'));
        Map<String, Object> templateResult = (Map<String, Object>) templateResponse.get('result');
        List<Object> templateContents = (List<Object>) templateResult.get('contents');
        Map<String, Object> templateContent = (Map<String, Object>) templateContents[0];
        System.assertEquals('mcp://templates/secret-sum', templateContent.get('uri'));
        System.assertEquals('6', templateContent.get('text'));

        Map<String, Object> promptResponse = (Map<String, Object>) payload[3];
        System.assertEquals(null, promptResponse.get('error'));
        Map<String, Object> promptResult = (Map<String, Object>) promptResponse.get('result');
        System.assertEquals(false, promptResult.containsKey('value'));
        List<Object> messages = (List<Object>) promptResult.get('messages');
        Map<String, Object> message = (Map<String, Object>) messages[0];
        List<Object> promptContent = (List<Object>) message.get('content');
        Map<String, Object> promptContentItem = (Map<String, Object>) promptContent[0];
        System.assertEquals('Hello agent', promptContentItem.get('text'));
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
    static void testInvalidArgumentsAreMapped() {
        McpServer server = buildServer();
        List<Map<String, Object>> invalidCalls = new List<Map<String, Object>>{
            new Map<String, Object>{
                'jsonrpc' => '2.0',
                'id' => 30,
                'method' => 'tools/call',
                'params' => new Map<String, Object>{
                    'name' => 'math.sum',
                    'arguments' => 'bad'
                }
            },
            new Map<String, Object>{
                'jsonrpc' => '2.0',
                'id' => 31,
                'method' => 'resources/templates/call',
                'params' => new Map<String, Object>{
                    'name' => 'secret-sum',
                    'arguments' => new List<Object>{ 'bad' }
                }
            },
            new Map<String, Object>{
                'jsonrpc' => '2.0',
                'id' => 32,
                'method' => 'prompts/get',
                'params' => new Map<String, Object>{
                    'name' => 'greet-target',
                    'arguments' => 5
                }
            }
        };

        JsonRpcExecutionResult result = server.execute(JSON.serialize(invalidCalls));
        List<Object> payload = (List<Object>) JSON.deserializeUntyped(result.toJson());
        System.assertEquals(3, payload.size());

        for (Object entry : payload) {
            Map<String, Object> response = (Map<String, Object>) entry;
            Map<String, Object> error = (Map<String, Object>) response.get('error');
            System.assertEquals(-32602, error.get('code'));
        }
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
