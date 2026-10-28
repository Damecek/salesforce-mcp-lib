@IsTest
private class McpToolTest {
    private static McpServer server() {
        return McpTestKit.fullServer();
    }

    private static Map<String, Object> call(String name, Map<String, Object> args) {
        Map<String, Object> p = new Map<String, Object>{ 'name' => name };
        if (args != null) { p.put('arguments', args); }
        return p;
    }

    private static String firstText(McpTestKit.Reply r) {
        return (String) ((Map<String, Object>) r.items('content')[0]).get('text');
    }

    // ---------------------------------------------------------------- tools/list

    @IsTest
    static void listShowsToolMetadataInTheModernEra() {
        McpTestKit.Reply r = McpTestKit.modern(server(), 'tools/list', null);
        Assert.areEqual(1, r.items('tools').size());
        Assert.isFalse(r.result().containsKey('nextCursor'));
        Map<String, Object> tool = r.item('tools', 0);
        Assert.areEqual('echo', tool.get('name'));
        Assert.areEqual('Echo', tool.get('title'));
        Assert.areEqual('Echoes a message.', tool.get('description'));
        Map<String, Object> input = (Map<String, Object>) tool.get('inputSchema');
        Assert.areEqual('object', input.get('type'));
        Assert.areEqual(false, input.get('additionalProperties'));
        Assert.areEqual(new List<Object>{ 'message' }, (List<Object>) input.get('required'));
        Map<String, Object> message = (Map<String, Object>) ((Map<String, Object>) input.get('properties')).get('message');
        Assert.areEqual(1, message.get('minLength'));
        Assert.areEqual(20, message.get('maxLength'));
        Map<String, Object> annotations = (Map<String, Object>) tool.get('annotations');
        Assert.areEqual(true, annotations.get('readOnlyHint'));
        Assert.areEqual(false, annotations.get('openWorldHint'));
        Assert.areEqual('acme', ((Map<String, Object>) tool.get('_meta')).get('vendor'));
        Assert.isNotNull(tool.get('outputSchema'));
        Assert.isNotNull(tool.get('icons'));
    }

    @IsTest
    static void toolWithoutInputSchemaGetsTheParameterlessSchema() {
        McpServer s = new McpServer('s', '1').tool(new McpTestKit.ModeTool('plain', 'ok'));
        Map<String, Object> input = (Map<String, Object>) McpTestKit.modern(s, 'tools/list', null).item('tools', 0).get('inputSchema');
        Assert.areEqual(2, input.size());
        Assert.areEqual('object', input.get('type'));
        Assert.areEqual(false, input.get('additionalProperties'));
    }

    @IsTest
    static void parameterlessToolRejectsArgumentsInsteadOfOnlyAdvertisingIt() {
        McpServer s = new McpServer('s', '1').tool(new McpTestKit.ModeTool('plain', 'ok'));
        for (McpTestKit.Reply r : new List<McpTestKit.Reply>{
            McpTestKit.modern(s, 'tools/call', call('plain', new Map<String, Object>{ 'x' => 1 })),
            McpTestKit.legacy(s, 'tools/call', call('plain', new Map<String, Object>{ 'x' => 1 }))
        }) {
            Assert.areEqual(200, r.status);
            Assert.areEqual(true, r.result().get('isError'));
            Assert.areEqual('arguments.x: is not allowed', firstText(r));
        }
        Assert.areEqual('ok', firstText(McpTestKit.modern(s, 'tools/call', call('plain', null))));
        Assert.areEqual('ok', firstText(McpTestKit.modern(s, 'tools/call', call('plain', new Map<String, Object>()))));
        // a raw schema stays trusted: the framework does not police its arguments
        McpTool raw = new McpTestKit.ModeTool('raw', 'ok').inputSchema(new Map<String, Object>{ 'type' => 'object', 'additionalProperties' => false });
        Assert.areEqual('ok', firstText(McpTestKit.modern(new McpServer('s', '1').tool(raw), 'tools/call', call('raw', new Map<String, Object>{ 'x' => 1 }))));
    }

