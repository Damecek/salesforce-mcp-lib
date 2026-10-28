@IsTest
private class McpContentTest {
    private static final String SIZE_ERROR = 'Response exceeds the server size limit';

    public class FixedTool extends McpTool {
        private final McpToolResult fixed;
        public FixedTool(String name, McpToolResult fixed) {
            super(name);
            this.fixed = fixed;
        }
        public override McpToolResult execute(McpRequest request) {
            return fixed;
        }
    }

    private static McpTestKit.Reply callFixed(McpServer server, McpToolResult result) {
        return McpTestKit.modern(server.tool(new FixedTool('fixed', result)), 'tools/call', new Map<String, Object>{ 'name' => 'fixed' });
    }

    private static McpTestKit.Reply callFixed(McpToolResult result) {
        return callFixed(new McpServer('s', '1'), result);
    }

    private static void assertTooLarge(McpTestKit.Reply r) {
        Assert.areEqual(200, r.status);
        Assert.areEqual(-32603, r.code());
        Assert.areEqual(SIZE_ERROR, r.message());
    }

    // ---------------------------------------------------------------- wire shapes

    @IsTest
    static void textBlockShape() {
        Map<String, Object> m = McpContent.text('hi')
            .annotations(new McpAnnotations().audience(new List<String>{ 'user' }).priority(0.25).lastModified(Datetime.newInstanceGmt(2026, 5, 6, 7, 8, 9)))
            .meta('k', 'v').toMap();
        Assert.areEqual('text', m.get('type'));
        Assert.areEqual('hi', m.get('text'));
        Map<String, Object> annotations = (Map<String, Object>) m.get('annotations');
        Assert.areEqual(new List<String>{ 'user' }, (List<String>) annotations.get('audience'));
        Assert.areEqual(0.25, annotations.get('priority'));
        Assert.areEqual('2026-05-06T07:08:09.000Z', annotations.get('lastModified'));
        Assert.areEqual('v', ((Map<String, Object>) m.get('_meta')).get('k'));
        Assert.areEqual('', McpContent.text(null).toMap().get('text'));
    }

    @IsTest
    static void imageAndAudioBlockShapes() {
        Map<String, Object> image = McpContent.image(Blob.valueOf('png'), 'image/png').toMap();
        Assert.areEqual(new Set<String>{ 'type', 'data', 'mimeType' }, image.keySet());
        Assert.areEqual('image', image.get('type'));
        Assert.areEqual(EncodingUtil.base64Encode(Blob.valueOf('png')), image.get('data'));
        Assert.areEqual('image/png', image.get('mimeType'));
        Map<String, Object> imageB64 = McpContent.imageBase64('AAAA', 'image/gif').toMap();
        Assert.areEqual('AAAA', imageB64.get('data'));
        Map<String, Object> audio = McpContent.audio(Blob.valueOf('wav'), 'audio/wav').toMap();
        Assert.areEqual('audio', audio.get('type'));
        Assert.areEqual('audio/wav', audio.get('mimeType'));
        Assert.areEqual('BBBB', McpContent.audioBase64('BBBB', 'audio/mpeg').toMap().get('data'));
        Assert.areEqual('', McpContent.image(null, 'image/png').toMap().get('data'));
        Assert.areEqual('', McpContent.imageBase64(null, 'image/png').toMap().get('data'));
        Assert.areEqual('', McpContent.audio(null, 'audio/wav').toMap().get('data'));
    }

    @IsTest
    static void resourceLinkBlockShape() {
        Map<String, Object> m = McpContent.resourceLink('acme://org', 'org').title('Org').description('d').mimeType('text/plain').size(12L)
            .icon(new McpIcon('https://example.com/o.png').mimeType('image/png')).annotations(new McpAnnotations().priority(1)).meta('a', 1).toMap();
        Assert.areEqual('resource_link', m.get('type'));
        Assert.areEqual('acme://org', m.get('uri'));
        Assert.areEqual('org', m.get('name'));
        Assert.areEqual('Org', m.get('title'));
        Assert.areEqual('d', m.get('description'));
        Assert.areEqual('text/plain', m.get('mimeType'));
        Assert.areEqual(12L, m.get('size'));
        Assert.areEqual('https://example.com/o.png', ((Map<String, Object>) ((List<Object>) m.get('icons'))[0]).get('src'));
        Assert.isNotNull(m.get('annotations'));
        Assert.isNotNull(m.get('_meta'));
        Assert.areEqual(new Set<String>{ 'type', 'uri', 'name' }, McpContent.resourceLink('x://a', 'a').toMap().keySet());
    }

