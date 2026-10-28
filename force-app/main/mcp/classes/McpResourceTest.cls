@IsTest
private class McpResourceTest {
    private static McpServer server() {
        return McpTestKit.fullServer();
    }

    private static Map<String, Object> uri(String value) {
        return new Map<String, Object>{ 'uri' => value };
    }

    private static String text(McpTestKit.Reply r) {
        return (String) ((Map<String, Object>) r.items('contents')[0]).get('text');
    }

    public class NamedTemplate extends McpResourceTemplate {
        private final String label;
        public NamedTemplate(String template, String label) {
            super(template, label);
            this.label = label;
        }
        public override McpResourceResult read(McpRequest request) {
            return McpResourceResult.of(McpResourceContents.text(request.uri(), 'text/plain', label + ':' + request.variables()));
        }
    }

    public class Unnamed extends McpResource {
        public Unnamed() { super('x://a', ' '); }
        public override McpResourceResult read(McpRequest request) { return null; }
    }

    public class Fixed extends McpResource {
        private final McpResourceResult fixed;
        public Fixed(String uri, McpResourceResult fixed) {
            super(uri, 'fixed');
            this.fixed = fixed;
        }
        public override McpResourceResult read(McpRequest request) {
            return fixed;
        }
    }

    // ---------------------------------------------------------------- listing

    @IsTest
    static void listShowsStaticResourceMetadata() {
        McpTestKit.Reply r = McpTestKit.modern(server(), 'resources/list', null);
        Map<String, Object> resource = r.item('resources', 0);
        Assert.areEqual('acme://org', resource.get('uri'));
        Assert.areEqual('org', resource.get('name'));
        Assert.areEqual('Org', resource.get('title'));
        Assert.areEqual('Org info', resource.get('description'));
        Assert.areEqual('text/plain', resource.get('mimeType'));
        Assert.areEqual(5, resource.get('size'));
        Map<String, Object> annotations = (Map<String, Object>) resource.get('annotations');
        Assert.areEqual('2026-01-02T03:04:05.000Z', annotations.get('lastModified'));
        Assert.areEqual(1, annotations.get('priority'));
        Assert.isNotNull(resource.get('icons'));
        Assert.areEqual(1, ((Map<String, Object>) resource.get('_meta')).get('m'));
        Assert.areEqual(0, r.result().get('ttlMs'));
    }

    @IsTest
    static void templatesListIsSeparateFromResources() {
        McpTestKit.Reply r = McpTestKit.modern(server(), 'resources/templates/list', null);
        Assert.areEqual(1, r.items('resourceTemplates').size());
        Map<String, Object> template = r.item('resourceTemplates', 0);
        Assert.areEqual('acme://account/{id}', template.get('uriTemplate'));
        Assert.areEqual('account', template.get('name'));
        Assert.areEqual('Account', template.get('title'));
        Assert.areEqual('text/plain', template.get('mimeType'));
        Assert.areEqual(true, ((Map<String, Object>) template.get('_meta')).get('t'));
        Assert.areEqual(0.5, ((Map<String, Object>) template.get('annotations')).get('priority'));
        Assert.isNotNull(template.get('icons'));
        Assert.areEqual(1, McpTestKit.modern(server(), 'resources/list', null).items('resources').size());
    }

