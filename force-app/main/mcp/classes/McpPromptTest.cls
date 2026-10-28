@IsTest
private class McpPromptTest {
    private static Map<String, Object> get(String name, Map<String, Object> args) {
        Map<String, Object> p = new Map<String, Object>{ 'name' => name };
        if (args != null) { p.put('arguments', args); }
        return p;
    }

    private static Map<String, Object> name(String value) {
        return new Map<String, Object>{ 'name' => value };
    }

    @IsTest
    static void listShowsPromptMetadataAndArguments() {
        McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'prompts/list', null);
        Map<String, Object> prompt = r.item('prompts', 0);
        Assert.areEqual('greet', prompt.get('name'));
        Assert.areEqual('Greet', prompt.get('title'));
        Assert.areEqual('Greets someone.', prompt.get('description'));
        List<Object> args = (List<Object>) prompt.get('arguments');
        Assert.areEqual(2, args.size());
        Map<String, Object> first = (Map<String, Object>) args[0];
        Assert.areEqual('name', first.get('name'));
        Assert.areEqual('Who to greet', first.get('description'));
        Assert.areEqual(true, first.get('required'));
        Assert.areEqual(false, ((Map<String, Object>) args[1]).get('required'));
        Assert.isNotNull(prompt.get('icons'));
        Assert.areEqual(1, ((Map<String, Object>) prompt.get('_meta')).get('p'));
        Assert.areEqual(0, r.result().get('ttlMs'));
        McpTestKit.Reply legacy = McpTestKit.legacy(McpTestKit.fullServer(), 'prompts/list', null);
        Assert.isFalse(legacy.result().containsKey('ttlMs'));
    }

    @IsTest
    static void promptWithoutArgumentsOmitsTheKey() {
        McpServer s = new McpServer('s', '1').prompt(new Plain());
        Assert.isFalse(McpTestKit.modern(s, 'prompts/list', null).item('prompts', 0).containsKey('arguments'));
    }

    @IsTest
    static void getReturnsEveryContentType() {
        McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', get('greet', new Map<String, Object>{ 'name' => 'Ada' }));
        Assert.areEqual(200, r.status);
        Assert.areEqual('Greeting', r.result().get('description'));
        Assert.areEqual(2, ((Map<String, Object>) r.result().get('_meta')).get('pm'));
        Assert.areEqual('complete', r.result().get('resultType'));
        List<Object> messages = r.items('messages');
        Assert.areEqual(5, messages.size());
        Map<String, Object> m0 = (Map<String, Object>) messages[0];
        Assert.areEqual('user', m0.get('role'));
        Assert.areEqual('Hello Ada', ((Map<String, Object>) m0.get('content')).get('text'));
        Assert.areEqual('assistant', ((Map<String, Object>) messages[1]).get('role'));
        Assert.areEqual('image', ((Map<String, Object>) ((Map<String, Object>) messages[1]).get('content')).get('type'));
        Assert.areEqual('audio', ((Map<String, Object>) ((Map<String, Object>) messages[2]).get('content')).get('type'));
        Assert.areEqual('resource_link', ((Map<String, Object>) ((Map<String, Object>) messages[3]).get('content')).get('type'));
        Map<String, Object> embedded = (Map<String, Object>) ((Map<String, Object>) messages[4]).get('content');
        Assert.areEqual('resource', embedded.get('type'));
        Assert.areEqual('AAAA', ((Map<String, Object>) embedded.get('resource')).get('blob'));
    }

    @IsTest
    static void legacyGetHasNoModernFields() {
        McpTestKit.Reply r = McpTestKit.legacy(McpTestKit.fullServer(), 'prompts/get', get('greet', new Map<String, Object>{ 'name' => 'Ada' }));
        Assert.isFalse(r.result().containsKey('resultType'));
        Assert.areEqual(5, r.items('messages').size());
    }

    @IsTest
    static void argumentsAreOptionalWhenNoneAreRequired() {
        McpServer s = new McpServer('s', '1').prompt(new Plain());
        McpTestKit.Reply r = McpTestKit.modern(s, 'prompts/get', name('plain'));
        Assert.areEqual(0, r.items('messages').size());
        Assert.isFalse(r.result().containsKey('description'));
    }

    @IsTest
    static void missingRequiredArgumentIsInvalidParams() {
        McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', get('greet', new Map<String, Object>()));
        Assert.areEqual(200, r.status);
        Assert.areEqual(-32602, r.code());
        Assert.areEqual('Missing required argument: name', r.message());
        Assert.areEqual(-32602, McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', name('greet')).code());
        // the optional argument may be omitted
        Assert.isNull(McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', get('greet', new Map<String, Object>{ 'name' => 'a' })).json.get('error'));
    }

    @IsTest
    static void nonStringArgumentsAreInvalidParams() {
        for (Object bad : new List<Object>{ 5, true, new Map<String, Object>(), new List<Object>() }) {
            McpTestKit.Reply r = McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', get('greet', new Map<String, Object>{ 'name' => bad }));
            Assert.areEqual(-32602, r.code(), JSON.serialize(bad));
            Assert.isTrue(r.message().contains('must be a string'));
        }
        Map<String, Object> notObject = new Map<String, Object>{ 'name' => 'greet', 'arguments' => 'x' };
        Assert.areEqual(-32602, McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', notObject).code());
    }

    @IsTest
    static void unknownPromptAndHandlerFailures() {
        Assert.areEqual(-32602, McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', name('nope')).code());
        Assert.areEqual(-32602, McpTestKit.legacy(McpTestKit.fullServer(), 'prompts/get', new Map<String, Object>{ 'name' => 5 }).code());
        McpTestKit.Reply boom = McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', get('greet', new Map<String, Object>{ 'name' => 'boom' }));
        Assert.areEqual(-32602, boom.code());
        Assert.areEqual('no boom \\ "here"\n', boom.message());
        McpTestKit.Reply crash = McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', get('greet', new Map<String, Object>{ 'name' => 'crash' }));
        Assert.areEqual(-32603, crash.code());
        Assert.areEqual('Internal error', crash.message());
        Assert.isFalse(crash.body.contains('crash'));
        Assert.areEqual(-32603, McpTestKit.modern(McpTestKit.fullServer(), 'prompts/get', get('greet', new Map<String, Object>{ 'name' => 'null' })).code());
    }

    @IsTest
    static void promptDefinitionMisuseIsRejected() {
        List<String> failures = new List<String>();
        try { new Plain().argument('', null, null); failures.add('blank'); } catch (McpConfigurationException e) { }
        try { new Plain().argument('a', null, null).argument('a', null, null); failures.add('duplicate'); } catch (McpConfigurationException e) { }
        try { new NamedPrompt(null); failures.add('null name'); } catch (McpConfigurationException e) { }
        try { new NamedPrompt('has space'); failures.add('bad name'); } catch (McpConfigurationException e) { }
        try { new McpPromptResult().user(null); failures.add('null user'); } catch (McpConfigurationException e) { }
        try { new McpPromptResult().assistant(null); failures.add('null assistant'); } catch (McpConfigurationException e) { }
        Assert.areEqual(new List<String>(), failures);
        Assert.areEqual(new List<String>{ 'a' }, new Plain().argument('a', null, true).argument('b', null, null).requiredArguments());
        Assert.isTrue(new Plain().argument('a', null, null).declaresArgument('a'));
        Assert.isFalse(new Plain().declaresArgument('a'));
        Assert.areEqual('plain', new Plain().getName());
    }

    public class NamedPrompt extends McpPrompt {
        public NamedPrompt(String name) { super(name); }
        public override McpPromptResult get(McpRequest request) { return new McpPromptResult(); }
    }

    public class Plain extends McpPrompt {
        public Plain() { super('plain'); }
        public override McpPromptResult get(McpRequest request) { return new McpPromptResult(); }
    }
}