    @IsTest
    static void listPagesInRegistrationOrderWithOpaqueCursors() {
        McpServer s = new McpServer('s', '1').pageSize(2);
        for (Integer i = 0; i < 5; i++) { s.tool(new McpTestKit.ModeTool('t' + i, 'ok')); }
        McpTestKit.Reply first = McpTestKit.modern(s, 'tools/list', null);
        Assert.areEqual('t0', first.item('tools', 0).get('name'));
        Assert.areEqual('t1', first.item('tools', 1).get('name'));
        String cursor = (String) first.result().get('nextCursor');
        Assert.areEqual('v1:2', EncodingUtil.base64Decode(cursor).toString());
        McpTestKit.Reply second = McpTestKit.modern(s, 'tools/list', new Map<String, Object>{ 'cursor' => cursor });
        Assert.areEqual('t2', second.item('tools', 0).get('name'));
        McpTestKit.Reply last = McpTestKit.modern(s, 'tools/list', new Map<String, Object>{ 'cursor' => (String) second.result().get('nextCursor') });
        Assert.areEqual(1, last.items('tools').size());
        Assert.isFalse(last.result().containsKey('nextCursor'));
        // offset equal to the size is an empty last page
        McpTestKit.Reply empty = McpTestKit.modern(s, 'tools/list', new Map<String, Object>{ 'cursor' => EncodingUtil.base64Encode(Blob.valueOf('v1:5')) });
        Assert.areEqual(0, empty.items('tools').size());
        Assert.isFalse(empty.result().containsKey('nextCursor'));
        // null cursor behaves like no cursor
        Assert.areEqual('t0', McpTestKit.modern(s, 'tools/list', new Map<String, Object>{ 'cursor' => null }).item('tools', 0).get('name'));
    }

    @IsTest
    static void invalidCursorsAreInvalidParams() {
        McpServer s = new McpServer('s', '1').pageSize(2).tool(new McpTestKit.ModeTool('a', 'ok')).tool(new McpTestKit.ModeTool('b', 'ok')).tool(new McpTestKit.ModeTool('c', 'ok'));
        List<Object> badCursors = new List<Object>{
            'not base64!', EncodingUtil.base64Encode(Blob.valueOf('v2:1')), EncodingUtil.base64Encode(Blob.valueOf('v1:x')),
            EncodingUtil.base64Encode(Blob.valueOf('v1:-1')), EncodingUtil.base64Encode(Blob.valueOf('v1:4')), EncodingUtil.base64Encode(Blob.valueOf('v1:')),
            EncodingUtil.base64Encode(Blob.valueOf('v1:99999999999999999999')), 'A'.repeat(100), 5, true, new Map<String, Object>(), ''
        };
        for (Object cursor : badCursors) {
            McpTestKit.Reply r = McpTestKit.modern(s, 'tools/list', new Map<String, Object>{ 'cursor' => cursor });
            Assert.areEqual(200, r.status, String.valueOf(cursor));
            Assert.areEqual(-32602, r.code(), String.valueOf(cursor));
            Assert.areEqual('Invalid cursor', r.message());
        }
    }

    @IsTest
    static void legacyListDropsNonObjectOutputSchemas() {
        McpTool arrayOut = new McpTestKit.ModeTool('arr', 'array').output(McpSchema.arr(McpSchema.integer()));
        McpTool rawArrayOut = new McpTestKit.ModeTool('raw', 'array').outputSchema(new Map<String, Object>{ 'type' => 'array' });
        McpTool objectOut = new McpTestKit.ModeTool('obj', 'ok').output(McpSchema.obj().property('a', McpSchema.str()));
        McpServer s = new McpServer('s', '1').tool(arrayOut).tool(rawArrayOut).tool(objectOut);
        McpTestKit.Reply legacy = McpTestKit.legacy(s, 'tools/list', null);
        Assert.isFalse(legacy.item('tools', 0).containsKey('outputSchema'));
        Assert.isFalse(legacy.item('tools', 1).containsKey('outputSchema'));
        Assert.isTrue(legacy.item('tools', 2).containsKey('outputSchema'));
        McpTestKit.Reply modern = McpTestKit.modern(s, 'tools/list', null);
        Assert.isTrue(modern.item('tools', 0).containsKey('outputSchema'));
        Assert.isTrue(modern.item('tools', 1).containsKey('outputSchema'));
    }