    @IsTest
    static void listsPageInRegistrationOrder() {
        McpServer s = new McpServer('s', '1').pageSize(1);
        s.resource(new Fixed('x://a', McpResourceResult.of(McpResourceContents.text('x://a', null, 'a'))));
        s.resource(new Fixed('x://b', McpResourceResult.of(McpResourceContents.text('x://b', null, 'b'))));
        s.resourceTemplate(new NamedTemplate('x://t/{a}', 't1'));
        s.resourceTemplate(new NamedTemplate('x://u/{a}', 't2'));
        McpTestKit.Reply first = McpTestKit.modern(s, 'resources/list', null);
        Assert.areEqual('x://a', first.item('resources', 0).get('uri'));
        McpTestKit.Reply second = McpTestKit.modern(s, 'resources/list', new Map<String, Object>{ 'cursor' => first.result().get('nextCursor') });
        Assert.areEqual('x://b', second.item('resources', 0).get('uri'));
        Assert.isFalse(second.result().containsKey('nextCursor'));
        McpTestKit.Reply tpl = McpTestKit.modern(s, 'resources/templates/list', null);
        Assert.areEqual('x://t/{a}', tpl.item('resourceTemplates', 0).get('uriTemplate'));
        Assert.areEqual(-32602, McpTestKit.modern(s, 'resources/templates/list', new Map<String, Object>{ 'cursor' => 'junk' }).code());
        Assert.areEqual(-32602, McpTestKit.modern(s, 'resources/list', new Map<String, Object>{ 'cursor' => 'junk' }).code());
    }

    // ---------------------------------------------------------------- reading

    @IsTest
    static void staticReadAppliesCacheHintsInTheModernEra() {
        McpTestKit.Reply r = McpTestKit.modern(server(), 'resources/read', uri('acme://org'));
        Assert.areEqual(200, r.status);
        Map<String, Object> contents = r.item('contents', 0);
        Assert.areEqual('acme://org', contents.get('uri'));
        Assert.areEqual('text/plain', contents.get('mimeType'));
        Assert.areEqual('hello', contents.get('text'));
        Assert.areEqual(5000, r.result().get('ttlMs'));
        Assert.areEqual('public', r.result().get('cacheScope'));
        Assert.areEqual('complete', r.result().get('resultType'));
        Map<String, Object> meta = (Map<String, Object>) r.result().get('_meta');
        Assert.areEqual('x', meta.get('r'));
        Assert.isNotNull(meta.get('io.modelcontextprotocol/serverInfo'));
    }

    @IsTest
    static void legacyReadHasNoCacheOrResultTypeFields() {
        McpTestKit.Reply r = McpTestKit.legacy(server(), 'resources/read', uri('acme://org'));
        Assert.areEqual('hello', text(r));
        Assert.isFalse(r.result().containsKey('ttlMs'));
        Assert.isFalse(r.result().containsKey('cacheScope'));
        Assert.isFalse(r.result().containsKey('resultType'));
        Assert.areEqual(new Set<String>{ 'contents', '_meta' }, r.result().keySet());
        Assert.areEqual('x', ((Map<String, Object>) r.result().get('_meta')).get('r'));
    }

    @IsTest
    static void defaultCacheHintIsZeroPrivate() {
        McpTestKit.Reply r = McpTestKit.modern(server(), 'resources/read', uri('acme://account/1'));
        Assert.areEqual(0, r.result().get('ttlMs'));
        Assert.areEqual('private', r.result().get('cacheScope'));
    }

    @IsTest
    static void templateReadMatchesAndDecodesVariables() {
        Assert.areEqual('account 42', text(McpTestKit.modern(server(), 'resources/read', uri('acme://account/42'))));
        Assert.areEqual('account a b', text(McpTestKit.modern(server(), 'resources/read', uri('acme://account/a%20b'))));
        Assert.areEqual('account a/b', text(McpTestKit.modern(server(), 'resources/read', uri('acme://account/a%2Fb'))));
        Assert.areEqual('account Zo\u00eb', text(McpTestKit.modern(server(), 'resources/read', uri('acme://account/Zo%C3%AB'))));
        Assert.areEqual('account a?b&c#d', text(McpTestKit.modern(server(), 'resources/read', uri('acme://account/a%3Fb%26c%23d'))));
    }

    @IsTest
    static void plusStaysALiteralPlusButPercentTwoBDecodesToPlus() {
        Assert.areEqual('account a+b', text(McpTestKit.modern(server(), 'resources/read', uri('acme://account/a+b'))));
        Assert.areEqual('account a+b', text(McpTestKit.modern(server(), 'resources/read', uri('acme://account/a%2Bb'))));
        Assert.areEqual('account a b+c', text(McpTestKit.modern(server(), 'resources/read', uri('acme://account/a%20b+c'))));
        Assert.areEqual('a+b', new McpUriTemplate('x://{v}').match('x://a+b').get('v'));
    }

