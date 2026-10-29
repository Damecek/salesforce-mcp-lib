/**
 * SYNTHETIC sales meeting preparation demo (account 360 and opportunity follow-up) at /mcp/sales-demo.
 * Reads and writes no records. Page size 2 makes tools/list span two pages.
 */
@RestResource(urlMapping='/mcp/sales-demo')
global with sharing class SalesDemoEndpoint {
    @HttpPost
    global static void post() {
        build().handle(RestContext.request, RestContext.response);
    }

    public static McpServer build() {
        return new McpServer('sales-meeting-demo', '1.0.0')
            .title('Sales meeting preparation (synthetic demo)')
            .description('Account 360 and opportunity follow-up over invented data. No Salesforce records are read or written.')
            .instructions('All data is synthetic. Start with sales_demo_find_accounts, then sales_demo_get_account_brief, sales_demo_review_opportunity and sales_demo_draft_follow_up. Drafts are never sent.')
            .tool(new SalesDemoFindAccountsTool())
            .tool(new SalesDemoAccountBriefTool())
            .tool(new SalesDemoReviewOpportunityTool())
            .tool(new SalesDemoDraftFollowUpTool())
            .resource(new SalesDemoPlaybookResource())
            .resourceTemplate(new SalesDemoAccountTemplate())
            .resourceTemplate(new SalesDemoOpportunityTemplate())
            .prompt(new SalesDemoMeetingPrompt())
            .pageSize(2);
    }
}
