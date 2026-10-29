/** Static markdown playbook. The rule table mirrors SalesDemoRisk, so the assistant can explain the scores. */
public with sharing class SalesDemoPlaybookResource extends McpResource {
    public static final String URI = 'demo-sales://playbook';

    public SalesDemoPlaybookResource() {
        super(URI, 'sales_meeting_playbook');
        title('Sales meeting playbook (demo)')
            .description('SYNTHETIC DEMO. How to prepare an account meeting and how the demo risk rules score an opportunity.')
            .mimeType('text/markdown')
            .annotations(new McpAnnotations().audience(new List<String>{ 'user', 'assistant' }).priority(0.8));
    }

    public override McpResourceResult read(McpRequest request) {
        return McpResourceResult.of(McpResourceContents.text(URI, 'text/markdown', text()));
    }

    public static String text() {
        return String.join(new List<String>{
            '# Sales meeting playbook (synthetic demo)',
            SalesDemoData.NOTICE,
            '',
            '## Before the meeting',
            '1. Read the account brief and note the open pipeline in the account currency.',
            '2. Review every medium or high risk opportunity.',
            '3. Draft the agenda from the triggered rules. Drafts are never sent from this server.',
            '',
            '## Risk rules (' + SalesDemoRisk.RULES_VERSION + ')',
            '| Rule | Points | Triggers when |',
            '| --- | --- | --- |',
            '| overdue_close_date | 3 | close date is before the as-of date |',
            '| imminent_close_early_stage | 2 | closes within 14 days while in prospecting or qualification |',
            '| stale_activity | 2 or 3 | last activity 14 to 29 days ago (2), 30 or more (3) |',
            '| no_decision_maker | 2 | no decision maker engaged |',
            '| no_next_step | 1 | no next step scheduled |',
            '',
            'Level: high at 5 points or more, medium at 3 or 4, low below 3. This is a demo rule set, not a forecast.'
        }, '\n');
    }
}