    // ---------------------------------------------------------------- tools/call

    @IsTest
    static void callHappyPathReturnsStructuredContentAndTextFallback() {
        McpTestKit.Reply r = McpTestKit.modern(server(), 'tools/call', call('echo', new Map<String, Object>{ 'message' => 'hi', 'count' => 2 }));
        Assert.areEqual(200, r.status);
        Map<String, Object> result = r.result();
        Assert.areEqual('complete', result.get('resultType'));
        Assert.isFalse(result.containsKey('isError'));
        Assert.isFalse(result.containsKey('ttlMs'));
        Map<String, Object> structured = (Map<String, Object>) result.get('structuredContent');
        Assert.areEqual('hi', structured.get('echo'));
        Assert.isTrue(structured.containsKey('note'), 'null values inside structured output survive');
        Assert.isNull(structured.get('note'));
        Map<String, Object> block = (Map<String, Object>) r.items('content')[0];
        Assert.areEqual('text', block.get('type'));
        Map<String, Object> reparsed = (Map<String, Object>) JSON.deserializeUntyped((String) block.get('text'));
        Assert.areEqual('hi', reparsed.get('echo'));
        Assert.isTrue(reparsed.containsKey('note'));
        Assert.isNotNull(((Map<String, Object>) result.get('_meta')).get('io.modelcontextprotocol/serverInfo'));
    }

    @IsTest
    static void unknownToolAndBadParamsAreInvalidParams() {
        McpTestKit.Reply unknown = McpTestKit.modern(server(), 'tools/call', call('nope', null));
        Assert.areEqual(200, unknown.status);
        Assert.areEqual(-32602, unknown.code());
        Assert.areEqual(-32602, McpTestKit.modern(server(), 'tools/call', new Map<String, Object>{ 'name' => 'echo', 'arguments' => 'x' }).code());
        Assert.areEqual(-32602, McpTestKit.modern(server(), 'tools/call', new Map<String, Object>{ 'name' => 'echo', 'arguments' => new List<Object>() }).code());
        Assert.areEqual(-32602, McpTestKit.legacy(server(), 'tools/call', new Map<String, Object>{ 'name' => 7 }).code());
        Assert.isTrue(McpTestKit.legacy(server(), 'tools/call', call('x'.repeat(500), null)).message().length() < 200);
    }

    @IsTest
    static void schemaFailuresAreToolErrorsListingUpToTenProblems() {
        McpTestKit.Reply r = McpTestKit.modern(server(), 'tools/call', call('echo', new Map<String, Object>{ 'count' => 99, 'extra' => 1 }));
        Assert.areEqual(200, r.status);
        Assert.isNull(r.json.get('error'));
        Assert.areEqual(true, r.result().get('isError'));
        String text = firstText(r);
        Assert.isTrue(text.contains('arguments.message: is required'), text);
        Assert.isTrue(text.contains('arguments.count: must be at most 5'), text);
        Assert.isTrue(text.contains('arguments.extra: is not allowed'), text);
        Assert.isFalse(r.result().containsKey('structuredContent'));
    }

    @IsTest
    static void missingArgumentsObjectIsTreatedAsEmpty() {
        McpTestKit.Reply r = McpTestKit.modern(server(), 'tools/call', call('echo', null));
        Assert.areEqual(true, r.result().get('isError'));
        Assert.isTrue(firstText(r).contains('arguments.message: is required'));
    }