    @IsTest
    static void embeddedResourceBlockShape() {
        Map<String, Object> text = McpContent.embedded(McpResourceContents.text('x://a', 'text/plain', 'body').meta('m', 1)).annotations(new McpAnnotations().priority(0)).toMap();
        Assert.areEqual('resource', text.get('type'));
        Map<String, Object> resource = (Map<String, Object>) text.get('resource');
        Assert.areEqual('body', resource.get('text'));
        Assert.areEqual(1, ((Map<String, Object>) resource.get('_meta')).get('m'));
        Assert.isNotNull(text.get('annotations'));
        Map<String, Object> binary = (Map<String, Object>) McpContent.embedded(McpResourceContents.blob('x://b', 'application/pdf', Blob.valueOf('pdf'))).toMap().get('resource');
        Assert.areEqual(EncodingUtil.base64Encode(Blob.valueOf('pdf')), binary.get('blob'));
        Assert.isFalse(binary.containsKey('text'));
    }

    @IsTest
    static void linkOnlySettersRejectOtherBlocks() {
        List<McpContent> others = new List<McpContent>{
            McpContent.text('t'), McpContent.imageBase64('A', 'image/png'), McpContent.embedded(McpResourceContents.text('x://a', null, 't'))
        };
        for (McpContent block : others) {
            Integer failures = 0;
            try { block.title('x'); } catch (McpConfigurationException e) { failures++; }
            try { block.description('x'); } catch (McpConfigurationException e) { failures++; }
            try { block.mimeType('x'); } catch (McpConfigurationException e) { failures++; }
            try { block.size(1L); } catch (McpConfigurationException e) { failures++; }
            try { block.icon(new McpIcon('https://x.example/i.png')); } catch (McpConfigurationException e) { failures++; }
            Assert.areEqual(5, failures);
        }
    }

    @IsTest
    static void invalidBlocksAreRejected() {
        List<String> failures = new List<String>();
        try { McpContent.imageBase64('A', null); failures.add('image mime'); } catch (McpConfigurationException e) { }
        try { McpContent.audioBase64('A', ' '); failures.add('audio mime'); } catch (McpConfigurationException e) { }
        try { McpContent.resourceLink(null, 'n'); failures.add('link uri'); } catch (McpConfigurationException e) { }
        try { McpContent.resourceLink('x://a', ''); failures.add('link name'); } catch (McpConfigurationException e) { }
        try { McpContent.embedded(null); failures.add('embedded'); } catch (McpConfigurationException e) { }
        Assert.areEqual(new List<String>(), failures);
    }

    @IsTest
    static void toolResultBuildersCoverTheDocumentedForms() {
        Assert.areEqual(true, McpToolResult.error('x').isErrorResult());
        Assert.areEqual(1, McpToolResult.text('x').contentBlocks().size());
        Assert.isFalse(McpToolResult.text('x').hasStructuredContent());
        Assert.isTrue(McpToolResult.structured(new Map<String, Object>()).needsGeneratedText());
        Assert.isFalse(McpToolResult.structured(null).hasStructuredContent(), 'null means no structuredContent');
        Assert.isFalse(McpToolResult.structured(null).needsGeneratedText());
        Assert.isFalse(new McpToolResult().add(null).meta('a', 1).markError().contentBlocks().size() > 0);
        Assert.areEqual(1, new McpToolResult().meta('a', 1).metaValues().size());
        Assert.areEqual('v', new McpToolResult().structuredContent('v').structuredContentValue());
    }

    // ---------------------------------------------------------------- size guards

    @IsTest
    static void hugeTextIsRejectedBeforeSerialization() {
        McpToolResult huge = McpToolResult.text('a'.repeat(300000));
        McpServer server = new McpServer('s', '1').tool(new FixedTool('fixed', huge));
        Integer heapBefore = Limits.getHeapSize();
        McpTestKit.Reply r = McpTestKit.modern(server, 'tools/call', new Map<String, Object>{ 'name' => 'fixed' });
        Integer heapAfter = Limits.getHeapSize();
        assertTooLarge(r);
        // A serialized copy of 300,000 characters plus its Blob would add well over 500,000 bytes.
        Assert.isTrue(heapAfter - heapBefore < 150000, 'heap delta ' + (heapAfter - heapBefore));
    }

