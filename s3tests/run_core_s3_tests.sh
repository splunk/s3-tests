#!/usr/bin/env bash
set -euo pipefail

# Run from repo root or from s3tests/. Config and reports live in s3tests/.
# Usage: ./s3tests/run_core_s3_tests.sh   (from repo root)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
S3TEST_CONF=${S3TEST_CONF:-$SCRIPT_DIR/splunk.conf}
PYTEST_TARGET=${PYTEST_TARGET:-s3tests/functional}
REPORT_DIR=${REPORT_DIR:-$SCRIPT_DIR/reports}
mkdir -p "$REPORT_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
JUNIT_FILE="$REPORT_DIR/junit-${TIMESTAMP}.xml"
LOG_FILE="$REPORT_DIR/pytest-${TIMESTAMP}.log"

cd "$REPO_ROOT"

# Configurable environment variables (in addition to S3TEST_CONF, REPORT_DIR above):
# - PYTEST_TARGET: path to tests (default: s3tests/functional)
# - PYTEST_ARGS: optional; if set (as a string), used as base pytest args instead of -q

# If caller provided PYTEST_ARGS env var, use it (as a string); otherwise start with sane defaults.
if [ -z "${PYTEST_ARGS+x}" ]; then
  PYTEST_ARGS=( -q )
else
  read -r -a PYTEST_ARGS <<< "$PYTEST_ARGS"
fi

PYTEST_MARK_EXCLUDE="not (iam_account or iam_cross_account or iam_role or iam_user or iam_tenant or \
bucket_policy or user_policy or role_policy or session_policy or group_policy or auth_common or \
object_lock or sse_s3 or encryption or bucket_encryption or cors or acl or acl_required or \
webidentity or sts or iam or s3select or checksum or logging or policy or fails_on_aws)"

PYTEST_KEY_EXCLUDE="not (test_lifecycle_expiration_header_put or test_lifecycle_expiration_header_head or \
test_lifecycle_expiration_header_tags_head or test_object_checksum_sha256 or \
test_versioning_concurrent_multi_object_delete)"

PYTEST_ARGS+=( "$PYTEST_TARGET" -m "$PYTEST_MARK_EXCLUDE" -k "$PYTEST_KEY_EXCLUDE" --junitxml "$JUNIT_FILE" )

DESELECT_MODULES=(
  "s3tests/functional/test_iam.py"
  "s3tests/functional/test_sts.py"
  "s3tests/functional/test_s3select.py"
  "s3tests/functional/test_headers.py"
)