    @IsTest
    static void mcpExceptionBecomesAnErrorResult() {
        McpServer s = new McpServer('s', '1').tool(new McpTestKit.ModeTool('m', 'mcp')).tool(new McpTestKit.ModeTool('v', 'validate'));
        McpTestKit.Reply r = McpTestKit.modern(s, 'tools/call', call('m', null));
        Assert.areEqual(true, r.result().get('isError'));
        Assert.areEqual('bad "quote" \\ back\nline', firstText(r));
        McpTestKit.Reply v = McpTestKit.modern(s, 'tools/call', call('v', null));
        Assert.areEqual(true, v.result().get('isError'));
        Assert.areEqual('validate said no', firstText(v));
    }

    @IsTest
    static void genericExceptionBecomesInternalErrorWithoutItsMessage() {
        McpServer s = new McpServer('s', '1').tool(new McpTestKit.ModeTool('g', 'generic')).tool(new McpTestKit.ModeTool('n', 'null'));
        McpTestKit.Reply r = McpTestKit.modern(s, 'tools/call', call('g', null));
        Assert.areEqual(200, r.status);
        Assert.areEqual(-32603, r.code());
        Assert.areEqual('Internal error', r.message());
        Assert.isFalse(r.body.contains('secret'));
        Assert.areEqual('Internal error', McpTestKit.legacy(s, 'tools/call', call('n', null)).message());
    }

    @IsTest
    static void outputIsValidatedAgainstBuilderSchemas() {
        McpTool bad = new McpTestKit.ModeTool('bad', 'badStructured').output(McpSchema.obj().requiredProperty('echo', McpSchema.str()));
        McpTool missing = new McpTestKit.ModeTool('missing', 'noStructured').output(McpSchema.obj().property('echo', McpSchema.str()));
        McpTool errorResult = new McpTestKit.ModeTool('declared', 'errorResult').output(McpSchema.obj().requiredProperty('echo', McpSchema.str()));
        McpServer s = new McpServer('s', '1').tool(bad).tool(missing).tool(errorResult);
        McpTestKit.Reply badReply = McpTestKit.modern(s, 'tools/call', call('bad', null));
        Assert.areEqual(-32603, badReply.code());
        Assert.areEqual('Internal error', badReply.message());
        Assert.areEqual(-32603, McpTestKit.modern(s, 'tools/call', call('missing', null)).code());
        // an error result is exempt: it does not have to match the output schema
        Assert.areEqual(true, McpTestKit.modern(s, 'tools/call', call('declared', null)).result().get('isError'));
    }

    @IsTest
    static void skipOutputValidationTrustsTheDeveloper() {
        McpTool bad = new McpTestKit.ModeTool('bad', 'badStructured').output(McpSchema.obj().requiredProperty('echo', McpSchema.str()));
        McpTool missing = new McpTestKit.ModeTool('missing', 'noStructured').output(McpSchema.obj().property('echo', McpSchema.str()));
        McpServer s = new McpServer('s', '1').skipOutputValidation().tool(bad).tool(missing);
        Assert.areEqual(200, McpTestKit.modern(s, 'tools/call', call('bad', null)).status);
        Assert.isNull(McpTestKit.modern(s, 'tools/call', call('bad', null)).json.get('error'));
        Assert.isNull(McpTestKit.modern(s, 'tools/call', call('missing', null)).json.get('error'));
    }

    @IsTest
    static void rawOutputSchemasAreTrustedNotValidated() {
        McpTool raw = new McpTestKit.ModeTool('raw', 'badStructured').outputSchema(new Map<String, Object>{ 'type' => 'object', 'required' => new List<Object>{ 'zzz' } });
        Assert.isNull(McpTestKit.modern(new McpServer('s', '1').tool(raw), 'tools/call', call('raw', null)).json.get('error'));
    }

