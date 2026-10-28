/**
 * Entry point of the framework. Configure a server fluently and let it handle one REST request:
 *
 * <pre>
 * new McpServer('acme-sales', '1.0.0')
 *     .tool(new SearchAccountsTool())
 *     .handle(RestContext.request, RestContext.response);
 * </pre>
 *
 * Creating a server per request is the intended use. The framework runs no SOQL, DML or callouts.
 */
public inherited sharing class McpServer {
    public static final String CACHE_PUBLIC = 'public';
    public static final String CACHE_PRIVATE = 'private';

    private final McpRuntime runtime;

    public McpServer(String name, String version) {
        this.runtime = new McpRuntime(name, version);
    }

    public McpServer title(String value) { runtime.serverTitle = value; return this; }
    public McpServer description(String value) { runtime.serverDescription = value; return this; }
    public McpServer websiteUrl(String value) { runtime.serverWebsite = value; return this; }
    public McpServer icon(McpIcon value) { runtime.serverIcon = value; return this; }
    public McpServer instructions(String value) { runtime.serverInstructions = value; return this; }

    public McpServer tool(McpTool value) { runtime.addTool(value); return this; }
    public McpServer resource(McpResource value) { runtime.addResource(value); return this; }
    public McpServer resourceTemplate(McpResourceTemplate value) { runtime.addTemplate(value); return this; }
    public McpServer prompt(McpPrompt value) { runtime.addPrompt(value); return this; }

    /** Adds an exact Origin header value that browsers may use. Requests without Origin always pass. */
    public McpServer allowOrigin(String origin) {
        if (String.isBlank(origin)) {
            throw new McpConfigurationException('Origin must not be blank');
        }
        runtime.allowedOrigins.add(origin);
        return this;
    }

    public McpServer listCache(Integer ttlMs, String scope) {
        if (ttlMs == null || ttlMs < 0) {
            throw new McpConfigurationException('ttlMs must be zero or greater');
        }
        if (!McpWire.same(scope, CACHE_PUBLIC) && !McpWire.same(scope, CACHE_PRIVATE)) {
            throw new McpConfigurationException('Cache scope must be "public" or "private"');
        }
        runtime.listTtlMs = ttlMs;
        runtime.listScope = scope;
        return this;
    }

    /**
     * Items per list page (1 to 100, default 50). A page is one response and must fit maxResponseBytes;
     * there is no adaptive paging, so lower the page size when the items are large.
     */
    public McpServer pageSize(Integer value) {
        if (value == null || value < 1 || value > 100) {
            throw new McpConfigurationException('pageSize must be between 1 and 100');
        }
        runtime.pageSize = value;
        return this;
    }

    /** Default 262,144. Raising it is capped at run time by the remaining heap (limit / 8). */
    public McpServer maxRequestBytes(Integer value) {
        runtime.maxRequestBytes = checkedBytes(value, 'maxRequestBytes');
        return this;
    }

    /** Default 262,144. Raising it is capped at run time by the remaining heap (estimate x 3). */
    public McpServer maxResponseBytes(Integer value) {
        runtime.maxResponseBytes = checkedBytes(value, 'maxResponseBytes');
        return this;
    }

    /** The developer asserts that structuredContent conforms to every builder output schema. */
    public McpServer skipOutputValidation() {
        runtime.skipOutputValidation = true;
        return this;
    }

    public void handle(RestRequest req, RestResponse res) {
        runtime.handle(req, res);
    }

    private static Integer checkedBytes(Integer value, String label) {
        if (value == null || value < McpRuntime.MIN_MAX_BYTES || value > McpRuntime.PLATFORM_MAX_BYTES) {
            throw new McpConfigurationException(label + ' must be between ' + McpRuntime.MIN_MAX_BYTES + ' and ' + McpRuntime.PLATFORM_MAX_BYTES);
        }
        return value;
    }
}
