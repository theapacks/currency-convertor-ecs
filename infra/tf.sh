#!/bin/bash
set -e

# --- Configuration ---
readonly ENVS_ROOT_DIR="environments"
readonly DEFAULT_TFVARS="terraform.tfvars"
readonly BACKEND_CONFIG_FILE="_backend.tf"

# --- Helper Functions ---

# Function to print usage information and exit.
usage() {
    echo "Usage: $0 <command> --env=<env_name> [--module=<module_name>] [--tfvars=<vars_file>]"
    echo ""
    echo "Terraform wrapper script with automated S3 backend setup."
    echo ""
    echo "Commands:"
    echo "  init        Initialize a new or existing Terraform working directory."
    echo "  plan        Create an execution plan."
    echo "  apply       Apply the changes required to reach the desired state."
    echo "  destroy     Destroy Terraform-managed infrastructure."
    echo "  fmt         Format Terraform configuration."
    echo "  validate    Validate the Terraform files."
    echo ""
    echo "Options:"
    echo "  --env=<name>         (Required) The name of the environment to operate on (e.g., 'dev', 'prod')."
    echo "  --module=<name>      (Optional) Target a specific module for 'plan' or 'destroy'."
    echo "  --tfvars=<filename>  (Optional) Specify a .tfvars file to use. Defaults to '${DEFAULT_TFVARS}'."
    exit 1
}

# This function checks for and sets up the Terraform S3 backend if it's not configured.
# It creates an S3 bucket for state and a DynamoDB table for locking.
setup_terraform_backend() {
    local env_dir=$1
    local env_name
    env_name=$(basename "$env_dir")

    echo "Checking for existing Terraform backend configuration in '${env_dir}'..."

    # Check all .tf files in the target directory for a backend "s3" block.
    if grep -r -q -E '^\s*backend\s+"s3"' "$env_dir" --include='*.tf' 2>/dev/null; then
        echo "Terraform S3 backend is already configured in this environment. Skipping setup."
        return
    fi

    echo "Terraform backend not found. Starting interactive setup..."
    echo "--------------------------------------------------------"

    # Read AWS region and profile from the tfvars file (default or specified)
    aws_region=$(grep -E '^ *aws_region *= *' "${env_dir}/${DEFAULT_TFVARS}" | awk -F= '{gsub(/"/, "", $2); print $2}' | xargs)
    aws_profile=$(grep -E '^ *aws_profile *= *' "${env_dir}/${DEFAULT_TFVARS}" | awk -F= '{gsub(/"/, "", $2); print $2}' | xargs)

    if [ -z "$aws_region" ]; then
        echo "Error: aws_region not found in ${env_dir}/${DEFAULT_TFVARS}"
        exit 1
    fi

    if [ -z "$aws_profile" ]; then
        echo "Error: aws_profile not found in ${env_dir}/${DEFAULT_TFVARS}"
        exit 1
    fi

    # Suggest a globally unique bucket name using the AWS Account ID.
    local account_id
    account_id=$(aws sts get-caller-identity --profile "$aws_profile" --query "Account" --output text)
    local suggested_bucket_name="tfstate-${account_id}-${aws_region}-${env_name}"
    read -p "Enter S3 bucket name for state file [${suggested_bucket_name}]: " s3_bucket
    s3_bucket=${s3_bucket:-$suggested_bucket_name}

    local state_key="${env_name}/terraform.tfstate"

    echo "--------------------------------------------------------"
    echo "Summary of backend resources to be created:"
    echo "  AWS Profile:      ${aws_profile}"
    echo "  AWS Region:       ${aws_region}"
    echo "  S3 Bucket:        ${s3_bucket}"
    echo "  State File Key:   ${state_key}"
    echo "  Locking:          Native S3 locking (use_lockfile = true)"
    echo "--------------------------------------------------------"
    read -p "Do you want to proceed with creating these resources? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Aborted by user."
        exit 1
    fi

    # --- Create S3 Bucket (if it doesn't exist) ---
    echo "Checking S3 bucket: ${s3_bucket}..."
    if ! aws s3api head-bucket --bucket "$s3_bucket" --profile "$aws_profile" 2>/dev/null; then
        echo "Creating S3 bucket..."
        aws s3api create-bucket \
            --bucket "$s3_bucket" \
            --region "$aws_region" \
            --profile "$aws_profile" \
            --create-bucket-configuration LocationConstraint="$aws_region" >/dev/null
        aws s3api put-bucket-versioning \
            --bucket "$s3_bucket" \
            --profile "$aws_profile" \
            --versioning-configuration Status=Enabled >/dev/null
        aws s3api put-public-access-block \
            --bucket "$s3_bucket" \
            --profile "$aws_profile" \
            --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" >/dev/null
        echo "S3 bucket created and configured successfully."
    else
        echo "S3 bucket already exists. Skipping creation."
    fi

    # --- Create DynamoDB Table (if it doesn't exist) ---
    echo "Checking DynamoDB table: ${dynamodb_table}..."
    if ! aws dynamodb describe-table --table-name "$dynamodb_table" --region "$aws_region" --profile "$aws_profile" &>/dev/null; then
        echo "Creating DynamoDB table for state locking..."
        aws dynamodb create-table \
            --table-name "$dynamodb_table" \
            --region "$aws_region" \
            --profile "$aws_profile" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 >/dev/null
        echo "Waiting for DynamoDB table to become active..."
        aws dynamodb wait table-exists --table-name "$dynamodb_table" --region "$aws_region" --profile "$aws_profile"
        echo "DynamoDB table created successfully."
    else
        echo "DynamoDB table already exists. Skipping creation."
    fi

    # --- Create the backend.tf file ---
    local backend_tf_path="${env_dir}/${BACKEND_CONFIG_FILE}"
    echo "Creating backend configuration file: ${backend_tf_path}..."
    cat <<EOF >"${backend_tf_path}"
# This file is auto-generated by the tf.sh wrapper script. DO NOT EDIT.
terraform {
  backend "s3" {
    bucket         = "${s3_bucket}"
    key            = "${state_key}"
    region         = "${aws_region}"
    profile        = "${aws_profile}"
    dynamodb_table = "${dynamodb_table}"
    encrypt        = true
  }
}
EOF

    echo "Backend configuration written successfully."
    echo "--------------------------------------------------------"
}

