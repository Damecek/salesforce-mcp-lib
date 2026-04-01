# Post 4 — Founder: Four Layers of Security You Didn't Have to Build

**Topic**: 4 — Four Layers of Security You Didn't Have to Build
**Variant**: Founder
**Word count**: 271
**Claims referenced**: [C-014, C-010, C-016, C-017]

---

When I started building Salesforce MCP Library, I assumed I'd need to design an authorization system from scratch. Every AI framework I'd looked at either ignored security entirely or bolted on its own permission model.

Then I realized Salesforce already solved this problem — years ago, for human users.

Connected App OAuth scopes already control API access. Profiles and Permission Sets already enforce object and field visibility. OWD and Sharing Rules already govern record-level access. All I had to do was make sure the library didn't bypass any of it. So that's exactly what I did: nothing new for security.

The only addition is a `validate()` method that developers implement on their tool classes — a place for business-specific checks that go beyond what the platform enforces declaratively. Everything else is inherited.

I spent the extra time on the edges that actually needed attention. The server automatically re-authenticates on expired sessions with a single retry, so agents don't break during long-running conversations. Secrets like `client_secret` are redacted at the logging layer — you'll see `"****"` in every log line. Raw Salesforce error details are sanitized before they reach any AI client.

The developer experience stayed simple: extend four abstract classes, implement two to three methods each, and the framework handles protocol compliance and error translation. The security model is the one your admin already configured.

I think the most trustworthy AI integrations will be the ones that inherit proven security rather than invent their own. Your Salesforce org has that model already.

Check out the repo and see how the four layers map to your existing setup. Link in comments.
