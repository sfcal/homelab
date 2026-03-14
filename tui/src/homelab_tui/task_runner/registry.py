"""Maps UI operations to `task` CLI commands."""


def task_command(task_name: str, env: str, **extra_vars: str) -> list[str]:
    """Build a generic task command with ENV and optional extra vars."""
    cmd = ["task", task_name, f"ENV={env}"]
    for key, value in extra_vars.items():
        cmd.append(f"{key}={value}")
    return cmd


def terraform_deploy_all(env: str) -> list[str]:
    return task_command("terraform:deploy", env)


def terraform_deploy_vm(env: str, vm_key: str) -> list[str]:
    return task_command("terraform:deploy-vm", env, VM=vm_key)


def terraform_destroy_all(env: str) -> list[str]:
    return task_command("terraform:destroy", env)


def terraform_destroy_vm(env: str, vm_key: str) -> list[str]:
    return task_command("terraform:destroy-vm", env, VM=vm_key)


def terraform_clean(env: str) -> list[str]:
    return task_command("terraform:clean", env)


def packer_build(env: str, template: str) -> list[str]:
    return task_command("packer:build", env, TEMPLATE=template)
