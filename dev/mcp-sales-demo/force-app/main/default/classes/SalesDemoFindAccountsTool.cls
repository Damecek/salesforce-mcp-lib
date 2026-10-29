/** Discovery step: search the synthetic accounts by text and filters, with a bounded limit/offset page. */
public with sharing class SalesDemoFindAccountsTool extends McpTool {
    public SalesDemoFindAccountsTool() {
        super('sales_demo_find_accounts');
        title('Find demo accounts')
            .description('SYNTHETIC DEMO DATA. Finds accounts by name, id or industry text and optional segment, region and open-pipeline filters. Returns at most 5 accounts per call; use page.offset with nextOffset to continue.')
            .annotations(SalesDemoData.safeHints('Find demo accounts'))
            .input(McpSchema.obj().closed()
                .property('query', McpSchema.str().maxLength(60).describe('Case-insensitive text matched against name, id and industry'))
                .property('filters', McpSchema.obj().closed()
                    .property('segment', McpSchema.enumOf(SalesDemoData.SEGMENTS))
                    .property('region', McpSchema.enumOf(SalesDemoData.REGIONS))
                    .property('hasOpenOpportunities', McpSchema.bool()))
                .property('page', McpSchema.obj().closed()
                    .property('limit', McpSchema.integer().minimum(1).maximum(5).defaultValue(3))
                    .property('offset', McpSchema.integer().minimum(0).maximum(100).defaultValue(0))))
            .output(McpSchema.obj()
                .requiredProperty('demoData', McpSchema.bool())
                .requiredProperty('dataNotice', McpSchema.str())
                .requiredProperty('total', McpSchema.integer().minimum(0).describe('Matches before paging'))
                .requiredProperty('nextOffset', McpSchema.integer().minimum(1).nullable().describe('Offset for the next page, null on the last page'))
                .requiredProperty('accounts', McpSchema.arr(McpSchema.obj()
                    .requiredProperty('accountId', McpSchema.str())
                    .requiredProperty('name', McpSchema.str())
                    .requiredProperty('segment', McpSchema.enumOf(SalesDemoData.SEGMENTS))
                    .requiredProperty('region', McpSchema.enumOf(SalesDemoData.REGIONS))
                    .requiredProperty('currency', McpSchema.str())
                    .requiredProperty('industry', McpSchema.str())
                    .requiredProperty('owner', McpSchema.str())
                    .requiredProperty('openOpportunityCount', McpSchema.integer().minimum(0))
                    .requiredProperty('openPipeline', McpSchema.integer().minimum(0).describe('Sum of open opportunity amounts in the account currency'))).maxItems(5)));
    }

    public override McpToolResult execute(McpRequest request) {
        String query = request.getString('query');
        String needle = query == null ? '' : query.toLowerCase();
        Map<String, Object> filters = request.getMap('filters') == null ? new Map<String, Object>() : request.getMap('filters');
        Map<String, Object> page = request.getMap('page') == null ? new Map<String, Object>() : request.getMap('page');
        Integer pageLimit = SalesDemoData.intArg(page.get('limit'), 3);
        Integer pageOffset = SalesDemoData.intArg(page.get('offset'), 0);

        List<SalesDemoData.Account> matches = new List<SalesDemoData.Account>();
        for (SalesDemoData.Account a : SalesDemoData.accounts()) {
            Boolean text = needle == '' || (a.name + ' ' + a.id + ' ' + a.industry).toLowerCase().contains(needle);
            Boolean segment = filters.get('segment') == null || (String) filters.get('segment') == a.segment;
            Boolean region = filters.get('region') == null || (String) filters.get('region') == a.region;
            Boolean open = filters.get('hasOpenOpportunities') == null || ((Boolean) filters.get('hasOpenOpportunities')) == !SalesDemoData.oppsFor(a.id, false).isEmpty();
            if (text && segment && region && open) { matches.add(a); }
        }

        List<McpContent> links = new List<McpContent>();
        List<Object> rows = new List<Object>();
        for (Integer i = pageOffset; i < matches.size() && i < pageOffset + pageLimit; i++) {
            SalesDemoData.Account a = matches[i];
            rows.add(new Map<String, Object>{
                'accountId' => a.id, 'name' => a.name, 'segment' => a.segment, 'region' => a.region, 'currency' => a.currencyCode,
                'industry' => a.industry, 'owner' => a.owner,
                'openOpportunityCount' => SalesDemoData.oppsFor(a.id, false).size(), 'openPipeline' => SalesDemoData.openPipeline(a.id)
            });
            links.add(SalesDemoData.accountLink(a));
        }
        Integer next = pageOffset + pageLimit;
        McpToolResult result = McpToolResult.structured(new Map<String, Object>{
            'demoData' => true, 'dataNotice' => SalesDemoData.NOTICE, 'total' => matches.size(),
            'nextOffset' => next < matches.size() ? (Object) next : null, 'accounts' => rows
        });
        for (McpContent link : links) { result.add(link); }
        return result;
    }
}
