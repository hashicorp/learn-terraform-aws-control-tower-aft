#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

export AFT_MGMT_ACCT="$(terraform output -raw aft_management_account_id)"
export LOG_ACCT="$(terraform output -raw log_archive_account_id)"
export REGION="$(terraform output -raw region)"
export AWS_PAGER=""
if grep -q "Warning" <<<$AFT_MGMT_ACCT; then
  echo "\$AFT_MGMT_ACCT is empty. Run 'terraform refresh'"
  exit 1
fi
if grep -q "Warning" <<<$LOG_ACCT; then
  echo "\$LOG_ACCT is empty. Run 'terraform refresh'"
  exit 1
fi
if ! grep -q aft-log-acct ~/.aws/config; then
  cat <<EOF >>~/.aws/config
[profile aft-log-acct]
source_profile = default
role_arn = arn:aws:iam::${LOG_ACCT}:role/AWSControlTowerExecution
[profile aft-mgmt-acct]
source_profile = default
role_arn = arn:aws:iam::${AFT_MGMT_ACCT}:role/AWSControlTowerExecution
EOF
fi

export AWS_PROFILE="aft-mgmt-acct"

## Delete vault backups
VAULT_NAME="aft-controltower-backup-vault"
for ARN in $(aws backup list-recovery-points-by-backup-vault --region ${REGION} --backup-vault-name "${VAULT_NAME}" --query 'RecoveryPoints[].RecoveryPointArn' --output text); do
  echo "Deleting backup ${ARN} ..."
  aws backup delete-recovery-point --region ${REGION} --backup-vault-name "${VAULT_NAME}" --recovery-point-arn "${ARN}"
done

# Deleting items in AFT Management Account
AFT_MGMT_BUCKETS=(
  "aft-customizations-pipeline-${AFT_MGMT_ACCT}"
  "aft-backend-${AFT_MGMT_ACCT}-primary-region"
  "aft-backend-${AFT_MGMT_ACCT}-secondary-region"
)
for bucket in ${AFT_MGMT_BUCKETS[*]}; do
  echo "Deleting ${bucket}"
  # Check if bucket versions and markers
  bucket_version_status=$(aws s3api list-object-versions --bucket "${bucket}" --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>&1)
  bucket_markers_status=$(aws s3api list-object-versions --bucket "${bucket}" --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>&1)
  # Remove bucket version items and markers
  if echo "${bucket_version_status}" | (! grep -q 'NoSuchBucket'); then
    echo "- Deleting versions"
    aws s3api delete-objects --bucket "${bucket}" --delete "$(aws s3api list-object-versions --bucket "${bucket}" --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"
  fi
  if echo "${bucket_markers_status}" | (! grep -q 'NoSuchBucket'); then
    echo "- Deleting markers"
    aws s3api delete-objects --bucket "${bucket}" --delete "$(aws s3api list-object-versions --bucket "${bucket}" --output=json --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')"
  fi
  if aws s3api head-bucket --bucket "${bucket}" 2>/dev/null; then
    echo "- Deleting bucket"
    aws s3 rb s3://${bucket} --force
  fi
done
# Deleting items in AFT Log Account
export AWS_PROFILE="aft-log-acct"
AFT_LOG_BUCKETS=(
  "aws-aft-logs-${LOG_ACCT}-${REGION}"
  "aws-aft-s3-access-logs-${LOG_ACCT}-${REGION}"
)
for bucket in ${AFT_LOG_BUCKETS[*]}; do
  echo "Deleting ${bucket}"
  # Check if bucket versions and markers
  bucket_version_status=$(aws s3api list-object-versions --bucket "${bucket}" --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>&1)
  bucket_markers_status=$(aws s3api list-object-versions --bucket "${bucket}" --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>&1)
  # Remove bucket version items and markers
  if echo "${bucket_version_status}" | (! grep -q 'NoSuchBucket'); then
    echo "- Deleting versions"
    aws s3api delete-objects --bucket "${bucket}" --delete "$(aws s3api list-object-versions --bucket "${bucket}" --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"
  fi
  if echo "${bucket_markers_status}" | (! grep -q 'NoSuchBucket'); then
    echo "- Deleting markers"
    aws s3api delete-objects --bucket "${bucket}" --delete "$(aws s3api list-object-versions --bucket "${bucket}" --output=json --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')"
  fi
  if aws s3api head-bucket --bucket "${bucket}" 2>/dev/null; then
    echo "- Deleting bucket"
    aws s3 rb s3://${bucket} --force
  fi
done