# Add failing/unsupported tests to per-test deselect (from original 310-line script)
DESELECT_TESTS=(
  # bucket listing / encoding / continuation token
  "s3tests/functional/test_s3.py::test_bucket_listv2_encoding_basic"
  "s3tests/functional/test_s3.py::test_bucket_list_encoding_basic"
  "s3tests/functional/test_s3.py::test_bucket_list_prefix_unreadable"
  "s3tests/functional/test_s3.py::test_bucket_listv2_continuationtoken_empty"
  "s3tests/functional/test_s3.py::test_bucket_listv2_both_continuationtoken_startafter"
  "s3tests/functional/test_s3.py::test_bucket_list_return_data"
  "s3tests/functional/test_s3.py::test_bucket_list_return_data_versioning"
  "s3tests/functional/test_s3.py::test_bucket_listv2_objects_anonymous"
  # CORS / presigned / ACL related
  "s3tests/functional/test_s3.py::test_bucket_concurrent_set_canned_acl"
  "s3tests/functional/test_s3.py::test_expected_bucket_owner"
  "s3tests/functional/test_s3.py::test_cors_presigned_put_object"
  "s3tests/functional/test_s3.py::test_cors_presigned_put_object_with_acl"
  "s3tests/functional/test_s3.py::test_cors_presigned_put_object_v2"
  "s3tests/functional/test_s3.py::test_cors_presigned_put_object_tenant_v2"
  "s3tests/functional/test_s3.py::test_cors_presigned_put_object_tenant"
  "s3tests/functional/test_s3.py::test_cors_presigned_put_object_tenant_with_acl"
  # multipart / atomic / versioning / tags / object-lock
  "s3tests/functional/test_s3.py::test_atomic_dual_write_8mb"
  "s3tests/functional/test_s3.py::test_multipart_resend_first_finishes_last"
  "s3tests/functional/test_s3.py::test_versioned_object_acl_no_version_specified"
  "s3tests/functional/test_s3.py::test_put_excess_tags"
  "s3tests/functional/test_s3.py::test_object_lock_put_obj_lock_invalid_days"
  "s3tests/functional/test_s3.py::test_object_lock_put_obj_lock_invalid_years"
  # policies / public ACL / block-public tests
  "s3tests/functional/test_s3.py::test_get_bucket_policy_status"
  "s3tests/functional/test_s3.py::test_get_public_acl_bucket_policy_status"
  "s3tests/functional/test_s3.py::test_get_authpublic_acl_bucket_policy_status"
  "s3tests/functional/test_s3.py::test_get_publicpolicy_acl_bucket_policy_status"
  "s3tests/functional/test_s3.py::test_get_nonpublicpolicy_acl_bucket_policy_status"
  "s3tests/functional/test_s3.py::test_get_nonpublicpolicy_principal_bucket_policy_status"
  "s3tests/functional/test_s3.py::test_block_public_object_canned_acls"
  "s3tests/functional/test_s3.py::test_block_public_policy_with_principal"
  "s3tests/functional/test_s3.py::test_block_public_restrict_public_buckets"
  "s3tests/functional/test_s3.py::test_ignore_public_acls"
  "s3tests/functional/test_s3.py::test_multipart_upload_on_a_bucket_with_policy"
  # logging / bucket logging tests
  "s3tests/functional/test_s3.py::test_put_bucket_logging"
  "s3tests/functional/test_s3.py::test_put_bucket_logging_errors"
  "s3tests/functional/test_s3.py::test_bucket_logging_owner"
  "s3tests/functional/test_s3.py::test_put_bucket_logging_permissions"
  "s3tests/functional/test_s3.py::test_put_bucket_logging_policy_wildcard"
  # multipart attribute helpers / listing attributes
  "s3tests/functional/test_s3.py::test_get_multipart_object_attributes"
  "s3tests/functional/test_s3.py::test_get_paginated_multipart_object_attributes"
  "s3tests/functional/test_s3.py::test_get_single_multipart_object_attributes"
  # raw / anon / ACL / bucket naming / multipart / CORS / conditional / ownership (from original long list)
  "s3tests/functional/test_s3.py::test_put_object_ifnonmatch_failed"
  "s3tests/functional/test_s3.py::test_object_raw_get_bucket_gone"
  "s3tests/functional/test_s3.py::test_object_raw_get_object_gone"
  "s3tests/functional/test_s3.py::test_object_put_acl_mtime"
  "s3tests/functional/test_s3.py::test_object_raw_authenticated_object_gone"
  "s3tests/functional/test_s3.py::test_object_raw_get_x_amz_expires_not_expired"
  "s3tests/functional/test_s3.py::test_object_raw_get_x_amz_expires_not_expired_tenant"
  "s3tests/functional/test_s3.py::test_object_raw_get_x_amz_expires_out_range_zero"
  "s3tests/functional/test_s3.py::test_object_raw_get_x_amz_expires_out_max_range"
  "s3tests/functional/test_s3.py::test_object_raw_get_x_amz_expires_out_positive_range"
  "s3tests/functional/test_s3.py::test_object_anon_put_write_access"
  "s3tests/functional/test_s3.py::test_object_raw_put_authenticated_expired"
  "s3tests/functional/test_s3.py::test_bucket_create_naming_bad_ip"
  "s3tests/functional/test_s3.py::test_bucket_create_exists_nonowner"
  "s3tests/functional/test_s3.py::test_bucket_recreate_overwrite_acl"
  "s3tests/functional/test_s3.py::test_bucket_recreate_new_acl"
  "s3tests/functional/test_s3.py::test_bucket_acl_default"
  "s3tests/functional/test_s3.py::test_put_bucket_acl_grant_group_read"
  "s3tests/functional/test_s3.py::test_object_acl_canned_bucketownerfullcontrol"
  "s3tests/functional/test_s3.py::test_bucket_acl_canned_private_to_private"
  "s3tests/functional/test_s3.py::test_object_acl"
  "s3tests/functional/test_s3.py::test_object_acl_write"
  "s3tests/functional/test_s3.py::test_object_acl_writeacp"
  "s3tests/functional/test_s3.py::test_object_acl_read"
  "s3tests/functional/test_s3.py::test_object_acl_readacp"
  "s3tests/functional/test_s3.py::test_bucket_acl_grant_userid_fullcontrol"
  "s3tests/functional/test_s3.py::test_bucket_acl_grant_userid_read"
  "s3tests/functional/test_s3.py::test_bucket_acl_grant_userid_readacp"
  "s3tests/functional/test_s3.py::test_bucket_acl_grant_userid_write"
  "s3tests/functional/test_s3.py::test_object_header_acl_grants"
  "s3tests/functional/test_s3.py::test_bucket_header_acl_grants"
  "s3tests/functional/test_s3.py::test_bucket_acl_grant_email_not_exist"
  "s3tests/functional/test_s3.py::test_access_bucket_private_objectv2_private"
  "s3tests/functional/test_s3.py::test_access_bucket_private_objectv2_publicread"
  "s3tests/functional/test_s3.py::test_access_bucket_private_objectv2_publicreadwrite"
  "s3tests/functional/test_s3.py::test_list_buckets_anonymous"
  "s3tests/functional/test_s3.py::test_bucket_create_special_key_names"
  "s3tests/functional/test_s3.py::test_multipart_upload_empty"
  "s3tests/functional/test_s3.py::test_list_multipart_upload_owner"
  "s3tests/functional/test_s3.py::test_multipart_single_get_part"
  "s3tests/functional/test_s3.py::test_non_multipart_get_part"
  "s3tests/functional/test_s3.py::test_non_multipart_sse_c_get_part"
  "s3tests/functional/test_s3.py::test_cors_origin_response"
  "s3tests/functional/test_s3.py::test_cors_origin_wildcard"
  "s3tests/functional/test_s3.py::test_cors_header_option"
  "s3tests/functional/test_s3.py::test_cors_presigned_get_object"
  "s3tests/functional/test_s3.py::test_cors_presigned_get_object_tenant"
  "s3tests/functional/test_s3.py::test_cors_presigned_get_object_v2"
  "s3tests/functional/test_s3.py::test_delete_marker_nonversioned"
  "s3tests/functional/test_s3.py::test_delete_marker_expiration"
  "s3tests/functional/test_s3.py::test_put_object_if_match"
  "s3tests/functional/test_s3.py::test_multipart_put_object_if_match"
  "s3tests/functional/test_s3.py::test_put_current_object_if_none_match"
  "s3tests/functional/test_s3.py::test_multipart_put_current_object_if_none_match"
  "s3tests/functional/test_s3.py::test_put_current_object_if_match"
  "s3tests/functional/test_s3.py::test_multipart_put_current_object_if_match"
  "s3tests/functional/test_s3.py::test_put_object_current_if_match"
  "s3tests/functional/test_s3.py::test_delete_object_if_match"
  "s3tests/functional/test_s3.py::test_delete_object_current_if_match"
  "s3tests/functional/test_s3.py::test_delete_object_version_if_match"
  "s3tests/functional/test_s3.py::test_delete_object_if_match_last_modified_time"
  "s3tests/functional/test_s3.py::test_delete_object_current_if_match_last_modified_time"
  "s3tests/functional/test_s3.py::test_delete_object_version_if_match_last_modified_time"
  "s3tests/functional/test_s3.py::test_delete_object_if_match_size"
  "s3tests/functional/test_s3.py::test_delete_object_current_if_match_size"
  "s3tests/functional/test_s3.py::test_delete_object_version_if_match_size"
  "s3tests/functional/test_s3.py::test_delete_objects_current_if_match"
  "s3tests/functional/test_s3.py::test_delete_objects_version_if_match"
  "s3tests/functional/test_s3.py::test_delete_objects_if_match_last_modified_time"
  "s3tests/functional/test_s3.py::test_delete_objects_current_if_match_last_modified_time"
  "s3tests/functional/test_s3.py::test_delete_objects_version_if_match_last_modified_time"
  "s3tests/functional/test_s3.py::test_delete_objects_if_match_size"
  "s3tests/functional/test_s3.py::test_delete_objects_current_if_match_size"
  "s3tests/functional/test_s3.py::test_delete_objects_version_if_match_size"
  "s3tests/functional/test_s3.py::test_create_bucket_no_ownership_controls"
  "s3tests/functional/test_s3.py::test_create_bucket_bucket_owner_enforced"
  "s3tests/functional/test_s3.py::test_create_bucket_bucket_owner_preferred"
  "s3tests/functional/test_s3.py::test_create_bucket_object_writer"
  "s3tests/functional/test_s3.py::test_put_bucket_ownership_bucket_owner_enforced"
  "s3tests/functional/test_s3.py::test_put_bucket_ownership_bucket_owner_preferred"
  "s3tests/functional/test_s3.py::test_put_bucket_ownership_object_writer"
)

for f in "${DESELECT_MODULES[@]}"; do
  PYTEST_ARGS+=( --deselect "$f" )
done
for t in "${DESELECT_TESTS[@]}"; do
  PYTEST_ARGS+=( --deselect "$t" )
done

echo "Running pytest with exclusions..."
echo "S3TEST_CONF=$S3TEST_CONF pytest ${PYTEST_ARGS[*]}"

S3TEST_CONF="$S3TEST_CONF" pytest "${PYTEST_ARGS[@]}" 2>&1 | tee "$LOG_FILE"
EXIT_STATUS=${PIPESTATUS[0]}

echo "pytest finished with exit status ${EXIT_STATUS}"
echo "JUnit report: ${JUNIT_FILE}"
echo "Raw log: ${LOG_FILE}"

exit ${EXIT_STATUS}
