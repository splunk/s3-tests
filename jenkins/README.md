# Running s3-tests against Storj/Gateway-MT

The toolset in this repository makes it easy to perform Gateway-MT's verification!
On every commit to main, Jenkins builds s3-tests and tests it with the off-main branch Gateway-MT.
We encourage everyone to also do this locally before pushes to save on CI cycles.

## Running tests locally

Warning: this will take a long time!

`$ make ci-run`

Optionally, clean everything up after the tests finish:

`$ make ci-purge`
