# Display Banner
function 480Banner()
{
    Write-Host "------------------------------------------------"
    Write-Host "480-utils by Jacob Williams"
    Write-Host "for SYS-480-01, Spring 2025 at Champlain College"
    Write-Host "Based on Devin Paden's example version"
    Write-Host "Written with assistance from Claude AI"
    Write-Host "------------------------------------------------"
}
# Connect to vCenter Server
Function 480Connect([string] $server)
{
    $conn = $global:DefaultVIServer
    #are we connected?
    if($conn){
        $msg = "Already connected to: {0}" -f $conn

        Write-Host -ForegroundColor Green $msg
    }else
    {
        $conn = Connect-VIServer -Server $server
        #if this fails, let Connect-VIServer handle the exception
    }
}

# Read and parse configuration file
Function Get-480Config([string] $config_path)
{
    # Display the configuration file we are trying to read
    Write-Host "Reading " $config_path
    $conf=$null
    # Check if the configuration file exists
    if(Test-Path $config_path)
    {
        # Read and parse the JSON configuration file
        $conf = (Get-Content -Raw -Path $config_path | convertFrom-Json)
        $msg = "Using Configuration at {0}" -f $config_path
        Write-Host -ForegroundColor "Green" $msg
    } else 
    {
        # If configuration file doesn't exist, tell user
        Write-Host -ForegroundColor "Yello" "No Configuration"
    }
    # Return theconfiguration object
    return $conf
}

# Select a VMfrom a specified folder
Function Select-VM([string] $folder)
{
    $selected_vm=$null
    try
    {
        $vms = Get-VM -Location $folder
        $index = 1
        foreach ($vm in $vms)
        {
            Write-Host [$index] $vm.Name
            $index+=1
        }
        $pick_index = Read-Host "which index number [x] do you wish to pick?"
        #480-TODO need to deal with an invalid index
        $selected_vm = $vms[$pick_index -1]
        Write-host "You picked " $select_vm.Name
        #note this is a full on vm onject that we can interact with
        return $selected_vm
}
    catch 
    {
        Write-Host "Invalid Folder: $folder" -ForegroundColor "Red"
    }
}
 
