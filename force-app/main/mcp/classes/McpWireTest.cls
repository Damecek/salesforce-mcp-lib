@IsTest
private class McpWireTest {
    @IsTest
    static void normalizeIdKeepsStringsIntegersAndLongs() {
        Assert.areEqual('abc', McpWire.normalizeId('abc'));
        Assert.areEqual(5, McpWire.normalizeId(5));
        Assert.areEqual(9007199254740991L, McpWire.normalizeId(9007199254740991L));
        Assert.areEqual(9223372036854775807L, McpWire.normalizeId(9223372036854775807L));
    }

    @IsTest
    static void normalizeIdConvertsOnlyIntegralDecimalsInRange() {
        Assert.areEqual(5L, McpWire.normalizeId(5.0));
        Assert.areEqual(100L, McpWire.normalizeId(Decimal.valueOf('1E+2')));
        Assert.areEqual(-7L, McpWire.normalizeId(Decimal.valueOf('-7.000')));
        Assert.areEqual(9223372036854775807L, McpWire.normalizeId(Decimal.valueOf('9223372036854775807')));
        Assert.isNull(McpWire.normalizeId(1.5));
        Assert.isNull(McpWire.normalizeId(Decimal.valueOf('9223372036854775808')));
        Assert.isNull(McpWire.normalizeId(Decimal.valueOf('-9223372036854775809')));
        Assert.isNull(McpWire.normalizeId(Decimal.valueOf('1E+400')));
        Assert.isNull(McpWire.normalizeId(true));
        Assert.isNull(McpWire.normalizeId(null));
        Assert.isNull(McpWire.normalizeId(new Map<String, Object>()));
        Assert.isNull(McpWire.normalizeId(new List<Object>()));
    }

    @IsTest
    static void envelopesOmitMissingIdsAndNullData() {
        Map<String, Object> ok = McpWire.resultEnvelope(null, new Map<String, Object>());
        Assert.isFalse(ok.containsKey('id'));
        Assert.areEqual('2.0', ok.get('jsonrpc'));
        Map<String, Object> err = McpWire.errorEnvelope(7, -32602, 'm', null);
        Assert.areEqual(7, err.get('id'));
        Assert.isFalse(((Map<String, Object>) err.get('error')).containsKey('data'));
        Map<String, Object> withData = McpWire.errorEnvelope(null, -32602, 'm', 'd');
        Assert.isFalse(withData.containsKey('id'));
        Assert.areEqual('d', ((Map<String, Object>) withData.get('error')).get('data'));
    }

    @IsTest
    static void headerValuesDecodeOrFailWithHeaderMismatch() {
        Assert.areEqual('plain value', McpWire.decodeHeaderValue('plain value', 'H'));
        Assert.areEqual('tab\there', McpWire.decodeHeaderValue('tab\there', 'H'));
        Assert.areEqual('Hello', McpWire.decodeHeaderValue('=?base64?SGVsbG8=?=', 'H'));
        Assert.areEqual('Hello, \u4e16\u754c', McpWire.decodeHeaderValue('=?base64?' + EncodingUtil.base64Encode(Blob.valueOf('Hello, \u4e16\u754c')) + '?=', 'H'));
        Assert.areEqual('=?base64?', McpWire.decodeHeaderValue('=?base64?', 'H'), 'an unterminated sentinel is a plain value');
        for (String bad : new List<String>{ '=?base64?%%%%?=', '=?base64?SGVsbG8?=', '=?base64??=', 'caf\u00e9', 'a\u007fb', 'a\nb' }) {
            Exception caught;
            try { McpWire.decodeHeaderValue(bad, 'Mcp-Name'); } catch (McpProtocolException e) { caught = e; }
            Assert.isNotNull(caught, bad);
            Assert.areEqual(-32020, ((McpProtocolException) caught).errorCode);
            Assert.areEqual(400, ((McpProtocolException) caught).httpStatus);
            Assert.areEqual('Invalid Mcp-Name header', caught.getMessage());
        }
    }

    private static Long est(Object value) {
        return McpWire.estimateBytes(value, McpWire.WALK_MIN_NODES, McpWire.WALK_MAX_DEPTH, McpWire.WALK_MAX_COLLECTION);
    }

