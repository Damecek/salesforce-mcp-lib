/** Account 360 for a meeting: account facts, pipeline totals in the account currency and opportunities with a risk level. */
public with sharing class SalesDemoAccountBriefTool extends McpTool {
    public SalesDemoAccountBriefTool() {
        super('sales_demo_get_account_brief');
        title('Account brief with opportunities')
            .description('SYNTHETIC DEMO DATA. Returns one account with its pipeline summary and opportunities (open by default), each with a rule-based risk level. Unknown accountId returns a tool error.')
            .annotations(SalesDemoData.safeHints('Account brief with opportunities'))
            .input(McpSchema.obj().closed()
                .requiredProperty('accountId', SalesDemoData.accountIdSchema())
                .property('opportunities', McpSchema.enumOf(new List<String>{ 'open', 'all' }).defaultValue('open').describe('Which opportunities to list')))
            .output(McpSchema.obj()
                .requiredProperty('demoData', McpSchema.bool())
                .requiredProperty('dataNotice', McpSchema.str())
                .requiredProperty('asOf', McpSchema.str().format('date'))
                .requiredProperty('account', McpSchema.obj()
                    .requiredProperty('accountId', McpSchema.str())
                    .requiredProperty('name', McpSchema.str())
                    .requiredProperty('segment', McpSchema.enumOf(SalesDemoData.SEGMENTS))
                    .requiredProperty('region', McpSchema.enumOf(SalesDemoData.REGIONS))
                    .requiredProperty('currency', McpSchema.str())
                    .requiredProperty('industry', McpSchema.str())
                    .requiredProperty('owner', McpSchema.str()))
                .requiredProperty('summary', McpSchema.obj()
                    .requiredProperty('openOpportunityCount', McpSchema.integer().minimum(0))
                    .requiredProperty('openPipeline', McpSchema.integer().minimum(0).describe('Sum of open amounts in the account currency'))
                    .requiredProperty('highRiskCount', McpSchema.integer().minimum(0))
                    .requiredProperty('nextCloseDate', McpSchema.str().format('date').nullable().describe('Earliest close date among open opportunities; may already be overdue')))
                .requiredProperty('opportunities', McpSchema.arr(SalesDemoData.opportunitySchema()).maxItems(10)));
    }

    public override McpToolResult execute(McpRequest request) {
        SalesDemoData.Account a = SalesDemoData.requireAccount(request.requireString('accountId'));
        Boolean all = request.getString('opportunities') == 'all';
        List<Object> rows = new List<Object>();
        List<McpContent> links = new List<McpContent>{ SalesDemoData.accountLink(a) };
        Integer high = 0;
        for (SalesDemoData.Opp o : SalesDemoData.oppsFor(a.id, all)) {
            SalesDemoRisk.Assessment risk = o.isOpen() ? SalesDemoRisk.evaluate(o) : null;
            if (risk != null && risk.level == 'high') { high++; }
            rows.add(SalesDemoData.opportunityMap(o, risk));
            links.add(SalesDemoData.opportunityLink(o));
        }
        List<SalesDemoData.Opp> open = SalesDemoData.oppsFor(a.id, false);
        Map<String, Object> structured = new Map<String, Object>{
            'demoData' => true, 'dataNotice' => SalesDemoData.NOTICE, 'asOf' => String.valueOf(SalesDemoData.AS_OF),
            'account' => new Map<String, Object>{
                'accountId' => a.id, 'name' => a.name, 'segment' => a.segment, 'region' => a.region, 'currency' => a.currencyCode, 'industry' => a.industry, 'owner' => a.owner
            },
            'summary' => new Map<String, Object>{
                'openOpportunityCount' => open.size(), 'openPipeline' => SalesDemoData.openPipeline(a.id), 'highRiskCount' => high,
                'nextCloseDate' => open.isEmpty() ? null : String.valueOf(open[0].closeDate)
            },
            'opportunities' => rows
        };
        McpToolResult result = McpToolResult.structured(structured);
        for (McpContent link : links) { result.add(link); }
        return result;
    }
}