    @IsTest
    static void firstMatchingTemplateWins() {
        McpServer s = new McpServer('s', '1').resourceTemplate(new NamedTemplate('x://item/{first}', 'one')).resourceTemplate(new NamedTemplate('x://item/{second}', 'two'));
        Assert.isTrue(text(McpTestKit.modern(s, 'resources/read', uri('x://item/7'))).startsWith('one:'));
    }

    @IsTest
    static void staticResourceBeatsTemplates() {
        McpServer s = new McpServer('s', '1')
            .resourceTemplate(new NamedTemplate('x://item/{id}', 'template'))
            .resource(new Fixed('x://item/special', McpResourceResult.of(McpResourceContents.text('x://item/special', null, 'static'))));
        Assert.areEqual('static', text(McpTestKit.modern(s, 'resources/read', uri('x://item/special'))));
        Assert.isTrue(text(McpTestKit.modern(s, 'resources/read', uri('x://item/other'))).startsWith('template:'));
    }

    @IsTest
    static void noMatchIsNotFoundWithTheEraSpecificCode() {
        for (String value : new List<String>{ 'acme://account/', 'acme://account/a/b', 'acme://account/a?x=1', 'other://account/1', 'acme://nothing', 'acme://account/%zz', 'acme://account/%E0%A4%A', 'acme://account/missing' }) {
            McpTestKit.Reply modern = McpTestKit.modern(server(), 'resources/read', uri(value));
            Assert.areEqual(200, modern.status, value);
            Assert.areEqual(-32602, modern.code(), value);
            Assert.areEqual('Resource not found', modern.message(), value);
            Assert.areEqual(value, ((Map<String, Object>) modern.error().get('data')).get('uri'), value);
            McpTestKit.Reply legacy = McpTestKit.legacy(server(), 'resources/read', uri(value));
            Assert.areEqual(200, legacy.status, value);
            Assert.areEqual(-32002, legacy.code(), value);
            Assert.areEqual(value, ((Map<String, Object>) legacy.error().get('data')).get('uri'), value);
        }
    }

    @IsTest
    static void readFailuresMapToProtocolErrors() {
        McpTestKit.Reply boom = McpTestKit.modern(server(), 'resources/read', uri('acme://account/boom'));
        Assert.areEqual(-32602, boom.code());
        Assert.areEqual('boom is not allowed', boom.message());
        Assert.areEqual(-32602, McpTestKit.legacy(server(), 'resources/read', uri('acme://account/boom')).code());
        McpTestKit.Reply crash = McpTestKit.modern(server(), 'resources/read', uri('acme://account/crash'));
        Assert.areEqual(-32603, crash.code());
        Assert.areEqual('Internal error', crash.message());
        Assert.isFalse(crash.body.contains('crash'));
        McpServer nullStatic = new McpServer('s', '1').resource(new Fixed('x://n', null));
        Assert.areEqual(-32602, McpTestKit.modern(nullStatic, 'resources/read', uri('x://n')).code());
    }

    @IsTest
    static void overlongAndNonStringUrisAreInvalidParams() {
        McpTestKit.Reply tooLong = McpTestKit.legacy(server(), 'resources/read', uri('acme://account/' + 'a'.repeat(2100)));
        Assert.areEqual(200, tooLong.status);
        Assert.areEqual(-32602, tooLong.code());
        Assert.areEqual('URI too long', tooLong.message());
        Assert.areEqual(-32602, McpTestKit.legacy(server(), 'resources/read', new Map<String, Object>{ 'uri' => 5 }).code());
        Assert.areEqual(-32602, McpTestKit.legacy(server(), 'resources/read', null).code());
    }

