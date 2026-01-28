========================
 S3 compatibility tests
========================

This is a set of unofficial Amazon AWS S3 compatibility
tests, that can be useful to people implementing software
that exposes an S3-like API. The tests use the Boto2 and Boto3 libraries.

The tests are executed with ``pytest``. Prefer creating a local Python
virtual environment and installing test tools there. Example (create a
venv and install pytest and the project test dependencies)::

  python3 -m venv .venv
  source .venv/bin/activate
  pip install -U pip
  pip install -r requirements.txt pytest

You will need to create a configuration file with the location of the
service and two different credentials. A sample configuration file named
``s3tests.conf.SAMPLE`` has been provided in this repo. This file can be
used to run the s3 tests on a Ceph cluster started with vstart.

Once you have that file copied and edited, you can run the tests the same
way upstream invokes them with a Splunk-specific configuration named
``splunk.conf``::

  # run using pytest and the upstream-style marker filter
  S3TEST_CONF=splunk.conf pytest -q s3tests/functional -m "not skip_for_splunk"

If you prefer to run tests directly with ``pytest`` (faster iteration,
no wrapper) make sure you have the test dependencies installed in
your active Python environment (for example, via virtualenv or pip).

Examples using ``pytest`` with `splunk.conf`:

    # run the full functional suite, excluding upstream skip list
    S3TEST_CONF=splunk.conf pytest -q s3tests/functional -m "not skip_for_splunk"

    # run a single file
    S3TEST_CONF=splunk.conf pytest -q s3tests/functional/test_headers.py -m "not skip_for_splunk"

    # run a single test function
    S3TEST_CONF=splunk.conf pytest -q s3tests/functional/test_headers.py::test_bucket_create_bad_contentlength_empty -k "not skip_for_splunk"

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

1. Create and activate a Python virtual environment and install deps::

  python3 -m venv .venv
  source .venv/bin/activate
  pip install -U pip
  pip install -r requirements.txt pytest

2. Copy the sample config and edit at least the required sections
   (``[s3 main]`` and ``[s3 alt]`` are required; ``[iam]`` and
   ``[tenant]`` are required for IAM/tenant tests)::

  cp s3tests.conf.SAMPLE splunk.conf
  # edit splunk.conf and set host/port/credentials

3. Run only the Splunk compliance tests (quick):

  S3TEST_CONF=splunk.conf pytest -q s3tests/functional -m splunk_compliance_test

4. Run the full suite (excluding versioning and skipped tests):

  S3TEST_CONF=splunk.conf pytest -q s3tests/functional/test_s3.py -m "not versioning and not skip_for_splunk"

Optional: run a single file or single test (still using the compliance marker)::

  S3TEST_CONF=splunk.conf pytest -q s3tests/functional/test_s3.py -m splunk_compliance_test
  S3TEST_CONF=splunk.conf pytest -q s3tests/functional/test_s3.py::test_multipart_upload -m splunk_compliance_test

Note: the project registers the ``splunk_compliance_test`` marker in
``pytest.ini``, and a ``s3tests/functional/splunk_compliance_tests.txt``
file is used to automatically mark candidate tests at collection time.

Required sections in `splunk.conf` (compulsory)

The test harness requires that `splunk.conf` contains at least the
following named sections. Create `splunk.conf` at the repository root and
ensure each section below is present and filled with appropriate values:

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


Some tests have attributes set based on their current reliability and
things like AWS not enforcing their spec stricly. You can filter tests
based on their attributes::

  S3TEST_CONF=aws.conf pytest -q s3tests/functional -m 'not fails_on_aws'

Most of the tests have both Boto3 and Boto2 versions. Tests written in
Boto2 are in the ``s3tests`` directory. Tests written in Boto3 are
located in the ``s3test_boto3`` directory.

You can run only the boto3 tests with::

  S3TEST_CONF=your.conf pytest -q s3tests/functional

========================
 STS compatibility tests
========================

This section contains some basic tests for the AssumeRole, GetSessionToken and AssumeRoleWithWebIdentity API's. The test file is located under ``s3tests/functional``.

To run the STS tests, the vstart cluster should be started with the following parameter (in addition to any parameters already used with it)::

        vstart.sh -o rgw_sts_key=abcdefghijklmnop -o rgw_s3_auth_use_sts=true

Note that the ``rgw_sts_key`` can be set to anything that is 128 bits in length.
After the cluster is up the following command should be executed::

      radosgw-admin caps add --tenant=testx --uid="9876543210abcdef0123456789abcdef0123456789abcdef0123456789abcdef" --caps="roles=*"

You can run only the sts tests (all the three API's) with::

  S3TEST_CONF=your.conf pytest -q s3tests/functional/test_sts.py

You can filter tests based on the attributes. There is a attribute named ``test_of_sts`` to run AssumeRole and GetSessionToken tests and ``webidentity_test`` to run the AssumeRoleWithWebIdentity tests. If you want to execute only ``test_of_sts`` tests you can apply that filter as below::

  S3TEST_CONF=your.conf pytest -q -m test_of_sts s3tests/functional/test_sts.py

For running ``webidentity_test`` you'll need have Keycloak running.

In order to run any STS test you'll need to add "iam" section to the config file. For further reference on how your config file should look check ``s3tests.conf.SAMPLE``.

========================
 IAM policy tests
========================

This is a set of IAM policy tests.
This section covers tests for user policies such as Put, Get, List, Delete, user policies with s3 actions, conflicting user policies etc
These tests uses Boto3 libraries. Tests are written in the ``s3test_boto3`` directory.

These iam policy tests uses two users with profile name "iam" and "s3 alt" as mentioned in s3tests.conf.SAMPLE.
If Ceph cluster is started with vstart, then above two users will get created as part of vstart with same access key, secrete key etc as mentioned in s3tests.conf.SAMPLE.
Out of those two users, "iam" user is with capabilities --caps=user-policy=* and "s3 alt" user is without capabilities.
Adding above capabilities to "iam" user is also taken care by vstart (If Ceph cluster is started with vstart).

To run these tests, create configuration file with section "iam" and "s3 alt" refer s3tests.conf.SAMPLE.

Once you have that configuration file copied and edited, you can run all the tests with::

  S3TEST_CONF=your.conf pytest -q s3tests/functional/test_iam.py

You can also specify specific test to run::

  S3TEST_CONF=your.conf pytest -q s3tests/functional/test_iam.py::test_put_user_policy

Some tests have attributes set such as "fails_on_rgw".
You can filter tests based on their attributes::

  S3TEST_CONF=your.conf pytest -q s3tests/functional/test_iam.py -m 'not fails_on_rgw'

========================
 Bucket logging tests
========================

Ceph has extensions for the bucket logging S3 API. For the tests to cover these extensions, the following file: `examples/rgw/boto3/service-2.sdk-extras.json` from the Ceph repo,
should be copied to the: `~/.aws/models/s3/2006-03-01/` directory on the machine where the tests are run.
If the file is not present, the tests will still run, but the extension tests will be skipped. In this case, the bucket logging object roll time must be decreased manually from its default of
300 seconds to 5 seconds::

  vstart.sh -o rgw_bucket_logging_object_roll_time=5

Then the tests can be run with::

  S3TEST_CONF=your.conf pytest -q s3tests/functional -m 'bucket_logging'

To run the only bucket logging tests that do not need extension of rollover time, use::

  S3TEST_CONF=your.conf pytest -q s3tests/functional -m 'bucket_logging and not fails_without_logging_rollover'
