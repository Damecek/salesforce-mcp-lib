# Derivatives: Post 4 — Four Layers of Security You Didn't Have to Build

**Source variant**: business
**Generated**: 2026-04-01

## Short Post
**Word count**: 82 (max: 100)

Every security review for AI integrations starts with: "How do you control what the agent can access?"

With Salesforce MCP Library, the answer is simple — the same way you control what your users can access. OAuth scopes, Profiles, Permission Sets, Sharing Rules. Four authorization layers your org already enforces, applied automatically to AI agents. No new permission system to build, audit, or maintain. Your existing Salesforce security investment carries forward.

## Carousel Script
**Slides**: 7 (target: 5–8)

### Slide 1: The Security Question Every AI Review Asks
"How do you control what the agent can access?" If you built a custom integration, the answer is usually long and painful — bespoke middleware, hand-rolled permission checks, weeks of engineering.

### Slide 2: There's a Shorter Answer
With Salesforce MCP Library: "The same way we control what our users can access." No new security system required.

### Slide 3: Four Authorization Layers — Already Built
Connected App OAuth scopes limit API access. Profiles and Permission Sets control object and field visibility. OWD and Sharing Rules determine record-level reach. Custom validation logic covers everything else.

### Slide 4: Authentication That Handles Itself
The OAuth 2.0 client credentials flow manages authentication with automatic token caching. No interactive login flows to build or maintain.

### Slide 5: Secrets Stay Secret
Credentials are redacted in all log output — `client_secret` is replaced by `"****"` at the logging layer. Raw Salesforce errors are sanitized before reaching the AI client.

### Slide 6: Your Security Investment Carries Forward
Every Profile, Permission Set, and Sharing Rule your team already configured applies automatically to AI agent access. Zero duplication.

### Slide 7: Start With What You Have
Audit your current Salesforce permission model. Identify which tools you could safely expose to AI agents today — without building anything new. Explore Salesforce MCP Library to see how.

## Comment Version
**Sentences**: 3 (target: 2–3)

The part of AI integration that slows teams down most isn't the AI itself — it's rebuilding security controls from scratch. If your org already has Profiles, Permission Sets, and Sharing Rules configured in Salesforce, those same four layers can govern what an AI agent accesses too. Worth exploring before committing to a custom authorization stack.

## DM Explanation
**Sentences**: 4 (target: 3–5)

So you know how every AI integration project gets stuck on the "how do we lock this down" question? The Salesforce MCP Library basically sidesteps that by reusing the four security layers your org already has — OAuth scopes, Profiles, Permission Sets, and Sharing Rules all apply automatically to AI agents. You don't build a new permission system; whatever you've already configured just carries forward. It even handles token caching and redacts secrets from logs automatically, so there's less operational overhead than you'd expect.

---
## Validation
- Short post word count: 82 (max: 100)
- Carousel slides: 7 (target: 5–8)
- Comment sentences: 3 (target: 2–3)
- DM sentences: 4 (target: 3–5)
- Core message preserved: YES
- Key repo fact preserved: YES