# Clone a VM (full/linked)
Function Clone-480VM([string] $folder, [string] $esxiHost, [string] $datastore)
{
    # Get folder object
    $folderObj = Get-Folder -Name $folder -ErrorAction SilentlyContinue # prevents errors if folder not found
    if (!$folderObj) {
        # If folder not found, inform user and exit function
        Write-Host "Folder not found: $folder"
        return
    }
    
    # Get VMs from the specified folder only
    $allVMs = Get-VM -Location $folderObj # Only shows VMs in the specified folder
    if (!$allVMs -or $allVMs.Count -eq 0) {
        # If no VMs, inform user and exit function
        Write-Host "No VMs found in the $folder folder."
        return
    }
    
    # Prompt user to select clone type
    $cloneType = Read-Host "Do you want to create a Full Clone or Linked Clone? (Enter 'F' for Full or 'L' for Linked)"
    
    if ($cloneType -eq "F" -or $cloneType -eq "f") {
        # Full Clone process
        # Display menu of available VMs
        Write-Host "Available VMs in $folder folder:"
        $index = 1
        foreach ($vm in $allVMs) {
            # Number each VM for selection
            Write-Host "[$index] $($vm.Name)"
            $index++
        }
        
        # Get user's VM selection by number
        $vmIndex = Read-Host "Enter the number of the VM you want to clone"
        
        # Validate input is a number and in range of choices
        if (-not [int]::TryParse($vmIndex, [ref]$null) -or [int]$vmIndex -lt 1 -or [int]$vmIndex -gt $allVMs.Count) {
            # If an invalid number is picked
            Write-Host "Invalid selection. Please enter a number between 1 and $($allVMs.Count)."
            return
        }
        
        # Get the selected VM
        $vm = $allVMs[[int]$vmIndex - 1]
        $vmName = $vm.Name
        Write-Host "You selected: $vmName"
        
        # Get available snapshots for the VM
        $snapshots = Get-Snapshot -VM $vm
        if (!$snapshots -or $snapshots.Count -eq 0) {
            # If VM has no snapshots, inform user and exit
            Write-Host "No snapshots found for VM '$($vmName)'. A snapshot is required for cloning."
            return
        }
        
        # Display menu of available snapshots
        Write-Host "Available snapshots for $($vmName):"
        $index = 1
        foreach ($snap in $snapshots) {
            # show name and creation date
            Write-Host "[$index] $($snap.Name) - Created: $($snap.Created)"
            $index++
        }
        
        # Get user's snapshot selection
        $snapIndex = Read-Host "Enter the number of the snapshot to use"
        
        # Validate input is a number and in range
        if (-not [int]::TryParse($snapIndex, [ref]$null) -or [int]$snapIndex -lt 1 -or [int]$snapIndex -gt $snapshots.Count) {
            # Input validation fail, inform user and exit
            Write-Host "Invalid selection. Please enter a number between 1 and $($snapshots.Count)."
            return
        }
        
        # Get the selected snapshot
        $snapshot = $snapshots[[int]$snapIndex - 1]
        $snapshotName = $snapshot.Name
        Write-Host "You selected snapshot: $snapshotName"
        
        # Prompt for Full Clone VM name
        $fullCloneName = Read-Host "Enter the name for the Full Clone VM"
        
        # Get the ESXi host object to create VM in
        $vmhost = Get-VMHost -Name $esxiHost
        # Get the datastore object to store VM
        $ds = Get-Datastore -Name $datastore
        
        # Check if the ESXi host is connected
        if ($vmhost.ConnectionState -ne 'Connected') {
            Write-Host "Host is not connected. Please try again"
            return
        }
        
        # Get available VM folders in inventory
        $vmFolders = Get-Folder -Type VM
        
        # Display menu of available folders
        Write-Host "Available folders for the new VM:"
        $index = 1
        foreach ($vmFolder in $vmFolders) {
            Write-Host "[$index] $($vmFolder.Name)"
            $index++
        }
        
        # Get user's folder selection by number
        $folderIndex = Read-Host "Enter the number of the folder where you want to place the new VM"
        
        # Validate input is a number and in range
        if (-not [int]::TryParse($folderIndex, [ref]$null) -or [int]$folderIndex -lt 1 -or [int]$folderIndex -gt $vmFolders.Count) {
            # Input validation fail, inform user and exist
            Write-Host "Invalid selection. Please enter a number between 1 and $($vmFolders.Count)."
            return
        }
        
        # Get the selected destination folder
        $destFolder = $vmFolders[[int]$folderIndex - 1]
        Write-Host "You selected folder: $($destFolder.Name)"
        
        # Create a linked clone (temporary for the full clone process)
        $linkedName = "$vmName.linked"
        Write-Host "Creating temporary linked clone..."
        $linkedVM = New-VM -LinkedClone -Name $linkedName -VM $vm -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $ds
        
        # Create a full clone from the linked clone
        Write-Host "Creating full clone..."
        $newVM = New-VM -Name $fullCloneName -VM $linkedVM -VMHost $vmhost -Datastore $ds
        
        # Create a snapshot on the new VM
        $newVM | New-Snapshot -Name "Base"
        
        # Remove the temporary linked clone
        Write-Host "Removing temporary linked clone..."
        $linkedVM | Remove-VM -Confirm:$false
        
        # Move the new VM to the destination folder
        Write-Host "Moving VM to selected folder..."
        Move-VM -VM $newVM -Destination $destFolder
        
        # Get available virtual networks (excluding Management Network)
        # It is reserved for ESXi management so we do not want it as an option
        $networks = Get-VirtualPortGroup -VMHost $vmhost | Where-Object { $_.Name -ne "Management Network" }
        
        # Display menu of available networks
        Write-Host "Available networks for the VM:"
        $index = 1
        foreach ($network in $networks) {
            Write-Host "[$index] $($network.Name)"
            $index++
        }
        
        # Get user's network selection by number
        $networkIndex = Read-Host "Enter the number of the network you want to connect the VM to"
        
        # Validate input is a number and in range
        if (-not [int]::TryParse($networkIndex, [ref]$null) -or [int]$networkIndex -lt 1 -or [int]$networkIndex -gt $networks.Count) {
            # If invalid selection, inform user and pick default
            Write-Host "Invalid selection. Using default network."
        } else {
            # Get the selected network
            $selectedNetwork = $networks[[int]$networkIndex - 1]
            Write-Host "You selected network: $($selectedNetwork.Name)"
            
            # Try to configure the network with error handling
            try {
                # Get the network adapter from the VM
                Write-Host "Getting network adapter information..."
                Start-Sleep -Seconds 2  # Add a small delay to let VM settle
                
                # Use Get-VM to refresh the VM object
                # ErrorAction Stop ensures failures are caught
                $vmToUpdate = Get-VM -Name $newVM.Name -ErrorAction Stop
                
                # Get the network adapter(s) from the VM
                $nic = Get-NetworkAdapter -VM $vmToUpdate -ErrorAction Stop
                
                # Set the network adapter to the selected network
                Write-Host "Configuring network adapter..."
                if ($nic) {
                    # Try setting the network with additional error handling
                    try {
                        # Configure the adapter to use the selected network
                        Set-NetworkAdapter -NetworkAdapter $nic -NetworkName $selectedNetwork.Name -Confirm:$false -ErrorAction Stop
                        Write-Host "Network adapter configured to use $($selectedNetwork.Name)"
                    } catch {
                        # If network configuration fails, inform user but continue
                        Write-Host "Error configuring network adapter: $_" -ForegroundColor Yellow
                        Write-Host "You may need to manually configure the network adapter after deployment."
                    }
                } else {
                    # If no adapter foundm inform user
                    Write-Host "No network adapter found on the VM."
                }
            } catch {
                # If there is a failure, inform user but continue
                Write-Host "Error accessing VM network adapter: $_" -ForegroundColor Yellow
                Write-Host "You may need to manually configure the network adapter after deployment."
            }
        }
        
        Write-Host "Full clone '$fullCloneName' created successfully with a 'Base' snapshot in folder '$($destFolder.Name)'."
        # avoid duplicate VM object console output
        return $null
    }
    elseif ($cloneType -eq "L" -or $cloneType -eq "l") {
        # Linked Clone process
        # Display menu of available VMs
        Write-Host "Available VMs in $folder folder:"
        $index = 1
        foreach ($vm in $allVMs) {
            # Number each VM for selection
            Write-Host "[$index] $($vm.Name)"
            $index++
        }
        
        # Get user's selection
        $vmIndex = Read-Host "Enter the number of the VM you want to clone"
        
        # Validate input is a number and in range
        if (-not [int]::TryParse($vmIndex, [ref]$null) -or [int]$vmIndex -lt 1 -or [int]$vmIndex -gt $allVMs.Count) {
            # Input validation failed, inform user and exit
            Write-Host "Invalid selection. Please enter a number between 1 and $($allVMs.Count)."
            return
        }
        
        # Get the selected VM
        $vm = $allVMs[[int]$vmIndex - 1]
        $vmName = $vm.Name
        Write-Host "You selected: $vmName"
        
        # Get available snapshots for the VM
        $snapshots = Get-Snapshot -VM $vm
        if (!$snapshots -or $snapshots.Count -eq 0) {
            # If VM has no snapshots, inform user and exit
            Write-Host "No snapshots found for VM '$($vmName)'. A snapshot is required for cloning."
            return
        }
        
        # Display menu of available snapshots
        Write-Host "Available snapshots for $($vmName):"
        $index = 1
        foreach ($snap in $snapshots) {
            # show details to identify snapshot
            Write-Host "[$index] $($snap.Name) - Created: $($snap.Created)"
            $index++
        }
        
        # Get user's snapshot selection number
        $snapIndex = Read-Host "Enter the number of the snapshot to use"
        
        # Validate input is a number and in range
        if (-not [int]::TryParse($snapIndex, [ref]$null) -or [int]$snapIndex -lt 1 -or [int]$snapIndex -gt $snapshots.Count) {
            # Input validation failure, inform user and exit
            Write-Host "Invalid selection. Please enter a number between 1 and $($snapshots.Count)."
            return
        }
        
        # Get the selected snapshot
        $snapshot = $snapshots[[int]$snapIndex - 1]
        $snapshotName = $snapshot.Name
        Write-Host "You selected snapshot: $snapshotName"
        
        # Prompt for Linked Clone VM name
        $linkedCloneName = Read-Host "Enter the name for the Linked Clone VM"
        
        # Get the ESXi host and Datastore objects
        $vmhost = Get-VMHost -Name $esxiHost
        $ds = Get-Datastore -Name $datastore
        
        # Check if the ESXi host is connected
        if ($vmhost.ConnectionState -ne 'Connected') {
            Write-Host "Host is not connected. Please try again."
            return
        }
        
        # Get available VM folders
        $vmFolders = Get-Folder -Type VM
        
        # Display menu of available folders
        Write-Host "Available folders for the new VM:"
        $index = 1
        foreach ($vmFolder in $vmFolders) {
            Write-Host "[$index] $($vmFolder.Name)"
            $index++
        }
        
        # Get user's folder selection by number
        $folderIndex = Read-Host "Enter the number of the folder where you want to place the new VM"
        
        # Validate input is a number and in range
        if (-not [int]::TryParse($folderIndex, [ref]$null) -or [int]$folderIndex -lt 1 -or [int]$folderIndex -gt $vmFolders.Count) {
            # Input validation failure, inform use and exit function
            Write-Host "Invalid selection. Please enter a number between 1 and $($vmFolders.Count)."
            return
        }
        
        # Get the selected destination folder
        $destFolder = $vmFolders[[int]$folderIndex - 1]
        Write-Host "You selected folder: $($destFolder.Name)"
        
        # Create a linked clone directly from source VM
        Write-Host "Creating linked clone..."
        $linkedVM = New-VM -LinkedClone -Name $linkedCloneName -VM $vm -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $ds
        
        # Create a snapshot on the new VM
        $linkedVM | New-Snapshot -Name "Base"
        
        # Move the new VM to the destination folder
        Write-Host "Moving VM to selected folder..."
        Move-VM -VM $linkedVM -Destination $destFolder
        
        # Get available virtual networks (excluding Management Network)
        $networks = Get-VirtualPortGroup -VMHost $vmhost | Where-Object { $_.Name -ne "Management Network" }
        
        # Display menu of available networks
        Write-Host "Available networks for the VM:"
        $index = 1
        foreach ($network in $networks) {
            Write-Host "[$index] $($network.Name)"
            $index++
        }
        
        # Get user's network selection by number
        $networkIndex = Read-Host "Enter the number of the network you want to connect the VM to"
        
        # Validate input is a number and in range
        if (-not [int]::TryParse($networkIndex, [ref]$null) -or [int]$networkIndex -lt 1 -or [int]$networkIndex -gt $networks.Count) {
            Write-Host "Invalid selection. Using default network."
        } else {
            # Get the selected network
            $selectedNetwork = $networks[[int]$networkIndex - 1]
            Write-Host "You selected network: $($selectedNetwork.Name)"
            
            # Try to configure the network with error handling
            try {
                # Get the network adapter from the VM
                Write-Host "Getting network adapter information..."
                Start-Sleep -Seconds 2  # Add a small delay to let VM settle
                
                # Use Get-VM to refresh the VM object
                # ErrorAction ensures failures are caught
                $vmToUpdate = Get-VM -Name $linkedVM.Name -ErrorAction Stop
                
                # Get network adapter from VM
                $nic = Get-NetworkAdapter -VM $vmToUpdate -ErrorAction Stop
                
                # Set the network adapter to the selected network
                Write-Host "Configuring network adapter..."
                if ($nic) {
                    # Try setting the network with additional error handling
                    try {
                        # Configure the adapter to use selected network
                        Set-NetworkAdapter -NetworkAdapter $nic -NetworkName $selectedNetwork.Name -Confirm:$false -ErrorAction Stop
                        Write-Host "Network adapter configured to use $($selectedNetwork.Name)"
                    } catch {
                        # If network configuration fails, inform user but continue
                        Write-Host "Error configuring network adapter: $_" -ForegroundColor Yellow
                        Write-Host "You may need to manually configure the network adapter after deployment."
                    }
                } else {
                    # If no network adapter found, inform user
                    Write-Host "No network adapter found on the VM."
                }
            } catch {
                # If accessing the VM or adapter fails, inform user but continue
                Write-Host "Error accessing VM network adapter: $_" -ForegroundColor Yellow
                Write-Host "You may need to manually configure the network adapter after deployment."
            }
        }
        
        Write-Host "Linked clone '$linkedCloneName' created successfully with a 'Base' snapshot in folder '$($destFolder.Name)'."
        # Avoids duplicating console output
        return $null
    }
    else {
        # Handle invalid clone type selection
        Write-Host "Invalid selection. Please enter 'F' for Full Clone or 'L' for Linked Clone."
    }
}