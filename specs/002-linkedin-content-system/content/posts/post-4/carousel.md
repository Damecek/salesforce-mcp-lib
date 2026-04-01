---
marp: true
theme: linkedin
paginate: true
---

# The Security Question Every AI Review Asks

"How do you control what the agent can access?"

If you built a custom integration, the answer is usually long and painful — bespoke middleware, hand-rolled permission checks, weeks of engineering.

---

## There's a Shorter Answer

With Salesforce MCP Library:

**"The same way we control what our users can access."**

No new security system required.

---

## Four Authorization Layers — Already Built

**External Client App OAuth scopes** limit API access.

**Profiles and Permission Sets** control object and field visibility.

**OWD and Sharing Rules** determine record-level reach.

**Custom validation logic** covers everything else.

---

## Authentication That Handles Itself

The OAuth 2.0 client credentials flow manages authentication with **automatic token caching**.

No interactive login flows to build or maintain.

---

## Secrets Stay Secret

Credentials are redacted in all log output — `client_secret` is replaced by `"****"` at the logging layer.

Raw Salesforce errors are **sanitized** before reaching the AI client.

---

## Your Security Investment Carries Forward

Every Profile, Permission Set, and Sharing Rule your team already configured applies **automatically** to AI agent access.

Zero duplication. Zero new infrastructure.

---

# Start With What You Have

Audit your current Salesforce permission model. Identify which tools you could safely expose to AI agents today — without building anything new.

**⭐ github.com/damecek/salesforce-mcp-lib**
