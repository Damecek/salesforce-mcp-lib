/**
 * Shared helpers and fixtures for the framework tests. Not part of the supported API.
 */
@IsTest
public class McpTestKit {
    public static final String MODERN = '2026-07-28';
    public static final String LEGACY = '2025-11-25';
    public static final String META_VERSION = 'io.modelcontextprotocol/protocolVersion';
    public static final String META_CAPS = 'io.modelcontextprotocol/clientCapabilities';

    /** A custom Apex object: not JSON-native, so the framework refuses it in results and schemas. */
    public class Opaque {
        public String field = 'x';
    }

    public class Reply {
        public Integer status;
        public Map<String, String> headers;
        public String body;
        public Map<String, Object> json;

        public Map<String, Object> result() { return (Map<String, Object>) json.get('result'); }
        public Map<String, Object> error() { return (Map<String, Object>) json.get('error'); }
        public Integer code() { return (Integer) error().get('code'); }
        public String message() { return (String) error().get('message'); }
        public List<Object> items(String key) { return (List<Object>) result().get(key); }
        public Map<String, Object> item(String key, Integer index) { return (Map<String, Object>) items(key)[index]; }
    }

    // ------------------------------------------------------------------ sending

    public static Reply sendRaw(McpServer server, String httpMethod, Map<String, String> headers, String body) {
        RestRequest req = new RestRequest();
        req.httpMethod = httpMethod;
        if (headers != null) { req.headers.putAll(headers); }
        if (body != null) { req.requestBody = Blob.valueOf(body); }
        RestResponse res = new RestResponse();
        server.handle(req, res);
        Reply reply = new Reply();
        reply.status = res.statusCode;
        reply.headers = res.headers;
        if (res.responseBody != null) {
            reply.body = res.responseBody.toString();
            reply.json = (Map<String, Object>) JSON.deserializeUntyped(reply.body);
        }
        return reply;
    }

    public static Reply post(McpServer server, Map<String, String> headers, Map<String, Object> message) {
        return sendRaw(server, 'POST', headers, JSON.serialize(message));
    }

    public static Map<String, Object> message(Object id, String method, Map<String, Object> params) {
        Map<String, Object> m = new Map<String, Object>{ 'jsonrpc' => '2.0', 'method' => method };
        if (id != null) { m.put('id', id); }
        if (params != null) { m.put('params', params); }
        return m;
    }

    public static Map<String, Object> modernParams(Map<String, Object> params) {
        Map<String, Object> p = params == null ? new Map<String, Object>() : new Map<String, Object>(params);
        p.put('_meta', new Map<String, Object>{
            META_VERSION => MODERN,
            META_CAPS => new Map<String, Object>(),
            'io.modelcontextprotocol/clientInfo' => new Map<String, Object>{ 'name' => 'test-client', 'version' => '1' }
        });
        return p;
    }

    public static Map<String, String> modernHeaders(String method, Map<String, Object> params) {
        Map<String, String> h = new Map<String, String>{
            'MCP-Protocol-Version' => MODERN, 'Mcp-Method' => method, 'Content-Type' => 'application/json',
            'Accept' => 'application/json, text/event-stream'
        };
        if (params != null && params.get('name') instanceof String) { h.put('Mcp-Name', (String) params.get('name')); }
        if (params != null && params.get('uri') instanceof String) { h.put('Mcp-Name', (String) params.get('uri')); }
        return h;
    }

    public static Reply modern(McpServer server, String method, Map<String, Object> params) {
        return post(server, modernHeaders(method, params), message(1, method, modernParams(params)));
    }

    public static Reply legacy(McpServer server, String method, Map<String, Object> params) {
        return post(server, new Map<String, String>{ 'MCP-Protocol-Version' => LEGACY }, message(1, method, params));
    }

    public static McpToolResult noop() { return McpToolResult.text('ok'); }

    // ------------------------------------------------------------------ fixtures

    public static McpServer fullServer() {
        return new McpServer('acme-test', '1.2.3')
            .title('Acme').description('Test server').websiteUrl('https://example.com')
            .icon(new McpIcon('https://example.com/i.png').mimeType('image/png').sizes(new List<String>{ '48x48' }).theme('light'))
            .instructions('Use echo first.')
            .tool(new EchoTool())
            .resource(new OrgInfoResource())
            .resourceTemplate(new AccountTemplate())
            .prompt(new GreetPrompt());
    }

