/**
 * One entry of a resources/read result or an embedded resource: text or base64 blob content.
 */
public inherited sharing class McpResourceContents {
    private final String uriText;
    private final String mimeTypeText;
    private final String textValue;
    private final String blobBase64;
    private Map<String, Object> metaMap;

    private McpResourceContents(String uri, String mimeType, String text, String blobBase64) {
        if (String.isBlank(uri)) {
            throw new McpConfigurationException('Resource contents need a uri');
        }
        this.uriText = uri;
        this.mimeTypeText = mimeType;
        this.textValue = text;
        this.blobBase64 = blobBase64;
    }

    public static McpResourceContents text(String uri, String mimeType, String text) {
        return new McpResourceContents(uri, mimeType, text == null ? '' : text, null);
    }

    public static McpResourceContents blob(String uri, String mimeType, Blob data) {
        return new McpResourceContents(uri, mimeType, null, data == null ? '' : EncodingUtil.base64Encode(data));
    }

    public static McpResourceContents blobBase64(String uri, String mimeType, String base64) {
        return new McpResourceContents(uri, mimeType, null, base64 == null ? '' : base64);
    }

    public McpResourceContents meta(String key, Object value) {
        if (metaMap == null) { metaMap = new Map<String, Object>(); }
        metaMap.put(key, value);
        return this;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new Map<String, Object>{ 'uri' => uriText };
        if (mimeTypeText != null) { m.put('mimeType', mimeTypeText); }
        if (textValue != null) { m.put('text', textValue); } else { m.put('blob', blobBase64); }
        if (metaMap != null) { m.put('_meta', metaMap); }
        return m;
    }
}
