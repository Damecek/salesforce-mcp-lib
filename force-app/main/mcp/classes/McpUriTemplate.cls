/**
 * Internal. RFC 6570 level-1 URI template: literals and simple {var} expressions only.
 * Matching is a linear scan: each variable takes the shortest run of characters, excluding / ? # &,
 * that ends at the first occurrence of the literal that follows it (the last variable ends at the
 * last occurrence of the trailing literal). Matched values are percent-decoded as URI components,
 * so '+' stays a literal plus.
 */
public inherited sharing class McpUriTemplate {
    public static final Integer MAX_URI_LENGTH = 2048;
    private static final Pattern VARIABLE_NAME = Pattern.compile('^[A-Za-z0-9_]+$');
    private static final Pattern SCHEME = Pattern.compile('^[A-Za-z][A-Za-z0-9+.-]*:.*');
    private static final String FORBIDDEN_IN_VALUE = '/?#&';

    private final String templateText;
    private final List<String> literals = new List<String>();
    private final List<String> variables = new List<String>();

    public McpUriTemplate(String template) {
        if (String.isBlank(template) || template.length() > MAX_URI_LENGTH) {
            throw new McpConfigurationException('URI template must be 1 to ' + MAX_URI_LENGTH + ' characters');
        }
        this.templateText = template;
        parse();
        if (!SCHEME.matcher(literals[0]).matches()) {
            throw new McpConfigurationException('URI template must start with a scheme: ' + template);
        }
    }

    private void parse() {
        Set<String> seen = new Set<String>();
        Integer pos = 0;
        while (true) {
            Integer open = templateText.indexOf('{', pos);
            if (open < 0) {
                String tail = templateText.substring(pos);
                if (tail.contains('}')) { fail('unbalanced }'); }
                literals.add(tail);
                return;
            }
            String literal = templateText.substring(pos, open);
            if (literal.contains('}')) { fail('unbalanced }'); }
            Integer close = templateText.indexOf('}', open);
            if (close < 0) { fail('unclosed {'); }
            String name = templateText.substring(open + 1, close);
            if (!VARIABLE_NAME.matcher(name).matches()) {
                fail('only level-1 {name} expressions with [A-Za-z0-9_] are allowed');
            }
            if (literal.length() == 0 && !variables.isEmpty()) { fail('adjacent expressions are not allowed'); }
            if (!seen.add(name)) { fail('duplicate variable ' + name); }
            literals.add(literal);
            variables.add(name);
            pos = close + 1;
            if (pos == templateText.length()) {
                literals.add('');
                return;
            }
        }
    }

    private void fail(String reason) {
        throw new McpConfigurationException('Invalid URI template ' + templateText + ': ' + reason);
    }

    public String template() {
        return templateText;
    }

    public List<String> variableNames() {
        return variables;
    }

    /** Returns the decoded variable values, or null when the uri does not match. */
    public Map<String, String> match(String uri) {
        if (uri == null || uri.length() > MAX_URI_LENGTH || !uri.startsWith(literals[0])) { return null; }
        Map<String, String> values = new Map<String, String>();
        if (variables.isEmpty()) { return uri.equals(literals[0]) ? values : null; }
        Integer pos = literals[0].length();
        for (Integer i = 0; i < variables.size(); i++) {
            String nextLiteral = literals[i + 1];
            Boolean last = i == variables.size() - 1;
            Integer stop;
            if (last) {
                if (!uri.endsWith(nextLiteral)) { return null; }
                stop = uri.length() - nextLiteral.length();
            } else {
                stop = uri.indexOf(nextLiteral, pos + 1);
            }
            if (stop <= pos) { return null; }
            String chunk = uri.substring(pos, stop);
            if (chunk.containsAny(FORBIDDEN_IN_VALUE)) { return null; }
            try {
                values.put(variables[i], EncodingUtil.urlDecode(chunk.replace('+', '%2B'), 'UTF-8'));
            } catch (Exception e) {
                return null;
            }
            pos = stop + nextLiteral.length();
        }
        return values;
    }
}
