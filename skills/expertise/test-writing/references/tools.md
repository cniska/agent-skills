# Tools and waits a test cannot fake

Read this when a test runs another program, or waits on something the runner's fakes cannot reach.

## Git

Give git an empty global and system config, and drop every `GIT_*` variable from the environment the test passes it. A hook exports `GIT_DIR`, so a test run from inside a hook acts on the real repo, and a global `commit.gpgsign true` signs every test commit.

## A wait in another process

A wait the fakes cannot reach, such as a native library's lock timeout honored in another process, is passed in as a dependency the way the clock is. Production passes the real value through the same parameter, and the test passes 0.