    @IsTest
    static void aRaisedLimitLetsTheSameTextThrough() {
        McpToolResult big = McpToolResult.text('a'.repeat(300000));
        McpServer server = new McpServer('s', '1').maxResponseBytes(1000000).tool(new FixedTool('fixed', big));
        Integer heapBefore = Limits.getHeapSize();
        McpTestKit.Reply r = McpTestKit.modern(server, 'tools/call', new Map<String, Object>{ 'name' => 'fixed' });
        Assert.areEqual(200, r.status);
        Assert.isNull(r.json.get('error'));
        Assert.isTrue(r.body.length() > 300000);
        Assert.isTrue(Limits.getHeapSize() - heapBefore > 250000, 'success path does build the response');
    }

    @IsTest
    static void everyBlockTypeCountsTowardTheLimit() {
        assertTooLarge(callFixed(McpToolResult.text('ok').add(McpContent.imageBase64('A'.repeat(300000), 'image/png'))));
        assertTooLarge(callFixed(McpToolResult.text('ok').add(McpContent.audioBase64('A'.repeat(300000), 'audio/wav'))));
        assertTooLarge(callFixed(McpToolResult.text('ok').add(McpContent.embedded(McpResourceContents.text('x://a', null, 'r'.repeat(300000))))));
        assertTooLarge(callFixed(McpToolResult.text('ok').add(McpContent.embedded(McpResourceContents.blobBase64('x://a', null, 'r'.repeat(300000))))));
        assertTooLarge(callFixed(McpToolResult.text('ok').add(McpContent.image(Blob.valueOf('b'.repeat(250000)), 'image/png'))));
    }

    @IsTest
    static void metadataAndAnnotationsCountTowardTheLimit() {
        assertTooLarge(callFixed(McpToolResult.text('x').meta('blob', 'm'.repeat(300000))));
        assertTooLarge(callFixed(McpToolResult.text('x').add(McpContent.text('y').meta('blob', 'm'.repeat(300000)))));
        assertTooLarge(callFixed(McpToolResult.text('x').add(McpContent.embedded(McpResourceContents.text('x://a', null, 't').meta('blob', 'm'.repeat(300000))))));
        assertTooLarge(callFixed(McpToolResult.text('x').add(McpContent.text('y').annotations(new McpAnnotations().audience(manyStrings(10001))))));
    }

    private static List<String> manyStrings(Integer count) {
        List<String> values = new List<String>();
        for (Integer i = 0; i < count; i++) { values.add('user'); }
        return values;
    }

    @IsTest
    static void structuredContentCountsTwiceBecauseTheTextCopyIsGenerated() {
        assertTooLarge(callFixed(McpToolResult.structured(new Map<String, Object>{ 'v' => 'c'.repeat(200000) })));
        McpTestKit.Reply fits = callFixed(McpToolResult.structured(new Map<String, Object>{ 'v' => 'c'.repeat(100000) }));
        Assert.areEqual(200, fits.status);
        Assert.isNull(fits.json.get('error'));
        Assert.isTrue(fits.body.length() > 200000 && fits.body.length() < 262144);
        // without the generated copy the same payload counts once
        McpToolResult once = new McpToolResult().structuredContent(new Map<String, Object>{ 'v' => 'c'.repeat(200000) });
        Assert.isNull(callFixed(once).json.get('error'));
    }

    @IsTest
    static void escapingGrowthIsCaughtAfterSerialization() {
        // 200,000 quotes estimate at about 200,000 bytes but serialize to 400,000 because each becomes \"
        McpTestKit.Reply r = callFixed(McpToolResult.text('"'.repeat(200000)));
        assertTooLarge(r);
        Assert.isTrue(r.body.length() < 200);
    }

    @IsTest
    static void walkLimitsRejectDeepWideAndCyclicStructures() {
        McpServer server = new McpServer('s', '1')
            .tool(new McpTestKit.ModeTool('deep', 'deep')).tool(new McpTestKit.ModeTool('many', 'many'))
            .tool(new McpTestKit.ModeTool('wide', 'wide')).tool(new McpTestKit.ModeTool('cycle', 'cycle'));
        for (String name : new List<String>{ 'deep', 'many', 'wide', 'cycle' }) {
            assertTooLarge(McpTestKit.modern(server, 'tools/call', new Map<String, Object>{ 'name' => name }));
        }
    }

