cat << 'EOF' > common-setup.sh
import os
import subprocess
import sys

terraform_file_path = "infra/terraform/main.tf"


def check_terraform_file_exists():
    # check the main file
    if not os.path.isfile(terraform_file_path):
        print(f"Terraform file not found at: {terraform_file_path}")
        sys.exit(1)


def run_terraform():
    # 1.check the run check_terraform_file_exists
    check_terraform_file_exists()

    try:
        # 2. Terraform Init
        print("Running terraform init...")
        subprocess.run(["terraform", "init"], check=True)

        # 3. Terraform Plan
        print("Running terraform plan...")
        subprocess.run(["terraform", "plan"], check=True)

        # 4. Terraform Apply
        print("Running terraform apply...")
        # '-auto-approve' automatically passes 'yes' to terminal
        subprocess.run(["terraform", "apply", "-auto-approve"], check=True)

        print("\nVirtual Machine and Network Interfaces provisioned successfully!")

    except subprocess.CalledProcessError as e:
        print(f"\n[ERROR] Terraform command execution failed with exit code: {e.returncode}")
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR] An unexpected error occurred: {e}")
        sys.exit(1)


if __name__ == "__main__":
    run_terraform()
EOF