/**
 * Result of a tool call. Build with text(), structured() or error(), then optionally add blocks.
 */
public inherited sharing class McpToolResult {
    private final List<McpContent> blocks = new List<McpContent>();
    private Object structuredValue;
    private Boolean hasStructured = false;
    private Boolean generateText = false;
    private Boolean errorFlag = false;
    private Map<String, Object> metaMap;

    public static McpToolResult text(String text) {
        return new McpToolResult().add(McpContent.text(text));
    }

    /**
     * Sets structuredContent and asks the framework to add the JSON text block that S-TOOLS
     * recommends. The text is generated after the size guard, never before.
     * A top-level null means no structuredContent; nested nulls are preserved.
     *
     * Supported values are JSON-native: null, String, Boolean, Integer, Long, Decimal, Double, Date,
     * Datetime, Time, Id, Blob, Map<String, X> (any value type X), List<X> and SObject (populated
     * fields only). Values keep their precision and nested nulls. A Set, a Map with a non-String key,
     * an enum or a custom Apex object is refused before anything is serialized with the error
     * "Internal error" and a debug log line that names the fix. Convert a Set to a List, a Map<Id, X>
     * to a Map<String, X> (keys via String.valueOf) and a custom object to a Map<String, Object>.
     */
    public static McpToolResult structured(Object value) {
        McpToolResult r = new McpToolResult().structuredContent(value);
        r.generateText = r.hasStructured;
        return r;
    }

    public static McpToolResult error(String message) {
        return text(message).markError();
    }

    public McpToolResult add(McpContent block) {
        if (block != null) { blocks.add(block); }
        return this;
    }

    /** A null value means no structuredContent. */
    public McpToolResult structuredContent(Object value) {
        this.structuredValue = value;
        this.hasStructured = value != null;
        return this;
    }

    public McpToolResult markError() { this.errorFlag = true; return this; }

    public McpToolResult meta(String key, Object value) {
        if (metaMap == null) { metaMap = new Map<String, Object>(); }
        metaMap.put(key, value);
        return this;
    }

    // Internal accessors for McpRuntime.
    public List<McpContent> contentBlocks() { return blocks; }
    public Boolean hasStructuredContent() { return hasStructured; }
    public Object structuredContentValue() { return structuredValue; }
    public Boolean needsGeneratedText() { return generateText; }
    public Boolean isErrorResult() { return errorFlag; }
    public Map<String, Object> metaValues() { return metaMap; }
}
