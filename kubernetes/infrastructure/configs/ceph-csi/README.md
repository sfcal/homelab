# Ceph CSI Configuration

This directory contains the configuration for Ceph CSI (Container Storage Interface) driver to use your Proxmox Ceph cluster for Kubernetes persistent storage.

## Prerequisites

Before applying these configurations, you need to:

1. **Get Ceph Cluster Information** from one of your Proxmox nodes:
   ```bash
   # SSH to a Proxmox node and run:
   ceph fsid                    # This is your CEPH_CLUSTER_ID
   ceph mon dump | grep mon     # Get monitor IPs
   ```

2. **Create a Ceph Pool for Kubernetes** (if not already exists):
   ```bash
   ceph osd pool create kubernetes 128
   ceph osd pool application enable kubernetes rbd
   ```

3. **Create Ceph User for Kubernetes**:
   ```bash
   # Create admin user for provisioning
   ceph auth get-or-create client.kubernetes-admin mon 'allow r' osd 'allow * pool=kubernetes' -o /etc/ceph/ceph.client.kubernetes-admin.keyring
   
   # Create regular user for mounting
   ceph auth get-or-create client.kubernetes mon 'allow r' osd 'allow rwx pool=kubernetes' -o /etc/ceph/ceph.client.kubernetes.keyring
   
   # Get the keys
   ceph auth get client.kubernetes-admin | grep key | awk '{print $3}'
   ceph auth get client.kubernetes | grep key | awk '{print $3}'
   ```

## Setup Instructions

1. **Add Secrets to 1Password**:
   - Create a new item in 1Password vault `k3s-dev` with title `ceph-csi`
   - Add the following fields:
     - `admin-user`: `kubernetes-admin`
     - `admin-key`: (base64 encoded key from step 3)
     - `user-id`: `kubernetes`
     - `user-key`: (base64 encoded key from step 3)

2. **Update Cluster Settings**:
   Edit the cluster settings files and fill in the TODO values:
   - `/clusters/dev/cluster-settings.yaml`
   - `/clusters/prod/cluster-settings.yaml`
   
   Required values:
   - `CEPH_CLUSTER_ID`: Your Ceph cluster FSID
   - `CEPH_MON1_IP`: First monitor IP
   - `CEPH_MON2_IP`: Second monitor IP
   - `CEPH_MON3_IP`: Third monitor IP

3. **Apply the Configuration**:
   ```bash
   # Commit and push your changes
   git add -A
   git commit -m "Add Ceph CSI configuration"
   git push
   
   # Flux will automatically reconcile and apply the changes
   ```

4. **Verify Installation**:
   ```bash
   # Check if Ceph CSI pods are running
   kubectl -n ceph-csi-system get pods
   
   # Check if StorageClass was created
   kubectl get storageclass ceph-rbd
   
   # Check if secrets were created from 1Password
   kubectl -n ceph-csi-system get secrets
   ```

## Testing

To test the Ceph storage:

```bash
# Apply the test PVC and pod
kubectl apply -f test/test-pvc.yaml

# Check PVC status
kubectl get pvc ceph-test-pvc

# Check if volume is bound
kubectl describe pvc ceph-test-pvc

# Check pod status
kubectl get pod ceph-test-pod

# Test writing to the volume
kubectl exec -it ceph-test-pod -- sh -c 'echo "Hello from Ceph!" > /data/test.txt'
kubectl exec -it ceph-test-pod -- cat /data/test.txt

# Cleanup
kubectl delete -f test/test-pvc.yaml
```

## Troubleshooting

1. **PVC stuck in Pending**:
   - Check Ceph CSI controller logs: `kubectl -n ceph-csi-system logs -l app=ceph-csi-rbd-provisioner`
   - Verify secrets exist: `kubectl -n ceph-csi-system get secrets`
   - Check Ceph connectivity from nodes

2. **Authentication Issues**:
   - Verify 1Password secrets are correctly synced
   - Check external-secrets operator logs
   - Ensure Ceph user permissions are correct

3. **Network Issues**:
   - Ensure Kubernetes nodes can reach Ceph monitors on port 6789
   - Check firewall rules on Proxmox nodes