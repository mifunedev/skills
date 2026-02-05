# Ruska AI Skills

A collection of agent skills for Claude Code and Cursor that extend AI capabilities with specialized knowledge, workflows, and tool integrations.

## What Are Skills?

Skills are modular, self-contained folders that transform general-purpose AI agents into specialized assistants. They provide:

- **Specialized Workflows** — Multi-step procedures for specific domains
- **Tool Integrations** — Instructions for working with specific file formats or APIs
- **Domain Expertise** — Company-specific knowledge, schemas, business logic
- **Bundled Resources** — Scripts, references, and assets for complex tasks

## Skill Structure

Every skill follows this directory structure:

```
skill-name/
├── SKILL.md              # Required — main instructions and metadata
├── references/           # Optional — documentation loaded on demand
│   └── api-docs.md
├── scripts/              # Optional — executable utility scripts
│   └── helper.py
└── assets/               # Optional — templates, images, files for output
    └── template.html
```

### SKILL.md Format

```markdown
---
name: your-skill-name
description: Brief description of what this skill does and when to use it. Include trigger phrases.
---

# Your Skill Name

## Instructions
Clear, step-by-step guidance for the agent.

## Examples
Concrete examples demonstrating usage.
```

### Metadata Fields

| Field | Requirements | Purpose |
|-------|--------------|---------|
| `name` | Max 64 chars, lowercase letters/numbers/hyphens | Unique identifier |
| `description` | Max 1024 chars | Triggers skill activation—be specific |

## Installation

### Personal Skills (All Projects)

```bash
# Clone to personal skills directory
git clone https://github.com/ruska-ai/skills.git ~/.cursor/skills/ruska-ai

# Or for Claude Code
git clone https://github.com/ruska-ai/skills.git ~/.codex/skills/ruska-ai
```

### Project Skills (Repository-Specific)

```bash
# Add as submodule to your project
git submodule add https://github.com/ruska-ai/skills.git .cursor/skills/ruska-ai
```

## Writing Effective Skills

### Core Principles

1. **Concise is Key** — Only include context the agent doesn't already have
2. **Keep SKILL.md Under 500 Lines** — Use progressive disclosure for detailed content
3. **Be Specific in Descriptions** — Include trigger phrases and scenarios
4. **Set Appropriate Degrees of Freedom** — Match specificity to task fragility

### Description Best Practices

Write descriptions in third person with both WHAT and WHEN:

```yaml
# Good
description: Extract text from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.

# Bad (too vague)
description: Helps with documents
```

### Progressive Disclosure

Keep essential instructions in SKILL.md; move detailed references to separate files:

```markdown
## Quick Start
[Essential instructions]

## Additional Resources
- For API details, see [references/api.md](references/api.md)
- For examples, see [references/examples.md](references/examples.md)
```

## Common Patterns

### Template Pattern

```markdown
## Report Format

Use this template:

\`\`\`markdown
# [Title]

## Summary
[Key findings]

## Recommendations
1. Action item
2. Action item
\`\`\`
```

### Workflow Pattern

```markdown
## Process

1. **Analyze** — Review the input
2. **Plan** — Determine approach
3. **Execute** — Run the operation
4. **Validate** — Verify the output
```

### Conditional Pattern

```markdown
## Choose Your Path

**Creating new?** → Follow "Creation Workflow"
**Editing existing?** → Follow "Edit Workflow"
```

## Bundled Resources

### Scripts (`scripts/`)

Executable code for deterministic, repeatable tasks:

```bash
python scripts/validate.py input.json
```

### References (`references/`)

Documentation loaded into context as needed:

- API specifications
- Database schemas
- Domain knowledge
- Workflow guides

### Assets (`assets/`)

Files used in output (not loaded into context):

- Templates
- Images
- Boilerplate code

## Anti-Patterns to Avoid

| Avoid | Instead |
|-------|---------|
| Too many library options | Provide one default with escape hatch |
| Time-sensitive information | Use versioned sections |
| Vague skill names like `helper` | Use descriptive names like `pdf-processor` |
| Windows-style paths `scripts\file.py` | Use forward slashes `scripts/file.py` |

## Contributing

1. Fork this repository
2. Create a skill following the structure above
3. Ensure your skill:
   - Has a descriptive name (max 64 chars, lowercase with hyphens)
   - Includes specific description with trigger phrases
   - Keeps SKILL.md under 500 lines
   - Uses progressive disclosure for detailed content
4. Submit a pull request

## License

MIT License — See [LICENSE](LICENSE) for details.
