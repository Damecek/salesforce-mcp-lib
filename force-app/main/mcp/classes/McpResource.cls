/**
 * Base class for a static resource with a fixed URI.
 */
public abstract inherited sharing class McpResource {
    private static final Pattern SCHEME = Pattern.compile('^[A-Za-z][A-Za-z0-9+.-]*:.*');

    private final String uriText;
    private final String nameText;
    private String titleText;
    private String descriptionText;
    private String mimeTypeText;
    private Long sizeBytes;
    private McpAnnotations annotationsValue;
    private McpIcon iconValue;
    private Map<String, Object> metaMap;

    public McpResource(String uri, String name) {
        if (String.isBlank(uri) || uri.length() > McpUriTemplate.MAX_URI_LENGTH || !SCHEME.matcher(uri).matches()) {
            throw new McpConfigurationException('Resource uri must start with a scheme and be at most 2048 characters');
        }
        if (String.isBlank(name)) {
            throw new McpConfigurationException('Resource needs a name');
        }
        this.uriText = uri;
        this.nameText = name;
    }

    public McpResource title(String value) { this.titleText = value; return this; }
    public McpResource description(String value) { this.descriptionText = value; return this; }
    public McpResource mimeType(String value) { this.mimeTypeText = value; return this; }
    public McpResource size(Long value) { this.sizeBytes = value; return this; }
    public McpResource annotations(McpAnnotations value) { this.annotationsValue = value; return this; }
    public McpResource icon(McpIcon value) { this.iconValue = value; return this; }

    public McpResource meta(String key, Object value) {
        if (metaMap == null) { metaMap = new Map<String, Object>(); }
        metaMap.put(key, value);
        return this;
    }

    public String getUri() {
        return uriText;
    }

    /** Return null when the resource cannot be produced; the client then sees "Resource not found". */
    public abstract McpResourceResult read(McpRequest request);

    public Map<String, Object> toWire() {
        Map<String, Object> m = new Map<String, Object>{ 'uri' => uriText, 'name' => nameText };
        if (titleText != null) { m.put('title', titleText); }
        if (descriptionText != null) { m.put('description', descriptionText); }
        if (mimeTypeText != null) { m.put('mimeType', mimeTypeText); }
        if (sizeBytes != null) { m.put('size', sizeBytes); }
        if (annotationsValue != null) { m.put('annotations', annotationsValue.toMap()); }
        if (iconValue != null) { m.put('icons', new List<Object>{ iconValue.toMap() }); }
        if (metaMap != null) { m.put('_meta', metaMap); }
        return m;
    }
}
