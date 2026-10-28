@IsTest
private class McpRuntimeTest {
    private static final String ID_BODY_PREFIX = '{"jsonrpc":"2.0","id":';

    private static McpServer server() {
        return McpTestKit.fullServer();
    }

    private static Map<String, String> bareHeaders() {
        return new Map<String, String>();
    }

    // ---------------------------------------------------------------- steps 1 to 3

    @IsTest
    static void nonPostIsMethodNotAllowed() {
        McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'GET', bareHeaders(), null);
        Assert.areEqual(405, r.status);
        Assert.areEqual('POST', r.headers.get('Allow'));
        Assert.isNull(r.body);
    }

    @IsTest
    static void originWithoutAllowlistIsForbidden() {
        McpTestKit.Reply r = McpTestKit.post(server(), new Map<String, String>{ 'Origin' => 'https://evil.example' },
            McpTestKit.message(1, 'initialize', null));
        Assert.areEqual(403, r.status);
        Assert.areEqual(-32600, r.code());
        Assert.areEqual('Origin not allowed', r.message());
        Assert.isFalse(r.json.containsKey('id'));
    }

    @IsTest
    static void originWithAllowlistIsExactMatch() {
        McpServer s = server().allowOrigin('https://app.example');
        Assert.areEqual(403, McpTestKit.post(s, new Map<String, String>{ 'origin' => 'https://app.example.evil' },
            McpTestKit.message(1, 'initialize', null)).status);
        Assert.areEqual(403, McpTestKit.post(s, new Map<String, String>{ 'origin' => 'HTTPS://APP.EXAMPLE' },
            McpTestKit.message(1, 'initialize', null)).status);
        Assert.areEqual(200, McpTestKit.post(s, new Map<String, String>{ 'ORIGIN' => 'https://app.example' },
            McpTestKit.message(1, 'initialize', null)).status);
        Assert.areEqual(200, McpTestKit.post(s, bareHeaders(), McpTestKit.message(1, 'initialize', null)).status);
    }

    @IsTest
    static void oversizedBodyIsRejectedBeforeParsing() {
        McpServer s = server().maxRequestBytes(1024);
        String body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"x":"' + 'a'.repeat(1100) + '"}}';
        McpTestKit.Reply r = McpTestKit.sendRaw(s, 'POST', bareHeaders(), body);
        Assert.areEqual(413, r.status);
        Assert.areEqual(-32600, r.code());
        Assert.areEqual('Request body too large', r.message());
    }

    @IsTest
    static void defaultRequestLimitIs256KiB() {
        String body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"x":"' + 'a'.repeat(262144) + '"}}';
        Assert.areEqual(413, McpTestKit.sendRaw(server(), 'POST', bareHeaders(), body).status);
    }

    // ---------------------------------------------------------------- steps 4 to 7

    @IsTest
    static void invalidJsonIsParseError() {
        for (String body : new List<String>{ 'not json', '', '{"jsonrpc":', '{"id":123456789012345678901}' }) {
            McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), body);
            Assert.areEqual(400, r.status, body);
            Assert.areEqual(-32700, r.code(), body);
        }
        Assert.areEqual(-32700, McpTestKit.sendRaw(server(), 'POST', bareHeaders(), null).code());
    }

    @IsTest
    static void batchAndNonObjectBodiesAreInvalidRequests() {
        McpTestKit.Reply batch = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), '[{"jsonrpc":"2.0","id":1,"method":"ping"}]');
        Assert.areEqual(400, batch.status);
        Assert.areEqual(-32600, batch.code());
        Assert.areEqual('Batch requests are not supported', batch.message());
        for (String body : new List<String>{ '"text"', '5', 'null', 'true' }) {
            McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), body);
            Assert.areEqual(400, r.status, body);
            Assert.areEqual(-32600, r.code(), body);
        }
    }

    @IsTest
    static void deeplyNestedBodyIsRejectedByTheBoundedWalk() {
        String body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":' + '['.repeat(60) + ']'.repeat(60) + '}';
        McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), body);
        Assert.areEqual(400, r.status);
        Assert.areEqual('Request structure too large', r.message());
    }

    @IsTest
    static void bodyWithTooManyNodesIsRejectedByTheBoundedWalk() {
        String body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"a":[' + '0,'.repeat(9000) + '0],"b":[' + '0,'.repeat(9000)
            + '0],"c":[' + '0,'.repeat(9000) + '0],"d":[' + '0,'.repeat(9000) + '0],"e":[' + '0,'.repeat(9000) + '0],"f":[' + '0,'.repeat(9000) + '0]}}';
        Assert.isTrue(body.length() < 262144);
        McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), body);
        Assert.areEqual(400, r.status);
        Assert.areEqual('Request structure too large', r.message());
    }

    @IsTest
    static void collectionOverTheLimitIsRejected() {
        String body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"a":[' + '0,'.repeat(10001) + '0]}}';
        Assert.areEqual('Request structure too large', McpTestKit.sendRaw(server(), 'POST', bareHeaders(), body).message());
    }

    @IsTest
    static void invalidEnvelopeFieldsAreInvalidRequests() {
        McpTestKit.Reply wrongVersion = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), '{"jsonrpc":"1.0","id":7,"method":"ping"}');
        Assert.areEqual(400, wrongVersion.status);
        Assert.areEqual(-32600, wrongVersion.code());
        Assert.areEqual(7, wrongVersion.json.get('id'));
        McpTestKit.Reply noMethod = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), '{"jsonrpc":"2.0","id":"abc"}');
        Assert.areEqual(-32600, noMethod.code());
        Assert.areEqual('abc', noMethod.json.get('id'));
        Assert.areEqual(-32600, McpTestKit.sendRaw(server(), 'POST', bareHeaders(), '{"jsonrpc":"2.0","method":5}').code());
    }

    @IsTest
    static void badIdsAreRejectedWithoutEcho() {
        for (String id : new List<String>{ '1.5', 'true', 'false', 'null', '{}', '[]', '{"a":1}', '1e400' }) {
            McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), ID_BODY_PREFIX + id + ',"method":"initialize"}');
            Assert.areEqual(400, r.status, id);
            Assert.areEqual(-32600, r.code(), id);
            Assert.isFalse(r.json.containsKey('id'), id);
        }
        Assert.areEqual(-32700, McpTestKit.sendRaw(server(), 'POST', bareHeaders(), ID_BODY_PREFIX + '9223372036854775808,"method":"initialize"}').code());
    }

    @IsTest
    static void goodIdsAreEchoedExactly() {
        Map<String, String> expectedWire = new Map<String, String>{
            '9007199254740991' => '9007199254740991', '9223372036854775807' => '9223372036854775807',
            '5.0' => '5', '1E+2' => '100', '-3' => '-3', '0' => '0', '"str-id"' => '"str-id"', '3000000000' => '3000000000'
        };
        for (String id : expectedWire.keySet()) {
            McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), ID_BODY_PREFIX + id + ',"method":"initialize"}');
            Assert.areEqual(200, r.status, id);
            Assert.isTrue(r.body.contains('"id":' + expectedWire.get(id) + ','), id + ' -> ' + r.body.left(60));
        }
    }

    @IsTest
    static void notificationsGet202WithoutBodyOrHeaderChecks() {
        McpTestKit.Reply r = McpTestKit.post(server(), bareHeaders(), McpTestKit.message(null, 'notifications/initialized', null));
        Assert.areEqual(202, r.status);
        Assert.isNull(r.body);
        McpTestKit.Reply unknown = McpTestKit.post(server(), bareHeaders(), McpTestKit.message(null, 'notifications/whatever', new Map<String, Object>{ 'a' => 1 }));
        Assert.areEqual(202, unknown.status);
        Assert.areEqual(400, McpTestKit.sendRaw(server(), 'POST', bareHeaders(), '{"jsonrpc":"2.0","method":7}').status);
    }

    // ---------------------------------------------------------------- steps 8 and 9

    @IsTest
    static void initializeNeedsNoHeadersAndAlwaysReturnsTheLegacyVersion() {
        for (String requested : new List<String>{ '2025-11-25', '2025-06-18', '2024-11-05', '2099-01-01' }) {
            McpTestKit.Reply r = McpTestKit.post(server(), bareHeaders(), McpTestKit.message(1, 'initialize', new Map<String, Object>{
                'protocolVersion' => requested, 'capabilities' => new Map<String, Object>(),
                'clientInfo' => new Map<String, Object>{ 'name' => 'c', 'version' => '1' }
            }));
            Assert.areEqual(200, r.status);
            Assert.areEqual('2025-11-25', r.result().get('protocolVersion'), requested);
        }
    }

    @IsTest
    static void missingVersionHeaderIsHeaderMismatch() {
        McpTestKit.Reply r = McpTestKit.post(server(), bareHeaders(), McpTestKit.message(1, 'tools/list', null));
        Assert.areEqual(400, r.status);
        Assert.areEqual(-32020, r.code());
        Assert.areEqual('Missing MCP-Protocol-Version header', r.message());
        Assert.areEqual(1, r.json.get('id'));
    }

    @IsTest
    static void metaVersionWithoutHeaderIsRejected() {
        McpTestKit.Reply r = McpTestKit.post(server(), new Map<String, String>{ 'Mcp-Method' => 'tools/list' },
            McpTestKit.message(1, 'tools/list', McpTestKit.modernParams(null)));
        Assert.areEqual(400, r.status);
        Assert.areEqual(-32020, r.code());
    }

    @IsTest
    static void headerAndMetaVersionMustAgree() {
        Map<String, String> h = McpTestKit.modernHeaders('tools/list', null);
        h.put('MCP-Protocol-Version', McpTestKit.LEGACY);
        McpTestKit.Reply r = McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/list', McpTestKit.modernParams(null)));
        Assert.areEqual(400, r.status);
        Assert.areEqual(-32020, r.code());
    }

    @IsTest
    static void unsupportedVersionListsSupportedOnes() {
        for (String version : new List<String>{ '2099-01-01', '2025-06-18', 'garbage' }) {
            McpTestKit.Reply byHeader = McpTestKit.post(server(), new Map<String, String>{ 'MCP-Protocol-Version' => version },
                McpTestKit.message(1, 'tools/list', null));
            Assert.areEqual(400, byHeader.status, version);
            Assert.areEqual(-32022, byHeader.code(), version);
            Map<String, Object> data = (Map<String, Object>) byHeader.error().get('data');
            Assert.areEqual(new List<Object>{ '2026-07-28', '2025-11-25' }, (List<Object>) data.get('supported'));
            Assert.areEqual(version, data.get('requested'));
        }
        Map<String, Object> params = McpTestKit.modernParams(null);
        ((Map<String, Object>) params.get('_meta')).put(McpTestKit.META_VERSION, '2099-01-01');
        McpTestKit.Reply both = McpTestKit.post(server(), new Map<String, String>{ 'MCP-Protocol-Version' => '2099-01-01', 'Mcp-Method' => 'tools/list' },
            McpTestKit.message(1, 'tools/list', params));
        Assert.areEqual(-32022, both.code());
    }

    @IsTest
    static void legacyRequestsNeedOnlyTheVersionHeader() {
        McpTestKit.Reply r = McpTestKit.legacy(server(), 'tools/list', null);
        Assert.areEqual(200, r.status);
        Assert.isFalse(r.result().containsKey('resultType'));
    }

    @IsTest
    static void legacyVersionInMetaIsServedAsLegacy() {
        Map<String, Object> params = McpTestKit.modernParams(null);
        ((Map<String, Object>) params.get('_meta')).put(McpTestKit.META_VERSION, McpTestKit.LEGACY);
        McpTestKit.Reply r = McpTestKit.post(server(), new Map<String, String>{ 'MCP-Protocol-Version' => McpTestKit.LEGACY },
            McpTestKit.message(1, 'tools/list', params));
        Assert.areEqual(200, r.status);
        Assert.isFalse(r.result().containsKey('resultType'));
        Assert.isFalse(r.result().containsKey('ttlMs'));
        Assert.isFalse(r.result().containsKey('_meta'));
    }

    // ---------------------------------------------------------------- step 10

    @IsTest
    static void modernRequestNeedsBothRequiredMetaFields() {
        Map<String, String> h = McpTestKit.modernHeaders('tools/list', null);
        McpTestKit.Reply noParams = McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/list', null));
        Assert.areEqual(400, noParams.status);
        Assert.areEqual(-32602, noParams.code());
        Assert.areEqual('Missing required _meta field: io.modelcontextprotocol/protocolVersion', noParams.message());

        McpTestKit.Reply noMeta = McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/list', new Map<String, Object>()));
        Assert.areEqual(-32602, noMeta.code());

        // The header alone never substitutes for the _meta version.
        McpTestKit.Reply versionOnlyInHeader = McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/list',
            new Map<String, Object>{ '_meta' => new Map<String, Object>{ McpTestKit.META_CAPS => new Map<String, Object>() } }));
        Assert.areEqual(400, versionOnlyInHeader.status);
        Assert.areEqual('Missing required _meta field: io.modelcontextprotocol/protocolVersion', versionOnlyInHeader.message());

        McpTestKit.Reply noCaps = McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/list',
            new Map<String, Object>{ '_meta' => new Map<String, Object>{ McpTestKit.META_VERSION => McpTestKit.MODERN } }));
        Assert.areEqual(400, noCaps.status);
        Assert.areEqual('Missing required _meta field: io.modelcontextprotocol/clientCapabilities', noCaps.message());

        McpTestKit.Reply badCaps = McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/list',
            new Map<String, Object>{ '_meta' => new Map<String, Object>{ McpTestKit.META_VERSION => McpTestKit.MODERN, McpTestKit.META_CAPS => 'x' } }));
        Assert.areEqual(-32602, badCaps.code());

        McpTestKit.Reply paramsNotObject = McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/list', null));
        paramsNotObject = McpTestKit.sendRaw(server(), 'POST', h, '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":[1]}');
        Assert.areEqual(-32602, paramsNotObject.code());
    }

    @IsTest
    static void mcpMethodHeaderIsRequiredAndMustMatch() {
        Map<String, String> missing = McpTestKit.modernHeaders('tools/list', null);
        missing.remove('Mcp-Method');
        McpTestKit.Reply a = McpTestKit.post(server(), missing, McpTestKit.message(1, 'tools/list', McpTestKit.modernParams(null)));
        Assert.areEqual(400, a.status);
        Assert.areEqual(-32020, a.code());
        Map<String, String> wrong = McpTestKit.modernHeaders('tools/list', null);
        wrong.put('Mcp-Method', 'prompts/list');
        McpTestKit.Reply b = McpTestKit.post(server(), wrong, McpTestKit.message(1, 'tools/list', McpTestKit.modernParams(null)));
        Assert.areEqual(-32020, b.code());
    }

    @IsTest
    static void nameParametersMustBeStrings() {
        Map<String, Object> p = McpTestKit.modernParams(new Map<String, Object>{ 'name' => 5 });
        McpTestKit.Reply r = McpTestKit.post(server(), McpTestKit.modernHeaders('tools/call', null), McpTestKit.message(1, 'tools/call', p));
        Assert.areEqual(400, r.status);
        Assert.areEqual(-32602, r.code());
        Map<String, Object> q = McpTestKit.modernParams(null);
        McpTestKit.Reply s = McpTestKit.post(server(), McpTestKit.modernHeaders('resources/read', null), McpTestKit.message(1, 'resources/read', q));
        Assert.areEqual(400, s.status);
        Assert.areEqual(-32602, s.code());
    }

    @IsTest
    static void mcpNameHeaderPlainBase64MismatchAndMissing() {
        Map<String, Object> params = new Map<String, Object>{ 'name' => 'echo', 'arguments' => new Map<String, Object>{ 'message' => 'hi' } };
        // plain
        Assert.areEqual(200, McpTestKit.modern(server(), 'tools/call', params).status);
        // base64 form of an ASCII value is accepted
        Map<String, String> encoded = McpTestKit.modernHeaders('tools/call', params);
        encoded.put('Mcp-Name', '=?base64?' + EncodingUtil.base64Encode(Blob.valueOf('echo')) + '?=');
        Assert.areEqual(200, McpTestKit.post(server(), encoded, McpTestKit.message(1, 'tools/call', McpTestKit.modernParams(params))).status);
        // missing
        Map<String, String> missing = McpTestKit.modernHeaders('tools/call', params);
        missing.remove('Mcp-Name');
        McpTestKit.Reply m = McpTestKit.post(server(), missing, McpTestKit.message(1, 'tools/call', McpTestKit.modernParams(params)));
        Assert.areEqual(400, m.status);
        Assert.areEqual(-32020, m.code());
        // mismatch
        Map<String, String> wrong = McpTestKit.modernHeaders('tools/call', params);
        wrong.put('Mcp-Name', 'other');
        Assert.areEqual(-32020, McpTestKit.post(server(), wrong, McpTestKit.message(1, 'tools/call', McpTestKit.modernParams(params))).code());
        // bad base64 variants, plain non-ASCII, control characters
        for (String bad : new List<String>{ '=?base64?!!!!?=', '=?base64?abc?=', '=?base64??=', '=?base64?/w==?=', 'café', 'echo\u0001' }) {
            Map<String, String> h = McpTestKit.modernHeaders('tools/call', params);
            h.put('Mcp-Name', bad);
            McpTestKit.Reply r = McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/call', McpTestKit.modernParams(params)));
            Assert.areEqual(400, r.status, bad);
            Assert.areEqual(-32020, r.code(), bad);
        }
    }

    @IsTest
    static void mcpNameHeaderDecodesUtf8Base64ForResourceUris() {
        String uri = 'acme://account/Zoë';
        Map<String, Object> params = new Map<String, Object>{ 'uri' => uri };
        Map<String, String> h = McpTestKit.modernHeaders('resources/read', params);
        h.put('Mcp-Name', '=?base64?' + EncodingUtil.base64Encode(Blob.valueOf(uri)) + '?=');
        McpTestKit.Reply r = McpTestKit.post(server(), h, McpTestKit.message(1, 'resources/read', McpTestKit.modernParams(params)));
        Assert.areEqual(200, r.status);
        Assert.areEqual('account Zoë', ((Map<String, Object>) r.items('contents')[0]).get('text'));
    }

    // ---------------------------------------------------------------- step 11

    @IsTest
    static void unknownMethodIs404InModernAnd200InLegacy() {
        McpTestKit.Reply modern = McpTestKit.modern(server(), 'frobnicate', null);
        Assert.areEqual(404, modern.status);
        Assert.areEqual(-32601, modern.code());
        McpTestKit.Reply legacy = McpTestKit.legacy(server(), 'frobnicate', null);
        Assert.areEqual(200, legacy.status);
        Assert.areEqual(-32601, legacy.code());
    }

    @IsTest
    static void notImplementedMethodsAreMethodNotFound() {
        for (String method : new List<String>{ 'resources/subscribe', 'resources/unsubscribe', 'logging/setLevel', 'subscriptions/listen',
                'sampling/createMessage', 'tasks/get', 'resources/templates/call', 'notifications/cancelled' }) {
            Assert.areEqual(404, McpTestKit.modern(server(), method, null).status, method);
            Assert.areEqual(-32601, McpTestKit.legacy(server(), method, null).code(), method);
        }
    }

    @IsTest
    static void eraSpecificMethodsAreGated() {
        Assert.areEqual(-32601, McpTestKit.legacy(server(), 'server/discover', null).code());
        McpTestKit.Reply ping = McpTestKit.modern(server(), 'ping', null);
        Assert.areEqual(404, ping.status);
        Assert.areEqual(-32601, ping.code());
    }

    // ---------------------------------------------------------------- initialize and explicit versions

    @IsTest
    static void initializeIsLegacyOnlyWhenNoVersionIsNamed() {
        McpTestKit.Reply bare = McpTestKit.post(server(), bareHeaders(), McpTestKit.message(1, 'initialize', null));
        Assert.areEqual(200, bare.status);
        Assert.areEqual('2025-11-25', bare.result().get('protocolVersion'));
        Assert.isFalse(bare.result().containsKey('resultType'));
        McpTestKit.Reply legacyHeader = McpTestKit.post(server(), new Map<String, String>{ 'MCP-Protocol-Version' => McpTestKit.LEGACY }, McpTestKit.message(1, 'initialize', null));
        Assert.areEqual(200, legacyHeader.status);
        Assert.areEqual('2025-11-25', legacyHeader.result().get('protocolVersion'));
    }

    @IsTest
    static void explicitModernInitializeIsValidatedThenMethodNotFound() {
        McpTestKit.Reply modern = McpTestKit.modern(server(), 'initialize', null);
        Assert.areEqual(404, modern.status);
        Assert.areEqual(-32601, modern.code());
        // header only: the modern request is validated, so the missing _meta is reported first
        McpTestKit.Reply headerOnly = McpTestKit.post(server(), McpTestKit.modernHeaders('initialize', null), McpTestKit.message(1, 'initialize', null));
        Assert.areEqual(400, headerOnly.status);
        Assert.areEqual(-32602, headerOnly.code());
        // _meta only: no header
        McpTestKit.Reply metaOnly = McpTestKit.post(server(), new Map<String, String>{ 'Mcp-Method' => 'initialize' }, McpTestKit.message(1, 'initialize', McpTestKit.modernParams(null)));
        Assert.areEqual(400, metaOnly.status);
        Assert.areEqual(-32020, metaOnly.code());
        // modern with a wrong Mcp-Method header
        Map<String, String> wrongMethod = McpTestKit.modernHeaders('initialize', null);
        wrongMethod.put('Mcp-Method', 'tools/list');
        Assert.areEqual(-32020, McpTestKit.post(server(), wrongMethod, McpTestKit.message(1, 'initialize', McpTestKit.modernParams(null))).code());
    }

    @IsTest
    static void unknownVersionCannotBypassValidationThroughInitialize() {
        for (String version : new List<String>{ '2099-01-01', '2025-06-18', 'garbage' }) {
            McpTestKit.Reply byHeader = McpTestKit.post(server(), new Map<String, String>{ 'MCP-Protocol-Version' => version }, McpTestKit.message(1, 'initialize', null));
            Assert.areEqual(400, byHeader.status, version);
            Assert.areEqual(-32022, byHeader.code(), version);
            Map<String, Object> params = McpTestKit.modernParams(null);
            ((Map<String, Object>) params.get('_meta')).put(McpTestKit.META_VERSION, version);
            McpTestKit.Reply byMeta = McpTestKit.post(server(), new Map<String, String>{ 'MCP-Protocol-Version' => version, 'Mcp-Method' => 'initialize' },
                McpTestKit.message(1, 'initialize', params));
            Assert.areEqual(-32022, byMeta.code(), version);
        }
        Map<String, Object> mismatch = McpTestKit.modernParams(null);
        Assert.areEqual(-32020, McpTestKit.post(server(), new Map<String, String>{ 'MCP-Protocol-Version' => McpTestKit.LEGACY, 'Mcp-Method' => 'initialize' },
            McpTestKit.message(1, 'initialize', mismatch)).code());
        Assert.areEqual('x'.repeat(128), ((Map<String, Object>) McpTestKit.post(server(), new Map<String, String>{ 'MCP-Protocol-Version' => 'x'.repeat(500) },
            McpTestKit.message(1, 'initialize', null)).error().get('data')).get('requested'), 'the echoed version is clipped');
    }

    @IsTest
    static void capabilityGatesHideMethodsOfMissingFeatures() {
        McpServer empty = new McpServer('empty', '1');
        for (String method : new List<String>{ 'tools/list', 'tools/call', 'resources/list', 'resources/read', 'resources/templates/list',
                'prompts/list', 'prompts/get', 'completion/complete' }) {
            Map<String, Object> params = method == 'resources/read' ? new Map<String, Object>{ 'uri' => 'x://y' }
                : (method == 'tools/call' || method == 'prompts/get' ? new Map<String, Object>{ 'name' => 'x' } : null);
            Assert.areEqual(404, McpTestKit.modern(empty, method, params).status, method);
            Assert.areEqual(-32601, McpTestKit.legacy(empty, method, params).code(), method);
        }
        Assert.areEqual(200, McpTestKit.modern(empty, 'server/discover', null).status);
        Assert.areEqual(0, ((Map<String, Object>) McpTestKit.modern(empty, 'server/discover', null).result().get('capabilities')).size());

        McpServer toolsOnly = new McpServer('t', '1').tool(new McpTestKit.EchoTool());
        Assert.areEqual(404, McpTestKit.modern(toolsOnly, 'resources/list', null).status);
        Assert.areEqual(404, McpTestKit.modern(toolsOnly, 'completion/complete', null).status);
        McpServer templateOnly = new McpServer('t', '1').resourceTemplate(new McpTestKit.AccountTemplate());
        Assert.areEqual(200, McpTestKit.modern(templateOnly, 'resources/templates/list', null).status);
        Assert.areEqual(404, McpTestKit.modern(templateOnly, 'prompts/list', null).status);
        Assert.areNotEqual(404, McpTestKit.modern(templateOnly, 'completion/complete', null).status);
        McpServer promptOnly = new McpServer('t', '1').prompt(new McpTestKit.GreetPrompt());
        Assert.areNotEqual(404, McpTestKit.modern(promptOnly, 'completion/complete', null).status);
    }

    @IsTest
    static void headerCasingDoesNotMatter() {
        Map<String, String> h = new Map<String, String>{ 'mcp-protocol-version' => McpTestKit.MODERN, 'MCP-METHOD' => 'tools/list' };
        Assert.areEqual(200, McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/list', McpTestKit.modernParams(null))).status);
    }

    // ---------------------------------------------------------------- case sensitivity

    @IsTest
    static void methodHeaderValueIsCaseSensitive() {
        for (String variant : new List<String>{ 'TOOLS/LIST', 'Tools/List', 'tools/LIST' }) {
            Map<String, String> h = McpTestKit.modernHeaders('tools/list', null);
            h.put('Mcp-Method', variant);
            McpTestKit.Reply r = McpTestKit.post(server(), h, McpTestKit.message(1, 'tools/list', McpTestKit.modernParams(null)));
            Assert.areEqual(400, r.status, variant);
            Assert.areEqual(-32020, r.code(), variant);
        }
        Map<String, String> exact = McpTestKit.modernHeaders('tools/list', null);
        Assert.areEqual(200, McpTestKit.post(server(), exact, McpTestKit.message(1, 'tools/list', McpTestKit.modernParams(null))).status);
    }

    @IsTest
    static void nameHeaderValueIsCaseSensitive() {
        Map<String, Object> params = new Map<String, Object>{ 'name' => 'echo', 'arguments' => new Map<String, Object>{ 'message' => 'hi' } };
        Map<String, String> upper = McpTestKit.modernHeaders('tools/call', params);
        upper.put('Mcp-Name', 'ECHO');
        McpTestKit.Reply r = McpTestKit.post(server(), upper, McpTestKit.message(1, 'tools/call', McpTestKit.modernParams(params)));
        Assert.areEqual(400, r.status);
        Assert.areEqual(-32020, r.code());
        Map<String, String> encoded = McpTestKit.modernHeaders('tools/call', params);
        encoded.put('Mcp-Name', '=?base64?' + EncodingUtil.base64Encode(Blob.valueOf('Echo')) + '?=');
        Assert.areEqual(-32020, McpTestKit.post(server(), encoded, McpTestKit.message(1, 'tools/call', McpTestKit.modernParams(params))).code());
        Map<String, Object> uriParams = new Map<String, Object>{ 'uri' => 'acme://account/abc' };
        Map<String, String> uriUpper = McpTestKit.modernHeaders('resources/read', uriParams);
        uriUpper.put('Mcp-Name', 'acme://account/ABC');
        Assert.areEqual(-32020, McpTestKit.post(server(), uriUpper, McpTestKit.message(1, 'resources/read', McpTestKit.modernParams(uriParams))).code());
        Assert.areEqual(200, McpTestKit.modern(server(), 'tools/call', params).status, 'the exact value passes');
        Map<String, String> lowerName = McpTestKit.modernHeaders('tools/call', params);
        lowerName.remove('Mcp-Name');
        lowerName.put('mcp-name', 'echo');
        Assert.areEqual(200, McpTestKit.post(server(), lowerName, McpTestKit.message(1, 'tools/call', McpTestKit.modernParams(params))).status, 'header names stay case-insensitive');
    }

    @IsTest
    static void bodyMethodIsCaseSensitive() {
        for (String variant : new List<String>{ 'Tools/List', 'TOOLS/LIST', 'tools/List', 'TOOLS/CALL', 'Server/Discover', 'PROMPTS/GET', 'Resources/Read' }) {
            Map<String, String> h = McpTestKit.modernHeaders(variant, null);
            McpTestKit.Reply modern = McpTestKit.post(server(), h, McpTestKit.message(1, variant, McpTestKit.modernParams(null)));
            Assert.areEqual(404, modern.status, variant);
            Assert.areEqual(-32601, modern.code(), variant);
            McpTestKit.Reply legacy = McpTestKit.legacy(server(), variant, null);
            Assert.areEqual(200, legacy.status, variant);
            Assert.areEqual(-32601, legacy.code(), variant);
        }
        McpTestKit.Reply init = McpTestKit.post(server(), bareHeaders(), McpTestKit.message(1, 'INITIALIZE', null));
        Assert.areEqual(400, init.status, 'INITIALIZE is not the initialize method, so it needs a version');
        Assert.areEqual(-32601, McpTestKit.legacy(server(), 'Ping', null).code());
    }

    @IsTest
    static void httpMethodAndCompletionRefTypeAreCaseSensitive() {
        Assert.areEqual(405, McpTestKit.sendRaw(server(), 'post', bareHeaders(), '{"jsonrpc":"2.0","id":1,"method":"initialize"}').status);
        Map<String, Object> params = new Map<String, Object>{
            'ref' => new Map<String, Object>{ 'type' => 'REF/PROMPT', 'name' => 'greet' },
            'argument' => new Map<String, Object>{ 'name' => 'name', 'value' => 'A' }
        };
        Assert.areEqual(-32602, McpTestKit.modern(server(), 'completion/complete', params).code());
        ((Map<String, Object>) params.get('ref')).put('type', 'ref/prompt');
        Assert.areEqual(200, McpTestKit.modern(server(), 'completion/complete', params).status);
    }

    // ---------------------------------------------------------------- hostile nesting (before the parser)

    private static String bodyWithParams(String paramsJson) {
        return '{"jsonrpc":"2.0","id":1,"method":"initialize","params":' + paramsJson + '}';
    }

    private static Object nested(Integer levels) {
        Object value = 'leaf';
        for (Integer i = 0; i < levels; i++) { value = new List<Object>{ value }; }
        return value;
    }

    @IsTest
    static void nestingJustWithinTheLimitIsServed() {
        // the root object is level 1, so params may hold 31 more levels
        McpTestKit.Reply ok = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), bodyWithParams('['.repeat(31) + ']'.repeat(31)));
        Assert.areEqual(200, ok.status);
        McpTestKit.Reply over = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), bodyWithParams('['.repeat(32) + ']'.repeat(32)));
        Assert.areEqual(400, over.status);
        Assert.areEqual(-32600, over.code());
        Assert.areEqual('Request structure too large', over.message());
        Assert.isFalse(over.json.containsKey('id'), 'rejected before the parser, so the id is unknown');
    }

    @IsTest
    static void aSmallBodyNestedThousandsOfLevelsIsRejectedWithoutParsing() {
        // 5 KB, 2,500 levels: the parser accepts it, an instanceof on the result overflows the stack
        String body = bodyWithParams('['.repeat(2500) + ']'.repeat(2500));
        Assert.isTrue(body.length() < 6000);
        Integer cpuBefore = Limits.getCpuTime();
        McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), body);
        Assert.areEqual(400, r.status);
        Assert.areEqual(-32600, r.code());
        Assert.areEqual('Request structure too large', r.message());
        Assert.isTrue(Limits.getCpuTime() - cpuBefore < 200, 'cpu ms ' + (Limits.getCpuTime() - cpuBefore));
    }

    @IsTest
    static void aMaximumSizeBodyOfOpeningBracketsIsRejectedCheaply() {
        String body = bodyWithParams('['.repeat(119900) + ']'.repeat(119900));
        Assert.isTrue(body.length() < 262144 && body.length() > 239000);
        Integer cpuBefore = Limits.getCpuTime();
        Integer heapBefore = Limits.getHeapSize();
        McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), body);
        Assert.areEqual(400, r.status);
        Assert.areEqual(-32600, r.code());
        Assert.isTrue(Limits.getCpuTime() - cpuBefore < 500, 'cpu ms ' + (Limits.getCpuTime() - cpuBefore));
        Assert.isTrue(Limits.getHeapSize() - heapBefore < 1200000, 'heap bytes ' + (Limits.getHeapSize() - heapBefore));
        String objects = bodyWithParams('{"a":'.repeat(40000) + '1' + '}'.repeat(40000));
        Assert.areEqual(-32600, McpTestKit.sendRaw(server(), 'POST', bareHeaders(), objects).code());
    }

    @IsTest
    static void bracketsAndEscapesInsideStringsDoNotCountAsNesting() {
        String brackets = '[{'.repeat(100) + ']}'.repeat(100);
        Map<String, Object> params = new Map<String, Object>{
            'a' => brackets, 'b' => 'say "hi" ' + '['.repeat(60) + ' "end"', 'c' => '\\', 'many' => manyEmptyMaps(40), 'deep' => nested(29)
        };
        McpTestKit.Reply ok = McpTestKit.legacy(server(), 'ping', params);
        Assert.areEqual(200, ok.status);
        Assert.isNull(ok.json.get('error'));
        // a trailing backslash in a string must not hide the real nesting that follows it
        Map<String, Object> hidden = new Map<String, Object>{ 'c' => '\\', 's' => ']'.repeat(100), 'many' => manyEmptyMaps(40), 'deep' => nested(31) };
        McpTestKit.Reply rejected = McpTestKit.legacy(server(), 'ping', hidden);
        Assert.areEqual(400, rejected.status);
        Assert.areEqual('Request structure too large', rejected.message());
    }

    private static List<Object> manyEmptyMaps(Integer count) {
        List<Object> values = new List<Object>();
        for (Integer i = 0; i < count; i++) { values.add(new Map<String, Object>()); }
        return values;
    }

    @IsTest
    static void malformedBodiesStillGetTheParseError() {
        List<String> bodies = new List<String>{
            '{"jsonrpc":"2.0","id":1,"method":"ping","params":{"a":[[[',
            '{"a":' + '[1],'.repeat(40) + '"unterminated',
            ']'.repeat(50) + '[]'.repeat(20) + '{}'.repeat(20),
            '{"a":"' + '['.repeat(100),
            '{' + '"a":{},'.repeat(40)
        };
        for (String body : bodies) {
            McpTestKit.Reply r = McpTestKit.sendRaw(server(), 'POST', bareHeaders(), body);
            Assert.areEqual(400, r.status, body.left(30));
            Assert.areEqual(-32700, r.code(), body.left(30));
        }
    }

    @IsTest
    static void walkDepthStaysTheSingleSourceOfTheNestingLimit() {
        Assert.areEqual(32, McpWire.WALK_MAX_DEPTH);
        Map<String, Object> deepOk = new Map<String, Object>{ 'deep' => nested(29) };
        Assert.areEqual(200, McpTestKit.legacy(server(), 'ping', deepOk).status);
        Assert.areEqual(400, McpTestKit.legacy(server(), 'ping', new Map<String, Object>{ 'deep' => nested(31) }).status);
    }

    // ---------------------------------------------------------------- governor behaviour

    @IsTest
    static void frameworkUsesNoSoqlDmlOrCalloutsAndStaysCheap() {
        McpServer s = McpTestKit.fullServer();
        Integer heapBefore = Limits.getHeapSize();
        Integer cpuBefore = Limits.getCpuTime();
        McpTestKit.modern(s, 'server/discover', null);
        McpTestKit.modern(s, 'tools/list', null);
        McpTestKit.modern(s, 'tools/call', new Map<String, Object>{ 'name' => 'echo', 'arguments' => new Map<String, Object>{ 'message' => 'hi' } });
        McpTestKit.modern(s, 'resources/read', new Map<String, Object>{ 'uri' => 'acme://account/42' });
        McpTestKit.modern(s, 'prompts/get', new Map<String, Object>{ 'name' => 'greet', 'arguments' => new Map<String, Object>{ 'name' => 'Ada' } });
        McpTestKit.legacy(s, 'tools/list', null);
        Assert.areEqual(0, Limits.getQueries(), 'SOQL');
        Assert.areEqual(0, Limits.getDmlStatements(), 'DML');
        Assert.areEqual(0, Limits.getCallouts(), 'callouts');
        Assert.areEqual(0, Limits.getFutureCalls() + Limits.getQueueableJobs(), 'async');
        // Generous bounds that catch accidental quadratic work, not microbenchmarks.
        Assert.isTrue(Limits.getCpuTime() - cpuBefore < 3000, 'cpu ms: ' + (Limits.getCpuTime() - cpuBefore));
        Assert.isTrue(Limits.getHeapSize() - heapBefore < 500000, 'heap bytes: ' + (Limits.getHeapSize() - heapBefore));
    }

    @IsTest
    static void representativeLargeResultStaysWithinBudget() {
        McpServer s = new McpServer('s', '1').tool(new McpTestKit.ModeTool('rows', 'rows'));
        Integer heapBefore = Limits.getHeapSize();
        Integer cpuBefore = Limits.getCpuTime();
        McpTestKit.Reply r = McpTestKit.modern(s, 'tools/call', new Map<String, Object>{ 'name' => 'rows' });
        Assert.areEqual(200, r.status);
        Assert.areEqual(300, ((List<Object>) ((Map<String, Object>) r.result().get('structuredContent')).get('rows')).size());
        Assert.isTrue(r.body.length() > 30000, 'about 2,700 nodes and two copies of the data');
        Assert.areEqual(0, Limits.getQueries() + Limits.getDmlStatements() + Limits.getCallouts());
        Assert.isTrue(Limits.getCpuTime() - cpuBefore < 3000, 'cpu ms: ' + (Limits.getCpuTime() - cpuBefore));
        Assert.isTrue(Limits.getHeapSize() - heapBefore < 1500000, 'heap bytes: ' + (Limits.getHeapSize() - heapBefore));
    }

    @IsTest
    static void largeRegistryListingStaysBounded() {
        McpServer s = new McpServer('big', '1').pageSize(100);
        for (Integer i = 0; i < 100; i++) { s.tool(new McpTestKit.ModeTool('tool_' + i, 'ok')); }
        Integer cpuBefore = Limits.getCpuTime();
        McpTestKit.Reply r = McpTestKit.modern(s, 'tools/list', null);
        Assert.areEqual(100, r.items('tools').size());
        Assert.isTrue(Limits.getCpuTime() - cpuBefore < 3000, 'cpu ms: ' + (Limits.getCpuTime() - cpuBefore));
        Assert.areEqual(0, Limits.getQueries() + Limits.getDmlStatements() + Limits.getCallouts());
    }

    @IsTest
    static void unexpectedFailuresBecomeInternalErrorsInsteadOfPlatformErrors() {
        RestResponse res = new RestResponse();
        server().handle(null, res);
        Assert.areEqual(200, res.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        Assert.areEqual(-32603, ((Map<String, Object>) body.get('error')).get('code'));
        Assert.areEqual('Internal error', ((Map<String, Object>) body.get('error')).get('message'));
    }

    @IsTest
    static void serverInstanceCanHandleManyRequestsWithoutLeakingState() {
        McpServer s = server();
        McpTestKit.Reply bad = McpTestKit.sendRaw(s, 'POST', bareHeaders(), '{"jsonrpc":"2.0","id":99,"method":5}');
        Assert.areEqual(99, bad.json.get('id'));
        McpTestKit.Reply next = McpTestKit.sendRaw(s, 'POST', bareHeaders(), 'garbage');
        Assert.isFalse(next.json.containsKey('id'));
        McpTestKit.Reply ok = McpTestKit.modern(s, 'tools/list', null);
        Assert.areEqual('complete', ok.result().get('resultType'));
        McpTestKit.Reply legacy = McpTestKit.legacy(s, 'tools/list', null);
        Assert.isFalse(legacy.result().containsKey('resultType'));
    }
}
