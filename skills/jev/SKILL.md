---
name: jev
description: |
  Get typed judgments from TypeSafe Jev, a hosted System One model that
  answers choice, yes/no (noul), and score questions about text or JSON state
  with probabilities instead of generated prose. Use when code needs
  semantic understanding it cannot compute: routing, triage, ranking,
  extraction by selection, verification, or confidence-gated escalation.
  Also use to replace an LLM prompt-and-parse step with a structured
  decision. TRIGGER when: asked to use Jev, TypeSafe, or System One; to
  classify, route, triage, score, or verify text with a typed answer; or to
  compare Jev with another System One backend such as Laya.
license: MIT
compatibility: Needs network access to api.typesafe.ai and a TypeSafe API key.
metadata:
  mifune:
    category: integration
    requires-tools: ["curl", "jq"]
---

# Jev — hosted System One judgments

Jev reads a `state` and a map of typed `questions`, then returns one typed
answer per question with its probability distribution. It does not generate
text. Code owns the workflow; Jev supplies the judgments that ordinary code
cannot make.

## Check the configuration first

```bash
bash scripts/ask.sh --check          # is TYPESAFE_API_KEY set?
bash scripts/ask.sh --check --live   # does the key work?
```

Report the output to the operator verbatim. An unset key is a configuration
fact, not a failure: say what is missing, then continue with work that does not
need Jev.

## Read the live docs

The live TypeSafe docs are the source of truth for the API, models, limits, and
patterns. Read the relevant pages as part of the task.

- Start at the index: <https://docs.typesafe.ai/llms.txt>.
- Append `.md` to a page path to get Markdown, for example
  <https://docs.typesafe.ai/api.md>.

| Task | Start here |
| --- | --- |
| Understand the model | [System One](https://docs.typesafe.ai/concepts/system-one.md), [building guide](https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md) |
| Find a pattern | [Use-case map](https://docs.typesafe.ai/concepts/use-case-map.md), then the closest cookbook in the index |
| Shape state and questions | [State](https://docs.typesafe.ai/concepts/state.md), [primitives](https://docs.typesafe.ai/primitives.md) |
| Act on uncertainty | [Confidence](https://docs.typesafe.ai/confidence.md) |
| Write code | [HTTP API](https://docs.typesafe.ai/api.md), [JavaScript SDK](https://docs.typesafe.ai/sdk/javascript.md), [Python SDK](https://docs.typesafe.ai/sdk/python.md) |

If live access fails, say so and do not invent version-specific details.

## Ask a question

Write the request as JSON. `model` defaults to `jev-latest`.

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
    "urgency": {
      "type": "score",
      "instructions": "How urgent is this?",
      "criteria": ["not urgent", "soon", "blocking"]
    },
    "churn_risk": {
      "type": "noul",
      "instructions": "Does the customer threaten to cancel or leave?"
    }
  }
}
```

```bash
bash scripts/ask.sh request.json | jq '.answers'
```

The script prints the response on stdout and `latency_ms=<n>` on stderr. It
retries HTTP 429 and 529 three times. It exits `1` on a failed request and names
the cause.

In application code, use the SDK (`npm install @typesafe-ai/sdk` or the Python
SDK) instead of the script. Keep the API key on the server side.

## Design the judgments

| Need | Primitive | Answer |
| --- | --- | --- |
| One option from a defined set | `choice` | `choice`, `probabilities`, `confidence`; at most 255 options |
| Whether a condition holds | `noul` | `noul`: the probability of yes |
| A position on ordered levels | `score` | `score` (0-based, can land between levels), `legend`, `probabilities`, `confidence`; 2 to 10 levels |

1. Give each question the state it needs: source text, identities, policies,
   current facts. Use named JSON fields when the state has several parts, and
   refer to them in backticks, for example `ticket.messages[0].text`.
2. Put the judgment in `instructions`. Define the answers in `criteria`.
   Question IDs are not sent to the model, so the instructions must carry the
   full meaning.
3. Ask one narrow judgment per question. Split dimensions that are useful on
   their own. Do not split a relationship that must be judged as a whole.
4. Include a no-match option when nothing may fit.
5. For selection from source values, make sure every candidate is in the
   options. The model cannot choose a value you left out.

## Compose the answers

- Ask independent questions over the same state in one request. They run in
  parallel and cannot see each other's answers.
- Make a second request only when an earlier answer decides what evidence to
  fetch or what options to offer next.
- Keep rules, calculations, and exact lookups in code.
- Keep policy explicit. Store raw judgments, then let code apply weights and
  thresholds, so a policy change does not need new inference.

## Act on uncertainty

- `confidence` on `choice` and `score` measures how concentrated the
  distribution is. It is not proof that the answer is correct, and it is not
  permission to act.
- A `noul` near 0.5 means yes and no are equally likely. It does not mean
  "medium".
- Choose thresholds from measured accuracy on your own data and the cost of an
  error. Send uncertain or high-stakes cases to a person or a reasoning model.
- Ignore uncertainty on branches that the code does not use.

## Verify before relying on it

1. Run representative cases, including negations, empty inputs, and cases that
   fit no option.
2. For each failure, inspect the exact state, questions, answers, and
   resulting behavior. Separate missing evidence, model error, code error, and
   service failure.
3. Record accuracy, latency (`latency_ms`), and token usage (`usage`) per
   workload. Use these numbers, not demo results, to decide adoption.

The request format is the System One wire protocol. A self-hosted server that
speaks it, such as Laya, accepts the same request file, which makes a direct
comparison possible. Confidence values differ between backends, so do not reuse
a Jev threshold on another backend.
