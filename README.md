# hold-that-thought

**`/q` for Claude Code: queue a message that waits until Claude is done.**

When you type a message while Claude Code is working, it gets injected at the next tool-call boundary and can derail the task halfway through. Prefix it with `/q` instead, and it waits until the current turn finishes.

```
/q fix the login bug
/q then add a test for it
```

- **Waits for the turn to end.** A queued `/q` runs only after Claude stops.
- **Runs in order.** Several `/q` messages run one after another, and each waits for the previous one to finish.
- **No hooks, no daemons, no settings changes.** It is a single custom command file.

## Install

One line, no clone:

```bash
curl -fsSL https://raw.githubusercontent.com/gvoze32/hold-that-thought/main/install.sh | bash
```

Then start a new Claude Code session. The installer drops `q.md` into `~/.claude/commands/` (it respects `CLAUDE_CONFIG_DIR`). If a different `q.md` is already there, it is backed up first.

If you would rather not pipe a script, the whole install is a single file:

```bash
mkdir -p ~/.claude/commands && curl -fsSL https://raw.githubusercontent.com/gvoze32/hold-that-thought/main/commands/q.md -o ~/.claude/commands/q.md
```

**Uninstall:** `rm ~/.claude/commands/q.md`

**Project-only:** put the file in `<project>/.claude/commands/q.md` instead.

**From a clone:** `./install.sh` symlinks the repo copy, so your edits apply live. `./uninstall.sh` removes it.

## How it works

Claude Code queues slash commands typed during a turn and runs them one at a time after the turn ends. Plain messages instead go to Claude as soon as the running tool calls finish.

`/q` is a custom command whose body is just `$ARGUMENTS`. It goes through the slash-command queue, then expands to your message as if you had typed it on an idle prompt.

## Proof

`tests/verify.py` drives a real Claude Code session in a pseudo-terminal, with timestamp-logging hooks passed via `--settings`. Your own settings are not touched. A sample run on Claude Code v2.1.323:

```
Timeline:
  +   0.0s  SUBMIT  Run these bash commands one at a time: first `sleep 20`, then `sleep 15`...
  +  18.5s  SUBMIT  reply PLAIN too                                   <- plain message: lands mid-task
  +  39.0s  STOP                                                      <- main task done
  +  39.2s  SUBMIT  /q run bash `sleep 8` then reply exactly DONE-Q1  <- typed at ~9s, held until now
  +  49.4s  STOP
  +  49.5s  SUBMIT  /q reply exactly DONE-Q2                          <- waited for /q #1
  +  50.5s  STOP

PASS /q #1 held until the main task finished
PASS /q #2 waited for /q #1 to finish
INFO plain message landed mid-task
```

Run it yourself. It uses Haiku and a few cents of quota:

```bash
python3 tests/verify.py          # add --debug to dump the terminal screen
```

## Tips

Built-in queue controls that work alongside `/q`:

| Key | Action |
|---|---|
| `Ctrl+Enter` | Send queued messages now |
| `↑` on the first line of the input | Pull queued messages back for editing |
| `Esc` | Interrupt the turn (the queue is kept) |

## Caveats

- Only messages that start with `/q` are held. A plain message still lands mid-task.
- This relies on Claude Code's documented queueing of slash commands. If a future version changes that, `tests/verify.py` will fail and tell you.
- A `/q` typed while Claude is idle just runs immediately, like a normal message.
