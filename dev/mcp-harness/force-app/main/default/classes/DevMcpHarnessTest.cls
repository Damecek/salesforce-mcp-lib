@IsTest
private class DevMcpHarnessTest {
    private static Map<String, Object> invoke(Map<String, Object> requestPayload) {
        return invoke(requestPayload, '/services/apexrest/mcp');
    }

    private static Map<String, Object> invoke(Map<String, Object> requestPayload, String requestUri) {
        RestRequest request = new RestRequest();
        request.httpMethod = 'POST';
        request.requestURI = requestUri;
        request.requestBody = Blob.valueOf(JSON.serialize(requestPayload));

        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;

        if (requestUri == '/services/apexrest/opportunity/mcp') {
            DevMcpOpportunityHarnessEndpoint.handlePost();
        } else {
            DevMcpHarnessEndpoint.handlePost();
        }

        System.assertEquals('application/json', response.headers.get('Content-Type'));
        System.assertEquals(200, response.statusCode);
        return (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
    }

    @IsTest
    static void testInitializeAndListShapes() {
        Map<String, Object> initializePayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 1,
            'method' => 'initialize',
            'params' => new Map<String, Object>{
                'protocolVersion' => '2025-11-25',
                'capabilities' => new Map<String, Object>(),
                'clientInfo' => new Map<String, Object>{
                    'name' => 'inspector',
                    'version' => '1.0.0'
                }
            }
        });

        Map<String, Object> initializeResult = (Map<String, Object>) initializePayload.get('result');
        System.assertEquals('2025-11-25', initializeResult.get('protocolVersion'));

