# RT-01 Synthetic Fixtures

Use these logs to validate the analyzer before spending device time.

All examples use:

```sh
--locked-from-ms 1000 --unlock-at-ms 5000
```

Expected outcomes:

```text
pass.logcat                   status=pass         locked_evidence=2
fail_after_unlock.logcat      status=fail         locked_evidence=0
inconclusive_no_evidence.logcat status=inconclusive locked_evidence=0
```

Example command:

```sh
mix meshx.mobile.rt01.analyze \
  --input apps/meshx_mobile_app/test/fixtures/rt01/pass.logcat \
  --locked-from-ms 1000 \
  --unlock-at-ms 5000
```
