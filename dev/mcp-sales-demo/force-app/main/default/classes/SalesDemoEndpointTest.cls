@IsTest
private class SalesDemoEndpointTest {
    private static McpTestKit.Reply call(String tool, Map<String, Object> args) {
        return McpTestKit.modern(SalesDemoEndpoint.build(), 'tools/call', new Map<String, Object>{ 'name' => tool, 'arguments' => args });
    }

    private static Map<String, Object> structured(McpTestKit.Reply reply) {
        Assert.areEqual(200, reply.status);
        Assert.isNotNull(reply.json.get('result'), reply.body);
        Assert.isNull(reply.result().get('isError'), 'unexpected tool error: ' + reply.body);
        return (Map<String, Object>) reply.result().get('structuredContent');
    }

    private static String errorText(McpTestKit.Reply reply) {
        Assert.areEqual(true, reply.result().get('isError'), reply.body);
        return (String) reply.item('content', 0).get('text');
    }

    @IsTest
    static void toolsListSpansTwoPagesWithHonestAnnotations() {
        McpServer server = SalesDemoEndpoint.build();
        McpTestKit.Reply first = McpTestKit.modern(server, 'tools/list', null);
        Assert.areEqual(2, first.items('tools').size());
        Assert.isNotNull(first.result().get('nextCursor'));
        McpTestKit.Reply second = McpTestKit.modern(server, 'tools/list', new Map<String, Object>{ 'cursor' => first.result().get('nextCursor') });
        Assert.areEqual(2, second.items('tools').size());
        Assert.isNull(second.result().get('nextCursor'));
        List<Object> all = new List<Object>(first.items('tools'));
        all.addAll(second.items('tools'));
        for (Object o : all) {
            Map<String, Object> tool = (Map<String, Object>) o;
            Map<String, Object> hints = (Map<String, Object>) tool.get('annotations');
            Assert.areEqual(true, hints.get('readOnlyHint'));
            Assert.areEqual(false, hints.get('destructiveHint'));
            Assert.areEqual(false, hints.get('openWorldHint'));
            Assert.isNotNull(tool.get('outputSchema'), tool.get('name') + ' has no output schema');
        }
        Assert.areEqual('sales_demo_find_accounts', ((Map<String, Object>) all[0]).get('name'));
    }

    @IsTest
    static void searchFiltersAndPages() {
        Map<String, Object> all = structured(call('sales_demo_find_accounts', new Map<String, Object>()));
        Assert.areEqual(5, all.get('total'));
        Assert.areEqual(3, ((List<Object>) all.get('accounts')).size());
        Assert.areEqual(3, all.get('nextOffset'));
        Map<String, Object> enterprise = structured(call('sales_demo_find_accounts', new Map<String, Object>{
            'filters' => new Map<String, Object>{ 'segment' => 'enterprise' }, 'page' => new Map<String, Object>{ 'limit' => 1 } }));
        Assert.areEqual(2, enterprise.get('total'));
        Assert.areEqual(1, enterprise.get('nextOffset'));
        Map<String, Object> last = structured(call('sales_demo_find_accounts', new Map<String, Object>{
            'query' => 'AUTO', 'filters' => new Map<String, Object>{ 'segment' => 'enterprise' }, 'page' => new Map<String, Object>{ 'limit' => 1, 'offset' => 0 } }));
        Assert.areEqual('demo-account-harborview', ((Map<String, Object>) ((List<Object>) last.get('accounts'))[0]).get('accountId'));
        Assert.isNull(last.get('nextOffset'));
        Map<String, Object> none = structured(call('sales_demo_find_accounts', new Map<String, Object>{ 'filters' => new Map<String, Object>{ 'hasOpenOpportunities' => false } }));
        Assert.areEqual('demo-account-lumen', ((Map<String, Object>) ((List<Object>) none.get('accounts'))[0]).get('accountId'));
    }