    @IsTest
    static void aLimitRaisedToTheCeilingStillObeysTheHeapBudget() {
        // 5,000,000 characters estimate at 5 MB: 3x of that is far above the remaining 10 MB or 6 MB heap.
        McpToolResult huge = McpToolResult.text('z'.repeat(2500000));
        McpServer server = new McpServer('s', '1').maxResponseBytes(6000000);
        Integer remaining = Limits.getLimitHeapSize() - Limits.getHeapSize();
        McpTestKit.Reply r = callFixed(server, huge);
        if (2500000L * 3 > remaining) {
            assertTooLarge(r);
        } else {
            Assert.isNull(r.json.get('error'));
        }
    }

    @IsTest
    static void legacyEraGetsTheSameGuard() {
        McpServer server = new McpServer('s', '1').tool(new FixedTool('fixed', McpToolResult.text('a'.repeat(300000))));
        McpTestKit.Reply r = McpTestKit.legacy(server, 'tools/call', new Map<String, Object>{ 'name' => 'fixed' });
        Assert.areEqual(-32603, r.code());
        Assert.areEqual(SIZE_ERROR, r.message());
    }

    @IsTest
    static void largeListingsAreGuardedToo() {
        McpServer server = new McpServer('s', '1').pageSize(100);
        for (Integer i = 0; i < 100; i++) {
            server.tool(new McpTestKit.ModeTool('tool_' + i, 'ok').description('d'.repeat(4000)));
        }
        assertTooLarge(McpTestKit.modern(server, 'tools/list', null));
    }

    // ---------------------------------------------------------------- opaque values fail closed

    private static void assertRefusedBeforeSerialization(McpToolResult result, Integer maxHeapGrowth, String label) {
        McpServer server = new McpServer('s', '1').tool(new FixedTool('fixed', result));
        Integer heapBefore = Limits.getHeapSize();
        McpTestKit.Reply modern = McpTestKit.modern(server, 'tools/call', new Map<String, Object>{ 'name' => 'fixed' });
        Integer growth = Limits.getHeapSize() - heapBefore;
        Assert.areEqual(200, modern.status, label);
        Assert.areEqual(-32603, modern.code(), label);
        Assert.areEqual('Internal error', modern.message(), label);
        Assert.isTrue(modern.body.length() < 200, label);
        Assert.isTrue(growth < maxHeapGrowth, label + ': heap grew by ' + growth + ', so the value was serialized or copied');
        Assert.areEqual(-32603, McpTestKit.legacy(server, 'tools/call', new Map<String, Object>{ 'name' => 'fixed' }).code(), label + ' (legacy)');
    }

    @IsTest
    static void aTwentyThousandItemSetIsRefusedWithoutBeingSerialized() {
        Set<String> items = new Set<String>();
        for (Integer i = 0; i < 20000; i++) { items.add('item-number-' + i); }
        // serialized it would be about 340,000 bytes, twice with the generated text
        assertRefusedBeforeSerialization(McpToolResult.structured(new Map<String, Object>{ 'items' => items }), 100000, 'set in structured()');
        assertRefusedBeforeSerialization(McpToolResult.structured(items), 100000, 'set as the root');
        assertRefusedBeforeSerialization(new McpToolResult().structuredContent(new Map<String, Object>{ 'items' => items }), 100000, 'set in structuredContent()');
    }

    @IsTest
    static void aHundredThousandValueMapWithNonStringKeysIsRefusedWithoutBeingSerialized() {
        Map<Integer, Integer> numbered = new Map<Integer, Integer>();
        for (Integer i = 0; i < 100000; i++) { numbered.put(i, i); }
        assertRefusedBeforeSerialization(McpToolResult.structured(new Map<String, Object>{ 'byNumber' => numbered }), 100000, 'Map<Integer, Integer>');
        Map<Id, Integer> byId = new Map<Id, Integer>{ UserInfo.getUserId() => 1 };
        assertRefusedBeforeSerialization(McpToolResult.structured(new Map<String, Object>{ 'byId' => byId }), 100000, 'Map<Id, Integer>');
    }