    @IsTest
    static void modernKeepsAnyStructuredValue() {
        McpServer s = new McpServer('s', '1').tool(new McpTestKit.ModeTool('arr', 'array')).tool(new McpTestKit.ModeTool('sc', 'scalar')).tool(new McpTestKit.ModeTool('rawarr', 'rawStructured'));
        McpTestKit.Reply arr = McpTestKit.modern(s, 'tools/call', call('arr', null));
        Assert.areEqual(new List<Object>{ 1, 2, 3 }, (List<Object>) arr.result().get('structuredContent'));
        Assert.areEqual('just a string', McpTestKit.modern(s, 'tools/call', call('sc', null)).result().get('structuredContent'));
        McpTestKit.Reply raw = McpTestKit.modern(s, 'tools/call', call('rawarr', null));
        Assert.areEqual(new List<Object>{ 'a' }, (List<Object>) raw.result().get('structuredContent'));
        Assert.areEqual(0, raw.items('content').size(), 'no text is generated for structuredContent() without structured()');
    }

    @IsTest
    static void legacyDropsNonObjectStructuredContentAndKeepsTheData() {
        McpServer s = new McpServer('s', '1').tool(new McpTestKit.ModeTool('arr', 'array')).tool(new McpTestKit.ModeTool('sc', 'scalar')).tool(new McpTestKit.ModeTool('rawarr', 'rawStructured'));
        McpTestKit.Reply arr = McpTestKit.legacy(s, 'tools/call', call('arr', null));
        Assert.isFalse(arr.result().containsKey('structuredContent'));
        Assert.areEqual('[1,2,3]', firstText(arr));
        McpTestKit.Reply sc = McpTestKit.legacy(s, 'tools/call', call('sc', null));
        Assert.isFalse(sc.result().containsKey('structuredContent'));
        Assert.areEqual('"just a string"', firstText(sc));
        // no generated text: the framework adds one so the data still reaches the client
        McpTestKit.Reply raw = McpTestKit.legacy(s, 'tools/call', call('rawarr', null));
        Assert.isFalse(raw.result().containsKey('structuredContent'));
        Assert.areEqual('["a"]', firstText(raw));
    }

    @IsTest
    static void legacyKeepsObjectStructuredContentWithoutModernFields() {
        McpTestKit.Reply r = McpTestKit.legacy(server(), 'tools/call', call('echo', new Map<String, Object>{ 'message' => 'hi' }));
        Assert.areEqual('hi', ((Map<String, Object>) r.result().get('structuredContent')).get('echo'));
        Assert.isFalse(r.result().containsKey('resultType'));
        Assert.isFalse(r.result().containsKey('_meta'));
    }

    @IsTest
    static void richContentAndResultMetaAreSerialized() {
        McpServer s = new McpServer('s', '1').tool(new McpTestKit.ModeTool('rich', 'rich'));
        McpTestKit.Reply r = McpTestKit.modern(s, 'tools/call', call('rich', null));
        Assert.areEqual(5, r.items('content').size());
        Assert.areEqual('v', ((Map<String, Object>) r.result().get('_meta')).get('k'));
        Assert.isNotNull(((Map<String, Object>) r.result().get('_meta')).get('io.modelcontextprotocol/serverInfo'));
    }

    @IsTest
    static void typedGettersConvertAndRejectMismatches() {
        // a raw schema: the framework leaves argument checking to the typed getters
        McpServer s = new McpServer('s', '1').tool(new McpTestKit.ModeTool('typed', 'typed').inputSchema(new Map<String, Object>{ 'type' => 'object' }));
        Map<String, Object> args = new Map<String, Object>{
            'i' => 7, 'l' => 9007199254740991L, 'd' => 1.25, 'b' => true, 'm' => new Map<String, Object>{ 'k' => 1 }, 'a' => new List<Object>{ 1 }, 's' => 'str'
        };
        McpTestKit.Reply r = McpTestKit.modern(s, 'tools/call', call('typed', args));
        Map<String, Object> out = (Map<String, Object>) r.result().get('structuredContent');
        Assert.areEqual(7, out.get('int'));
        Assert.areEqual(9007199254740991L, out.get('long'));
        Assert.areEqual(1.25, out.get('dec'));
        Assert.areEqual('str', out.get('str'));
        // integral decimal accepted as integer
        Assert.areEqual(3, ((Map<String, Object>) McpTestKit.modern(s, 'tools/call', call('typed', new Map<String, Object>{ 'i' => 3.0 })).result().get('structuredContent')).get('int'));
        for (String key : new List<String>{ 'i', 'l', 'd', 'b', 'm', 'a', 's' }) {
            Object wrong = key == 's' ? (Object) 5 : (Object) 'text';
            McpTestKit.Reply bad = McpTestKit.modern(s, 'tools/call', call('typed', new Map<String, Object>{ key => wrong }));
            Assert.areEqual(true, bad.result().get('isError'), key);
            Assert.isTrue(firstText(bad).startsWith('Argument "' + key + '" must be'), firstText(bad));
        }
        Assert.areEqual(true, McpTestKit.modern(s, 'tools/call', call('typed', new Map<String, Object>{ 'i' => 1.5 })).result().get('isError'));
        Assert.areEqual(true, McpTestKit.modern(s, 'tools/call', call('typed', new Map<String, Object>{ 'i' => 3000000000L })).result().get('isError'));
        Exception caught;
        try { McpRequest.forTool('t', new Map<String, Object>{ 'l' => Decimal.valueOf(10).pow(30) }).getLong('l'); } catch (McpException e) { caught = e; }
        Assert.areEqual('Argument "l" must be an integer', caught.getMessage());
    }