    public class EchoTool extends McpTool {
        public EchoTool() {
            super('echo');
            title('Echo').description('Echoes a message.')
                .input(McpSchema.obj()
                    .requiredProperty('message', McpSchema.str().minLength(1).maxLength(20))
                    .property('count', McpSchema.integer().minimum(1).maximum(5))
                    .closed())
                .output(McpSchema.obj()
                    .requiredProperty('echo', McpSchema.str())
                    .property('note', McpSchema.str().nullable()))
                .annotations(new McpToolAnnotations().readOnly(true).openWorld(false))
                .icon(new McpIcon('https://example.com/echo.png'))
                .meta('vendor', 'acme');
        }
        public override McpToolResult execute(McpRequest request) {
            return McpToolResult.structured(new Map<String, Object>{ 'echo' => request.requireString('message'), 'note' => null });
        }
    }

    /** Behaviour is selected by mode so one fixture covers many result shapes. */
    public class ModeTool extends McpTool {
        private final String mode;
        public ModeTool(String name, String mode) {
            super(name);
            this.mode = mode;
        }
        public override void validate(McpRequest request) {
            if (mode == 'validate') { throw new McpException('validate said no'); }
        }
        public override McpToolResult execute(McpRequest request) {
            if (mode == 'mcp') { throw new McpException('bad "quote" \\ back\nline'); }
            if (mode == 'generic') { throw new ListException('secret internals'); }
            if (mode == 'null') { return null; }
            if (mode == 'rows') {
                List<Object> rows = new List<Object>();
                for (Integer i = 0; i < 300; i++) {
                    rows.add(new Map<String, Object>{ 'id' => '001' + i, 'name' => 'Account ' + i, 'industry' => 'Tech', 'city' => 'Prague',
                        'active' => true, 'score' => i, 'ratio' => 1.5, 'note' => null });
                }
                return McpToolResult.structured(new Map<String, Object>{ 'rows' => rows });
            }
            if (mode == 'bigtext') { return McpToolResult.text('a'.repeat(300000)); }
            if (mode == 'bigmeta') { return McpToolResult.text('x').meta('blob', 'b'.repeat(300000)); }
            if (mode == 'bigstructured') { return McpToolResult.structured(new Map<String, Object>{ 'v' => 'c'.repeat(200000) }); }
            if (mode == 'deep') {
                Object nested = 'leaf';
                for (Integer i = 0; i < 40; i++) { nested = new List<Object>{ nested }; }
                return McpToolResult.structured(new Map<String, Object>{ 'v' => nested });
            }
            if (mode == 'many') {
                List<Object> items = new List<Object>();
                for (Integer i = 0; i < 6000; i++) { items.add(new List<Object>{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }); }
                return McpToolResult.structured(new Map<String, Object>{ 'v' => items });
            }
            if (mode == 'wide') {
                List<Object> items = new List<Object>();
                for (Integer i = 0; i < 10001; i++) { items.add(i); }
                return McpToolResult.structured(new Map<String, Object>{ 'v' => items });
            }
            if (mode == 'cycle') {
                Map<String, Object> m = new Map<String, Object>();
                m.put('self', m);
                return McpToolResult.structured(m);
            }
            if (mode == 'scalar') { return McpToolResult.structured('just a string'); }
            if (mode == 'array') { return McpToolResult.structured(new List<Object>{ 1, 2, 3 }); }
            if (mode == 'rawStructured') { return new McpToolResult().structuredContent(new List<Object>{ 'a' }); }
            if (mode == 'noStructured') { return McpToolResult.text('plain'); }
            if (mode == 'badStructured') { return McpToolResult.structured(new Map<String, Object>{ 'echo' => 5 }); }
            if (mode == 'errorResult') { return McpToolResult.error('declared failure'); }
            if (mode == 'rich') {
                return new McpToolResult()
                    .add(McpContent.text('t').annotations(new McpAnnotations().audience(new List<String>{ 'user' }).priority(0.5)))
                    .add(McpContent.image(Blob.valueOf('img'), 'image/png'))
                    .add(McpContent.audioBase64('YXVk', 'audio/wav'))
                    .add(McpContent.resourceLink('acme://org', 'org').title('Org').description('d').mimeType('text/plain').size(3).icon(new McpIcon('https://example.com/o.png')))
                    .add(McpContent.embedded(McpResourceContents.text('acme://org', 'text/plain', 'hi')))
                    .meta('k', 'v');
            }
            if (mode == 'typed') {
                return McpToolResult.structured(new Map<String, Object>{
                    'int' => request.getInteger('i'), 'long' => request.getLong('l'), 'dec' => request.getDecimal('d'),
                    'bool' => request.getBoolean('b'), 'map' => request.getMap('m'), 'list' => request.getList('a'),
                    'str' => request.getString('s'), 'raw' => request.get('s')
                });
            }
            return McpToolResult.text('ok');
        }
    }