    @IsTest
    static void resourceResultSupportsSeveralContentsAndBlobs() {
        McpResourceResult multi = McpResourceResult.of(McpResourceContents.text('x://m', 'text/plain', 'one'))
            .add(McpResourceContents.blob('x://m/b', 'application/octet-stream', Blob.valueOf('bin')).meta('k', 'v'))
            .add(McpResourceContents.blobBase64('x://m/c', null, 'AAAA')).add(null).cache(1, 'private');
        McpTestKit.Reply r = McpTestKit.modern(new McpServer('s', '1').resource(new Fixed('x://m', multi)), 'resources/read', uri('x://m'));
        Assert.areEqual(3, r.items('contents').size());
        Assert.areEqual(EncodingUtil.base64Encode(Blob.valueOf('bin')), r.item('contents', 1).get('blob'));
        Assert.areEqual('v', ((Map<String, Object>) r.item('contents', 1).get('_meta')).get('k'));
        Assert.isFalse(r.item('contents', 2).containsKey('mimeType'));
        Assert.areEqual(1, r.result().get('ttlMs'));
    }

    @IsTest
    static void invalidCacheAndContentsAreRejected() {
        List<String> failures = new List<String>();
        try { McpResourceResult.of(null).cache(-1, 'public'); failures.add('ttl'); } catch (McpConfigurationException e) { }
        try { McpResourceResult.of(null).cache(null, 'public'); failures.add('null ttl'); } catch (McpConfigurationException e) { }
        try { McpResourceResult.of(null).cache(1, 'shared'); failures.add('scope'); } catch (McpConfigurationException e) { }
        try { McpResourceContents.text(' ', null, 'x'); failures.add('blank uri'); } catch (McpConfigurationException e) { }
        Assert.areEqual(new List<String>(), failures);
        Assert.areEqual('', McpResourceContents.text('x://a', null, null).toMap().get('text'));
        Assert.areEqual('', McpResourceContents.blob('x://a', null, null).toMap().get('blob'));
        Assert.areEqual('', McpResourceContents.blobBase64('x://a', null, null).toMap().get('blob'));
        Assert.areEqual(0, McpResourceResult.of(null).contents().size());
    }

    // ---------------------------------------------------------------- registration syntax

    @IsTest
    static void templateSyntaxIsRestrictedToLevelOne() {
        for (String bad : new List<String>{ 'x://{+path}', 'x://{a}{b}', 'x://{#frag}', 'x://{.dot}', 'x://{/seg}', 'x://{;p}', 'x://{?q}', 'x://{&q}',
                'x://{a', 'x://a}', 'x://{}', 'x://{a b}', 'x://{a}/{a}', '{a}://x', 'no-scheme', 'x://{a*}', 'x://{a:3}', 'x://{a,b}', '' }) {
            Exception caught;
            try { new NamedTemplate(bad, 'n'); } catch (Exception e) { caught = e; }
            Assert.isTrue(caught instanceof McpConfigurationException, 'template "' + bad + '" threw ' + (caught == null ? 'nothing' : caught.getTypeName()));
        }
        Exception caught;
        try { new NamedTemplate('x://' + 'a'.repeat(2050), 'n'); } catch (Exception e) { caught = e; }
        Assert.isTrue(caught instanceof McpConfigurationException);
        caught = null;
        try { new NamedTemplate(null, 'n'); } catch (Exception e) { caught = e; }
        Assert.isTrue(caught instanceof McpConfigurationException);
        caught = null;
        try { new NamedTemplate('x://{a}', ' '); } catch (Exception e) { caught = e; }
        Assert.isTrue(caught instanceof McpConfigurationException);
        new NamedTemplate('x://{a}/{b_2}.json', 'ok');
        new NamedTemplate('x://static', 'no variables');
        new NamedTemplate('x://{a}', 'trailing variable only');
    }

