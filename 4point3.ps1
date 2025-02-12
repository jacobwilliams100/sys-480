# Drafted with assistance from ChatGPT
# Hardcoded variable for vcenter.jake.local because it is our only server.
$vserver = "vcenter.jake.local"

# Connect to vCenter
Connect-VIServer -Server $vserver

# List all VMs and prompt user to select one
$allVMs = Get-VM
$allVMNames = $allVMs | Select-Object -ExpandProperty Name

Write-Host "Available VMs:"
$allVMNames | ForEach-Object { Write-Host "$($_)" }

$vmName = Read-Host "Enter the name of the Source VM for linked clone"

# Ensure the VM exists in the list
if ($allVMNames -contains $vmName) {
    # Prompt for Snapshot name and Linked Clone VM name after selecting the source VM
    $snapshotName = Read-Host "Enter the Snapshot name"
    $linkedclone = Read-Host "Enter the name for the Linked Clone VM"

    # Get the source VM and snapshot
    $vm = Get-VM -Name $vmName
    $snapshot = Get-Snapshot -VM $vm -Name $snapshotName

    # Hardcoded ESXi host and datastore (just easier for now)
    $vmhost = Get-VMHost -Name "esxi.jake.local"
    $ds = Get-Datastore -Name "datastore1-super10"

    # Check if the ESXi host is connected
    if ($vmhost.ConnectionState -ne 'Connected') {
        Write-Host "Host is not connected. Please try again."
    }

    # Create a linked clone
    $linkedVM = New-VM -LinkedClone -Name $linkedclone -VM $vm -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $ds

    # Create a snapshot on the new VM
    $linkedVM | New-Snapshot -Name "Base"

    # Disconnect from vCenter
    Disconnect-VIServer -Confirm:$false
} else {
    Write-Host "The VM name entered is not valid. Exiting script."
    Disconnect-VIServer -Confirm:$false
}