    @IsTest
    static void briefTotalsAreConsistent() {
        McpTestKit.Reply reply = call('sales_demo_get_account_brief', new Map<String, Object>{ 'accountId' => 'demo-account-northstar' });
        Map<String, Object> brief = structured(reply);
        Map<String, Object> summary = (Map<String, Object>) brief.get('summary');
        Assert.areEqual(325000, summary.get('openPipeline'), '240000 + 85000 EUR');
        Assert.areEqual(2, summary.get('openOpportunityCount'));
        Assert.areEqual(1, summary.get('highRiskCount'));
        Assert.areEqual('2026-11-05', summary.get('nextCloseDate'));
        List<Object> opps = (List<Object>) brief.get('opportunities');
        Assert.areEqual('demo-opp-northstar-telematics-pilot', ((Map<String, Object>) opps[0]).get('opportunityId'), 'sorted by close date');
        List<String> types = new List<String>();
        for (Object block : reply.items('content')) { types.add((String) ((Map<String, Object>) block).get('type')); }
        Assert.isTrue(types.contains('resource_link') && types.contains('text'), 'links and JSON text fallback: ' + types);
        Map<String, Object> lumen = structured(call('sales_demo_get_account_brief', new Map<String, Object>{ 'accountId' => 'demo-account-lumen' }));
        Assert.isNull(((Map<String, Object>) lumen.get('summary')).get('nextCloseDate'));
        Assert.areEqual(1, ((List<Object>) structured(call('sales_demo_get_account_brief', new Map<String, Object>{ 'accountId' => 'demo-account-lumen', 'opportunities' => 'all' })).get('opportunities')).size());
    }

    @IsTest
    static void reviewExplainsEveryPoint() {
        Map<String, Object> high = structured(call('sales_demo_review_opportunity', new Map<String, Object>{ 'opportunityId' => 'demo-opp-bluepeak-support-upgrade' }));
        Assert.areEqual(7, high.get('riskScore'));
        Assert.areEqual('high', high.get('riskLevel'));
        Integer points = 0;
        for (Object f : (List<Object>) high.get('factors')) { points += (Integer) ((Map<String, Object>) f).get('points'); }
        Assert.areEqual(7, points, 'factor points add up to the score');
        Assert.areEqual('medium', structured(call('sales_demo_review_opportunity', new Map<String, Object>{ 'opportunityId' => 'demo-opp-cedarline-starter-plan' })).get('riskLevel'));
        Map<String, Object> low = structured(call('sales_demo_review_opportunity', new Map<String, Object>{ 'opportunityId' => 'demo-opp-northstar-fleet-renewal' }));
        Assert.areEqual('low', low.get('riskLevel'));
        Assert.areEqual('none_triggered', ((Map<String, Object>) ((List<Object>) low.get('nextSteps'))[0]).get('rule'));
    }

    @IsTest
    static void businessAndInputMistakesAreVisibleToolErrors() {
        Assert.isTrue(errorText(call('sales_demo_get_account_brief', new Map<String, Object>{ 'accountId' => 'demo-account-nope' })).contains('sales_demo_find_accounts'));
        Assert.isTrue(errorText(call('sales_demo_review_opportunity', new Map<String, Object>{ 'opportunityId' => 'demo-opp-cedarline-onboarding' })).contains('closed_won'));
        Assert.isTrue(errorText(call('sales_demo_find_accounts', new Map<String, Object>{ 'page' => new Map<String, Object>{ 'limit' => 6 } })).contains('arguments.page.limit'));
        Assert.isTrue(errorText(call('sales_demo_find_accounts', new Map<String, Object>{ 'filters' => new Map<String, Object>{ 'segment' => 'giant' } })).contains('must be one of'));
        Assert.isTrue(errorText(call('sales_demo_get_account_brief', new Map<String, Object>())).contains('accountId: is required'));
        Assert.isTrue(errorText(call('sales_demo_draft_follow_up', new Map<String, Object>{ 'opportunityId' => 'demo-opp-harborview-training', 'channel' => 'sms' })).contains('must be one of'));
    }