    @IsTest
    static void estimateCountsEveryKindOfValue() {
        Assert.areEqual(3, est('a'));
        Assert.areEqual(4, est(null));
        Assert.areEqual(4, est(5));
        Assert.areEqual(4, est(true));
        Assert.areEqual(12, est(Date.newInstance(2026, 1, 1)));
        Assert.areEqual(12, est(Datetime.now()));
        Assert.areEqual(12, est(Time.newInstance(1, 2, 3, 4)));
        Assert.isTrue(est(UserInfo.getUserId()) >= 12);
        Assert.areEqual(128 + 2 + (4 + 4) + 3, est(new Account(Name = 'x')), 'an SObject is its populated fields plus 128 for attributes');
        Assert.areEqual(12, est(Blob.valueOf('12345678')), 'blobs count their base64 size');
        Assert.areEqual(2 + 3 + 4 + 7, est(new Map<String, Object>{ 'key' => 'value' }));
        Assert.areEqual(2 + 2 + 6, est(new List<Object>{ 'a', 'b' }));
        Assert.areEqual(2 + (1 + 4) + 4, est(new Map<String, String>{ 'k' => 'vv' }), 'typed maps are walked as maps');
        Assert.areEqual(2 + 1 + 3, est(new List<String>{ 'a' }), 'typed lists are walked as lists');
        Assert.areEqual(2 + 1 + 141, est(new List<Account>{ new Account(Name = 'x') }), 'lists of SObjects count each record');
        Assert.areEqual(2 + (1 + 4) + (2 + 2 + 4 + 4), est(new Map<String, List<Integer>>{ 'k' => new List<Integer>{ 1, 2 } }));
    }

    @IsTest
    static void compoundAddressAndLocationAreBounded() {
        Account account = new Account(Name = 'compound', BillingStreet = 's'.repeat(200),
            BillingCity = 'Prague', BillingPostalCode = '11000');
        insert account;
        account = [SELECT BillingAddress FROM Account WHERE Id = :account.Id];
        System.Address address = account.BillingAddress;
        Assert.isNotNull(address);
        Assert.isTrue(est(address) >= JSON.serialize(address).length());
        Assert.isTrue(est(account) >= JSON.serialize(account).length());
        System.Location location = System.Location.newInstance(50.0755, 14.4378);
        Assert.isTrue(est(location) >= JSON.serialize(location).length());
    }

    @IsTest
    static void estimateReturnsMinusOneWhenALimitIsHit() {
        Assert.areEqual(-1, McpWire.estimateBytes(new List<Object>{ 1, 2, 3, 4 }, 3, 10, 10));
        Assert.areEqual(-1, McpWire.estimateBytes(new List<Object>{ 1, 2, 3, 4 }, 100, 10, 3));
        Assert.areEqual(-1, McpWire.estimateBytes(new List<Object>{ new List<Object>{ new List<Object>{ 1 } } }, 100, 2, 10));
        Assert.areEqual(-1, McpWire.estimateBytes(new Map<String, Object>{ 'a' => 1, 'b' => 2 }, 100, 10, 1));
        Assert.isTrue(McpWire.estimateBytes(new List<Object>{ 1, 2, 3 }, 4, 10, 10) > 0);
        Assert.areEqual(25000, McpWire.nodeLimit(1024));
        Assert.areEqual(32768, McpWire.nodeLimit(262144));
        Assert.areEqual(200000, McpWire.nodeLimit(6000000));
    }

    @IsTest
    static void aWideSObjectIsSizedByItsPopulatedFields() {
        Account wide = new Account(Name = 'wide', Description = 'd'.repeat(30000), BillingStreet = 's'.repeat(200));
        Long estimate = est(wide);
        Long actual = JSON.serialize(wide).length();
        Assert.isTrue(estimate > 30200, 'estimate ' + estimate);
        Assert.isTrue(Math.abs(estimate - actual) < 300, 'estimate ' + estimate + ' actual ' + actual);
        Assert.areEqual(-1, McpWire.estimateBytes(new List<Account>{ wide, wide, wide }, 5, 10, 10), 'record fields count as nodes');
    }

