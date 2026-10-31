# Dependencies and migrations

## Dependency review

When the change adds a dependency, check:

- whether the existing stack already solves the problem
- whether it is actively maintained
- what it adds to the size of what ships
- whether it has known vulnerabilities

## Migration review

When the change includes database migrations, load `database-design` and check each migration against its rules. File each finding under the review's areas, so a schema defect is a correctness or security finding. Trace every view and function that joins a changed table.
