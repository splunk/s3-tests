========================
 Splunk S3 compatibility tests
========================

This is a set of unofficial Amazon AWS S3 compatibility
tests, that can be useful to people implementing software
that exposes an S3-like API. The tests use the Boto2 and Boto3 libraries.

**Paths:** All S3 test assets live in **s3tests/** (e.g. ``s3tests/run_core_s3_tests.sh``,
``s3tests/s3tests.conf.SAMPLE``, ``s3tests/splunk.conf``, ``s3tests/reports/``).

The tests are executed with ``pytest``. Prefer creating a local Python
virtual environment at repo root and installing test tools there. Example::

  python3 -m venv .venv
  source .venv/bin/activate
  pip install -U pip
  pip install -r s3tests/requirements.txt pytest
  pip install -e ./s3tests

You will need to create a configuration file with the location of the
service and two different credentials. A sample configuration file ``s3tests/s3tests.conf.SAMPLE`` has been provided.
Copy it to ``s3tests/splunk.conf`` and edit. The sample can be used to run
the s3 tests on a Ceph cluster started with vstart.

Once you have that file copied and edited (e.g. to ``s3tests/splunk.conf``), you can run
the tests the same way upstream invokes them::

  # run using the repository helper (from repo root)
  ./s3tests/run_core_s3_tests.sh

  # or run pytest directly (when running pytest directly you must apply the upstream skip filter)
  S3TEST_CONF=s3tests/splunk.conf pytest -q s3tests/functional -m "not skip_for_splunk"

If you prefer to run tests directly with ``pytest`` (faster iteration,
no wrapper) make sure you have the test dependencies installed in
your active Python environment (for example, via virtualenv or pip).

Examples using ``pytest`` with ``s3tests/splunk.conf`` (run from repo root):

    # run the full functional suite (pytest direct; apply upstream skip list)
    S3TEST_CONF=s3tests/splunk.conf pytest -q s3tests/functional -m "not skip_for_splunk"

    # run a single file (pytest direct; apply upstream skip list)
    S3TEST_CONF=s3tests/splunk.conf pytest -q s3tests/functional/test_headers.py -m "not skip_for_splunk"

    # run a single test function (pytest direct; apply upstream skip list)
    S3TEST_CONF=s3tests/splunk.conf pytest -q s3tests/functional/test_headers.py::test_bucket_create_bad_contentlength_empty -k "not skip_for_splunk"

Notes:

- If you use ``pytest`` directly, make sure required test dependencies
  (boto3, botocore, pytest, requests, etc.) are installed in the active
  environment (for example via a virtualenv or other Python environment).
- The repository contains a generated list of upstream tests to skip at
  ``s3tests/functional/skip_for_splunk_tests.txt`` and a
  ``s3tests/functional/conftest.py`` that will mark those test functions
  as skipped during collection. The ``-m "not skip_for_splunk"`` filter
  can be used with ``pytest`` to exclude any tests already marked with
  that pytest marker.

Bare minimum to run Splunk compliance tests

The following is the minimal setup and command to run the tests marked
as Splunk compliance checks (pytest marker: ``splunk_compliance_test``).
These commands assume you are in the repository root.

1. Create and activate a Python virtual environment at repo root and install deps::

  python3 -m venv .venv
  source .venv/bin/activate
  pip install -U pip
  pip install -r s3tests/requirements.txt pytest
  pip install -e ./s3tests

2. Copy the sample config into ``s3tests/`` and edit at least the required sections
   (``[s3 main]`` and ``[s3 alt]`` are required; ``[iam]`` and
   ``[tenant]`` are required for IAM/tenant tests)::

  cp s3tests/s3tests.conf.SAMPLE s3tests/splunk.conf
  # edit s3tests/splunk.conf and set host/port/credentials

3. Run only the Splunk compliance tests (quick):

  S3TEST_CONF=s3tests/splunk.conf pytest -q s3tests/functional -m splunk_compliance_test

4. Run the s3-core suite (excluding versioning) — optional full run:

  # If you'd like to run a curated, quick focused set first see the "Running the core S3 tests"
  # section below (it uses ``s3tests/run_core_s3_tests.sh``). If those core checks pass, run the full s3-core
  # suite (excluding versioning) as the final verification:

5. Run the full test suite excluding versioning and tests that should be skip_for_splunk:

  # This runs the full functional tests but excludes 'versioning' tests and tests that should not be run for Splunk.
    Use this when you want a comprehensive compatibility check that includes tests the wrapper normally filters out.
  S3TEST_CONF=s3tests/splunk.conf pytest -q s3tests/functional -m "not versioning and not skip_for_splunk"

Optional: run a single file or single test (still using the compliance marker)::

  S3TEST_CONF=s3tests/splunk.conf pytest -q s3tests/functional/test_s3.py -m splunk_compliance_test
  S3TEST_CONF=s3tests/splunk.conf pytest -q s3tests/functional/test_s3.py::test_multipart_upload -m splunk_compliance_test

Note: the project registers the ``splunk_compliance_test`` marker in
``pytest.ini`` (at repository root), and ``s3tests/functional/splunk_compliance_tests.txt``
is used to automatically mark candidate tests at collection time.

Required sections in `splunk.conf` (compulsory)

The test harness requires that `splunk.conf` contains at least the
following named sections. Create ``s3tests/splunk.conf`` (e.g. copy from
``s3tests/s3tests.conf.SAMPLE``) and ensure each section below is present and filled with appropriate values:

- ``[s3 main]`` — primary S3 endpoint credentials and connection fields used
  by most tests.
- ``[s3 alt]`` — alternate credentials used by ACL/permission tests.
- ``[iam]`` — (required if you run IAM policy tests) credentials/profile
  entries used by IAM tests.
- ``[tenant]`` — (required for multi-tenant RGW deployments) tenant-specific
  admin credentials and tenant name.

Below is a comprehensive sample `splunk.conf` containing the mandatory
sections plus commonly-used optional fields. This sample is compulsory as
the minimal starting point for running the functional tests; edit values
to match your test endpoint and credentials.

.. code-block:: ini

  ; -----------------------------
  ; S3 main (required)
  ; -----------------------------
  [s3 main]
  ; Host or IP address of the S3-compatible endpoint
  host = 127.0.0.1

  ; Port the endpoint listens on
  port = 8000

  ; Whether to use TLS/SSL (true/false)
  is_secure = false

  ; Optional: fully-qualified endpoint URL (overrides host/port/is_secure)
  ; endpoint = http://127.0.0.1:8000

  ; Whether to verify server TLS certificate (true/false)
  verify_ssl = false

  ; API name or region used by some tests
  api_name = 

  ; Default prefix for created buckets
  prefix = test-

  ; Signature/version behaviour (e.g., s3v4 or v2)
  signature_version = s3v4

  ; Primary credentials for main user
  access_key = TESTACCESSKEY
  secret_key = TESTSECRETKEY

  ; Optional: v2 credentials (if your target requires AWS v2 signing)
  v2_access_key = V2ACCESS
  v2_secret_key = V2SECRET

  ; Optional metadata used by some tests
  main_display_name = main-user
  main_user_id = 0123456789abcdef
  main_email = main@example.invalid

  ; Request timeout in seconds
  timeout = 60

  ; -----------------------------
  ; S3 alt (required)
  ; -----------------------------
  [s3 alt]
  ; Alternate credential pair used for ACL and permission tests
  access_key = ALTACCESSKEY
  secret_key = ALTSECRETKEY

  alt_display_name = alt-user
  alt_user_id = fedcba9876543210
  alt_email = alt@example.invalid

  ; -----------------------------
  ; IAM (required if running IAM tests)
  ; -----------------------------
  [iam]
  ; Credentials/profile used for IAM policy tests
  access_key = IAMACCESSKEY
  secret_key = IAMSECRETKEY
  ; Optional: display name / user id for iam user
  iam_display_name = iam-user
  iam_user_id = 0011223344556677

  ; -----------------------------
  ; Tenant (required for multi-tenant RGW)
  ; -----------------------------
  [tenant]
  ; Tenant name (if applicable)
  tenant = 
  tenant_admin_access_key = 
  tenant_admin_secret_key = 

  ; -----------------------------
  ; Notes
  ; - Provide at least the `s3 main` and `s3 alt` credential pairs.
  ; - Fill the `iam` section when running IAM policy tests.
  ; - Fill `tenant` for multi-tenant RGW testing.


Running the core S3 tests (s3tests/run_core_s3_tests.sh)
--------------------------------------------------------

The repository ships a helper script ``s3tests/run_core_s3_tests.sh`` that runs a curated subset of the
upstream functional tests. Run it from the repository root. It focuses on core object-storage semantics and intentionally skips
IAM, ACL/policy, advanced CORS/presign, checksum, logging and other backend-specific tests that
are frequently incompatible with some remote storages.

Quick setup

1. Create and activate a Python virtualenv at repo root and install dependencies::

  python3 -m venv .venv
  source .venv/bin/activate
  pip install -U pip
  pip install -r s3tests/requirements.txt pytest
  pip install -e ./s3tests

2. Copy the sample config into ``s3tests/`` and edit required sections (at minimum fill `[s3 main]` and `[s3 alt]`)::

  cp s3tests/s3tests.conf.SAMPLE s3tests/splunk.conf
  # edit s3tests/splunk.conf: set host/port/endpoint and credentials

Run the focused test launcher (from repo root)::

  ./s3tests/run_core_s3_tests.sh

Configuration and outputs

- Environment variables you can set before running:
  - `S3TEST_CONF` – path to config file (default: `s3tests/splunk.conf`).
  - `PYTEST_TARGET` – pytest target path (default: `s3tests/functional`).
  - `REPORT_DIR` – directory where `junit-*.xml` and `pytest-*.log` are written (default: `s3tests/reports`).
- Artifacts produced in `s3tests/reports/`:
  - `junit-<timestamp>.xml` — JUnit-style XML useful for CI dashboards.
  - `pytest-<timestamp>.log` — full pytest output log (useful for triage and failures).
- The script exits with pytest's exit code so CI will flag failures.

What is intentionally excluded
------------------------------
The launcher deselects tests that exercise features not commonly implemented by simple S3-like backends:

- IAM/STS and tenant management
- Public ACL / BlockPublicAcls enforcement and some ACL permutations
- Advanced CORS / browser presigned OPTIONS handshake tests
- Checksum/GetObjectAttributes and other object-attribute extensions
- Bucket logging and other vendor-specific extensions

Triage tips when testing against other remote storage providers
----------------------------------------------------------
- If tests fail, collect `s3tests/reports/pytest-<timestamp>.log` and the referenced raw test output. This will
  contain the request/response bodies for the failing test.
- See `s3tests/reports/vendor-failure-mapping.csv` for a mapping of known vendor failures to core
  operations and recommended short-term test changes (skip/xfail) or long-term fixes.
- If you need a narrower or broader selection of tests, edit `s3tests/run_core_s3_tests.sh` to add/remove `--deselect`
  entries or run pytest directly with the marker filters shown earlier in this README.
