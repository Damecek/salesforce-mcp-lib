@IsTest
private class McpServerTest {
    private static final String SERVER_INFO_KEY = 'io.modelcontextprotocol/serverInfo';

    private static void assertConfigurationError(String description, Exception e) {
        Assert.isNotNull(e, description + ' should throw');
        Assert.isTrue(e instanceof McpConfigurationException, description + ' threw ' + e.getTypeName());
    }

    @IsTest
    static void discoverReturnsTheModernShape() {
        McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'server/discover', null);
        Assert.areEqual(200, r.status);
        Assert.areEqual('application/json', r.headers.get('Content-Type'));
        Assert.areEqual(1, r.json.get('id'));
        Map<String, Object> result = r.result();
        Assert.areEqual('complete', result.get('resultType'));
        Assert.areEqual(0, result.get('ttlMs'));
        Assert.areEqual('private', result.get('cacheScope'));
        Assert.areEqual(new List<Object>{ '2026-07-28', '2025-11-25' }, (List<Object>) result.get('supportedVersions'));
        Assert.areEqual('Use echo first.', result.get('instructions'));
        Map<String, Object> caps = (Map<String, Object>) result.get('capabilities');
        Assert.areEqual(new Set<String>{ 'tools', 'resources', 'prompts', 'completions' }, caps.keySet());
        Map<String, Object> info = (Map<String, Object>) ((Map<String, Object>) result.get('_meta')).get(SERVER_INFO_KEY);
        Assert.areEqual('acme-test', info.get('name'));
        Assert.areEqual('1.2.3', info.get('version'));
        Assert.areEqual('Acme', info.get('title'));
        Assert.areEqual('Test server', info.get('description'));
        Assert.areEqual('https://example.com', info.get('websiteUrl'));
        Map<String, Object> icon = (Map<String, Object>) ((List<Object>) info.get('icons'))[0];
        Assert.areEqual('https://example.com/i.png', icon.get('src'));
        Assert.areEqual('light', icon.get('theme'));
        Assert.areEqual(new List<Object>{ '48x48' }, (List<Object>) icon.get('sizes'));
    }

    @IsTest
    static void discoverUsesConfiguredListCache() {
        McpServer s = McpTestKit.fullServer().listCache(60000, McpServer.CACHE_PUBLIC);
        Map<String, Object> result = McpTestKit.modern(s, 'server/discover', null).result();
        Assert.areEqual(60000, result.get('ttlMs'));
        Assert.areEqual('public', result.get('cacheScope'));
        Assert.areEqual(60000, McpTestKit.modern(s, 'tools/list', null).result().get('ttlMs'));
        Assert.areEqual(60000, McpTestKit.modern(s, 'prompts/list', null).result().get('ttlMs'));
        Assert.areEqual(60000, McpTestKit.modern(s, 'resources/list', null).result().get('ttlMs'));
        Assert.areEqual(60000, McpTestKit.modern(s, 'resources/templates/list', null).result().get('ttlMs'));
    }

    @IsTest
    static void discoverOmitsOptionalServerInfoAndInstructionsWhenUnset() {
        McpServer s = new McpServer('plain', '0.1').tool(new McpTestKit.EchoTool());
        Map<String, Object> result = McpTestKit.modern(s, 'server/discover', null).result();
        Assert.isFalse(result.containsKey('instructions'));
        Map<String, Object> info = (Map<String, Object>) ((Map<String, Object>) result.get('_meta')).get(SERVER_INFO_KEY);
        Assert.areEqual(new Set<String>{ 'name', 'version' }, info.keySet());
    }

    @IsTest
    static void legacyInitializeAndPing() {
        McpTestKit.Reply init = McpTestKit.post(McpTestKit.fullServer(), new Map<String, String>(), McpTestKit.message('init-1', 'initialize',
            new Map<String, Object>{ 'protocolVersion' => '2025-11-25', 'capabilities' => new Map<String, Object>(),
                'clientInfo' => new Map<String, Object>{ 'name' => 'c', 'version' => '1' } }));
        Assert.areEqual('init-1', init.json.get('id'));
        Map<String, Object> result = init.result();
        Assert.areEqual('2025-11-25', result.get('protocolVersion'));
        Assert.areEqual('Use echo first.', result.get('instructions'));
        Map<String, Object> info = (Map<String, Object>) result.get('serverInfo');
        Assert.areEqual('acme-test', info.get('name'));
        Assert.areEqual('Acme', info.get('title'));
        Assert.isFalse(result.containsKey('resultType'));
        Assert.isFalse(result.containsKey('ttlMs'));
        Assert.isFalse(result.containsKey('cacheScope'));
        Assert.isFalse(result.containsKey('_meta'));
        McpTestKit.Reply ping = McpTestKit.legacy(McpTestKit.fullServer(), 'ping', null);
        Assert.areEqual(200, ping.status);
        Assert.areEqual(0, ping.result().size());
    }

    @IsTest
    static void legacyListResultsCarryNoModernFields() {
        for (String method : new List<String>{ 'tools/list', 'resources/list', 'resources/templates/list', 'prompts/list' }) {
            Map<String, Object> result = McpTestKit.legacy(McpTestKit.fullServer(), method, null).result();
            Assert.isFalse(result.containsKey('resultType'), method);
            Assert.isFalse(result.containsKey('ttlMs'), method);
            Assert.isFalse(result.containsKey('cacheScope'), method);
            Assert.isFalse(result.containsKey('_meta'), method);
        }
    }

    @IsTest
    static void errorMessagesAreEscapedIntoValidJson() {
        String expected = 'no boom \\ "here"\n';
        McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get',
            new Map<String, Object>{ 'name' => 'greet', 'arguments' => new Map<String, Object>{ 'name' => 'boom' } });
        Assert.areEqual(expected, r.message());
        Assert.isTrue(r.body.contains('\\\\'));
        Assert.isTrue(r.body.contains('\\n'));
        Assert.isTrue(r.body.contains('\\"here\\"'));
        McpTestKit.Reply tool = McpTestKit.modern(new McpServer('s', '1').tool(new McpTestKit.ModeTool('m', 'mcp')), 'tools/call',
            new Map<String, Object>{ 'name' => 'm' });
        Assert.areEqual('bad "quote" \\ back\nline', (String) ((Map<String, Object>) tool.items('content')[0]).get('text'));
    }

    @IsTest
    static void instructionsAreEscaped() {
        McpServer s = new McpServer('s', '1').instructions('Say "hi" \\ twice\nplease').tool(new McpTestKit.EchoTool());
        Assert.areEqual('Say "hi" \\ twice\nplease', McpTestKit.modern(s, 'server/discover', null).result().get('instructions'));
    }

    // ---------------------------------------------------------------- configuration

    @IsTest
    static void constructorRejectsBlankNameOrVersion() {
        for (List<String> args : new List<List<String>>{ new List<String>{ null, '1' }, new List<String>{ '', '1' }, new List<String>{ 'n', ' ' }, new List<String>{ 'n', null } }) {
            Exception caught;
            try { new McpServer(args[0], args[1]); } catch (Exception e) { caught = e; }
            assertConfigurationError('blank ' + args, caught);
        }
    }

    @IsTest
    static void listCacheAndPageSizeAreValidated() {
        McpServer s = new McpServer('s', '1');
        Exception caught;
        try { s.listCache(-1, 'public'); } catch (Exception e) { caught = e; }
        assertConfigurationError('negative ttl', caught);
        caught = null;
        try { s.listCache(null, 'public'); } catch (Exception e) { caught = e; }
        assertConfigurationError('null ttl', caught);
        caught = null;
        try { s.listCache(1, 'shared'); } catch (Exception e) { caught = e; }
        assertConfigurationError('bad scope', caught);
        for (Integer bad : new List<Integer>{ 0, 101, -5 }) {
            caught = null;
            try { s.pageSize(bad); } catch (Exception e) { caught = e; }
            assertConfigurationError('pageSize ' + bad, caught);
        }
        caught = null;
        try { s.pageSize(null); } catch (Exception e) { caught = e; }
        assertConfigurationError('null pageSize', caught);
        s.pageSize(1).pageSize(100).listCache(0, McpServer.CACHE_PRIVATE);
    }

    @IsTest
    static void byteLimitsAreBoundedByThePlatformCeiling() {
        McpServer s = new McpServer('s', '1');
        for (Integer bad : new List<Integer>{ 0, 1023, 6000001, -1 }) {
            Exception caught;
            try { s.maxRequestBytes(bad); } catch (Exception e) { caught = e; }
            assertConfigurationError('maxRequestBytes ' + bad, caught);
            caught = null;
            try { s.maxResponseBytes(bad); } catch (Exception e) { caught = e; }
            assertConfigurationError('maxResponseBytes ' + bad, caught);
        }
        Exception caught;
        try { s.maxRequestBytes(null); } catch (Exception e) { caught = e; }
        assertConfigurationError('null', caught);
        s.maxRequestBytes(1024).maxRequestBytes(6000000).maxResponseBytes(1024).maxResponseBytes(6000000);
    }

    @IsTest
    static void duplicateAndNullRegistrationsAreRejected() {
        McpServer s = McpTestKit.fullServer();
        List<String> failures = new List<String>();
        try { s.tool(new McpTestKit.EchoTool()); failures.add('tool'); } catch (McpConfigurationException e) { }
        try { s.resource(new McpTestKit.OrgInfoResource()); failures.add('resource'); } catch (McpConfigurationException e) { }
        try { s.resourceTemplate(new McpTestKit.AccountTemplate()); failures.add('template'); } catch (McpConfigurationException e) { }
        try { s.prompt(new McpTestKit.GreetPrompt()); failures.add('prompt'); } catch (McpConfigurationException e) { }
        try { s.tool(null); failures.add('null tool'); } catch (McpConfigurationException e) { }
        try { s.resource(null); failures.add('null resource'); } catch (McpConfigurationException e) { }
        try { s.resourceTemplate(null); failures.add('null template'); } catch (McpConfigurationException e) { }
        try { s.prompt(null); failures.add('null prompt'); } catch (McpConfigurationException e) { }
        try { s.allowOrigin(' '); failures.add('blank origin'); } catch (McpConfigurationException e) { }
        Assert.areEqual(new List<String>(), failures);
    }

    @IsTest
    static void toolAndPromptNamesAreValidated() {
        for (String bad : new List<String>{ '', 'has space', 'ünïcode', 'a/b', 'x'.repeat(129) }) {
            Exception caught;
            try { new McpTestKit.ModeTool(bad, 'ok'); } catch (Exception e) { caught = e; }
            assertConfigurationError('tool name ' + bad, caught);
        }
        Exception caught;
        try { new McpTestKit.ModeTool(null, 'ok'); } catch (Exception e) { caught = e; }
        assertConfigurationError('null tool name', caught);
        new McpTestKit.ModeTool('a.b-c_D9', 'ok');
        new McpTestKit.ModeTool('x'.repeat(128), 'ok');
    }

    @IsTest
    static void skipOutputValidationIsChainable() {
        McpServer s = new McpServer('s', '1').skipOutputValidation().tool(new McpTestKit.EchoTool());
        Assert.areEqual(200, McpTestKit.modern(s, 'tools/list', null).status);
    }

    @IsTest
    static void iconAndMetadataSettersValidate() {
        List<String> failures = new List<String>();
        try { new McpIcon('http://insecure.example/i.png'); failures.add('http'); } catch (McpConfigurationException e) { }
        try { new McpIcon('javascript:alert(1)'); failures.add('js'); } catch (McpConfigurationException e) { }
        try { new McpIcon(' '); failures.add('blank'); } catch (McpConfigurationException e) { }
        try { new McpIcon('https://x.example/i.png').theme('blue'); failures.add('theme'); } catch (McpConfigurationException e) { }
        try { new McpAnnotations().audience(new List<String>{ 'robot' }); failures.add('audience'); } catch (McpConfigurationException e) { }
        try { new McpIcon('https://x.example/i.png').theme('LIGHT'); failures.add('theme case'); } catch (McpConfigurationException e) { }
        try { new McpIcon('https://x.example/i.png').theme(null); failures.add('theme null'); } catch (McpConfigurationException e) { }
        try { new McpAnnotations().audience(new List<String>{ 'USER' }); failures.add('audience case'); } catch (McpConfigurationException e) { }
        try { new McpAnnotations().audience(new List<String>{ 'user', 'Assistant' }); failures.add('audience case 2'); } catch (McpConfigurationException e) { }
        try { new McpServer('s', '1').listCache(1, 'PUBLIC'); failures.add('scope case'); } catch (McpConfigurationException e) { }
        try { new McpServer('s', '1').listCache(1, 'Private'); failures.add('scope case 2'); } catch (McpConfigurationException e) { }
        try { McpResourceResult.of(null).cache(1, 'PUBLIC'); failures.add('result scope case'); } catch (McpConfigurationException e) { }
        try { new McpAnnotations().priority(1.5); failures.add('priority hi'); } catch (McpConfigurationException e) { }
        try { new McpAnnotations().priority(-0.1); failures.add('priority lo'); } catch (McpConfigurationException e) { }
        Assert.areEqual(new List<String>(), failures);
        new McpIcon('HTTPS://x.example/i.png').theme('dark');
        new McpIcon('data:image/png;base64,AAAA');
        Map<String, Object> annotations = new McpAnnotations().audience(new List<String>{ 'user', 'assistant' }).priority(0).lastModified('2026-01-01T00:00:00Z').toMap();
        Assert.areEqual(3, annotations.size());
        Assert.areEqual(0, new McpAnnotations().toMap().size());
        Map<String, Object> toolAnnotations = new McpToolAnnotations().title('T').readOnly(true).destructive(false).idempotent(true).openWorld(false).toMap();
        Assert.areEqual(5, toolAnnotations.size());
        Assert.areEqual(false, toolAnnotations.get('destructiveHint'));
        Assert.areEqual(0, new McpToolAnnotations().toMap().size());
    }
}