    @IsTest
    static void anSObjectGraphIsBoundedByDepthLikeAnyOtherContainer() {
        Contact c = new Contact(LastName = 'c');
        Assert.areEqual(-1, McpWire.estimateBytes(c, 100, 0, 10), 'depth 0 allows no container at all');
        Assert.isTrue(est(new Map<String, Object>{ 'contact' => c, 'nothing' => null }) > 128);
    }

    @IsTest
    static void unsupportedTypesAreRefusedWithoutBeingSerialized() {
        Set<String> big = new Set<String>();
        Map<Integer, String> numbered = new Map<Integer, String>();
        for (Integer i = 0; i < 20000; i++) {
            big.add('item-' + i);
            numbered.put(i, 'v' + i);
        }
        List<Object> opaque = new List<Object>{
            big, new Set<Integer>{ 1 }, numbered, new Map<Id, String>{ UserInfo.getUserId() => 'x' }, new McpTestKit.Opaque(),
            new Map<String, Object>{ 'nested' => big }, new List<Object>{ new List<Object>{ big } }, Schema.DisplayType.STRING
        };
        for (Object value : opaque) {
            Integer heapBefore = Limits.getHeapSize();
            Exception caught;
            try { est(value); } catch (McpConfigurationException e) { caught = e; }
            Assert.isNotNull(caught, 'refused');
            Assert.isTrue(caught.getMessage().contains('JSON-native'), caught.getMessage());
            Assert.isTrue(Limits.getHeapSize() - heapBefore < 20000, 'refusing allocates nothing proportional to the data: ' + (Limits.getHeapSize() - heapBefore));
        }
    }

    @IsTest
    static void caseSensitiveComparison() {
        Assert.isTrue(McpWire.same('tools/list', 'tools/list'));
        Assert.isFalse(McpWire.same('TOOLS/LIST', 'tools/list'));
        Assert.isFalse(McpWire.same('Tools/List', 'tools/list'));
        Assert.isFalse(McpWire.same(null, 'x'));
        Assert.isFalse(McpWire.same(null, null));
        Assert.isFalse(McpWire.same(5, 'x'));
        Assert.isFalse(McpWire.same('x', null));
        Assert.isTrue(McpWire.same((Object) 'dev_echo', 'dev_echo'));
        Assert.isFalse(McpWire.same((Object) 'DEV_ECHO', 'dev_echo'));
    }

    @IsTest
    static void base64HeaderValuesKeepTheirCase() {
        Assert.areEqual('Dev_Echo', McpWire.decodeHeaderValue('=?base64?' + EncodingUtil.base64Encode(Blob.valueOf('Dev_Echo')) + '?=', 'H'));
        Assert.areEqual('=?BASE64?SGVsbG8=?=', McpWire.decodeHeaderValue('=?BASE64?SGVsbG8=?=', 'H'), 'the sentinel is case-sensitive');
    }

    // ---------------------------------------------------------------- lexical nesting guard

    private static String nest(Integer levels) {
        return '['.repeat(levels) + ']'.repeat(levels);
    }

    @IsTest
    static void nestingLimitIsTheWalkDepth() {
        Assert.areEqual(32, McpWire.WALK_MAX_DEPTH);
        Assert.isFalse(McpWire.nestsDeeperThan(nest(32), 32));
        Assert.isTrue(McpWire.nestsDeeperThan(nest(33), 32));
        Assert.isFalse(McpWire.nestsDeeperThan('{"a":' + nest(31) + '}', 32), 'objects and arrays count alike');
        Assert.isTrue(McpWire.nestsDeeperThan('{"a":' + nest(32) + '}', 32));
        Assert.isTrue(McpWire.nestsDeeperThan('{"a":'.repeat(33) + '1' + '}'.repeat(33), 32));
        Assert.isFalse(McpWire.nestsDeeperThan('[]'.repeat(5000), 32), 'siblings are not nesting');
        Assert.isFalse(McpWire.nestsDeeperThan('', 32));
        // the estimate and the guard agree on the same boundary
        Assert.isTrue(McpWire.estimateBytes(JSON.deserializeUntyped(nest(32)), 100, 32, 10) >= 0);
        Assert.areEqual(-1, McpWire.estimateBytes(JSON.deserializeUntyped(nest(33)), 100, 32, 10));
    }

