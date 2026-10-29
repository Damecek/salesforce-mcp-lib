/** Drafts follow-up text from the risk factors. It sends nothing and writes nothing; the result is text for a human to edit. */
public with sharing class SalesDemoDraftFollowUpTool extends McpTool {
    public SalesDemoDraftFollowUpTool() {
        super('sales_demo_draft_follow_up');
        title('Draft follow-up email or meeting agenda')
            .description('SYNTHETIC DEMO DATA. Drafts a follow-up email or a meeting agenda for one open opportunity from its risk factors. Draft only: nothing is sent, no task or event is created and no record is changed.')
            .annotations(SalesDemoData.safeHints('Draft follow-up email or meeting agenda'))
            .input(McpSchema.obj().closed()
                .requiredProperty('opportunityId', SalesDemoData.opportunityIdSchema())
                .requiredProperty('channel', McpSchema.enumOf(new List<String>{ 'email', 'meeting_agenda' }))
                .property('tone', McpSchema.enumOf(new List<String>{ 'concise', 'formal' }).defaultValue('concise').describe('Email greeting and sign-off only'))
                .property('meeting', McpSchema.obj().closed()
                    .property('durationMinutes', McpSchema.integer().minimum(15).maximum(90).defaultValue(30).describe('Agenda only'))
                    .property('attendees', McpSchema.arr(McpSchema.str().minLength(1).maxLength(60)).maxItems(5).describe('Agenda only: names listed in the draft'))))
            .output(McpSchema.obj()
                .requiredProperty('demoData', McpSchema.bool())
                .requiredProperty('dataNotice', McpSchema.str())
                .requiredProperty('mode', McpSchema.enumOf(new List<String>{ 'draft_only' }))
                .requiredProperty('sent', McpSchema.bool().describe('Always false: this server cannot send'))
                .requiredProperty('opportunityId', McpSchema.str())
                .requiredProperty('channel', McpSchema.enumOf(new List<String>{ 'email', 'meeting_agenda' }))
                .requiredProperty('riskLevel', McpSchema.enumOf(SalesDemoData.RISK_LEVELS))
                .requiredProperty('subject', McpSchema.str())
                .requiredProperty('body', McpSchema.str())
                .requiredProperty('basedOnRules', McpSchema.arr(McpSchema.str()).maxItems(5)));
    }

    public override McpToolResult execute(McpRequest request) {
        SalesDemoData.Opp o = SalesDemoData.requireOpp(request.requireString('opportunityId'));
        if (!o.isOpen()) {
            throw new McpException('Opportunity "' + o.id + '" is ' + o.stage + '. Drafts are only available for open opportunities.');
        }
        SalesDemoData.Account a = SalesDemoData.account(o.accountId);
        SalesDemoRisk.Assessment risk = SalesDemoRisk.evaluate(o);
        Map<String, Object> meeting = request.getMap('meeting') == null ? new Map<String, Object>() : request.getMap('meeting');
        Boolean formal = request.getString('tone') == 'formal';
        Boolean email = request.requireString('channel') == 'email';

        List<String> asks = new List<String>();
        List<Object> rules = new List<Object>();
        for (Map<String, Object> f : risk.factors) {
            asks.add(ask((String) f.get('rule'), o));
            rules.add(f.get('rule'));
        }
        if (asks.isEmpty()) { asks.add('Confirm the next milestone and who owns it'); }

        String subject = (email ? 'Follow-up: ' : 'Agenda: ') + o.name;
        List<String> lines = new List<String>{ 'DRAFT (synthetic demo, not sent)' };
        if (email) {
            lines.add((formal ? 'Dear ' : 'Hello ') + a.name + ' team,');
            lines.add('Thank you for your time on "' + o.name + '" (' + o.amount + ' ' + a.currencyCode + ', planned close ' + String.valueOf(o.closeDate) + '). To keep it on track I would like to:');
            for (String s : asks) { lines.add('- ' + s); }
            lines.add(formal ? 'Kind regards,' : 'Thanks,');
            lines.add(a.owner);
        } else {
            Integer minutes = SalesDemoData.intArg(meeting.get('durationMinutes'), 30);
            List<String> items = new List<String>{ 'Recap and goals' };
            items.addAll(asks);
            items.add('Agree owners and dates');
            Integer each = minutes / items.size();
            lines.add('Meeting with ' + a.name + ', ' + minutes + ' minutes');
            List<Object> attendees = (List<Object>) meeting.get('attendees');
            if (attendees != null && !attendees.isEmpty()) { lines.add('Attendees: ' + String.join(attendees, ', ')); }
            for (Integer i = 0; i < items.size(); i++) {
                Integer slot = i == items.size() - 1 ? minutes - each * i : each;
                lines.add((i + 1) + '. ' + items[i] + ' (' + slot + ' min)');
            }
        }
        return McpToolResult.text(String.join(lines, '\n')).structuredContent(new Map<String, Object>{
            'demoData' => true, 'dataNotice' => SalesDemoData.NOTICE, 'mode' => 'draft_only', 'sent' => false,
            'opportunityId' => o.id, 'channel' => email ? 'email' : 'meeting_agenda', 'riskLevel' => risk.level,
            'subject' => subject, 'body' => String.join(lines, '\n'), 'basedOnRules' => rules
        }).add(SalesDemoData.opportunityLink(o));
    }

    private static String ask(String rule, SalesDemoData.Opp o) {
        if (rule == 'overdue_close_date') { return 'Agree a revised close date, since ' + String.valueOf(o.closeDate) + ' has passed'; }
        if (rule == 'imminent_close_early_stage') { return 'Confirm scope and budget so the ' + String.valueOf(o.closeDate) + ' close date is realistic'; }
        if (rule == 'stale_activity') { return 'Catch up, as our last contact was ' + o.daysSinceActivity() + ' days ago'; }
        if (rule == 'no_decision_maker') { return 'Meet the person who approves this decision'; }
        return 'Set a date for the next step';
    }
}
