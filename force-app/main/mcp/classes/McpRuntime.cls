/**
 * Internal. Holds the registrations and runs the request pipeline of the HTTP wire contract:
 * method, origin, size, JSON, id, era detection, header validation, dispatch, result decoration and
 * size guards. One instance serves one request. McpServer is the public front for it.
 */
public inherited sharing class McpRuntime {
    public static final String MODERN = '2026-07-28';
    public static final String LEGACY = '2025-11-25';
    public static final List<String> SUPPORTED = new List<String>{ MODERN, LEGACY };
    public static final String META_VERSION = 'io.modelcontextprotocol/protocolVersion';
    public static final String META_CAPABILITIES = 'io.modelcontextprotocol/clientCapabilities';
    public static final String META_SERVER_INFO = 'io.modelcontextprotocol/serverInfo';
    public static final Integer DEFAULT_MAX_BYTES = 262144;
    public static final Integer MIN_MAX_BYTES = 1024;
    public static final Integer PLATFORM_MAX_BYTES = 6000000;

    // Exact, case-sensitive method names. Apex == ignores case, so membership is checked in a Set first.
    private static final Set<String> METHODS = new Set<String>{
        'initialize', 'ping', 'server/discover', 'tools/list', 'tools/call', 'resources/list', 'resources/read',
        'resources/templates/list', 'prompts/list', 'prompts/get', 'completion/complete'
    };
    private static final Pattern CURSOR_OFFSET = Pattern.compile('^[0-9]{1,9}$');
    private static final Integer MAX_ECHOED_NAME = 128;

    // Server configuration.
    public final String serverName;
    public final String serverVersion;
    public String serverTitle;
    public String serverDescription;
    public String serverWebsite;
    public McpIcon serverIcon;
    public String serverInstructions;
    public Integer maxRequestBytes = DEFAULT_MAX_BYTES;
    public Integer maxResponseBytes = DEFAULT_MAX_BYTES;
    public Integer pageSize = 50;
    public Integer listTtlMs = 0;
    public String listScope = 'private';
    public Boolean skipOutputValidation = false;
    public final Set<String> allowedOrigins = new Set<String>();

    // Registrations, in registration order.
    private final List<McpTool> tools = new List<McpTool>();
    private final Map<String, McpTool> toolsByName = new Map<String, McpTool>();
    private final List<McpResource> resources = new List<McpResource>();
    private final Map<String, McpResource> resourcesByUri = new Map<String, McpResource>();
    private final List<McpResourceTemplate> templates = new List<McpResourceTemplate>();
    private final Map<String, McpResourceTemplate> templatesByText = new Map<String, McpResourceTemplate>();
    private final List<McpPrompt> prompts = new List<McpPrompt>();
    private final Map<String, McpPrompt> promptsByName = new Map<String, McpPrompt>();

    // Per-request state.
    private Object requestId;
    private Boolean legacyEra = false;
    private String versionText;
    private Integer cacheTtl;
    private String cacheScopeText;
    private Long precomputedEstimate;

    public class PageSlice {
        public Integer start;
        public Integer endIndex;
        public String nextCursor;
    }

    public McpRuntime(String name, String version) {
        if (String.isBlank(name) || String.isBlank(version)) {
            throw new McpConfigurationException('Server name and version must not be blank');
        }
        this.serverName = name;
        this.serverVersion = version;
    }

    // ---------------------------------------------------------------- registration

    public void addTool(McpTool tool) {
        if (tool == null) { throw new McpConfigurationException('Tool must not be null'); }
        if (toolsByName.containsKey(tool.getName())) {
            throw new McpConfigurationException('Duplicate tool name: ' + tool.getName());
        }
        tool.compile();
        tools.add(tool);
        toolsByName.put(tool.getName(), tool);
    }

    public void addResource(McpResource resource) {
        if (resource == null) { throw new McpConfigurationException('Resource must not be null'); }
        if (resourcesByUri.containsKey(resource.getUri())) {
            throw new McpConfigurationException('Duplicate resource uri: ' + resource.getUri());
        }
        resources.add(resource);
        resourcesByUri.put(resource.getUri(), resource);
    }

    public void addTemplate(McpResourceTemplate template) {
        if (template == null) { throw new McpConfigurationException('Resource template must not be null'); }
        if (templatesByText.containsKey(template.getUriTemplate())) {
            throw new McpConfigurationException('Duplicate resource template: ' + template.getUriTemplate());
        }
        templates.add(template);
        templatesByText.put(template.getUriTemplate(), template);
    }

    public void addPrompt(McpPrompt prompt) {
        if (prompt == null) { throw new McpConfigurationException('Prompt must not be null'); }
        if (promptsByName.containsKey(prompt.getName())) {
            throw new McpConfigurationException('Duplicate prompt name: ' + prompt.getName());
        }
        prompts.add(prompt);
        promptsByName.put(prompt.getName(), prompt);
    }

    // ---------------------------------------------------------------- entry point

    public void handle(RestRequest req, RestResponse res) {
        requestId = null;
        legacyEra = false;
        versionText = null;
        cacheTtl = null;
        cacheScopeText = null;
        precomputedEstimate = null;
        try {
            process(req, res);
        } catch (McpProtocolException e) {
            writeError(res, e);
        } catch (Exception e) {
            logInternal('request', e);
            writeError(res, new McpProtocolException(-32603, 'Internal error', 200));
        }
    }

    private void process(RestRequest req, RestResponse res) {
        if (!McpWire.same(req.httpMethod, 'POST')) {
            res.statusCode = 405;
            res.addHeader('Allow', 'POST');
            return;
        }
        Map<String, String> headers = lowerCaseHeaders(req.headers);
        String origin = headers.get('origin');
        if (origin != null && !allowedOrigins.contains(origin)) {
            throw new McpProtocolException(-32600, 'Origin not allowed', 403);
        }
        Blob raw = req.requestBody;
        Integer bytes = raw == null ? 0 : raw.size();
        Integer remaining = Limits.getLimitHeapSize() - Limits.getHeapSize();
        if (bytes > Math.min(maxRequestBytes, remaining / 8)) {
            throw new McpProtocolException(-32600, 'Request body too large', 413);
        }
        String text = raw == null ? '' : raw.toString();
        // Before the parser: deep nesting makes it slow and later instanceof checks overflow the stack.
        if (McpWire.nestsDeeperThan(text, McpWire.WALK_MAX_DEPTH)) {
            throw new McpProtocolException(-32600, 'Request structure too large', 400);
        }
        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(text);
        } catch (Exception e) {
            throw new McpProtocolException(-32700, 'Parse error', 400);
        }
        if (parsed instanceof List<Object>) {
            throw new McpProtocolException(-32600, 'Batch requests are not supported', 400);
        }
        if (!(parsed instanceof Map<String, Object>)) {
            throw new McpProtocolException(-32600, 'Invalid Request', 400);
        }
        if (McpWire.estimateBytes(parsed, maxRequestBytes) < 0) {
            throw new McpProtocolException(-32600, 'Request structure too large', 400);
        }
        Map<String, Object> message = (Map<String, Object>) parsed;
        Boolean hasId = message.containsKey('id');
        if (hasId) {
            Object id = McpWire.normalizeId(message.get('id'));
            if (id == null) { throw new McpProtocolException(-32600, 'Invalid Request', 400); }
            requestId = id;
        }
        if (!McpWire.same(message.get('jsonrpc'), McpWire.JSONRPC) || !(message.get('method') instanceof String)) {
            throw new McpProtocolException(-32600, 'Invalid Request', 400);
        }
        if (!hasId) {
            res.statusCode = 202;
            return;
        }
        String method = (String) message.get('method');
        Object paramsObject = message.get('params');
        Map<String, Object> params = paramsObject instanceof Map<String, Object> ? (Map<String, Object>) paramsObject : null;
        Map<String, Object> meta = null;
        if (params != null && params.get('_meta') instanceof Map<String, Object>) {
            meta = (Map<String, Object>) params.get('_meta');
        }
        detectEra(method, headers, meta);
        if (!legacyEra) { validateModernHeaders(method, headers, params, meta); }
        if (!isAvailable(method)) {
            throw new McpProtocolException(-32601, 'Method not found', legacyEra ? 200 : 404);
        }
        McpRequest request = new McpRequest().initContext(method, versionText, legacyEra, meta);
        Map<String, Object> result = dispatch(method, params, request);
        writeResult(res, result);
    }

    // ---------------------------------------------------------------- era and headers

    private void detectEra(String method, Map<String, String> headers, Map<String, Object> meta) {
        String headerVersion = headers.get('mcp-protocol-version');
        String metaVersion = null;
        if (meta != null && meta.get(META_VERSION) instanceof String) { metaVersion = (String) meta.get(META_VERSION); }
        // initialize is the legacy handshake only when the client names no version at all. An explicit
        // version, modern or unknown, goes through the normal validation below.
        if (McpWire.same(method, 'initialize') && headerVersion == null && metaVersion == null) {
            legacyEra = true;
            versionText = LEGACY;
            return;
        }
        if (metaVersion != null && headerVersion != null && !McpWire.same(metaVersion, headerVersion)) {
            throw new McpProtocolException(-32020, 'Header MCP-Protocol-Version does not match _meta protocolVersion', 400);
        }
        if (headerVersion == null) {
            throw new McpProtocolException(-32020, 'Missing MCP-Protocol-Version header', 400);
        }
        String version = metaVersion != null ? metaVersion : headerVersion;
        if (!SUPPORTED.contains(version)) {
            throw new McpProtocolException(-32022, 'Unsupported protocol version', 400,
                new Map<String, Object>{ 'supported' => SUPPORTED, 'requested' => clip(version) });
        }
        versionText = version;
        legacyEra = McpWire.same(version, LEGACY);
    }

    private void validateModernHeaders(String method, Map<String, String> headers, Map<String, Object> params, Map<String, Object> meta) {
        if (meta == null || !(meta.get(META_VERSION) instanceof String)) { throw missingMeta(META_VERSION); }
        if (!(meta.get(META_CAPABILITIES) instanceof Map<String, Object>)) { throw missingMeta(META_CAPABILITIES); }
        String mcpMethod = headers.get('mcp-method');
        if (mcpMethod == null) { throw new McpProtocolException(-32020, 'Missing Mcp-Method header', 400); }
        if (!McpWire.same(mcpMethod, method)) {
            throw new McpProtocolException(-32020, 'Header Mcp-Method does not match the request method', 400);
        }
        String key = McpWire.same(method, 'resources/read') ? 'uri'
            : (McpWire.same(method, 'tools/call') || McpWire.same(method, 'prompts/get') ? 'name' : null);
        if (key == null) { return; }
        Object value = params.get(key);
        if (!(value instanceof String)) {
            throw new McpProtocolException(-32602, 'Invalid params: ' + key + ' must be a string', 400);
        }
        String mcpName = headers.get('mcp-name');
        if (mcpName == null) { throw new McpProtocolException(-32020, 'Missing Mcp-Name header', 400); }
        if (!McpWire.same(McpWire.decodeHeaderValue(mcpName, 'Mcp-Name'), (String) value)) {
            throw new McpProtocolException(-32020, 'Header Mcp-Name does not match params.' + key, 400);
        }
    }

    private McpProtocolException missingMeta(String field) {
        return new McpProtocolException(-32602, 'Missing required _meta field: ' + field, 400);
    }

    private static Map<String, String> lowerCaseHeaders(Map<String, String> source) {
        Map<String, String> lower = new Map<String, String>();
        if (source != null) {
            for (String key : source.keySet()) { lower.put(key.toLowerCase(), source.get(key)); }
        }
        return lower;
    }

    private Boolean isAvailable(String method) {
        if (!METHODS.contains(method)) { return false; } // after this, == below only meets exact names
        if (method == 'initialize' || method == 'ping') { return legacyEra; }
        if (method == 'server/discover') { return !legacyEra; }
        if (method == 'tools/list' || method == 'tools/call') { return !tools.isEmpty(); }
        if (method == 'resources/list' || method == 'resources/read' || method == 'resources/templates/list') {
            return !resources.isEmpty() || !templates.isEmpty();
        }
        if (method == 'prompts/list' || method == 'prompts/get') { return !prompts.isEmpty(); }
        if (method == 'completion/complete') { return !prompts.isEmpty() || !templates.isEmpty(); }
        return false;
    }

    // ---------------------------------------------------------------- dispatch

    private Map<String, Object> dispatch(String method, Map<String, Object> params, McpRequest request) {
        if (method == 'server/discover') { return discover(); }
        if (method == 'initialize') { return initialize(); }
        if (method == 'ping') { return new Map<String, Object>(); }
        if (method == 'tools/list') { return listTools(params); }
        if (method == 'tools/call') { return callTool(params, request); }
        if (method == 'resources/list') { return listResources(params); }
        if (method == 'resources/templates/list') { return listTemplates(params); }
        if (method == 'resources/read') { return readResource(params, request); }
        if (method == 'prompts/list') { return listPrompts(params); }
        if (method == 'prompts/get') { return getPrompt(params, request); }
        return complete(params);
    }

    private Map<String, Object> capabilities() {
        Map<String, Object> caps = new Map<String, Object>();
        if (!tools.isEmpty()) { caps.put('tools', new Map<String, Object>()); }
        if (!resources.isEmpty() || !templates.isEmpty()) { caps.put('resources', new Map<String, Object>()); }
        if (!prompts.isEmpty()) { caps.put('prompts', new Map<String, Object>()); }
        if (!prompts.isEmpty() || !templates.isEmpty()) { caps.put('completions', new Map<String, Object>()); }
        return caps;
    }

    private Map<String, Object> serverInfo() {
        Map<String, Object> info = new Map<String, Object>{ 'name' => serverName, 'version' => serverVersion };
        if (serverTitle != null) { info.put('title', serverTitle); }
        if (serverDescription != null) { info.put('description', serverDescription); }
        if (serverWebsite != null) { info.put('websiteUrl', serverWebsite); }
        if (serverIcon != null) { info.put('icons', new List<Object>{ serverIcon.toMap() }); }
        return info;
    }

    private Map<String, Object> discover() {
        Map<String, Object> result = new Map<String, Object>{ 'supportedVersions' => SUPPORTED, 'capabilities' => capabilities() };
        if (serverInstructions != null) { result.put('instructions', serverInstructions); }
        useListCache();
        return result;
    }

    private Map<String, Object> initialize() {
        Map<String, Object> result = new Map<String, Object>{
            'protocolVersion' => LEGACY, 'capabilities' => capabilities(), 'serverInfo' => serverInfo()
        };
        if (serverInstructions != null) { result.put('instructions', serverInstructions); }
        return result;
    }

    private void useListCache() {
        cacheTtl = listTtlMs;
        cacheScopeText = listScope;
    }

    // ---------------------------------------------------------------- lists and pagination

    private PageSlice paginate(Integer total, Map<String, Object> params) {
        PageSlice p = new PageSlice();
        p.start = 0;
        if (params != null && params.get('cursor') != null) { p.start = decodeCursor(params.get('cursor'), total); }
        p.endIndex = Math.min(p.start + pageSize, total);
        if (p.endIndex < total) {
            p.nextCursor = EncodingUtil.base64Encode(Blob.valueOf('v1:' + p.endIndex));
        }
        return p;
    }

    private Integer decodeCursor(Object cursor, Integer total) {
        McpProtocolException invalid = new McpProtocolException(-32602, 'Invalid cursor', 200);
        if (!(cursor instanceof String) || ((String) cursor).length() > 64) { throw invalid; }
        String decoded;
        try {
            decoded = EncodingUtil.base64Decode((String) cursor).toString();
        } catch (Exception e) {
            throw invalid;
        }
        if (!decoded.startsWith('v1:') || !CURSOR_OFFSET.matcher(decoded.substring(3)).matches()) { throw invalid; }
        Integer offset = Integer.valueOf(decoded.substring(3));
        if (offset > total) { throw invalid; }
        return offset;
    }

    private Map<String, Object> pagedResult(String key, List<Object> items, PageSlice p) {
        Map<String, Object> result = new Map<String, Object>{ key => items };
        if (p.nextCursor != null) { result.put('nextCursor', p.nextCursor); }
        useListCache();
        return result;
    }

    private Map<String, Object> listTools(Map<String, Object> params) {
        PageSlice p = paginate(tools.size(), params);
        List<Object> items = new List<Object>();
        for (Integer i = p.start; i < p.endIndex; i++) { items.add(tools[i].toWire(legacyEra)); }
        return pagedResult('tools', items, p);
    }

    private Map<String, Object> listResources(Map<String, Object> params) {
        PageSlice p = paginate(resources.size(), params);
        List<Object> items = new List<Object>();
        for (Integer i = p.start; i < p.endIndex; i++) { items.add(resources[i].toWire()); }
        return pagedResult('resources', items, p);
    }

    private Map<String, Object> listTemplates(Map<String, Object> params) {
        PageSlice p = paginate(templates.size(), params);
        List<Object> items = new List<Object>();
        for (Integer i = p.start; i < p.endIndex; i++) { items.add(templates[i].toWire()); }
        return pagedResult('resourceTemplates', items, p);
    }

    private Map<String, Object> listPrompts(Map<String, Object> params) {
        PageSlice p = paginate(prompts.size(), params);
        List<Object> items = new List<Object>();
        for (Integer i = p.start; i < p.endIndex; i++) { items.add(prompts[i].toWire()); }
        return pagedResult('prompts', items, p);
    }

    // ---------------------------------------------------------------- tools/call

    private Map<String, Object> callTool(Map<String, Object> params, McpRequest request) {
        String name = requireParamString(params, 'name');
        McpTool tool = toolsByName.get(name);
        if (tool == null) { throw invalidParams('Unknown tool: ' + clip(name)); }
        Map<String, Object> args = new Map<String, Object>();
        Object argsObject = params.get('arguments');
        if (argsObject instanceof Map<String, Object>) {
            args = (Map<String, Object>) argsObject;
        } else if (argsObject != null) {
            throw invalidParams('Invalid params: arguments must be an object');
        }
        request.initTool(name, args);
        McpToolResult toolResult;
        try {
            McpSchema inputSchema = tool.inputValidator();
            List<String> errors = inputSchema == null ? new List<String>() : inputSchema.validate(args, 'arguments');
            if (errors.isEmpty()) {
                tool.validate(request);
                toolResult = tool.execute(request);
            } else {
                toolResult = McpToolResult.error(String.join(errors, '\n'));
            }
        } catch (McpException e) {
            toolResult = McpToolResult.error(e.getMessage() == null ? 'Tool error' : e.getMessage());
        } catch (Exception e) {
            logInternal('tools/call ' + name, e);
            throw internalError();
        }
        if (toolResult == null) {
            logInternal('tools/call ' + name, new McpConfigurationException('execute() returned null'));
            throw internalError();
        }
        return toolResultMap(tool, toolResult);
    }

    private Map<String, Object> toolResultMap(McpTool tool, McpToolResult tr) {
        List<Object> content = new List<Object>();
        for (McpContent block : tr.contentBlocks()) { content.add(block.toMap()); }
        Map<String, Object> result = new Map<String, Object>{ 'content' => content };
        if (tr.isErrorResult()) { result.put('isError', true); }
        if (tr.metaValues() != null) { result.put('_meta', tr.metaValues()); }

        Boolean hasStructured = tr.hasStructuredContent();
        Object structured = tr.structuredContentValue();
        Long estimate = measure(result);
        if (hasStructured) { estimate += measure(structured) * (tr.needsGeneratedText() ? 2 : 1); }
        checkBudget(estimate);
        precomputedEstimate = estimate;
        McpSchema outputSchema = tool.outputBuilderSchema();
        if (outputSchema != null && !skipOutputValidation && !tr.isErrorResult()) {
            List<String> errors = hasStructured ? outputSchema.validate(structured, 'structuredContent') : new List<String>{ 'structuredContent is missing' };
            if (!errors.isEmpty()) {
                logInternal('tools/call ' + tool.getName(), new McpConfigurationException('Output schema mismatch: ' + String.join(errors, '; ')));
                throw internalError();
            }
        }
        if (hasStructured && (!legacyEra || structured instanceof Map<String, Object>)) {
            result.put('structuredContent', structured);
        }
        if (hasStructured && (tr.needsGeneratedText() || (legacyEra && !(structured instanceof Map<String, Object>) && content.isEmpty()))) {
            content.add(McpContent.text(JSON.serialize(structured)).toMap());
        }
        return result;
    }

    /** Bounded walk of value; throws the size error when a walk limit is hit. */
    private Long measure(Object value) {
        Long estimate = McpWire.estimateBytes(value, maxResponseBytes);
        if (estimate < 0) { throw tooLarge(); }
        return estimate;
    }

    /** Throws the size error when the estimate exceeds the response limit or the remaining heap budget. */
    private void checkBudget(Long estimate) {
        Integer remaining = Limits.getLimitHeapSize() - Limits.getHeapSize();
        if (estimate > maxResponseBytes || estimate * 3 > remaining) { throw tooLarge(); }
    }

    private McpProtocolException tooLarge() {
        return new McpProtocolException(-32603, 'Response exceeds the server size limit', 200);
    }

    // ---------------------------------------------------------------- resources/read

    private Map<String, Object> readResource(Map<String, Object> params, McpRequest request) {
        String uri = requireParamString(params, 'uri');
        if (uri.length() > McpUriTemplate.MAX_URI_LENGTH) { throw invalidParams('URI too long'); }
        McpResourceResult found;
        Boolean matched = false;
        try {
            McpResource resource = resourcesByUri.get(uri);
            if (resource != null) {
                matched = true;
                request.initResource(uri, null);
                found = resource.read(request);
            } else {
                for (McpResourceTemplate template : templates) {
                    Map<String, String> variables = template.uriTemplateParser().match(uri);
                    if (variables != null) {
                        matched = true;
                        request.initResource(uri, variables);
                        found = template.read(request);
                        break;
                    }
                }
            }
        } catch (McpException e) {
            throw invalidParams(e.getMessage());
        } catch (Exception e) {
            logInternal('resources/read', e);
            throw internalError();
        }
        if (found == null) {
            Integer code = legacyEra ? -32002 : -32602;
            throw new McpProtocolException(code, 'Resource not found', 200, new Map<String, Object>{ 'uri' => uri });
        }
        List<Object> contents = new List<Object>();
        for (McpResourceContents c : found.contents()) { contents.add(c.toMap()); }
        Map<String, Object> result = new Map<String, Object>{ 'contents' => contents };
        if (found.metaValues() != null) { result.put('_meta', found.metaValues()); }
        cacheTtl = found.ttlMs();
        cacheScopeText = found.cacheScope();
        return result;
    }

    // ---------------------------------------------------------------- prompts/get

    private Map<String, Object> getPrompt(Map<String, Object> params, McpRequest request) {
        String name = requireParamString(params, 'name');
        McpPrompt prompt = promptsByName.get(name);
        if (prompt == null) { throw invalidParams('Unknown prompt: ' + clip(name)); }
        Map<String, String> args = new Map<String, String>();
        Object argsObject = params.get('arguments');
        if (argsObject != null && !(argsObject instanceof Map<String, Object>)) {
            throw invalidParams('Invalid params: arguments must be an object');
        }
        if (argsObject != null) {
            Map<String, Object> raw = (Map<String, Object>) argsObject;
            for (String key : raw.keySet()) {
                if (!(raw.get(key) instanceof String)) {
                    throw invalidParams('Prompt argument "' + clip(key) + '" must be a string');
                }
                args.put(key, (String) raw.get(key));
            }
        }
        for (String required : prompt.requiredArguments()) {
            if (!args.containsKey(required)) { throw invalidParams('Missing required argument: ' + required); }
        }
        request.initPrompt(name, args);
        McpPromptResult promptResult;
        try {
            promptResult = prompt.get(request);
        } catch (McpException e) {
            throw invalidParams(e.getMessage());
        } catch (Exception e) {
            logInternal('prompts/get ' + name, e);
            throw internalError();
        }
        if (promptResult == null) {
            logInternal('prompts/get ' + name, new McpConfigurationException('get() returned null'));
            throw internalError();
        }
        Map<String, Object> result = new Map<String, Object>{ 'messages' => promptResult.messages() };
        if (promptResult.descriptionValue() != null) { result.put('description', promptResult.descriptionValue()); }
        if (promptResult.metaValues() != null) { result.put('_meta', promptResult.metaValues()); }
        return result;
    }

    // ---------------------------------------------------------------- completion/complete

    private Map<String, Object> complete(Map<String, Object> params) {
        if (params == null || !(params.get('ref') instanceof Map<String, Object>)
            || !(params.get('argument') instanceof Map<String, Object>)) {
            throw invalidParams('Invalid params: ref and argument are required');
        }
        Map<String, Object> ref = (Map<String, Object>) params.get('ref');
        Map<String, Object> argument = (Map<String, Object>) params.get('argument');
        if (!(argument.get('name') instanceof String) || !(argument.get('value') instanceof String)) {
            throw invalidParams('Invalid params: argument name and value must be strings');
        }
        String argName = (String) argument.get('name');
        String argValue = (String) argument.get('value');
        Map<String, String> context = new Map<String, String>();
        Object contextObject = params.get('context');
        if (contextObject instanceof Map<String, Object> && ((Map<String, Object>) contextObject).get('arguments') instanceof Map<String, Object>) {
            Map<String, Object> ctx = (Map<String, Object>) ((Map<String, Object>) contextObject).get('arguments');
            for (String key : ctx.keySet()) {
                if (ctx.get(key) instanceof String) { context.put(key, (String) ctx.get(key)); }
            }
        }
        Object type = ref.get('type');
        McpCompletion completion;
        try {
            if (McpWire.same(type, 'ref/prompt') && ref.get('name') instanceof String) {
                McpPrompt prompt = promptsByName.get((String) ref.get('name'));
                if (prompt == null || !prompt.declaresArgument(argName)) { throw invalidParams('Unknown completion reference or argument'); }
                completion = prompt.complete(argName, argValue, context);
            } else if (McpWire.same(type, 'ref/resource') && ref.get('uri') instanceof String) {
                String uri = (String) ref.get('uri');
                McpResourceTemplate template = templatesByText.get(uri);
                if (template != null) {
                    if (!template.uriTemplateParser().variableNames().contains(argName)) { throw invalidParams('Unknown completion reference or argument'); }
                    completion = template.complete(argName, argValue, context);
                } else if (resourcesByUri.containsKey(uri)) {
                    completion = McpCompletion.none();
                } else {
                    throw invalidParams('Unknown completion reference or argument');
                }
            } else {
                throw invalidParams('Unknown completion reference or argument');
            }
        } catch (McpProtocolException e) {
            throw e;
        } catch (McpException e) {
            throw invalidParams(e.getMessage());
        } catch (Exception e) {
            logInternal('completion/complete', e);
            throw internalError();
        }
        return (completion == null ? McpCompletion.none() : completion).toMap();
    }

    // ---------------------------------------------------------------- response writing

    private void writeResult(RestResponse res, Map<String, Object> result) {
        if (!legacyEra) {
            Map<String, Object> meta = result.get('_meta') instanceof Map<String, Object>
                ? new Map<String, Object>((Map<String, Object>) result.get('_meta'))
                : new Map<String, Object>();
            meta.put(META_SERVER_INFO, serverInfo());
            result.put('_meta', meta);
            result.put('resultType', 'complete');
            if (cacheTtl != null) {
                result.put('ttlMs', cacheTtl);
                result.put('cacheScope', cacheScopeText);
            }
        }
        Map<String, Object> envelope = McpWire.resultEnvelope(requestId, result);
        if (precomputedEstimate == null) { checkBudget(measure(envelope)); }
        Blob body = Blob.valueOf(JSON.serialize(envelope));
        if (body.size() > maxResponseBytes) { throw tooLarge(); }
        res.statusCode = 200;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = body;
    }

    private void writeError(RestResponse res, McpProtocolException e) {
        Map<String, Object> envelope = McpWire.errorEnvelope(requestId, e.errorCode, e.getMessage(), e.errorData);
        res.statusCode = e.httpStatus;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(envelope));
    }

    // ---------------------------------------------------------------- helpers

    private String requireParamString(Map<String, Object> params, String key) {
        Object value = params == null ? null : params.get(key);
        if (!(value instanceof String)) { throw invalidParams('Invalid params: ' + key + ' must be a string'); }
        return (String) value;
    }

    private McpProtocolException invalidParams(String message) {
        return new McpProtocolException(-32602, message == null ? 'Invalid params' : message, 200);
    }

    private McpProtocolException internalError() {
        return new McpProtocolException(-32603, 'Internal error', 200);
    }

    private String clip(String value) {
        return value.length() > MAX_ECHOED_NAME ? value.substring(0, MAX_ECHOED_NAME) : value;
    }

    private void logInternal(String location, Exception e) {
        System.debug(LoggingLevel.ERROR, 'MCP internal error in ' + location + ': ' + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
    }
}