        Map<String, Object> toolsPayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 2,
            'method' => 'tools/list',
            'params' => new Map<String, Object>()
        });

        Map<String, Object> toolsResult = (Map<String, Object>) toolsPayload.get('result');
        List<Object> tools = (List<Object>) toolsResult.get('tools');
        System.assertEquals(2, tools.size());

        Map<String, Object> nestedTool;
        for (Object item : tools) {
            Map<String, Object> candidate = (Map<String, Object>) item;
            if ((String) candidate.get('name') == 'math.profile_sum') {
                nestedTool = candidate;
            }
        }

        System.assertNotEquals(null, nestedTool);
        Map<String, Object> inputSchema = (Map<String, Object>) nestedTool.get('inputSchema');
        Map<String, Object> profileSchema = (Map<String, Object>) ((Map<String, Object>) inputSchema.get('properties')).get('profile');
        System.assertEquals(false, inputSchema.get('additionalProperties'));
        System.assertEquals(false, profileSchema.get('additionalProperties'));
    }

    @IsTest
    static void testCallFlatAndNestedTools() {
        Map<String, Object> sumPayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 3,
            'method' => 'tools/call',
            'params' => new Map<String, Object>{
                'name' => 'math.sum',
                'arguments' => new Map<String, Object>{ 'a' => 2, 'b' => 5 }
            }
        });
        assertSingleTextContent(sumPayload, '7');

        Map<String, Object> nestedPayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 4,
            'method' => 'tools/call',
            'params' => new Map<String, Object>{
                'name' => 'math.profile_sum',
                'arguments' => new Map<String, Object>{
                    'profile' => new Map<String, Object>{
                        'user' => new Map<String, Object>{
                            'id' => 'user-7',
                            'weights' => new Map<String, Object>{
                                'primary' => 4,
                                'secondary' => 6
                            }
                        },
                        'metadata' => new Map<String, Object>{
                            'label' => 'alpha'
                        }
                    },
                    'bonus' => 3
                }
            }
        });
        assertSingleTextContent(nestedPayload, 'user-7|alpha|13');
    }

    @IsTest
    static void testReadTemplateAndPromptFlows() {
        Map<String, Object> resourcesListPayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 5,
            'method' => 'resources/list',
            'params' => new Map<String, Object>()
        });
        List<Object> resources = (List<Object>) ((Map<String, Object>) resourcesListPayload.get('result')).get('resources');
        System.assertEquals(1, resources.size());

        Map<String, Object> resourcePayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 6,
            'method' => 'resources/read',
            'params' => new Map<String, Object>{ 'uri' => DevMcpHarnessServerFactory.SECRET_RESOURCE_URI }
        });
        List<Object> contents = (List<Object>) ((Map<String, Object>) resourcePayload.get('result')).get('contents');
        System.assertEquals('{"value":1}', ((Map<String, Object>) contents[0]).get('text'));

        Map<String, Object> templatesPayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 7,
            'method' => 'resources/templates/list',
            'params' => new Map<String, Object>()
        });
        List<Object> templates = (List<Object>) ((Map<String, Object>) templatesPayload.get('result')).get('resourceTemplates');
        System.assertEquals(1, templates.size());

        Map<String, Object> templateCallPayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 8,
            'method' => 'resources/templates/call',
            'params' => new Map<String, Object>{
                'name' => DevMcpHarnessServerFactory.TEMPLATE_NAME,
                'arguments' => new Map<String, Object>{ 'value' => 9 }
            }
        });
        List<Object> templateContents = (List<Object>) ((Map<String, Object>) templateCallPayload.get('result')).get('contents');
        System.assertEquals('{"value":10}', ((Map<String, Object>) templateContents[0]).get('text'));

        Map<String, Object> promptsPayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 9,
            'method' => 'prompts/list',
            'params' => new Map<String, Object>()
        });
        List<Object> prompts = (List<Object>) ((Map<String, Object>) promptsPayload.get('result')).get('prompts');
        System.assertEquals(1, prompts.size());

        Map<String, Object> promptGetPayload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 10,
            'method' => 'prompts/get',
            'params' => new Map<String, Object>{
                'name' => DevMcpHarnessServerFactory.PROMPT_NAME,
                'arguments' => new Map<String, Object>{ 'target' => 'Acme' }
            }
        });
        List<Object> messages = (List<Object>) ((Map<String, Object>) promptGetPayload.get('result')).get('messages');
        Map<String, Object> firstMessage = (Map<String, Object>) messages[0];
        Map<String, Object> content = (Map<String, Object>) firstMessage.get('content');
        System.assertEquals('Review profile for Acme using the harness outputs.', content.get('text'));
    }

    @IsTest
    static void testInvalidNestedPayloadMapsToError() {
        Map<String, Object> payload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 11,
            'method' => 'tools/call',
            'params' => new Map<String, Object>{
                'name' => 'math.profile_sum',
                'arguments' => new Map<String, Object>{
                    'profile' => new Map<String, Object>{
                        'user' => new Map<String, Object>{
                            'id' => 'broken',
                            'weights' => new Map<String, Object>{
                                'primary' => 4
                            }
                        },
                        'metadata' => new Map<String, Object>{
                            'label' => 'alpha'
                        }
                    },
                    'bonus' => 1
                }
            }
        });

        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertNotEquals(null, error);
        System.assertEquals(-32602, error.get('code'));
    }

    @IsTest
    static void testNestedApexRestPathUsesSameHarness() {
        Map<String, Object> payload = invoke(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 12,
            'method' => 'tools/call',
            'params' => new Map<String, Object>{
                'name' => 'math.sum',
                'arguments' => new Map<String, Object>{ 'a' => 4, 'b' => 6 }
            }
        }, '/services/apexrest/opportunity/mcp');

        assertSingleTextContent(payload, '10');
    }

    private static void assertSingleTextContent(Map<String, Object> payload, String expectedText) {
        Map<String, Object> result = (Map<String, Object>) payload.get('result');
        List<Object> content = (List<Object>) result.get('content');
        Map<String, Object> firstItem = (Map<String, Object>) content[0];
        System.assertEquals(expectedText, firstItem.get('text'));
        System.assertEquals(false, result.get('isError'));
    }
}