    @IsTest
    static void draftsAreDraftOnly() {
        McpTestKit.Reply emailReply = call('sales_demo_draft_follow_up', new Map<String, Object>{ 'opportunityId' => 'demo-opp-northstar-telematics-pilot', 'channel' => 'email', 'tone' => 'formal' });
        Map<String, Object> email = structured(emailReply);
        Assert.areEqual(false, email.get('sent'));
        Assert.areEqual('draft_only', email.get('mode'));
        Assert.isTrue(((String) email.get('body')).contains('Dear Northstar Mobility (demo) team'));
        Assert.isTrue(((String) emailReply.item('content', 0).get('text')).startsWith('DRAFT'));
        Map<String, Object> agenda = structured(call('sales_demo_draft_follow_up', new Map<String, Object>{
            'opportunityId' => 'demo-opp-northstar-telematics-pilot', 'channel' => 'meeting_agenda',
            'meeting' => new Map<String, Object>{ 'durationMinutes' => 45, 'attendees' => new List<Object>{ 'Dana (demo)' } } }));
        Integer minutes = 0;
        for (String line : ((String) agenda.get('body')).split('\n')) {
            if (line.contains(' min)')) { minutes += Integer.valueOf(line.substringAfterLast('(').substringBefore(' min)')); }
        }
        Assert.areEqual(45, minutes, 'agenda slots add up to the meeting length');
        Assert.isTrue(((String) agenda.get('body')).contains('Attendees: Dana (demo)'));
    }

    @IsTest
    static void resourcesAndTemplates() {
        McpServer server = SalesDemoEndpoint.build();
        Assert.areEqual(1, McpTestKit.modern(server, 'resources/list', null).items('resources').size());
        Assert.areEqual(2, McpTestKit.modern(server, 'resources/templates/list', null).items('resourceTemplates').size());
        McpTestKit.Reply playbook = McpTestKit.modern(server, 'resources/read', new Map<String, Object>{ 'uri' => 'demo-sales://playbook' });
        Assert.isTrue(((String) playbook.item('contents', 0).get('text')).contains('overdue_close_date'));
        McpTestKit.Reply account = McpTestKit.modern(server, 'resources/read', new Map<String, Object>{ 'uri' => 'demo-sales://accounts/demo-account-bluepeak' });
        Assert.isNotNull(account.json.get('result'), account.body);
        Assert.isTrue(((String) account.item('contents', 0).get('text')).contains('Open pipeline: 2450000 CZK'));
        McpTestKit.Reply opp = McpTestKit.modern(server, 'resources/read', new Map<String, Object>{ 'uri' => 'demo-sales://opportunities/demo-opp-bluepeak-support-upgrade' });
        Assert.isTrue(((String) opp.item('contents', 0).get('text')).contains('Risk: high (7 points)'));
        Assert.areEqual(-32602, McpTestKit.modern(server, 'resources/read', new Map<String, Object>{ 'uri' => 'demo-sales://accounts/demo-account-nope' }).code());
    }

