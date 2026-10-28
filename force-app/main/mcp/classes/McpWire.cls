/**
 * Internal. JSON-RPC envelope builders, id normalisation, header value decoding, the pre-parse nesting
 * guard and the bounded iterative walk that estimates serialized size before anything is serialized.
 * Builders never put null values into maps, so only handler data can contain null.
 *
 * Apex == and != compare Strings case-insensitively. Every comparison the wire contract defines as
 * case-sensitive (method, header values, enum values, version) goes through same() instead.
 */
public inherited sharing class McpWire {
    public static final String JSONRPC = '2.0';
    public static final Integer WALK_MAX_DEPTH = 32;
    public static final Integer WALK_MIN_NODES = 25000;
    public static final Integer WALK_MAX_NODES = 200000;
    public static final Integer WALK_MAX_COLLECTION = 10000;

    private static final Decimal LONG_MAX = Decimal.valueOf(9223372036854775807L);
    private static final Integer SOBJECT_OVERHEAD = 128; // the "attributes" entry JSON.serialize adds
    private static final Integer SCALAR_ESTIMATE = 4;
    private static final Integer TEMPORAL_ESTIMATE = 12;
    private static final Pattern BASE64_BODY = Pattern.compile('^[A-Za-z0-9+/]*={0,2}$');

    public static final String UNSUPPORTED_VALUE = 'Unsupported value type in a result. Only JSON-native values are supported: '
        + 'null, String, Boolean, Integer, Long, Decimal, Double, Date, Datetime, Time, Id, Blob, Map<String, ...>, List<...> and SObject. '
        + 'Convert a Set to a List, a Map with non-String keys to a Map<String, Object> and a custom object to a Map<String, Object>.';

    /** Case-sensitive equality of a String with a String. False when value is not a String. */
    public static Boolean same(Object value, String expected) {
        return value instanceof String && ((String) value).equals(expected);
    }

    public static Map<String, Object> resultEnvelope(Object id, Map<String, Object> result) {
        Map<String, Object> envelope = new Map<String, Object>{ 'jsonrpc' => JSONRPC };
        if (id != null) { envelope.put('id', id); }
        envelope.put('result', result);
        return envelope;
    }

    public static Map<String, Object> errorEnvelope(Object id, Integer code, String message, Object data) {
        Map<String, Object> error = new Map<String, Object>{ 'code' => code, 'message' => message };
        if (data != null) { error.put('data', data); }
        Map<String, Object> envelope = new Map<String, Object>{ 'jsonrpc' => JSONRPC };
        if (id != null) { envelope.put('id', id); }
        envelope.put('error', error);
        return envelope;
    }

    /**
     * Returns the id in its wire type (String, Integer or Long), or null when the id is not allowed
     * (boolean, fractional, out of Long range, object, array, null). Integral Decimals become Long.
     */
    public static Object normalizeId(Object id) {
        if (id instanceof String || id instanceof Integer || id instanceof Long) {
            return id;
        }
        if (id instanceof Decimal) {
            try {
                Decimal d = ((Decimal) id).stripTrailingZeros();
                if (d.scale() > 0 || d.abs() > LONG_MAX) { return null; }
                return d.longValue();
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    /**
     * Decodes an Mcp-Name style header value. Plain values must be visible ASCII, space or tab.
     * Values wrapped in the base64 sentinel are decoded as UTF-8. Throws -32020 on any failure.
     */
    public static String decodeHeaderValue(String raw, String headerName) {
        String failure = 'Invalid ' + headerName + ' header';
        if (raw.startsWith('=?base64?') && raw.endsWith('?=') && raw.length() >= 11) {
            String middle = raw.substring(9, raw.length() - 2);
            try {
                if (middle.length() == 0 || Math.mod(middle.length(), 4) != 0 || !BASE64_BODY.matcher(middle).matches()) {
                    throw new McpProtocolException(-32020, failure, 400);
                }
                String decoded = EncodingUtil.base64Decode(middle).toString();
                if (!same(EncodingUtil.base64Encode(Blob.valueOf(decoded)), middle)) {
                    throw new McpProtocolException(-32020, failure, 400);
                }
                return decoded;
            } catch (McpProtocolException e) {
                throw e;
            } catch (Exception e) {
                throw new McpProtocolException(-32020, failure, 400);
            }
        }
        for (Integer i = 0; i < raw.length(); i++) {
            Integer c = raw.charAt(i);
            if (c != 9 && (c < 32 || c > 126)) {
                throw new McpProtocolException(-32020, failure, 400);
            }
        }
        return raw;
    }

    /**
     * Lexical nesting check that runs on the raw JSON text, before JSON.deserializeUntyped. The platform
     * parser accepts thousands of nesting levels, after which even an instanceof check overflows the
     * stack with an uncatchable LimitException, and a body of 100,000 opening brackets costs seconds of CPU.
     * Returns true when the text nests containers deeper than maxDepth. Brackets inside strings and
     * escaped quotes do not count. Malformed text never throws here: the parser reports it afterwards.
     * Cost: three native counts when the text has at most maxDepth opening brackets (about 2 ms at 256 KiB);
     * otherwise a pass over the characters outside strings, about 4 microseconds each, plus 7 microseconds
     * per escaped quote inside strings. Measured worst cases at 240,000 characters: 1.0 s for brackets and
     * objects with no strings, 1.1 s for 160,000 characters of escaped quotes; text that is mostly string
     * content costs about 2 ms. Rejection of a deeply nested body ends after the 33rd bracket (about 2 ms).
     */
    public static Boolean nestsDeeperThan(String json, Integer maxDepth) {
        if (json.countMatches('[') + json.countMatches('{') <= maxDepth) { return false; }
        Integer depth = 0;
        Integer length = json.length();
        for (Integer i = 0; i < length; i++) {
            Integer c = json.charAt(i);
            if (c == 34) {
                i = endOfString(json, i);
                if (i < 0) { return false; }
            } else if (c == 91 || c == 123) {
                depth++;
                if (depth > maxDepth) { return true; }
            } else if ((c == 93 || c == 125) && depth > 0) {
                depth--;
            }
        }
        return false;
    }

    /** Index of the quote that closes the string opened at start (not preceded by an odd run of backslashes), or -1. */
    private static Integer endOfString(String json, Integer start) {
        Integer quote = start;
        while (true) {
            quote = json.indexOf('"', quote + 1);
            if (quote < 0) { return -1; }
            Integer backslashes = 0;
            for (Integer k = quote - 1; k > start && json.charAt(k) == 92; k--) { backslashes++; }
            if (Math.mod(backslashes, 2) == 0) { return quote; }
        }
        return -1; // unreachable; Apex requires a return after while (true)
    }

    /** True for the values the walk can size without looking inside: null, scalars, temporal values, Id and Blob. */
    public static Boolean isScalar(Object value) {
        return value == null || value instanceof String || value instanceof Boolean || value instanceof Integer
            || value instanceof Long || value instanceof Decimal || value instanceof Double || value instanceof Blob
            || value instanceof Date || value instanceof Datetime || value instanceof Time || value instanceof Id;
    }

    private static Boolean isContainer(Object value) {
        return value instanceof Map<String, Object> || value instanceof List<Object> || value instanceof SObject;
    }

    /**
     * Iterative bounded walk (no recursion). Returns a lower bound of the serialized byte size, or -1
     * when the node, depth or collection limit is hit. Cyclic structures fail the depth limit.
     * Only containers go through the stack; scalars are counted inline while their parent is walked.
     * Containers are Map<String, ...>, List<...> and SObject (walked through its populated fields, plus
     * a fixed 128 for the attributes entry). Anything else (Set, Map with a non-String key, Apex objects,
     * enums) throws McpConfigurationException before anything is serialized: its size cannot be bounded.
     */
    public static Long estimateBytes(Object root, Integer maxNodes, Integer maxDepth, Integer maxCollection) {
        if (!isContainer(root)) {
            return scalarBytes(root);
        }
        List<Object> stack = new List<Object>{ root };
        List<Integer> depths = new List<Integer>{ 0 };
        Long total = 0;
        Integer nodes = 1;
        while (!stack.isEmpty()) {
            Integer last = stack.size() - 1;
            Object container = stack.remove(last);
            Integer depth = depths.remove(last);
            Integer childDepth = depth + 1;
            List<Object> children;
            // List first: Apex answers true to "List<Account> instanceof SObject".
            if (container instanceof List<Object>) {
                children = (List<Object>) container;
                if (children.size() > maxCollection) { return -1; }
                total += 2 + children.size();
            } else {
                Map<String, Object> m;
                if (container instanceof Map<String, Object>) {
                    m = (Map<String, Object>) container;
                } else {
                    total += SOBJECT_OVERHEAD;
                    m = ((SObject) container).getPopulatedFieldsAsMap();
                }
                if (m.size() > maxCollection) { return -1; }
                total += 2;
                children = new List<Object>();
                for (String key : m.keySet()) {
                    total += key.length() + 4;
                    children.add(m.get(key));
                }
            }
            nodes += children.size();
            if (depth >= maxDepth || nodes + stack.size() > maxNodes) { return -1; }
            for (Object child : children) {
                if (child instanceof String) {
                    total += ((String) child).length() + 2;
                } else if (isContainer(child)) {
                    stack.add(child);
                    depths.add(childDepth);
                } else {
                    total += scalarBytes(child);
                }
            }
        }
        return total;
    }

    private static Long scalarBytes(Object value) {
        if (value == null || value instanceof Boolean || value instanceof Integer || value instanceof Long
            || value instanceof Decimal || value instanceof Double) {
            return SCALAR_ESTIMATE;
        }
        if (value instanceof String) { return ((String) value).length() + 2; }
        // Address extends Location; count its text before the fixed-size coordinate case.
        if (value instanceof System.Address) {
            System.Address address = (System.Address) value;
            Long bytes = 256;
            for (String part : new List<String>{ address.getStreet(), address.getCity(),
                address.getState(), address.getStateCode(), address.getPostalCode(),
                address.getCountry(), address.getCountryCode(), address.getGeocodeAccuracy() }) {
                if (part != null) { bytes += (Long) part.length() * 6; }
            }
            return bytes;
        }
        if (value instanceof System.Location) { return 128; }
        if (value instanceof Blob) { return (Long) ((Blob) value).size() * 4 / 3 + 2; }
        if (value instanceof Date || value instanceof Datetime || value instanceof Time || value instanceof Id) {
            return TEMPORAL_ESTIMATE;
        }
        throw new McpConfigurationException(UNSUPPORTED_VALUE);
    }

    /** Walk with the default depth and collection limits and a node budget derived from the byte limit. */
    public static Long estimateBytes(Object root, Integer byteLimit) {
        return estimateBytes(root, nodeLimit(byteLimit), WALK_MAX_DEPTH, WALK_MAX_COLLECTION);
    }

    /** One node needs at least two serialized bytes; 1 node per 8 bytes of budget keeps CPU bounded. */
    public static Integer nodeLimit(Integer byteLimit) {
        return Math.min(WALK_MAX_NODES, Math.max(WALK_MIN_NODES, byteLimit / 8));
    }
}
