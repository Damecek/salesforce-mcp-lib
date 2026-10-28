@IsTest
private class McpCompletionTest {
    private static Map<String, Object> promptRef(String name, String arg, String value) {
        return new Map<String, Object>{
            'ref' => new Map<String, Object>{ 'type' => 'ref/prompt', 'name' => name },
            'argument' => new Map<String, Object>{ 'name' => arg, 'value' => value }
        };
    }

    private static Map<String, Object> templateRef(String uri, String arg, String value) {
        return new Map<String, Object>{
            'ref' => new Map<String, Object>{ 'type' => 'ref/resource', 'uri' => uri },
            'argument' => new Map<String, Object>{ 'name' => arg, 'value' => value }
        };
    }

    private static Map<String, Object> completion(McpTestKit.Reply r) {
        return (Map<String, Object>) r.result().get('completion');
    }

    @IsTest
    static void promptArgumentCompletion() {
        McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'completion/complete', promptRef('greet', 'name', 'A'));
        Assert.areEqual(200, r.status);
        Assert.areEqual(new List<Object>{ 'Ada', 'Alan' }, (List<Object>) completion(r).get('values'));
        Assert.isFalse(completion(r).containsKey('total'));
        Assert.isFalse(completion(r).containsKey('hasMore'));
        Assert.isFalse(r.result().containsKey('ttlMs'));
        Assert.areEqual('complete', r.result().get('resultType'));
    }

    @IsTest
    static void templateVariableCompletionWithContext() {
        McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'completion/complete', templateRef('acme://account/{id}', 'id', 'x'));
        Assert.areEqual(new List<Object>{ 'a1', 'a2' }, (List<Object>) completion(r).get('values'));
        Assert.areEqual(2, completion(r).get('total'));
        Assert.areEqual(false, completion(r).get('hasMore'));
        Map<String, Object> withContext = templateRef('acme://account/{id}', 'id', 'ctx');
        withContext.put('context', new Map<String, Object>{ 'arguments' => new Map<String, Object>{ 'x' => 'from-context', 'ignored' => 5 } });
        Assert.areEqual(new List<Object>{ 'from-context' }, (List<Object>) completion(McpTestKit.legacy(McpTestKit.fullServer(), 'completion/complete', withContext)).get('values'));
    }

    @IsTest
    static void staticResourceReferenceHasNoSuggestions() {
        McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'completion/complete', templateRef('acme://org', 'x', 'y'));
        Assert.areEqual(0, ((List<Object>) completion(r).get('values')).size());
    }

    @IsTest
    static void unknownReferencesAndArgumentsAreInvalidParams() {
        List<Map<String, Object>> bad = new List<Map<String, Object>>{
            promptRef('nope', 'name', 'a'), promptRef('greet', 'undeclared', 'a'),
            templateRef('acme://unknown/{id}', 'id', 'a'), templateRef('acme://account/{id}', 'undeclared', 'a'),
            new Map<String, Object>{ 'ref' => new Map<String, Object>{ 'type' => 'ref/other' }, 'argument' => new Map<String, Object>{ 'name' => 'a', 'value' => 'b' } },
            new Map<String, Object>{ 'ref' => new Map<String, Object>{ 'type' => 'ref/prompt' }, 'argument' => new Map<String, Object>{ 'name' => 'a', 'value' => 'b' } },
            new Map<String, Object>{ 'ref' => new Map<String, Object>{ 'type' => 5 }, 'argument' => new Map<String, Object>{ 'name' => 'a', 'value' => 'b' } }
        };
        for (Map<String, Object> params : bad) {
            McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'completion/complete', params);
            Assert.areEqual(200, r.status, JSON.serialize(params));
            Assert.areEqual(-32602, r.code(), JSON.serialize(params));
        }
    }

    @IsTest
    static void malformedParamsAreInvalidParams() {
        List<Map<String, Object>> bad = new List<Map<String, Object>>{
            new Map<String, Object>(),
            new Map<String, Object>{ 'ref' => 'x', 'argument' => new Map<String, Object>() },
            new Map<String, Object>{ 'ref' => new Map<String, Object>(), 'argument' => 'x' },
            promptRef('greet', 'name', null),
            new Map<String, Object>{ 'ref' => new Map<String, Object>{ 'type' => 'ref/prompt', 'name' => 'greet' }, 'argument' => new Map<String, Object>{ 'name' => 5, 'value' => 'a' } }
        };
        for (Map<String, Object> params : bad) {
            Assert.areEqual(-32602, McpTestKit.legacy(McpTestKit.fullServer(), 'completion/complete', params).code(), JSON.serialize(params));
        }
    }

    @IsTest
    static void moreThanHundredValuesAreCutWithHasMoreAndTotal() {
        McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'completion/complete', templateRef('acme://account/{id}', 'id', 'many'));
        Map<String, Object> c = completion(r);
        List<Object> values = (List<Object>) c.get('values');
        Assert.areEqual(100, values.size());
        Assert.areEqual('v0', values[0]);
        Assert.areEqual('v99', values[99]);
        Assert.areEqual(true, c.get('hasMore'));
        Assert.areEqual(150, c.get('total'));
    }

    @IsTest
    static void completionBuilderCutsAndKeepsDeveloperTotals() {
        List<String> many = new List<String>();
        for (Integer i = 0; i < 101; i++) { many.add('v' + i); }
        Map<String, Object> cut = (Map<String, Object>) McpCompletion.of(many).total(500).toMap().get('completion');
        Assert.areEqual(500, cut.get('total'));
        Assert.areEqual(true, cut.get('hasMore'));
        Assert.areEqual(100, ((List<String>) cut.get('values')).size());
        Map<String, Object> exact = (Map<String, Object>) McpCompletion.of(new List<String>{ 'a' }).hasMore(true).toMap().get('completion');
        Assert.areEqual(true, exact.get('hasMore'));
        Assert.isFalse(exact.containsKey('total'));
        Assert.areEqual(0, ((List<String>) ((Map<String, Object>) McpCompletion.none().toMap().get('completion')).get('values')).size());
        Assert.areEqual(0, ((List<String>) ((Map<String, Object>) McpCompletion.of(null).toMap().get('completion')).get('values')).size());
    }

    @IsTest
    static void handlerFailuresMapToProtocolErrors() {
        McpTestKit.Reply boom = McpTestKit.modern(McpTestKit.fullServer(), 'completion/complete', templateRef('acme://account/{id}', 'id', 'boom'));
        Assert.areEqual(-32602, boom.code());
        Assert.areEqual('completion refused', boom.message());
        McpTestKit.Reply crash = McpTestKit.modern(McpTestKit.fullServer(), 'completion/complete', templateRef('acme://account/{id}', 'id', 'crash'));
        Assert.areEqual(-32603, crash.code());
        Assert.areEqual('Internal error', crash.message());
        McpTestKit.Reply none = McpTestKit.modern(McpTestKit.fullServer(), 'completion/complete', templateRef('acme://account/{id}', 'id', 'null'));
        Assert.areEqual(0, ((List<Object>) completion(none).get('values')).size());
    }

    @IsTest
    static void defaultCompleteImplementationsReturnNothing() {
        McpServer s = new McpServer('s', '1').prompt(new McpTestKit.PlainPrompt().argument('a', null, null))
            .resourceTemplate(new McpTestKit.PlainTemplate('x://{id}'));
        Assert.areEqual(0, ((List<Object>) completion(McpTestKit.modern(s, 'completion/complete', promptRef('plain', 'a', 'v'))).get('values')).size());
        Assert.areEqual(0, ((List<Object>) completion(McpTestKit.modern(s, 'completion/complete', templateRef('x://{id}', 'id', 'v'))).get('values')).size());
    }
}
