"""Maps UI operations to `task` CLI commands."""


def terraform_deploy_all(env: str) -> list[str]:
    return ["task", "terraform:deploy", f"ENV={env}"]


def terraform_deploy_vm(env: str, vm_key: str) -> list[str]:
    return ["task", "terraform:deploy-vm", f"ENV={env}", f"VM={vm_key}"]


def terraform_destroy_all(env: str) -> list[str]:
    return ["task", "terraform:destroy", f"ENV={env}"]


def terraform_destroy_vm(env: str, vm_key: str) -> list[str]:
    return ["task", "terraform:destroy-vm", f"ENV={env}", f"VM={vm_key}"]


def ansible_task(task_name: str, env: str) -> list[str]:
    return ["task", task_name, f"ENV={env}"]
