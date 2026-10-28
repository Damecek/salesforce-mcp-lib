@IsTest
private class McpSchemaTest {
    private static List<String> check(McpSchema schema, Object value) {
        return schema.validate(value, '$');
    }

    private static void assertValid(McpSchema schema, Object value) {
        Assert.areEqual(new List<String>(), check(schema, value), 'value ' + JSON.serialize(value));
    }

    private static void assertInvalid(McpSchema schema, Object value, String expectedFragment) {
        List<String> errors = check(schema, value);
        Assert.areEqual(1, errors.size(), 'value ' + JSON.serialize(value) + ' errors ' + errors);
        Assert.isTrue(errors[0].contains(expectedFragment), errors[0]);
    }

    private static Exception registrationError(Map<String, Object> rawInput, Map<String, Object> rawOutput) {
        McpTool tool = new McpTestKit.ModeTool('t', 'ok');
        if (rawInput != null) { tool.inputSchema(rawInput); }
        if (rawOutput != null) { tool.outputSchema(rawOutput); }
        try {
            new McpServer('s', '1').tool(tool);
        } catch (Exception e) {
            return e;
        }
        return null;
    }

    private static Map<String, Object> objectSchema(Map<String, Object> properties) {
        return new Map<String, Object>{ 'type' => 'object', 'properties' => properties };
    }

    // ---------------------------------------------------------------- validation subset

    @IsTest
    static void stringKeywords() {
        McpSchema s = McpSchema.str().minLength(2).maxLength(4);
        assertValid(s, 'ab');
        assertValid(s, 'abcd');
        assertInvalid(s, 'a', 'at least 2');
        assertInvalid(s, 'abcde', 'at most 4');
        assertInvalid(s, 5, 'must be a string');
        assertInvalid(s, true, 'must be a string');
        assertInvalid(s, null, 'must not be null');
        assertInvalid(s, new List<Object>(), 'must be a string');
    }

    @IsTest
    static void enumKeyword() {
        McpSchema s = McpSchema.enumOf(new List<String>{ 'red', 'green' });
        assertValid(s, 'red');
        assertInvalid(s, 'blue', 'one of red, green');
        assertInvalid(s, 'RED', 'one of red, green');
        assertInvalid(s, 'Green', 'one of red, green');
        assertInvalid(McpSchema.enumOf(new List<String>{ 'a', null }), 'b', 'one of');
        assertInvalid(s, 1, 'must be a string');
        Exception caught;
        try { McpSchema.enumOf(new List<String>()); } catch (McpConfigurationException e) { caught = e; }
        Assert.isNotNull(caught);
        caught = null;
        try { McpSchema.enumOf(null); } catch (McpConfigurationException e) { caught = e; }
        Assert.isNotNull(caught);
    }

    @IsTest
    static void integerKeywords() {
        McpSchema s = McpSchema.integer().minimum(1).maximum(10);
        assertValid(s, 5);
        assertValid(s, 5L);
        assertValid(s, 1);
        assertValid(s, 10);
        assertValid(s, 5.0);
        assertValid(s, Decimal.valueOf('5.00'));
        assertInvalid(s, 0, 'at least 1');
        assertInvalid(s, 11, 'at most 10');
        assertInvalid(s, 5.5, 'must be an integer');
        assertInvalid(s, 'five', 'must be an integer');
        assertInvalid(s, true, 'must be an integer');
        assertInvalid(s, null, 'must not be null');
    }

    @IsTest
    static void numberKeywords() {
        McpSchema s = McpSchema.num().minimum(0.5).maximum(2.5);
        assertValid(s, 1);
        assertValid(s, 1.25);
        assertValid(s, 2L);
        assertValid(s, Double.valueOf(1.5));
        assertInvalid(s, 0.25, 'at least 0.5');
        assertInvalid(s, 3, 'at most 2.5');
        assertInvalid(s, 'x', 'must be a number');
        assertInvalid(s, new Map<String, Object>(), 'must be a number');
    }

    @IsTest
    static void booleanAndNullable() {
        assertValid(McpSchema.bool(), true);
        assertValid(McpSchema.bool(), false);
        assertInvalid(McpSchema.bool(), 'true', 'must be a boolean');
        assertInvalid(McpSchema.bool(), 1, 'must be a boolean');
        assertValid(McpSchema.bool().nullable(), null);
        assertValid(McpSchema.str().nullable(), null);
        assertInvalid(McpSchema.str().nullable(), 5, 'must be a string');
    }