    @IsTest
    static void requestHelpersExposeContext() {
        McpRequest tool = McpRequest.forTool('t', new Map<String, Object>{ 'a' => 'b' });
        Assert.areEqual('tools/call', tool.method());
        Assert.areEqual('t', tool.name());
        Assert.areEqual('b', tool.requireString('a'));
        Assert.isNull(tool.getString('missing'));
        Assert.isFalse(tool.isLegacy());
        Assert.isNull(McpRequest.forTool('t', null).get('x'));
        Assert.areEqual(0, McpRequest.forTool('t', null).arguments().size());
        Exception caught;
        try { tool.requireString('missing'); } catch (McpException e) { caught = e; }
        Assert.areEqual('Argument "missing" is required', caught.getMessage());
        Assert.areEqual('prompts/get', McpRequest.forPrompt('p', new Map<String, String>{ 'x' => 'y' }).method());
        Assert.areEqual('y', McpRequest.forPrompt('p', new Map<String, String>{ 'x' => 'y' }).promptArguments().get('x'));
        Assert.areEqual(0, McpRequest.forPrompt('p', null).promptArguments().size());
        McpRequest res = McpRequest.forResource('acme://a/1', new Map<String, String>{ 'id' => '1' });
        Assert.areEqual('1', res.variable('id'));
        Assert.areEqual('acme://a/1', res.uri());
        Assert.areEqual(0, McpRequest.forResource('acme://a').variables().size());
    }

    @IsTest
    static void handlersSeeProtocolContext() {
        McpTestKit.Reply r = McpTestKit.modern(new McpServer('s', '1').tool(new ContextTool()), 'tools/call', call('ctx', null));
        Map<String, Object> out = (Map<String, Object>) r.result().get('structuredContent');
        Assert.areEqual('2026-07-28', out.get('version'));
        Assert.areEqual(false, out.get('legacy'));
        Assert.areEqual('test-client', out.get('client'));
        Assert.areEqual('tools/call', out.get('method'));
        McpTestKit.Reply l = McpTestKit.legacy(new McpServer('s', '1').tool(new ContextTool()), 'tools/call', call('ctx', null));
        Map<String, Object> lo = (Map<String, Object>) l.result().get('structuredContent');
        Assert.areEqual('2025-11-25', lo.get('version'));
        Assert.areEqual(true, lo.get('legacy'));
        Assert.isNull(lo.get('client'));
    }

    public class ContextTool extends McpTool {
        public ContextTool() { super('ctx'); }
        public override McpToolResult execute(McpRequest request) {
            return McpToolResult.structured(new Map<String, Object>{
                'version' => request.protocolVersion(), 'legacy' => request.isLegacy(), 'client' => request.clientInfo().get('name'),
                'method' => request.method(), 'caps' => request.clientCapabilities().size(), 'meta' => request.meta().size()
            });
        }
    }
}
