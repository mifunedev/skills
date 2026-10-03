# Laya — the self-hosted System One backend

## Contents

1. [Check the hardware](#check-the-hardware)
2. [Start the server](#start-the-server)
3. [Ask a question](#ask-a-question)
4. [Read the answers correctly](#read-the-answers-correctly)
5. [Avoid the known failure modes](#avoid-the-known-failure-modes)
6. [Pilot Laya against Jev](#pilot-laya-against-jev)

Laya is an open-weight (Apache-2.0) System One model. Laya answers each request
in a single encoder pass. Its server, `laya-serve`, accepts the same request
body as Jev on `POST /v1/systemone`.

Source and full docs: <https://github.com/NandhaKishorM/laya>. Read the README
section "Self-Hosting: HTTP Server" before you change server settings.

## Check the hardware

| Setup | Hardware | Latency per request, preloaded |
| --- | --- | --- |
| CPU | 4+ cores, about 8 GB free RAM, about 8 GB disk | 193 to 464 ms |
| GPU | CUDA GPU with 4+ GB VRAM (T4 class) | about 33 ms; about 7 ms per question batched |
| Apple silicon | M-series through MPS | between CPU and GPU |

RAM and disk are estimates for the two default checkpoints plus PyTorch. A cold
checkpoint load takes 7 to 10 s, so run the server preloaded and keep it up.

## Start the server

Install into a virtual environment. On a CPU-only host, install the CPU
PyTorch build to avoid a multi-gigabyte CUDA download.

```bash
python3 -m venv ~/.venvs/laya
~/.venvs/laya/bin/python -m pip install torch --index-url https://download.pytorch.org/whl/cpu
~/.venvs/laya/bin/python -m pip install "laya[serve]"
```

Run the server in a named tmux session so it survives a terminal disconnect.
The server binds `0.0.0.0` by default; bind it to loopback unless other hosts
need it, and set `LAYA_API_KEY` if they do.

```bash
tmux new-session -d -s laya-serve \
  'LAYA_HOST=127.0.0.1 LAYA_PORT=8000 LAYA_PRELOAD=1 LAYA_MODELS=english,multilingual ~/.venvs/laya/bin/laya-serve'
bash scripts/ask.sh --backend laya --check
```

The first start downloads the checkpoints from Hugging Face. Watch progress
with `tmux attach -t laya-serve`, and detach with `Ctrl-b d`.

| Variable | Use |
| --- | --- |
| `LAYA_DEVICE` | `cpu`, `cuda`, or `mps` |
| `LAYA_THREADS` | Cap CPU threads at or below the physical core count |
| `LAYA_MAX_LOADED` | Checkpoints kept in memory; default 2 |
| `LAYA_API_KEY` | Require `Authorization: Bearer <key>` from clients |

Stop the server with `tmux kill-session -t laya-serve`.

## Ask a question

The request format is the same as Jev's. Omit `model` to let the Laya router
pick a checkpoint by language, or set it to `english`, `multilingual`, or
`typed-decisions`.

```json
{
  "state": "Hi, we were billed twice for March. Refund the duplicate or we cancel.",
  "questions": {
    "department": {
      "type": "choice",
      "instructions": "Which team should handle this?",
      "criteria": {
        "billing": "invoices, payments, refunds",
        "technical": "bugs, outages, errors",
        "other": "anything else"
      }
    },
    "churn_risk": {
      "type": "noul",
      "instructions": "Does the customer threaten to cancel or leave?"
    }
  }
}
```

```bash
bash scripts/ask.sh --backend laya request.json | jq '.answers'
```

The script prints the response on stdout and `latency_ms=<n>` on stderr. It
retries HTTP 503 three times. It exits `1` on a failed request and names the
cause. Point `LAYA_URL` at another host to use a remote server.

In a TypeScript application, the `laya-ts` package runs the model in process
through ONNX Runtime, in Node or the browser. It needs exported ONNX weights;
see the `laya-ts/` directory in the Laya repository.

## Read the answers correctly

- Gate decisions on `answer_confidence`, the probability of the reported
  answer. It means the same thing for every question type.
- Do not gate on `confidence`. On Laya it is 1 minus normalized entropy, which
  differs from Jev's formula. A Jev threshold does not transfer.
- The shipped checkpoints are over-confident. `laya-multilingual` has no fitted
  temperatures. Fit temperatures on your data before you trust a threshold.

## Avoid the known failure modes

1. **Many options.** Keep a `choice` at 20 options or fewer. The server rejects
   more than 100 with HTTP 413. Past the token budget, option text is trimmed
   and similar options become the same to the model.
2. **Boolean-word labels.** Do not use `yes`/`no` or `true`/`false` as `choice`
   keys. The model can follow the label instead of its description. Use
   semantic keys or opaque keys such as `A` and `B`.
3. **Negation.** "Do not cancel my account" can come back as `cancel`. Test
   negated wording for every action a decision can trigger.
4. **Score levels.** Give every score level a description. A `null` level
   returns HTTP 422.
5. **Long documents.** The English checkpoint reads 512 tokens and the
   multilingual one 1,024 by default. Long input is cut off silently. For long
   documents, use `model: "multilingual"` and read the README section on
   `max_len`.
6. **Language.** The English checkpoint fails on non-Latin scripts while it
   stays confident. Let the router choose, or name `multilingual`.

## Pilot Laya against Jev

The same request file works on both backends, so a pilot compares like with
like.

1. Pick one workload with ground truth, for example issues or tickets that
   already carry labels. Use at least 100 cases.
2. Write one request per case with the same questions.
3. Run each request through `bash scripts/ask.sh --backend laya` and
   through `bash scripts/ask.sh --backend jev`. Save the responses and `latency_ms`.
4. Record per backend: accuracy against the labels, p50 and p95 latency,
   accuracy at a fixed `answer_confidence` threshold, and failures grouped by
   cause (option count, negation, language, length).
5. Record the host: CPU or GPU, free RAM, disk used, and cold-start time.

Adopt Laya for a workload only when its accuracy is acceptable on that
workload's data and one Laya condition in "Choose the backend" in `SKILL.md`
holds.