    @IsTest
    static void arrayKeywords() {
        McpSchema s = McpSchema.arr(McpSchema.integer()).minItems(1).maxItems(3);
        assertValid(s, new List<Object>{ 1 });
        assertValid(s, new List<Object>{ 1, 2, 3 });
        assertInvalid(s, new List<Object>(), 'at least 1 items');
        assertInvalid(s, new List<Object>{ 1, 2, 3, 4 }, 'at most 3 items');
        assertInvalid(s, 'x', 'must be an array');
        List<String> itemErrors = check(s, new List<Object>{ 1, 'two', 3 });
        Assert.areEqual(new List<String>{ '$[1]: must be an integer' }, itemErrors);
        assertValid(McpSchema.arr(null), new List<Object>{ 1, 'anything' });
    }

    @IsTest
    static void objectKeywords() {
        McpSchema s = McpSchema.obj()
            .requiredProperty('name', McpSchema.str())
            .property('age', McpSchema.integer())
            .property('tags', McpSchema.arr(McpSchema.str()))
            .property('address', McpSchema.obj().requiredProperty('zip', McpSchema.str()));
        assertValid(s, new Map<String, Object>{ 'name' => 'Ada' });
        assertValid(s, new Map<String, Object>{ 'name' => 'Ada', 'extra' => 1 });
        assertInvalid(s, new Map<String, Object>(), '$.name: is required');
        assertInvalid(s, new Map<String, Object>{ 'name' => 'Ada', 'age' => 'x' }, '$.age: must be an integer');
        assertInvalid(s, new Map<String, Object>{ 'name' => 'Ada', 'tags' => new List<Object>{ 1 } }, '$.tags[0]: must be a string');
        assertInvalid(s, new Map<String, Object>{ 'name' => 'Ada', 'address' => new Map<String, Object>() }, '$.address.zip: is required');
        assertInvalid(s, 'x', 'must be an object');
        assertInvalid(s, new List<Object>(), 'must be an object');
        assertInvalid(s, new Map<String, Object>{ 'name' => null }, '$.name: must not be null');
        assertInvalid(s.closed(), new Map<String, Object>{ 'name' => 'Ada', 'extra' => 1 }, '$.extra: is not allowed');
    }

    @IsTest
    static void validationStopsAtTenErrors() {
        List<Object> bad = new List<Object>();
        for (Integer i = 0; i < 30; i++) { bad.add('x'); }
        List<String> errors = check(McpSchema.arr(McpSchema.integer()), bad);
        Assert.areEqual(10, errors.size());
        Map<String, Object> manyProps = new Map<String, Object>();
        McpSchema obj = McpSchema.obj().closed();
        for (Integer i = 0; i < 25; i++) { manyProps.put('p' + i, 1); }
        Assert.areEqual(10, check(obj, manyProps).size());
        McpSchema req = McpSchema.obj();
        for (Integer i = 0; i < 25; i++) { req.requiredProperty('r' + i, McpSchema.str()); }
        Assert.areEqual(10, check(req, new Map<String, Object>()).size());
    }

    // ---------------------------------------------------------------- builder output

    @IsTest
    static void toMapEmitsAnnotationsAndKeywords() {
        Map<String, Object> m = McpSchema.obj().title('T').describe('D').format('f').defaultValue(null)
            .requiredProperty('a', McpSchema.str().minLength(1).maxLength(2).defaultValue('z'))
            .property('n', McpSchema.num().minimum(0).maximum(1).nullable())
            .property('e', McpSchema.enumOf(new List<String>{ 'x' }))
            .property('l', McpSchema.arr(McpSchema.bool()).minItems(0).maxItems(9))
            .closed().toMap();
        Assert.areEqual('object', m.get('type'));
        Assert.areEqual('T', m.get('title'));
        Assert.areEqual('D', m.get('description'));
        Assert.areEqual('f', m.get('format'));
        Assert.isTrue(m.containsKey('default'));
        Assert.areEqual(false, m.get('additionalProperties'));
        Assert.areEqual(new List<Object>{ 'a' }, (List<Object>) m.get('required'));
        Map<String, Object> props = (Map<String, Object>) m.get('properties');
        Assert.areEqual('z', ((Map<String, Object>) props.get('a')).get('default'));
        Assert.areEqual(new List<Object>{ 'number', 'null' }, (List<Object>) ((Map<String, Object>) props.get('n')).get('type'));
        Assert.areEqual(new List<Object>{ 'x' }, (List<Object>) ((Map<String, Object>) props.get('e')).get('enum'));
        Map<String, Object> arr = (Map<String, Object>) props.get('l');
        Assert.areEqual('boolean', ((Map<String, Object>) arr.get('items')).get('type'));
        Assert.areEqual(9, arr.get('maxItems'));
        Assert.areEqual('object', McpSchema.obj().kindName());
    }

