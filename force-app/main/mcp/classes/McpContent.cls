/**
 * Content block used in tool results and prompt messages: text, image, audio, resource_link or an
 * embedded resource.
 */
public inherited sharing class McpContent {
    private final String blockType;
    private String textValue;
    private String dataBase64;
    private String mimeTypeText;
    private String uriText;
    private String nameText;
    private String titleText;
    private String descriptionText;
    private Long sizeBytes;
    private McpIcon iconValue;
    private McpResourceContents embeddedValue;
    private McpAnnotations annotationsValue;
    private Map<String, Object> metaMap;

    private McpContent(String blockType) {
        this.blockType = blockType;
    }

    public static McpContent text(String text) {
        McpContent c = new McpContent('text');
        c.textValue = text == null ? '' : text;
        return c;
    }

    public static McpContent image(Blob data, String mimeType) {
        return imageBase64(data == null ? '' : EncodingUtil.base64Encode(data), mimeType);
    }

    public static McpContent imageBase64(String base64, String mimeType) {
        return media('image', base64, mimeType);
    }

    public static McpContent audio(Blob data, String mimeType) {
        return audioBase64(data == null ? '' : EncodingUtil.base64Encode(data), mimeType);
    }

    public static McpContent audioBase64(String base64, String mimeType) {
        return media('audio', base64, mimeType);
    }

    public static McpContent resourceLink(String uri, String name) {
        if (String.isBlank(uri) || String.isBlank(name)) {
            throw new McpConfigurationException('A resource link needs a uri and a name');
        }
        McpContent c = new McpContent('resource_link');
        c.uriText = uri;
        c.nameText = name;
        return c;
    }

    public static McpContent embedded(McpResourceContents resource) {
        if (resource == null) {
            throw new McpConfigurationException('An embedded resource needs contents');
        }
        McpContent c = new McpContent('resource');
        c.embeddedValue = resource;
        return c;
    }

    private static McpContent media(String type, String base64, String mimeType) {
        if (String.isBlank(mimeType)) {
            throw new McpConfigurationException('Image and audio content need a mimeType');
        }
        McpContent c = new McpContent(type);
        c.dataBase64 = base64 == null ? '' : base64;
        c.mimeTypeText = mimeType;
        return c;
    }

    public McpContent annotations(McpAnnotations value) { this.annotationsValue = value; return this; }

    public McpContent meta(String key, Object value) {
        if (metaMap == null) { metaMap = new Map<String, Object>(); }
        metaMap.put(key, value);
        return this;
    }

    public McpContent title(String value) { requireLink(); this.titleText = value; return this; }
    public McpContent description(String value) { requireLink(); this.descriptionText = value; return this; }
    public McpContent mimeType(String value) { requireLink(); this.mimeTypeText = value; return this; }
    public McpContent size(Long value) { requireLink(); this.sizeBytes = value; return this; }
    public McpContent icon(McpIcon value) { requireLink(); this.iconValue = value; return this; }

    private void requireLink() {
        if (blockType != 'resource_link') {
            throw new McpConfigurationException('This setter is only valid on a resource link block');
        }
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new Map<String, Object>{ 'type' => blockType };
        if (blockType == 'text') {
            m.put('text', textValue);
        } else if (blockType == 'image' || blockType == 'audio') {
            m.put('data', dataBase64);
            m.put('mimeType', mimeTypeText);
        } else if (blockType == 'resource_link') {
            m.put('uri', uriText);
            m.put('name', nameText);
            if (titleText != null) { m.put('title', titleText); }
            if (descriptionText != null) { m.put('description', descriptionText); }
            if (mimeTypeText != null) { m.put('mimeType', mimeTypeText); }
            if (sizeBytes != null) { m.put('size', sizeBytes); }
            if (iconValue != null) { m.put('icons', new List<Object>{ iconValue.toMap() }); }
        } else {
            m.put('resource', embeddedValue.toMap());
        }
        if (annotationsValue != null) { m.put('annotations', annotationsValue.toMap()); }
        if (metaMap != null) { m.put('_meta', metaMap); }
        return m;
    }
}
