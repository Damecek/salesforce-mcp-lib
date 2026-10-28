/**
 * Result of reading a resource. Cache hints apply to the modern protocol only.
 */
public inherited sharing class McpResourceResult {
    private final List<McpResourceContents> contentList = new List<McpResourceContents>();
    private Integer ttlMsValue = 0;
    private String scopeValue = 'private';
    private Map<String, Object> metaMap;

    public static McpResourceResult of(McpResourceContents contents) {
        return new McpResourceResult().add(contents);
    }

    public McpResourceResult add(McpResourceContents contents) {
        if (contents != null) { contentList.add(contents); }
        return this;
    }

    public McpResourceResult cache(Integer ttlMs, String scope) {
        if (ttlMs == null || ttlMs < 0) {
            throw new McpConfigurationException('ttlMs must be zero or greater');
        }
        if (!McpWire.same(scope, 'public') && !McpWire.same(scope, 'private')) {
            throw new McpConfigurationException('Cache scope must be "public" or "private"');
        }
        this.ttlMsValue = ttlMs;
        this.scopeValue = scope;
        return this;
    }

    public McpResourceResult meta(String key, Object value) {
        if (metaMap == null) { metaMap = new Map<String, Object>(); }
        metaMap.put(key, value);
        return this;
    }

    // Internal accessors for McpRuntime.
    public List<McpResourceContents> contents() { return contentList; }
    public Integer ttlMs() { return ttlMsValue; }
    public String cacheScope() { return scopeValue; }
    public Map<String, Object> metaValues() { return metaMap; }
}