    @IsTest
    static void bracketsInsideStringsAreNotNesting() {
        Assert.isFalse(McpWire.nestsDeeperThan('{"a":"' + '['.repeat(100) + '","b":"' + '{'.repeat(100) + '"}', 32));
        Assert.isFalse(McpWire.nestsDeeperThan('["' + '[{'.repeat(500) + '"]', 32));
        // closers inside strings must not lower the depth of real nesting
        Assert.isTrue(McpWire.nestsDeeperThan('{"s":"' + ']'.repeat(100) + '","b":' + nest(32) + '}', 32));
        Assert.isFalse(McpWire.nestsDeeperThan('{"s":"' + ']'.repeat(100) + '","b":' + nest(30) + '}', 32));
    }

    @IsTest
    static void escapesInsideStringsAreHonoured() {
        // \" is an escaped quote: the string goes on, the brackets after it are still text
        Assert.isFalse(McpWire.nestsDeeperThan('{"a":"x\\"' + '['.repeat(60) + '"}', 32));
        // \\" is an escaped backslash then the closing quote: the brackets after it are real
        Assert.isTrue(McpWire.nestsDeeperThan('{"a":"x\\\\","b":' + nest(40) + '}', 32));
        Assert.isFalse(McpWire.nestsDeeperThan('{"a":"x\\\\","b":' + nest(20) + ',"c":"' + '['.repeat(50) + '"}', 32));
        // three backslashes: escaped backslash plus escaped quote, the string continues
        Assert.isFalse(McpWire.nestsDeeperThan('{"a":"x\\\\\\"' + '['.repeat(60) + '"}', 32));
        Assert.isFalse(McpWire.nestsDeeperThan('{"a":"' + '\\\\'.repeat(5000) + '"}' + '{}'.repeat(40), 32));
    }

    @IsTest
    static void malformedTextIsNeverTheGuardsBusiness() {
        Assert.isFalse(McpWire.nestsDeeperThan('{"a":"unterminated' + '['.repeat(100), 32), 'an open string swallows the rest');
        Assert.isFalse(McpWire.nestsDeeperThan(']'.repeat(100) + '[]'.repeat(50), 32), 'stray closers do not go below zero');
        Assert.isTrue(McpWire.nestsDeeperThan('[' .repeat(40) + 'garbage', 32));
    }

    private static void assertCheap(List<String> bodies) {
        for (String body : bodies) {
            Integer cpuBefore = Limits.getCpuTime();
            McpWire.nestsDeeperThan(body, 32);
            Assert.isTrue(Limits.getCpuTime() - cpuBefore < 3000, 'cpu ms ' + (Limits.getCpuTime() - cpuBefore) + ' for ' + body.left(20));
        }
    }

    @IsTest
    static void hostileStringBodiesAreCheapToExamine() {
        assertCheap(new List<String>{
            '{"k":"' + 'a'.repeat(240000) + '"}' + '{}'.repeat(40),
            '"' + '\\"'.repeat(80000) + '"' + '[]'.repeat(40),
            '["' + '[{'.repeat(120000) + '"]'
        });
        Integer cpuBefore = Limits.getCpuTime();
        Assert.isTrue(McpWire.nestsDeeperThan('['.repeat(120000) + ']'.repeat(120000), 32));
        Assert.isTrue(McpWire.nestsDeeperThan('{"a":'.repeat(48000), 32));
        Assert.isTrue(Limits.getCpuTime() - cpuBefore < 100, 'a deep body is rejected after 33 brackets');
    }

    @IsTest
    static void hostileStructureBodiesAreCheapToExamine() {
        assertCheap(new List<String>{
            '{"a":1,"b":"x[y"},'.repeat(13000),
            '0,'.repeat(120000) + '[]'.repeat(40),
            '[]'.repeat(120000)
        });
    }
}