    @IsTest
    static void customObjectsAndEnumsAreRefusedEverywhereAResultCanCarryData() {
        assertRefusedBeforeSerialization(McpToolResult.structured(new Map<String, Object>{ 'o' => new McpTestKit.Opaque() }), 100000, 'custom object');
        assertRefusedBeforeSerialization(McpToolResult.structured(new List<Object>{ Schema.DisplayType.STRING }), 100000, 'enum');
        assertRefusedBeforeSerialization(McpToolResult.text('x').meta('k', new Set<String>{ 'a' }), 100000, 'result _meta');
        assertRefusedBeforeSerialization(McpToolResult.text('x').add(McpContent.text('y').meta('k', new McpTestKit.Opaque())), 100000, 'content _meta');
        assertRefusedBeforeSerialization(McpToolResult.text('x').add(McpContent.embedded(McpResourceContents.text('x://a', null, 't').meta('k', new Set<Integer>{ 1 }))), 100000, 'embedded _meta');
        McpServer withMeta = new McpServer('s', '1').tool(new McpTestKit.ModeTool('t', 'ok').meta('k', new Set<String>{ 'a' }));
        Assert.areEqual(-32603, McpTestKit.modern(withMeta, 'tools/list', null).code(), 'tool _meta is walked before the list is serialized');
        Assert.areEqual(-32603, McpTestKit.legacy(withMeta, 'tools/list', null).code());
    }

    @IsTest
    static void wideSObjectsAreSizedByTheirPopulatedFieldsBeforeSerialization() {
        List<Account> wide = new List<Account>();
        for (Integer i = 0; i < 10; i++) { wide.add(new Account(Name = 'wide ' + i, Description = 'd'.repeat(32000))); }
        // about 322,000 bytes of fields: over the 262,144 limit before anything is serialized or doubled
        McpToolResult tooBig = McpToolResult.structured(new Map<String, Object>{ 'records' => wide });
        McpServer server = new McpServer('s', '1').tool(new FixedTool('fixed', tooBig));
        Integer heapBefore = Limits.getHeapSize();
        McpTestKit.Reply r = McpTestKit.modern(server, 'tools/call', new Map<String, Object>{ 'name' => 'fixed' });
        assertTooLarge(r);
        Assert.isTrue(Limits.getHeapSize() - heapBefore < 150000, 'heap grew by ' + (Limits.getHeapSize() - heapBefore));
        Assert.isTrue(McpWire.estimateBytes(new Map<String, Object>{ 'records' => wide }, 262144) > 320000, 'the estimate is of the right magnitude');
        // three such records are 96,000 bytes, 192,000 with the generated text: they fit
        McpTestKit.Reply fits = callFixed(McpToolResult.structured(new Map<String, Object>{ 'records' => new List<Account>{ wide[0], wide[1], wide[2] } }));
        Assert.areEqual(200, fits.status);
        Assert.isNull(fits.json.get('error'));
        Assert.isTrue(fits.body.length() > 190000 && fits.body.length() < 262144, 'body ' + fits.body.length());
        Map<String, Object> structured = (Map<String, Object>) fits.result().get('structuredContent');
        Assert.areEqual(3, ((List<Object>) structured.get('records')).size());
        Assert.areEqual('wide 1', ((Map<String, Object>) ((List<Object>) structured.get('records'))[1]).get('Name'));
    }

    @IsTest
    static void jsonNativeValuesOfAnyTypedShapeKeepTheirPrecisionAndNulls() {
        Map<String, Object> value = new Map<String, Object>{
            'decimal' => Decimal.valueOf('12345678901234567890.123456789'),
            'long' => 9223372036854775807L,
            'date' => Date.newInstance(2026, 1, 2),
            'id' => UserInfo.getUserId(),
            'strings' => new List<String>{ 'a', null },
            'typedMap' => new Map<String, String>{ 'k' => null, 'j' => 'v' },
            'listOfMaps' => new List<Map<String, Object>>{ new Map<String, Object>{ 'z' => null } },
            'nested' => new Map<String, Object>{ 'a' => new List<Object>{ null, new Map<String, Object>{ 'deep' => null } } },
            'record' => new Account(Name = 'n'),
            'blob' => Blob.valueOf('b')
        };
        McpTestKit.Reply r = callFixed(McpToolResult.structured(value));
        Assert.areEqual(200, r.status);
        Assert.isNull(r.json.get('error'));
        for (String expected : new List<String>{ '12345678901234567890.123456789', '9223372036854775807', '"2026-01-02"', '"k":null', '"deep":null', '"z":null', '"Name":"n"', '"strings":["a",null]' }) {
            Assert.isTrue(r.body.contains(expected), expected + ' in ' + r.body.left(400));
        }
        Map<String, Object> structured = (Map<String, Object>) r.result().get('structuredContent');
        Assert.isTrue(structured.containsKey('typedMap'));
        Assert.isNull(((Map<String, Object>) structured.get('typedMap')).get('k'));
        Assert.isTrue(((Map<String, Object>) structured.get('typedMap')).containsKey('k'));
        Assert.areEqual(2, ((List<Object>) structured.get('strings')).size());
    }
}
