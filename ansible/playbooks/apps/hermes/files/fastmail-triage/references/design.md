# Why the skill is built this way

Email is untrusted input, and a weekly agent reads it with nobody watching. An agent that reads mail, holds a mail token and has a terminal could be talked into forwarding or deleting mail by a well-crafted subject line. So stranger-written text only ever reaches a model with no tools.

| Step | Hermes job | Model? | Tools | Token |
|---|---|---|---|---|
| Scan the Inbox, set protected mail aside, write a cleaned digest | pre-run script of `fastmail-triage-decide` | no | n/a | yes |
| Classify the digest | `fastmail-triage-decide`, Mondays 08:00 | yes | none (`enabled_toolsets: []`) | no |
| Check the decisions, move mail, print the report | `fastmail-triage-apply`, Mondays 08:30, `--no-agent` | no | n/a | yes |

**The worst case.** A hostile message can steer the classifier, so unprotected machine mail can land in the wrong one of five folders, up to the per-run limit, and be undone from the journal. It can also keep unknown senders in the Inbox, or make the model ask about mail again next week, and get a short, plain sender address into the delivered report. It should not be able to reach the token, a terminal or the network through this skill, because this skill never hands mail text to a model with tools. One gap depends on Hermes: see the session store below.

**The report carries no stranger prose.** Only counts, fixed wording and short sender addresses that pass a strict pattern, since a long address can spell out a sentence. Hermes acts on what it delivers: `MEDIA:<path>` anywhere in the text uploads that file to the chat, and Telegram turns links into previews. The model has no free-text field, so it cannot put words in the report either. The copy kept on disk, which `report` prints in chat, has counts and no addresses at all.

**The session store is the known gap.** Hermes saves every cron run's prompt, digest included, in `state.db`, and a chat agent's `session_search` can read it. No per-job opt-out showed up in the source. So `apply` deletes the decide job's sessions (`hermes sessions delete`) and saved output after each run, and the report says if it could not. Session ids differ by Hermes version (`cron_<job>_<time>`, or `local-<hash>` on v0.23), so it finds sessions by the job's title and by the digest header, then checks that none are left. Between the 08:00 and 08:30 jobs the digest does sit in the store, and a chat search in that window could find it. Disabling `session_search` for chat would close that fully, at the cost of the feature.

**The chat path never reads mail.** "Sort my inbox now" triggers the same two jobs. A chat session has a terminal, so it must not see a digest, and `scan` refuses to print one unless the Hermes launcher started it.

**Personal settings stay encrypted.** The skill lives in a public repo, so `default-config.json` holds generic rules only. Addresses, protected senders and phrases that say something about the owner's life are in an encrypted `group_vars` file, and each deploy writes them to `data/fastmail-triage/site-config.json`. `scan` gives the model nothing if they are missing, and `check` fails. `mode` and `teach` save to `config.json`, so a deploy never overwrites them.

**The token is not in `~/.hermes/.env`.** Hermes loads that file into its environment and passes most of it to terminal commands. The token sits in `data/fastmail-triage/token` with mode 0600. A terminal running as the same user could still read that file, so keeping stranger text away from terminals is the real control.

**Decisions must carry the run id.** It is random, generated at scan time, and unknowable to anyone writing an email beforehand. Only text after the `## Response` heading of the saved run counts.

## Hermes behaviour this depends on (read from the v0.23.0 source on the VM, Nov 2026)

Needs **Hermes v0.22.6 or newer**: `--timezone` arrives there, and `enabled_toolsets: []` only means "no tools" from v0.22.0. `install.py` refuses older versions.

- `cron/scheduler_prompt.py`: script stdout goes into the prompt in a fixed three-backtick fence, under "Script Output". The whole assembled prompt, skill included, is scanned for four injection phrases, and a match stops the job. So messages matching them are held back, and SKILL.md must not contain them.
- `cron/scheduler.py`: the wake gate is honoured only when the script exits 0, so scan failures exit 0 with `{"wakeAgent": false}` and `apply` reports the reason.
- The Claude subscription plugin (0.3.4) starts Claude Code with `--tools ''`, `--strict-mcp-config`, `--setting-sources ''`, `--max-turns 1` and `--no-session-persistence`. So a job with no Hermes tools has no Claude Code tools either, and Claude Code keeps no transcript of the digest. Each deploy updates this plugin, so recheck these flags if its major behaviour changes.
- `cron/scheduler.py`: `enabled_toolsets: []` means no tools, with no MCP servers merged in, and `null` means the defaults. The CLI has no flag for it, so `install.py` creates the job paused, sets the field in `cron/jobs.json`, then resumes it.
- `cron/scheduler.py`: cron agents run with `skip_background_review=True`, so no skill or memory review fork, which would have tools, sees the digest.
- `cron/scheduler_script.py`: scripts must be real files inside `$HERMES_HOME/scripts`, so `install.py` writes small launchers there. Stdout is redacted before use.
- `cron/jobs.py`: output is saved to `cron/output/<job id>/<timestamp>.md`, with the model's text after a `## Response` heading.
- `cron/scheduler_delivery.py`: no-agent stdout is delivered with a header and footer unless `cron.wrap_response` is false, and is scanned for media tags.

## If Hermes changes

`scan --cron` checks the tool setting first on every run and gives the agent no digest if it is wrong. If the output format changes, the decisions will not parse and unknown senders simply stay in the Inbox, with a line in the report saying so. Both failures leave mail where it is.

## Not verified on a live system

Whether real providers return the JSON reply, whether Fastmail sets `$followed`, and the real delivery of a report. The first `hermes cron run` in `propose` mode tests all of these and moves nothing.
