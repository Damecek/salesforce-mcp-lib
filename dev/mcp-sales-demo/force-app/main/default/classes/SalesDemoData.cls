/**
 * SYNTHETIC demo data for the sales-meeting-preparation server. Everything here is constant: no SOQL, no DML, no
 * callouts, no customer records. A fixed as-of date keeps every day count and risk result reproducible.
 * Production adaptation: replace the lookups below with Database.query(..., AccessLevel.USER_MODE) so the caller's
 * sharing and field-level security apply.
 */
public with sharing class SalesDemoData {
    public static final Date AS_OF = Date.newInstance(2026, 10, 29);
    public static final String NOTICE = 'SYNTHETIC DEMO DATA: invented accounts and opportunities, fixed as-of date 2026-10-29. Not read from Salesforce records.';
    public static final List<String> SEGMENTS = new List<String>{ 'enterprise', 'mid_market', 'smb' };
    public static final List<String> REGIONS = new List<String>{ 'dach', 'czsk', 'pl' };
    public static final List<String> GOALS = new List<String>{ 'renewal_review', 'pipeline_risk_review', 'expansion_discovery', 'executive_alignment' };
    public static final List<String> RISK_LEVELS = new List<String>{ 'low', 'medium', 'high' };
    public static final String ACCOUNT_URI = 'demo-sales://accounts/';
    public static final String OPPORTUNITY_URI = 'demo-sales://opportunities/';

    public class Account {
        public String id;
        public String name;
        public String segment;
        public String region;
        public String currencyCode;
        public String industry;
        public String owner;

        public Account(String id, String name, String segment, String region, String currencyCode, String industry, String owner) {
            this.id = id; this.name = name; this.segment = segment; this.region = region;
            this.currencyCode = currencyCode; this.industry = industry; this.owner = owner;
        }
    }

    public class Opp {
        public String id;
        public String accountId;
        public String name;
        public String stage;
        public Integer amount;
        public Date closeDate;
        public Date lastActivity;
        public Boolean decisionMakerEngaged;
        public Boolean nextStepScheduled;

        public Opp(String id, String accountId, String name, String stage, Integer amount, Date closeDate, Date lastActivity, Boolean decisionMakerEngaged, Boolean nextStepScheduled) {
            this.id = id; this.accountId = accountId; this.name = name; this.stage = stage; this.amount = amount;
            this.closeDate = closeDate; this.lastActivity = lastActivity;
            this.decisionMakerEngaged = decisionMakerEngaged; this.nextStepScheduled = nextStepScheduled;
        }

        public Boolean isOpen() { return stage != 'closed_won' && stage != 'closed_lost'; }
        public Integer daysToClose() { return AS_OF.daysBetween(closeDate); }
        public Integer daysSinceActivity() { return lastActivity.daysBetween(AS_OF); }
    }

    private static final List<Account> ACCOUNTS = new List<Account>{
        new Account('demo-account-northstar', 'Northstar Mobility (demo)', 'enterprise', 'dach', 'EUR', 'Fleet leasing', 'Demo AE Alex Morgan'),
        new Account('demo-account-bluepeak', 'BluePeak Logistics (demo)', 'mid_market', 'czsk', 'CZK', 'Logistics', 'Demo AE Jamie Novak'),
        new Account('demo-account-cedarline', 'Cedarline Fleet Services (demo)', 'smb', 'pl', 'PLN', 'Fleet services', 'Demo AE Sam Kowal'),
        new Account('demo-account-harborview', 'Harborview Auto Group (demo)', 'enterprise', 'dach', 'EUR', 'Dealer group', 'Demo AE Alex Morgan'),
        new Account('demo-account-lumen', 'Lumen Leasing (demo)', 'mid_market', 'czsk', 'CZK', 'Leasing', 'Demo AE Jamie Novak')
    };

    private static final List<Opp> OPPS = new List<Opp>{
        new Opp('demo-opp-northstar-fleet-renewal', 'demo-account-northstar', 'Fleet contract renewal 2027', 'negotiation', 240000, Date.newInstance(2026, 11, 20), Date.newInstance(2026, 10, 27), true, true),
        new Opp('demo-opp-northstar-telematics-pilot', 'demo-account-northstar', 'Telematics pilot, 40 vehicles', 'proposal', 85000, Date.newInstance(2026, 11, 5), Date.newInstance(2026, 10, 9), false, false),
        new Opp('demo-opp-bluepeak-depot-expansion', 'demo-account-bluepeak', 'Depot expansion, second site', 'qualification', 1800000, Date.newInstance(2026, 12, 15), Date.newInstance(2026, 10, 22), false, true),
        new Opp('demo-opp-bluepeak-support-upgrade', 'demo-account-bluepeak', 'Premium support upgrade', 'proposal', 650000, Date.newInstance(2026, 10, 20), Date.newInstance(2026, 9, 24), true, false),
        new Opp('demo-opp-cedarline-starter-plan', 'demo-account-cedarline', 'Starter plan for 12 vans', 'prospecting', 42000, Date.newInstance(2026, 11, 10), Date.newInstance(2026, 10, 20), false, true),
        new Opp('demo-opp-cedarline-onboarding', 'demo-account-cedarline', 'Onboarding package', 'closed_won', 18000, Date.newInstance(2026, 9, 30), Date.newInstance(2026, 9, 30), true, false),
        new Opp('demo-opp-harborview-multisite', 'demo-account-harborview', 'Multi-site rollout, 6 dealerships', 'negotiation', 410000, Date.newInstance(2026, 12, 18), Date.newInstance(2026, 10, 14), true, false),
        new Opp('demo-opp-harborview-training', 'demo-account-harborview', 'Dealer staff training', 'qualification', 30000, Date.newInstance(2027, 1, 31), Date.newInstance(2026, 10, 28), true, true),
        new Opp('demo-opp-lumen-pilot', 'demo-account-lumen', 'Lease-portfolio pilot', 'closed_lost', 300000, Date.newInstance(2026, 8, 31), Date.newInstance(2026, 8, 15), true, false)
    };

    public static List<Account> accounts() { return ACCOUNTS; }

    public static Account account(String id) {
        for (Account a : ACCOUNTS) { if (a.id == id) { return a; } }
        return null;
    }

    public static Opp opp(String id) {
        for (Opp o : OPPS) { if (o.id == id) { return o; } }
        return null;
    }

    /** Opportunities of one account, soonest close date first; closed ones only when includeClosed. */
    public static List<Opp> oppsFor(String accountId, Boolean includeClosed) {
        List<Opp> sorted = new List<Opp>();
        for (Opp o : OPPS) {
            if (o.accountId != accountId || (!includeClosed && !o.isOpen())) { continue; }
            Integer at = sorted.size();
            while (at > 0 && sorted[at - 1].closeDate > o.closeDate) { at--; }
            if (at == sorted.size()) { sorted.add(o); } else { sorted.add(at, o); } // List.add(0, x) on an empty list throws
        }
        return sorted;
    }

    public static Integer openPipeline(String accountId) {
        Integer total = 0;
        for (Opp o : oppsFor(accountId, false)) { total += o.amount; }
        return total;
    }

    public static Account requireAccount(String id) {
        Account a = account(id);
        if (a == null) { throw new McpException('Unknown demo account "' + (id == null ? 'null' : id.abbreviate(64)) + '". Call sales_demo_find_accounts to list valid accountId values.'); }
        return a;
    }

    public static Opp requireOpp(String id) {
        Opp o = opp(id);
        if (o == null) { throw new McpException('Unknown demo opportunity "' + (id == null ? 'null' : id.abbreviate(64)) + '". Call sales_demo_get_account_brief to list opportunityId values.'); }
        return o;
    }

    public static Map<String, Object> opportunityMap(Opp o, SalesDemoRisk.Assessment assessment) {
        Map<String, Object> m = new Map<String, Object>{
            'opportunityId' => o.id, 'accountId' => o.accountId, 'name' => o.name, 'stage' => o.stage,
            'amount' => o.amount, 'currency' => account(o.accountId).currencyCode,
            'closeDate' => String.valueOf(o.closeDate),
            'daysToClose' => o.daysToClose(), 'lastActivityDate' => String.valueOf(o.lastActivity),
            'daysSinceActivity' => o.daysSinceActivity(), 'riskLevel' => null, 'riskScore' => null
        };
        if (assessment != null) {
            m.put('riskLevel', assessment.level);
            m.put('riskScore', assessment.score);
        }
        return m;
    }

    public static McpSchema accountIdSchema() {
        return McpSchema.str().minLength(1).maxLength(64).describe('Synthetic demo account id, for example demo-account-northstar. Discover ids with sales_demo_find_accounts.');
    }

    public static McpSchema opportunityIdSchema() {
        return McpSchema.str().minLength(1).maxLength(64).describe('Synthetic demo opportunity id, for example demo-opp-northstar-telematics-pilot.');
    }

    public static McpSchema opportunitySchema() {
        return McpSchema.obj()
            .requiredProperty('opportunityId', McpSchema.str())
            .requiredProperty('accountId', McpSchema.str())
            .requiredProperty('name', McpSchema.str())
            .requiredProperty('stage', McpSchema.str())
            .requiredProperty('amount', McpSchema.integer().minimum(0).describe('Whole units of the account currency'))
            .requiredProperty('currency', McpSchema.str())
            .requiredProperty('closeDate', McpSchema.str().format('date'))
            .requiredProperty('daysToClose', McpSchema.integer().describe('Negative when the close date has passed'))
            .requiredProperty('lastActivityDate', McpSchema.str().format('date'))
            .requiredProperty('daysSinceActivity', McpSchema.integer().minimum(0))
            .property('riskLevel', McpSchema.enumOf(RISK_LEVELS).nullable().describe('Only set for open opportunities'))
            .property('riskScore', McpSchema.integer().minimum(0).maximum(10).nullable());
    }

    public static McpContent accountLink(Account a) {
        return McpContent.resourceLink(ACCOUNT_URI + a.id, a.id).title(a.name + ' brief').mimeType('text/markdown');
    }

    public static McpContent opportunityLink(Opp o) {
        return McpContent.resourceLink(OPPORTUNITY_URI + o.id, o.id).title(o.name).mimeType('text/markdown');
    }

    public static Integer intArg(Object value, Integer fallback) {
        if (value == null) { return fallback; }
        return value instanceof Decimal ? ((Decimal) value).intValue() : (Integer) value;
    }

    /** Every tool here only computes from constants and returns text, so all four advertise the same safe hints. */
    public static McpToolAnnotations safeHints(String title) {
        return new McpToolAnnotations().title(title).readOnly(true).destructive(false).idempotent(true).openWorld(false);
    }
}
