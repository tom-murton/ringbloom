# Ringbloom agent guide

This benchmark app is not currently a Git worktree. Work only inside this directory and
preserve benchmark evidence, human playtest results and App Store outcomes exactly as
recorded.

## Physical iPhone testing

When Tom asks to run or test the app on his attached iPhone, discover the current
`.xcodeproj` or `.xcworkspace` and shared scheme. Prefer the workspace when the project
uses workspace-managed dependencies, then run from this directory:

```bash
/Users/tommurton/GitHub/Build-an-app/scripts/test-on-iphone.sh <container> <scheme>
```

Use the helper's final `PHYSICAL_IPHONE_TESTS_PASSED` or
`PHYSICAL_IPHONE_TESTS_FAILED` line as the result. Swift Testing results are separate
from XCTest's potentially misleading `Executed 0 tests` footer. If the scheme has no
test action or tests, report that limitation rather than treating build success as test
coverage.
