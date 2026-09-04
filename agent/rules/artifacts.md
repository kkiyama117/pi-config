# Domain: Artifacts (durable outputs)

Read when: producing durable outputs (reports, generated files, scratch builds,
diagrams) in any project.

- Durable outputs go under the project's `artifacts/` directory — never the repo
  root, never ad-hoc paths.
- Ephemeral scratch no one will read again does not count; when unsure,
  `artifacts/` is the default.
