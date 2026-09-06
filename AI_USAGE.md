# AI Usage

## Development approach

I used a spec-driven development approach for this challenge.

Before implementation, I defined the main requirements, architecture, modeling choices, data-quality rules, scope limits, and implementation stages. These decisions were reviewed before code was written.

From that point on, AI was used mainly to accelerate execution against the approved specification rather than to independently define the solution.

The workflow was:

1. define the requirement or technical decision;
2. review the trade-offs;
3. approve the intended behavior;
4. implement one bounded stage;
5. validate the result;
6. commit the completed stage.

This kept the project incremental, reviewable, and easier to control within the three-hour constraint.

## How I used AI

I used two AI systems with different roles.

- **Codex** was used primarily as an implementation accelerator against the approved specification.
- **ChatGPT** was used as a second review layer to challenge design decisions, identify overengineering, compare alternatives, and help verify that the solution remained simple and defensible.

After each implementation stage, I also used a separate review pass/subagent to inspect the changes for correctness, scope creep, and consistency with the approved design before moving forward. I treated those reviews as additional input and made the final call on whether a stage was ready to continue.

I kept responsibility for:
- scope;
- architecture;
- modeling decisions;
- trade-offs;
- approval of implementation stages;
- final validation.

AI was most useful for:
- producing implementation drafts from already-defined requirements;
- accelerating repetitive dbt, SQL, and test code;
- helping inspect failures and validate behavior;
- reviewing consistency between code, tests, and documentation.

I did not use AI as a one-shot repository generator. The project was built incrementally, with each major stage reviewed and committed separately.

## Main decisions and overrides

### Keeping the solution proportional to the challenge

An early version of the plan included broader rerun comparisons, multiple reconciliation checks, automatic retry/backoff behavior, and more elaborate recovery and schema-handling logic.

I decided to simplify that approach.

The challenge has a strict three-hour limit, so I kept the checks that directly support:
- grain;
- referential integrity;
- idempotency;
- relevant data quality.

More production-oriented safeguards were deliberately deferred to the "What I would do with more time" section.

### Python version

During environment setup, Python 3.14 exposed a real compatibility issue with the validated dbt dependency stack.

Because the challenge requires Python 3.11+, I chose to use a supported version between Python 3.11 and 3.13 instead of forcing the latest interpreter.

The priority was reproducibility and stability rather than using the newest available Python version.

### Ingestion performance

The first ingestion approach became a clear bottleneck because Python was processing and binding a large number of CSV rows into DuckDB.

I changed the approach so that Python remained responsible for download, caching, and source validation, while DuckDB read the cached CSV files directly using its native CSV reader.

This kept the design simple and reduced the ingestion time significantly without changing the raw-data contract.

### Incremental implementation

I intentionally implemented the project in small, independently verifiable stages.

The sequence was:
- project setup;
- ingestion;
- staging;
- dimensions and fact;
- data-quality checks;
- analytical marts;
- final verification and documentation.

Each stage was validated before moving forward and committed separately.

This made the implementation easier to inspect and reduced the risk of carrying hidden problems into later stages.

### Third analytical question

The original plan used daily station balance as the third analysis.

I compared that with a simpler bike type × rider segment analysis.

I chose the bike-mix analysis because it:
- uses attributes already available in the fact table;
- requires less additional transformation logic;
- is easier to validate and explain;
- still answers a meaningful analytical question.

The station-balance option was deferred because the available data does not include inventory, repositioning activity, or other information needed to support stronger operational conclusions.

## Documentation and review

All reported figures in the submission come from the actual DuckDB pipeline and analytical queries.

AI was used to help collect verified implementation details and review documentation for consistency, but the final submission was reviewed against the implemented behavior and measured outputs.

The main design choices and trade-offs in the README reflect decisions I made during the challenge and that I am prepared to explain in the follow-up discussion.

## Final ownership

AI was used heavily as an engineering accelerator, but I treated its outputs as proposals to review rather than final authority.

I defined the development structure, reviewed the main technical choices, rejected unnecessary complexity, approved each implementation stage, and validated the final result.

The submitted code, tests, analytical findings, and design decisions represent a solution I understand and can defend.