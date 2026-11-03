cat << 'EOF' > 01-auto_ssh_setup.sh
import json
import os
import subprocess
import sys

# Paths & Configurations
SSH_KEY_PATH = os.path.expanduser("~/.ssh/id_rsa")
TERRAFORM_DIR = os.path.join("infra", "terraform")
VM_USER = "adminuser"


def check_and_prep_ssh_key():
    if not os.path.isfile(SSH_KEY_PATH):
        print(f"[ERROR] SSH private key not found at: {SSH_KEY_PATH}")
        sys.exit(1)

    # File permissions 400 (Read-only for owner)
    os.chmod(SSH_KEY_PATH, 0o400)


def get_terraform_ips(output_key="public_ip_address"):
    vm_dict = {}
    try:
        result = subprocess.run(
            ["terraform", "output", "-json"],
            cwd=TERRAFORM_DIR,
            capture_output=True,
            text=True,
            check=True,
        )

        outputs = json.loads(result.stdout)

        if output_key in outputs:
            ip_data = outputs[output_key]["value"]

            if isinstance(ip_data, list):
                for index, pub_ip in enumerate(ip_data):
                    vm_dict[f"vm_{index+1}"] = pub_ip
            else:
                vm_dict["master_pub_ip"] = ip_data
            return vm_dict
        else:
            print(f"[ERROR] Key '{output_key}' not found in terraform output.")
            sys.exit(1)

    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Failed to execute terraform command: {e.stderr}")
        sys.exit(1)


def auto_login_vm():
    check_and_prep_ssh_key()
    vm_dict = get_terraform_ips()

    try:
        # Get IP address from dictionary
        master_ip = vm_dict.get("master_pub_ip") or vm_dict.get("vm_1")

        if not master_ip:
            print("[ERROR] No valid IP address retrieved from Terraform outputs.")
            sys.exit(1)

        print(f"[INFO] Connecting to {VM_USER}@{master_ip}...")
        
        # Execute SSH session
        subprocess.run(
            ["ssh", "-i", SSH_KEY_PATH, f"{VM_USER}@{master_ip}"],
            check=True,
        )

    except subprocess.CalledProcessError as e:
        print(f"[ERROR] SSH session ended with error: {e}")
    except Exception as e:
        print(f"[ERROR] An unexpected error occurred: {e}")


if __name__ == "__main__":
    auto_login_vm()
EOF    

# login master node and check your worker node has can be loging privte_ip adress