    @IsTest
    static void resourceUrisAndNamesAreValidated() {
        for (String bad : new List<String>{ '', 'no-scheme', '1x://a', '://a', 'x//a', 'x://' + 'a'.repeat(2050) }) {
            Exception caught;
            try { new Fixed(bad, null); } catch (Exception e) { caught = e; }
            Assert.isTrue(caught instanceof McpConfigurationException, 'uri "' + bad.left(20) + '"');
        }
        Exception caught;
        try { new Fixed(null, null); } catch (Exception e) { caught = e; }
        Assert.isTrue(caught instanceof McpConfigurationException);
        caught = null;
        try { new Unnamed(); } catch (Exception e) { caught = e; }
        Assert.isTrue(caught instanceof McpConfigurationException, 'a resource needs a name');
        new Fixed('git+ssh://host/x', null);
        new Fixed('urn:isbn:0451450523', null);
    }

    // ---------------------------------------------------------------- template matcher

    @IsTest
    static void matcherHandlesMultipleVariablesAndLiterals() {
        McpUriTemplate t = new McpUriTemplate('acme://org/{org}/acct/{id}.json');
        Map<String, String> m = t.match('acme://org/emea/acct/42.json');
        Assert.areEqual('emea', m.get('org'));
        Assert.areEqual('42', m.get('id'));
        Assert.areEqual(new List<String>{ 'org', 'id' }, t.variableNames());
        Assert.areEqual('acme://org/{org}/acct/{id}.json', t.template());
        Assert.areEqual('a.json', t.match('acme://org/x/acct/a.json.json').get('id'), 'the last variable ends at the last trailing literal');
        Assert.isNull(t.match('acme://org/x/acct/42.xml'));
        Assert.isNull(t.match('acme://org//acct/42.json'));
        Assert.isNull(t.match('acme://org/x/acct/.json'));
        Assert.isNull(t.match('acme://org/x/acct/4/2.json'));
        Assert.isNull(t.match(null));
        Assert.isNull(t.match('x'.repeat(2100)));
        Assert.areEqual(0, new McpUriTemplate('x://plain').match('x://plain').size());
        Assert.isNull(new McpUriTemplate('x://plain').match('x://plain/more'));
    }

    @IsTest
    static void uriMatchingIsCaseSensitive() {
        Assert.isNull(new McpUriTemplate('x://plain').match('X://PLAIN'));
        Assert.isNull(new McpUriTemplate('x://plain').match('x://Plain'));
        Assert.isNull(new McpUriTemplate('acme://account/{id}').match('ACME://account/1'));
        Assert.isNull(new McpUriTemplate('acme://account/{id}').match('acme://ACCOUNT/1'));
        Assert.isNull(new McpUriTemplate('acme://a/{id}.json').match('acme://a/1.JSON'));
        for (String value : new List<String>{ 'ACME://ORG', 'acme://Org', 'ACME://account/1' }) {
            Assert.areEqual(-32602, McpTestKit.modern(server(), 'resources/read', uri(value)).code(), value);
        }
        Assert.areEqual(200, McpTestKit.modern(server(), 'resources/read', uri('acme://org')).status);
        McpServer fixed = new McpServer('s', '1').resourceTemplate(new McpTestKit.PlainTemplate('x://plain'));
        Assert.areEqual(-32602, McpTestKit.modern(fixed, 'resources/read', uri('X://PLAIN')).code());
    }

    @IsTest
    static void matcherIsLinearOnAdversarialInput() {
        McpUriTemplate t = new McpUriTemplate('x://{a}-{b}-{c}-{d}-{e}-{f}-{g}-{h}');
        Integer cpuBefore = Limits.getCpuTime();
        Assert.isNotNull(t.match('x://' + '-'.repeat(2000)), 'each variable takes the shortest non-empty run');
        Assert.isNull(t.match('x://' + 'a-'.repeat(1000) + '/'));
        Assert.isTrue(Limits.getCpuTime() - cpuBefore < 1000, 'cpu ms: ' + (Limits.getCpuTime() - cpuBefore));
    }
}