    public class OrgInfoResource extends McpResource {
        public OrgInfoResource() {
            super('acme://org', 'org');
            title('Org').description('Org info').mimeType('text/plain').size(5)
                .annotations(new McpAnnotations().priority(1).lastModified(Datetime.newInstanceGmt(2026, 1, 2, 3, 4, 5)))
                .icon(new McpIcon('data:image/png;base64,AAAA')).meta('m', 1);
        }
        public override McpResourceResult read(McpRequest request) {
            return McpResourceResult.of(McpResourceContents.text('acme://org', 'text/plain', 'hello')).cache(5000, 'public').meta('r', 'x');
        }
    }

    public class AccountTemplate extends McpResourceTemplate {
        public AccountTemplate() {
            super('acme://account/{id}', 'account');
            title('Account').description('An account').mimeType('text/plain').meta('t', true)
                .annotations(new McpAnnotations().priority(0.5)).icon(new McpIcon('https://example.com/a.png'));
        }
        public override McpResourceResult read(McpRequest request) {
            String id = request.variable('id');
            if (id == 'missing') { return null; }
            if (id == 'boom') { throw new McpException('boom is not allowed'); }
            if (id == 'crash') { throw new MathException('crash'); }
            return McpResourceResult.of(McpResourceContents.text(request.uri(), 'text/plain', 'account ' + id));
        }
        public override McpCompletion complete(String argumentName, String value, Map<String, String> context) {
            if (value == 'many') {
                List<String> values = new List<String>();
                for (Integer i = 0; i < 150; i++) { values.add('v' + i); }
                return McpCompletion.of(values);
            }
            if (value == 'ctx') { return McpCompletion.of(new List<String>{ context.get('x') }); }
            if (value == 'boom') { throw new McpException('completion refused'); }
            if (value == 'crash') { throw new MathException('crash'); }
            if (value == 'null') { return null; }
            return McpCompletion.of(new List<String>{ 'a1', 'a2' }).total(2).hasMore(false);
        }
    }

    public class GreetPrompt extends McpPrompt {
        public GreetPrompt() {
            super('greet');
            title('Greet').description('Greets someone.').icon(new McpIcon('https://example.com/g.png')).meta('p', 1)
                .argument('name', 'Who to greet', true)
                .argument('tone', 'How', false);
        }
        public override McpPromptResult get(McpRequest request) {
            String name = request.promptArguments().get('name');
            if (name == 'boom') { throw new McpException('no boom \\ "here"\n'); }
            if (name == 'crash') { throw new MathException('crash'); }
            if (name == 'null') { return null; }
            return new McpPromptResult().description('Greeting')
                .user(McpContent.text('Hello ' + name))
                .assistant(McpContent.imageBase64('AAAA', 'image/png'))
                .user(McpContent.audioBase64('AAAA', 'audio/wav'))
                .user(McpContent.resourceLink('acme://org', 'org'))
                .assistant(McpContent.embedded(McpResourceContents.blobBase64('acme://blob', 'application/octet-stream', 'AAAA')))
                .meta('pm', 2);
        }
        public override McpCompletion complete(String argumentName, String value, Map<String, String> context) {
            return McpCompletion.of(new List<String>{ 'Ada', 'Alan' });
        }
    }

    /** Prompt and template that keep the default (empty) complete() implementation. */
    public class PlainPrompt extends McpPrompt {
        public PlainPrompt() { super('plain'); }
        public override McpPromptResult get(McpRequest request) { return new McpPromptResult(); }
    }

    public class PlainTemplate extends McpResourceTemplate {
        public PlainTemplate(String template) { super(template, 'plain'); }
        public override McpResourceResult read(McpRequest request) { return null; }
    }
}
