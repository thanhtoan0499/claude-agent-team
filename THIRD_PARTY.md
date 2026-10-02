# Third-party material

Role skills in `skills/` are condensed and adapted from the open-source projects below. Each carries a one-line `Adapted from ...` comment under
its frontmatter. Changes: shortened, rewritten (not copied verbatim), tool and process references removed (agents here have no Skill tool, no web
and no way to ask the user), human-partner steps replaced by `NEEDS_DECISION`, team report contract and severity scheme added.

| This plugin | Adapted from | Licence |
|---|---|---|
| `evidence-before-claims` | obra/superpowers `verification-before-completion` | MIT |
| `tdd-red-green` | obra/superpowers `test-driven-development` | MIT |
| `root-cause-first` | obra/superpowers `systematic-debugging` | MIT |
| `receiving-findings` | obra/superpowers `receiving-code-review` | MIT |
| `test-quality` | obra/superpowers `test-driven-development/writing-good-tests` | MIT |
| `review-method` | obra/superpowers `requesting-code-review/code-reviewer` | MIT |
| `stack-checks` | awesome-skills/code-review-skill (security, SQL-injection, FastAPI, React references) | MIT |
| `plan-writing` | obra/superpowers `writing-plans` | MIT |
| `ux-spec-format`, `a11y-acceptance` | aditya-ariosity/ux-ui-skills `handoff-to-dev` and its accessibility reference | MIT |
| `copy-and-restraint` | anthropics/skills `frontend-design` | Apache-2.0 |
| `react-vite-perf` | vercel-labs/agent-skills `react-best-practices` (licence stated in the skill's frontmatter; the repo has no LICENSE file; rules paraphrased, no code copied) | MIT |
| `ui-guidelines` | vercel-labs/web-interface-guidelines (`command.md` rules) | MIT |
| `test-gap-analysis` | anthropics/claude-plugins-official `pr-review-toolkit/pr-test-analyzer` | Apache-2.0 |
| `silent-failure-and-boundaries` | anthropics/claude-plugins-official `pr-review-toolkit/silent-failure-hunter` | Apache-2.0 |
| `ui-recon-and-a11y-verify` | anthropics/skills `webapp-testing` | Apache-2.0 |

## MIT
Copyright (c) 2025 Jesse Vincent (obra/superpowers)
Copyright (c) 2025 awesome-skills (awesome-skills/code-review-skill)
Copyright (c) 2026 Aditya Sharma (aditya-ariosity/ux-ui-skills)
Copyright (c) 2025 Vercel Labs (vercel-labs/web-interface-guidelines; vercel-labs/agent-skills react-best-practices)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Apache-2.0
Works by Anthropic (pr-review-toolkit, webapp-testing, frontend-design). The licence text is in `licenses/Apache-2.0.txt`; no NOTICE file is shipped with
these works. The adapted skills are modified versions, as stated above.