    @IsTest
    static void builderMisuseIsRejected() {
        List<String> failures = new List<String>();
        try { McpSchema.str().property('a', McpSchema.str()); failures.add('property on string'); } catch (McpConfigurationException e) { }
        try { McpSchema.obj().property(' ', McpSchema.str()); failures.add('blank name'); } catch (McpConfigurationException e) { }
        try { McpSchema.obj().property('a', null); failures.add('null schema'); } catch (McpConfigurationException e) { }
        Assert.areEqual(new List<String>(), failures);
        McpSchema twice = McpSchema.obj().property('a', McpSchema.str()).property('a', McpSchema.integer());
        Assert.areEqual(1, ((Map<String, Object>) twice.toMap().get('properties')).size());
    }

    @IsTest
    static void toolInputRootMustBeAnObject() {
        Exception caught;
        try { new McpServer('s', '1').tool(new McpTestKit.ModeTool('t', 'ok').input(McpSchema.str())); } catch (Exception e) { caught = e; }
        Assert.isTrue(caught instanceof McpConfigurationException);
        // a non-object output root is fine
        new McpServer('s', '1').tool(new McpTestKit.ModeTool('t', 'ok').output(McpSchema.arr(McpSchema.str())));
    }

    // ---------------------------------------------------------------- raw schema registration walk

    @IsTest
    static void rawSchemaRootMustBeAnObjectForInput() {
        Assert.isNotNull(registrationError(new Map<String, Object>{ 'type' => 'string' }, null));
        Assert.isNotNull(registrationError(new Map<String, Object>(), null));
        Assert.isNotNull(registrationError(new Map<String, Object>{ 'type' => new List<Object>{ 'object', 'null' } }, null));
        Assert.isNull(registrationError(new Map<String, Object>{ 'type' => 'object' }, null));
        Assert.isNull(registrationError(null, new Map<String, Object>{ 'type' => 'array' }));
    }

    @IsTest
    static void xMcpHeaderIsRejectedAnywhere() {
        Map<String, Object> deep = objectSchema(new Map<String, Object>{
            'a' => new Map<String, Object>{ 'type' => 'string', 'x-mcp-header' => 'Region' }
        });
        Assert.isTrue(registrationError(deep, null) instanceof McpConfigurationException);
        Map<String, Object> inList = objectSchema(new Map<String, Object>{
            'a' => new Map<String, Object>{ 'anyOf' => new List<Object>{ new Map<String, Object>{ 'x-mcp-header' => 'H' } } }
        });
        Assert.isTrue(registrationError(inList, null) instanceof McpConfigurationException);
        Assert.isTrue(registrationError(null, new Map<String, Object>{ 'type' => 'object', 'x-mcp-header' => 'H' }) instanceof McpConfigurationException);
    }

    @IsTest
    static void rawSchemaTypeAndKeywordsAreCaseSensitive() {
        Assert.isTrue(registrationError(new Map<String, Object>{ 'type' => 'OBJECT' }, null) instanceof McpConfigurationException, 'OBJECT is not object');
        Assert.isTrue(registrationError(new Map<String, Object>{ 'type' => 'Object' }, null) instanceof McpConfigurationException);
        Assert.isNull(registrationError(new Map<String, Object>{ 'type' => 'object' }, null));
        Assert.isNull(registrationError(new Map<String, Object>{ 'type' => 'object', 'X-MCP-HEADER' => 'x' }, null), 'JSON Schema keywords are case-sensitive; only x-mcp-header is refused');
        // legacy tools/list drops a non-object output schema; 'OBJECT' is not an object schema
        McpTool upper = new McpTestKit.ModeTool('t', 'ok').outputSchema(new Map<String, Object>{ 'type' => 'OBJECT' });
        Assert.isFalse(McpTestKit.legacy(new McpServer('s', '1').tool(upper), 'tools/list', null).item('tools', 0).containsKey('outputSchema'));
    }

