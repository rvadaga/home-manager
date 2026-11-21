# Planner input

Run `python3 scripts/plan.py <snapshot.json>` from the skill folder. The planner only reads Git and prints proposed actions. The Desktop skill collects live evidence, executes supported app actions, and checks the result; the planner neither attaches nor archives anything.

```json
{
  "threadId": "11111111-1111-4111-8111-111111111111",
  "artifacts": [],
  "verifiedBindings": [],
  "claims": [],
  "pulls": [
    {
      "url": "https://github.com/example/app/pull/12",
      "state": "OPEN",
      "isDraft": true,
      "sourceRoot": "/absolute/path/to/app",
      "remote": "origin",
      "headRepository": "example/app",
      "headRefName": "feature",
      "headRefOid": "123456789011223344556677889900aabbccddee",
      "baseRefName": "main",
      "baseRefOid": "02123456789011223344556677889900aabbccdd",
      "stackParent": false
    }
  ]
}
```

- Use the live list_artifacts array. Do not replace an unavailable inventory with an empty one.
- A verifiedBindings row has threadId, url, and absolute path. Include only a previously verified PR-to-checkout receipt or an equivalently verified mapping. An app PR attachment with a populated root is read directly. Do not invent a receipt from a path label or an exact SHA alone.
- A claims row has threadId and absolute path. Build it from verified current or archived chat claims on this host, including a chat working in a subdirectory of the checkout. An incomplete scan never clears an archive blocker.
- Read the live base and head on GitHub, including the fork head repository when applicable. Set stackParent for a genuine GitHub parent PR, not merely for a branch named something other than main. Scope the comparison and any fetch to the named PR.

The output lists creation, reuse or hold per PR; attachPr means the exact PR is not attached. A reuse row with no attachment needs app registration if it is allowed and not a primary workspace already available in Changes. A review object is a proposed panel request. nativePairVerified reflects matching attachment records only, never rendered proof. Possible duplicates and blockingChats describe what to preserve and report, not what to archive.