# --- Main Script Logic ---

# Check for at least one argument (the command).
if [ "$#" -lt 1 ]; then
    usage
fi

# Parse command-line arguments into variables.
COMMAND=$1
shift # Shift off the command so we can loop through the flags.
ENV_NAME=""
MODULE=""
TFVARS=$DEFAULT_TFVARS

while [ "$#" -gt 0 ]; do
    case "$1" in
    --env=*) ENV_NAME="${1#*=}" ;;
    --module=*) MODULE="${1#*=}" ;;
    --tfvars=*) TFVARS="${1#*=}" ;;
    *)
        echo "Unknown parameter passed: $1"
        usage
        ;;
    esac
    shift
done

# Validate that the required --env flag was provided.
if [ -z "$ENV_NAME" ]; then
    echo "Error: --env is a required argument."
    usage
fi

# Define the full path to the environment directory.
ENV_DIR="${ENVS_ROOT_DIR}/${ENV_NAME}"

# Check if the environment directory actually exists.
if [ ! -d "$ENV_DIR" ]; then
    echo "Error: Environment directory not found at '${ENV_DIR}'"
    exit 1
fi

# --- Execute Terraform Command ---

echo "========================================================"
echo "Executing Terraform command: '${COMMAND}'"
echo "Environment: ${ENV_NAME}"
echo "Working Directory: ${ENV_DIR}"
[ -n "$MODULE" ] && echo "Module Target: ${MODULE}"
echo "========================================================"

# Change to the environment directory to run Terraform commands.
cd "$ENV_DIR"

case "$COMMAND" in
init)
    # For 'init', run the backend setup function first.
    setup_terraform_backend "$(pwd)"
    echo "Running 'terraform init'..."
    terraform init
    ;;
plan)
    # Build the plan command, adding the -target flag only if a module is specified.
    plan_cmd="terraform plan -var-file=${TFVARS} -out=planfile"
    if [ -n "$MODULE" ]; then
        plan_cmd="$plan_cmd -target=module.${MODULE}"
    fi
    echo "Running: $plan_cmd"
    eval "$plan_cmd"
    ;;
apply)
    # Apply command is straightforward.
    apply_cmd='terraform apply "planfile"'
    echo "Running: $apply_cmd"
    eval "$apply_cmd"
    ;;
destroy)
    # Build the destroy command, adding the -target flag if needed.
    destroy_cmd="terraform destroy -var-file=${TFVARS} -auto-approve"
    if [ -n "$MODULE" ]; then
        destroy_cmd="$destroy_cmd -target=module.${MODULE}"
    fi
    echo "Running: $destroy_cmd"
    eval "$destroy_cmd"
    ;;
fmt)
    echo "Running 'terraform fmt'..."
    terraform fmt -recursive
    ;;
validate)
    echo "Running 'terraform validate'..."
    terraform validate
    ;;
*)
    echo "Error: Unknown command '${COMMAND}'"
    # Go back to the original directory before printing usage.
    cd - >/dev/null
    usage
    ;;
esac

echo "========================================================"
echo "Command '${COMMAND}' completed successfully for environment '${ENV_NAME}'."
echo "========================================================"