    @IsTest
    static void rawSchemaLeavesMustBeJsonNative() {
        Map<String, Object> withSet = new Map<String, Object>{ 'type' => 'object', 'default' => new Set<String>{ 'a' } };
        Assert.isTrue(registrationError(withSet, null) instanceof McpConfigurationException);
        Map<String, Object> inList = new Map<String, Object>{ 'type' => 'object', 'examples' => new List<Object>{ new Map<Integer, String>{ 1 => 'x' } } };
        Assert.isTrue(registrationError(inList, null) instanceof McpConfigurationException);
        Map<String, Object> custom = new Map<String, Object>{ 'type' => 'object', 'default' => new McpTestKit.Opaque() };
        Assert.isTrue(registrationError(custom, null) instanceof McpConfigurationException);
        Exception viaBuilder;
        try {
            new McpServer('s', '1').tool(new McpTestKit.ModeTool('t', 'ok').input(McpSchema.obj().property('a', McpSchema.str().defaultValue(new Set<String>{ 'a' }))));
        } catch (McpConfigurationException e) { viaBuilder = e; }
        Assert.isNotNull(viaBuilder);
        Map<String, Object> scalars = new Map<String, Object>{ 'type' => 'object', 'default' => new Map<String, Object>{ 'd' => Date.today(), 'n' => null, 'x' => 1.5, 'b' => true } };
        Assert.isNull(registrationError(scalars, null));
    }

    @IsTest
    static void onlyLocalRefsAreAccepted() {
        Map<String, Object> local = new Map<String, Object>{ 'type' => 'object', 'properties' => new Map<String, Object>{ 'a' => new Map<String, Object>{ '$ref' => '#/$defs/a' } } };
        Assert.isNull(registrationError(local, null));
        for (Object ref : new List<Object>{ 'https://evil.example/schema.json', 'file:///etc/passwd', 'other.json', 5, null }) {
            Map<String, Object> remote = new Map<String, Object>{ 'type' => 'object', 'properties' => new Map<String, Object>{ 'a' => new Map<String, Object>{ '$ref' => ref } } };
            Assert.isTrue(registrationError(remote, null) instanceof McpConfigurationException, 'ref ' + ref);
        }
    }

    @IsTest
    static void rawSchemaDepthIsBounded() {
        Assert.isNull(registrationError(nested(16), null), '16 nested collections are allowed');
        Assert.isTrue(registrationError(nested(17), null) instanceof McpConfigurationException);
        Assert.isTrue(registrationError(nested(500), null) instanceof McpConfigurationException, 'deep input never recurses');
    }

    private static Map<String, Object> nested(Integer levels) {
        Map<String, Object> current = new Map<String, Object>{ 'type' => 'object' };
        for (Integer i = 1; i < levels; i++) { current = new Map<String, Object>{ 'type' => 'object', 'n' => current }; }
        return current;
    }

    @IsTest
    static void cyclicRawSchemaFailsTheDepthLimit() {
        Map<String, Object> cyclic = new Map<String, Object>{ 'type' => 'object' };
        cyclic.put('self', cyclic);
        Assert.isTrue(registrationError(cyclic, null) instanceof McpConfigurationException);
    }

    @IsTest
    static void rawSchemaNodesAndCollectionsAreCountedIncludingDataLeaves() {
        Assert.isNull(registrationError(withEnum(200), null));
        Assert.isTrue(registrationError(withEnum(201), null) instanceof McpConfigurationException, 'collection limit');
        Map<String, Object> many = new Map<String, Object>{ 'type' => 'object' };
        for (Integer i = 0; i < 6; i++) { many.put('k' + i, withEnum(190).get('enum')); }
        Assert.isTrue(registrationError(many, null) instanceof McpConfigurationException, 'node limit across collections');
        Map<String, Object> bigDefault = new Map<String, Object>{ 'type' => 'object', 'default' => withEnum(300).get('enum') };
        Assert.isTrue(registrationError(bigDefault, null) instanceof McpConfigurationException, 'default data is counted too');
        Assert.isTrue(registrationError(null, withEnum(1000)) instanceof McpConfigurationException);
    }

    private static Map<String, Object> withEnum(Integer values) {
        List<Object> entries = new List<Object>();
        for (Integer i = 0; i < values; i++) { entries.add('v' + i); }
        return new Map<String, Object>{ 'type' => 'object', 'enum' => entries };
    }

    @IsTest
    static void nullRawSchemaIsRejectedDirectly() {
        Exception caught;
        try { McpSchema.checkRaw(null, true, 'label'); } catch (McpConfigurationException e) { caught = e; }
        Assert.isNotNull(caught);
    }

    @IsTest
    static void builtSchemasAreCheckedOnRegistration() {
        McpSchema big = McpSchema.obj();
        for (Integer i = 0; i < 400; i++) { big.property('p' + i, McpSchema.str()); }
        Exception caught;
        try { new McpServer('s', '1').tool(new McpTestKit.ModeTool('t', 'ok').input(big)); } catch (McpConfigurationException e) { caught = e; }
        Assert.isNotNull(caught, 'a builder schema over the collection limit is rejected');
    }
}
