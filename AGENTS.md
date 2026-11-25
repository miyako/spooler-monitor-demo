# spooler-monitor-demo — working notes

A 4D host project that consumes the `miyako/spooler-monitor` component. It is a
demo, not the component: never rename `SpoolerMonitor`, `Queue` or the CLI, and
never edit the staged copy under `Components/`.

## Layout

- `Project/Sources/Classes/SpoolerConsole.4dm` — the whole view model. Every
  number, string and badge shown on screen comes from a real envelope.
- `Project/Sources/Forms/Console/` — the form, its method and one object method
  per button (`ObjectMethods/<object>.4dm`, bound by file name).
- `Project/Sources/Methods/QueueWorker.4dm` — runs component calls in a worker;
  the UI process only ever renders finished payloads.
- `Project/Sources/Methods/Demo_SelfTest.4dm` — headless matrix, drives the same
  class methods the form does.
- `scripts/` — dependency staging, acceptance, optional scratch CUPS queue.

## Commands

```sh
python3 scripts/fetch_dependency.py            # stage Components/spooler-monitor.4dbase
python3 scripts/verify.py                      # headless read-only acceptance
python3 scripts/demo_queue.py --create         # optional: one harmless queue
python3 scripts/demo_queue.py --remove
```

Form validation uses the skills tooling when it is present:

```sh
./tools/4dform/boon .agents/schemas/4dform/formsSchema.json Project/Sources/Forms/Console/form.4DForm
./tools/4dlsp/tool4d-lsp-stdio validate --workspace "$PWD/Project/" "$PWD/Project/Sources/Classes/SpoolerConsole.4dm"
```

## Rules

- Read-only by default. `pause`/`resume` only run when a human clicks (with a
  confirmation dialog) or when `scripts/verify.py --mutate <queue>` names a queue
  the caller owns.
- Never invent queue data. An empty CUPS state is a legitimate result and the
  console says so.
- Report what ran. Windows, Intel hosts, signing and dependency-manager installs
  are `not_run` unless someone actually executed them.
- Screenshots are captured with the full 4D application, not `tool4d`: the
  headless tool cannot open a form window.
