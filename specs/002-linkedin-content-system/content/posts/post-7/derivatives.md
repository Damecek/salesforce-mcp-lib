# Derivatives: Post 7 - Generic Salesforce Access Is Not the Same as Agent-Usable Operations

**Source variant**: business
**Generated**: 2026-04-09

## Short Post

**Word count**: 90 (max: 100)

An AI agent querying 500 Salesforce records to update one is not really an AI story. It is a tool design story.

Generic connectors expose generic actions. Reliable agents need business operations with names that match the real task.

That is why I like the `salesforce-mcp-lib` pattern: explicit Apex-registered tools, dynamic capability discovery, and Salesforce security still doing the enforcement underneath.

## Carousel Script

**Slides**: 6 (target: 5-8)

### Slide 1: One Record, 500 Queries
An agent needed to update one Salesforce account. It got there, but only after broad search attempts and a large fallback query.

### Slide 2: That Is Not The Model Failing
The problem was not "bad AI." The problem was a connector surface that knew Salesforce only in generic terms.

### Slide 3: Generic Access Is Not Enough
"Search Accounts" and "update record" are primitives. They are not business operations.

### Slide 4: Better Tools Change Behavior
When the agent sees explicit tools such as `update_billing_contact` or `find_customer_account`, it guesses less and reaches the right action faster.

### Slide 5: Why MCP Fits Here
`salesforce-mcp-lib` lets you register tools explicitly in Apex and expose only the capabilities you want the agent to discover.

### Slide 6: Design The Verbs - CTA
If you want better agent behavior in Salesforce, stop with generic reach and start with business-specific verbs. That is the real integration layer.

## Comment Version

**Sentences**: 3 (target: 2-3)

Strong example. What stood out to me is that the agent did reach the goal, but the tool surface forced it to behave like it was exploring an unknown database. That is why I think Salesforce agents need business-specific MCP tools, not just generic connector access.

## DM Explanation

**Sentences**: 4 (target: 3-5)

This is exactly the pattern I have been watching for. The model is usually not the real problem; the issue is that the connector gives it only generic actions, so it has to guess its way through the org. With MCP tools defined in Apex, you can expose the business operation directly and let the agent choose the right verb first. That tends to cut out a lot of wasted querying.

---

## Validation

- Short post word count: 90 (max: 100)
- Carousel slides: 6 (target: 5-8)
- Comment sentences: 3 (target: 2-3)
- DM sentences: 4 (target: 3-5)
- Core message preserved: YES
- Key repo fact preserved: YES