    @IsTest
    static void promptAndCompletion() {
        McpServer server = SalesDemoEndpoint.build();
        McpTestKit.Reply prompt = McpTestKit.modern(server, 'prompts/get', new Map<String, Object>{
            'name' => 'prepare_account_meeting', 'arguments' => new Map<String, Object>{ 'accountId' => 'demo-account-harborview', 'goal' => 'renewal_review' } });
        Assert.areEqual(3, prompt.items('messages').size());
        Assert.isTrue(((String) ((Map<String, Object>) prompt.item('messages', 0).get('content')).get('text')).contains('renewal_review'));
        Assert.areEqual('resource', ((Map<String, Object>) prompt.item('messages', 1).get('content')).get('type'));
        Assert.areEqual(-32602, McpTestKit.modern(server, 'prompts/get', new Map<String, Object>{
            'name' => 'prepare_account_meeting', 'arguments' => new Map<String, Object>{ 'accountId' => 'demo-account-harborview', 'goal' => 'world_domination' } }).code());
        Assert.areEqual(-32602, McpTestKit.modern(server, 'prompts/get', new Map<String, Object>{ 'name' => 'prepare_account_meeting', 'arguments' => new Map<String, Object>() }).code());
        Map<String, Object> ref = new Map<String, Object>{ 'type' => 'ref/prompt', 'name' => 'prepare_account_meeting' };
        McpTestKit.Reply ids = McpTestKit.modern(server, 'completion/complete', new Map<String, Object>{ 'ref' => ref, 'argument' => new Map<String, Object>{ 'name' => 'accountId', 'value' => 'demo-account-b' } });
        Assert.areEqual(new List<Object>{ 'demo-account-bluepeak' }, ((Map<String, Object>) ids.result().get('completion')).get('values'));
        McpTestKit.Reply goals = McpTestKit.modern(server, 'completion/complete', new Map<String, Object>{ 'ref' => ref, 'argument' => new Map<String, Object>{ 'name' => 'goal', 'value' => 'pipe' } });
        Assert.areEqual(new List<Object>{ 'pipeline_risk_review' }, ((Map<String, Object>) goals.result().get('completion')).get('values'));
        Map<String, Object> tpl = new Map<String, Object>{ 'type' => 'ref/resource', 'uri' => 'demo-sales://opportunities/{opportunityId}' };
        McpTestKit.Reply opps = McpTestKit.modern(server, 'completion/complete', new Map<String, Object>{ 'ref' => tpl, 'argument' => new Map<String, Object>{ 'name' => 'opportunityId', 'value' => 'demo-opp-harbor' } });
        Assert.isNotNull(opps.json.get('result'), opps.body);
        Assert.areEqual(2, ((List<Object>) ((Map<String, Object>) opps.result().get('completion')).get('values')).size());
    }

    @IsTest
    static void staysInsideTheDemoBudget() {
        Test.startTest();
        McpTestKit.Reply reply = call('sales_demo_get_account_brief', new Map<String, Object>{ 'accountId' => 'demo-account-harborview', 'opportunities' => 'all' });
        call('sales_demo_review_opportunity', new Map<String, Object>{ 'opportunityId' => 'demo-opp-harborview-multisite' });
        Assert.isTrue(reply.body.length() < 262144, 'response well under the 256 KiB cap');
        Assert.areEqual(0, Limits.getQueries(), 'no SOQL');
        Assert.areEqual(0, Limits.getDmlStatements(), 'no DML');
        Assert.areEqual(0, Limits.getCallouts(), 'no callouts');
        Assert.isTrue(Limits.getHeapSize() < 500000, 'heap ' + Limits.getHeapSize());
        Assert.isTrue(Limits.getCpuTime() < 3000, 'cpu ' + Limits.getCpuTime());
        Test.stopTest();
    }
    @IsTest
    static void oversizedPromptErrorsAreBounded() {
        String longValue = 'x'.repeat(2000);
        try {
            SalesDemoData.requireAccount(longValue);
            Assert.fail('Unknown account must fail');
        } catch (McpException e) {
            Assert.isTrue(e.getMessage().length() < 200);
        }
        McpTestKit.Reply reply = McpTestKit.modern(SalesDemoEndpoint.build(), 'prompts/get',
            new Map<String, Object>{ 'name' => 'prepare_account_meeting',
                'arguments' => new Map<String, Object>{ 'accountId' => 'demo-account-northstar', 'goal' => longValue } });
        Assert.areEqual(-32602, reply.code());
        Assert.isTrue(JSON.serialize(reply).length() < 2000);
    }
}
