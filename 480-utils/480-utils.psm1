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

# Creates Port Group and Virtual Switch
Function New-Network([string] $switchName, [string] $portGroupName, [string] $esxiHost)
{
    # Validate parameters
    if ([string]::IsNullOrEmpty($switchName) -or [string]::IsNullOrEmpty($portGroupName)) {
        Write-Host "Error: Switch name and port group name are required." -ForegroundColor Red
        return $null
    }
    
    # Get the VMHost object using provided hostname/IP of ESXI
    $vmhost = Get-VMHost -Name $esxiHost -ErrorAction SilentlyContinue
    if (!$vmhost) {
        Write-Host "Error: VMHost $esxiHost not found." -ForegroundColor Red
        return $null
    }
    
    try {
        # Check if virtual switch already exists
        $vSwitch = Get-VirtualSwitch -Name $switchName -VMHost $vmhost -ErrorAction SilentlyContinue
        
        # Create virtual switch if it doesn't exist
        if (!$vSwitch) {
            Write-Host "Creating new Virtual Switch: $switchName..." -ForegroundColor Cyan
            # Creates nte vSWitch on specified VM host from 480.json
            $vSwitch = New-VirtualSwitch -Name $switchName -VMHost $vmhost -ErrorAction Stop
            Write-Host "Virtual Switch $switchName created successfully." -ForegroundColor Green
        } else {
            Write-Host "Virtual Switch $switchName already exists. Using existing switch." -ForegroundColor Yellow
        }
        
        # Check if port group already exists
        $portGroup = Get-VirtualPortGroup -Name $portGroupName -VirtualSwitch $vSwitch -ErrorAction SilentlyContinue
        
        # Create port group if it doesn't exist
        if (!$portGroup) {
            Write-Host "Creating new Port Group: $portGroupName..." -ForegroundColor Cyan
            # Creates port group on specified switch from before
            $portGroup = New-VirtualPortGroup -Name $portGroupName -VirtualSwitch $vSwitch -ErrorAction Stop
            Write-Host "Port Group $portGroupName created successfully." -ForegroundColor Green
        } else {
            Write-Host "Port Group $portGroupName already exists. Using existing port group." -ForegroundColor Yellow
        }
        
        return $portGroup
    }
    catch {
        # Catch any errors during network creation and display to user
        Write-Host "Error creating network components: $_" -ForegroundColor Red
        return $null
    }
}

# Provides user interface for creating vswitch/portgroup
Function Handle-NetworkCreation([string] $esxiHost)
{
    Write-Host "Create a New Network"
    # Prompts user for switch name
    $switchName = Read-Host "Enter a name for the Virtual Switch"
    # Prompts user for port group name
    $portGroupName = Read-Host "Enter a name for the Port Group"
    
    # Create the network, calling the New-Network function
    $result = New-Network -switchName $switchName -portGroupName $portGroupName -esxiHost $esxiHost
    
    # Display resulting Switch and Port Group, (but only if successful)
    if ($result) {
        Write-Host "Network created successfully!" -ForegroundColor Green
        Write-Host "Switch Name: $switchName" -ForegroundColor Cyan
        Write-Host "Port Group Name: $portGroupName" -ForegroundColor Cyan
    }
}

# Retrieves IP and MAC information from a VM's first network addtress
Function Get-IP([string] $vmName)
{
    # Validate that VM name was provided

    if ([string]::IsNullOrEmpty($vmName)) {
        Write-Host "Error: VM name is required." -ForegroundColor Red
        return $null
    }
    
    try {
        # Get the VM using provided name
        # ErrorAction catches errors
        $vm = Get-VM -Name $vmName -ErrorAction Stop
        
        # Get network adapters for the VM, stopping for error if it has none
        $networkAdapters = Get-NetworkAdapter -VM $vm -ErrorAction Stop
        
        if (!$networkAdapters -or $networkAdapters.Count -eq 0) {
            Write-Host "Error: No network adapters found for VM $vmName." -ForegroundColor Red
            return $null
        }
        
        # Get the first network adapter (index 0)
        # Just the one for now
        $firstAdapter = $networkAdapters[0]
        
        # Get the MAC address
        # Available regarless of PowerState
        $macAddress = $firstAdapter.MacAddress
        
        # Initilize IP address with default message, will be updated if actual IP is detected
        $ipAddress = "Not available"
        
        # Try to get the guest IP - this only works if VMware Tools is installed and the VM is powered on
        if ($vm.PowerState -eq "PoweredOn" -and $vm.Guest.State -eq "Running") {
            # Check if there are any IP addresses available
            if ($vm.Guest.IPAddress -and $vm.Guest.IPAddress.Length -gt 0) {
                # Get the first IP address that's not a link-local address
                # Filters out IPV4/IPV6 link-locals
                $ipAddress = $vm.Guest.IPAddress | Where-Object { -not $_.StartsWith("fe80:") -and -not $_.StartsWith("169.254.") } | Select-Object -First 1
                
                # If no non-link-local IP is found, just get the first one
                if ([string]::IsNullOrEmpty($ipAddress)) {
                    $ipAddress = $vm.Guest.IPAddress[0]
                }
            } else {
                $ipAddress = "No IP assigned"
            }
        } else {
            $ipAddress = "VM not running or VMware Tools not available"
        }
        
        # Create and return a custom object with the information
        $result = [PSCustomObject]@{
            VMName = $vmName
            IPAddress = $ipAddress
            MACAddress = $macAddress
            NetworkAdapter = $firstAdapter.Name
            PortGroup = $firstAdapter.NetworkName
        }
        
        return $result
    }
    catch {
        # Catch and display any errors occuring during information retrieval
        Write-Host "Error retrieving network information: $_" -ForegroundColor Red
        return $null
    }
}

# Provide interface for retrieving IP and MAC from Get-IP
Function Handle-IPLookup([string] $folder)
{
    Write-Host "Get VM IP and MAC Address"
    
    # Present 2 options for selecting a VM
    Write-Host "1. Select VM from list"
    Write-Host "2. Enter VM name directly"
    $selectionMethod = Read-Host "Choose an option"
    
    if ($selectionMethod -eq "1") {
        # Get all VMs in environment instead of using Select-VM function
        $allVMs = Get-VM
        
        # Check if any VMs were found
        if ($allVMs.Count -eq 0) {
            Write-Host "No VMs found in the environment." -ForegroundColor Yellow
            return
        }
        
        # Display list of VMs with PowerState indicators (important because only PoweredOn VMs can show their IP)
        $index = 1
        foreach ($vm in $allVMs) {
            # Add power state information using green for on, red for off
            if ($vm.PowerState -eq "PoweredOn") {
                Write-Host "[$index] $($vm.Name)" -NoNewline
                Write-Host " [ON]" -ForegroundColor Green
            } else {
                Write-Host "[$index] $($vm.Name)" -NoNewline
                Write-Host " [OFF]" -ForegroundColor Red
            }
            $index++
        }
        
        # Gets user selection index number
        $pick_index = Read-Host "which index number [x] do you wish to pick?"
        
        # Validate the input is a number and in the valid range
        if (-not [int]::TryParse($pick_index, [ref]$null) -or [int]$pick_index -lt 1 -or [int]$pick_index -gt $allVMs.Count) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($allVMs.Count)." -ForegroundColor Red
            return
        }
        
        # Get selected VM and retrieve its network information
        $selectedVM = $allVMs[[int]$pick_index - 1]
        if ($selectedVM) {
            $result = Get-IP -vmName $selectedVM.Name
        }
    }
    else {
        # Option 2: Enter VM name directly
        $vmName = Read-Host "Enter the name of the VM"
        
        # Check if VM exists before querying information
        try {
            $vm = Get-VM -Name $vmName -ErrorAction Stop
            $result = Get-IP -vmName $vmName
        }
        catch {
            Write-Host "VM with name '$vmName' not found. Please check the name and try again." -ForegroundColor Red
            return
        }
    }
    
    # Display network information results
    if ($result) {
        Write-Host "`nVM Network Information:" -ForegroundColor Green
        Write-Host "VM Name: $($result.VMName)" -ForegroundColor Cyan
        Write-Host "IP Address: $($result.IPAddress)" -ForegroundColor Cyan
        Write-Host "MAC Address: $($result.MACAddress)" -ForegroundColor Cyan
        Write-Host "Network Adapter: $($result.NetworkAdapter)" -ForegroundColor Cyan
        Write-Host "Port Group: $($result.PortGroup)" -ForegroundColor Cyan
    }
}

# Provides user interface for managing VM powerstate
Function Handle-VMPower()
{
    # Gets all available VMs and displays power state
    $allVMs = Get-VM
    Write-Host "Available VMs:"
    $index = 1
    foreach ($vm in $allVMs) {
        # Determine VM power state and sets red for off and green for on
        $state = if ($vm.PowerState -eq "PoweredOn") { "[ON]" } else { "[OFF]" }
        $color = if ($vm.PowerState -eq "PoweredOn") { "Green" } else { "Red" }

        # Displays VM with index and powerstate color/indicator
        Write-Host "[$index] $($vm.Name)" -NoNewline
        Write-Host " $state" -ForegroundColor $color
        $index++
    }
    
    # Get user's VM selection by number
    $vmIndex = Read-Host "Select VM by number"
    if (-not [int]::TryParse($vmIndex, [ref]$null) -or [int]$vmIndex -lt 1 -or [int]$vmIndex -gt $allVMs.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        return
    }
    
    # Gets selected VM object and extracts its name
    $selectedVM = $allVMs[[int]$vmIndex - 1]
    $vmName = $selectedVM.Name
    
    # Displays current powerstate of selected VM
    Write-Host "Current state: $($selectedVM.PowerState)"
    # Presents user with action options
    Write-Host "1. Start VM"
    Write-Host "2. Stop VM (graceful)"
    Write-Host "3. Stop VM (force)"
    $action = Read-Host "Select action"
    
    # Perform selected action
    if ($action -eq "1") {
        # Start VM
        Start-480VM -vmName $vmName
    }
    elseif ($action -eq "2") {
        # Stop VM (gracefully)
        Stop-480VM -vmName $vmName -useForce $false
    }
    elseif ($action -eq "3") {
        # Stop VM (forcefully)
        Stop-480VM -vmName $vmName -useForce $true
    }
    else {
        # Invalid selection
        Write-Host "Invalid action." -ForegroundColor Red
    }
}

# Powers on VM by name
Function Start-480VM([string] $vmName)
{
    try {
        # Get the VM object by name via Get-VM cmdlet
        # Erroraction to catch errors
        $vm = Get-VM -Name $vmName -ErrorAction Stop
        
        # Check if already powered on
        if ($vm.PowerState -eq "PoweredOn") {
            # Tells user if VM is already on
            Write-Host "VM '$vmName' is already powered on." -ForegroundColor Yellow
            return
        }
        
        # Start the VM and suppress output with out-null to avoid crowding CLI
        Write-Host "Starting VM '$vmName'..." -ForegroundColor Cyan
        Start-VM -VM $vm -ErrorAction Stop | Out-Null
        # Confirms success to user
        Write-Host "VM '$vmName' started successfully." -ForegroundColor Green
    }
    catch {
        # Catches any errors occuring during process
        Write-Host "Error starting VM '$vmName': $_" -ForegroundColor Red
    }
}

# Powers off a virtual machine by name
Function Stop-480VM
{
    param(
        # Name of VM to stop
        [Parameter(Mandatory=$true)]
        [string]$vmName,
        
        # Whether to force poweroff or graceful shutdown from handler function
        # Default to false (graceful)
        [Parameter(Mandatory=$false)]
        [bool]$useForce = $false
    )
    
    try {
        # Get the VM by name using Get-VM
        # ErrorAction ensures errors are caught
        $vm = Get-VM -Name $vmName -ErrorAction Stop
        
        # Check if already powered off
        if ($vm.PowerState -eq "PoweredOff") {
            # Inform user if VM is already stopped
            Write-Host "VM '$vmName' is already powered off." -ForegroundColor Yellow
            return
        }
        
        # Stop the VM, depends on graceful vs forceful
        if ($useForce) {
            # Force power off (uses vSphere API directly)
            Write-Host "Force stopping VM '$vmName'..." -ForegroundColor Cyan
            $vm.ExtensionData.PowerOffVM() | Out-Null
            # Confirm success to user
            Write-Host "VM '$vmName' force stopped successfully." -ForegroundColor Green
        } else {
            # Graceful shutdown
            # sends shutdown signal to guest OS
            # only works with VM tools installed
            Write-Host "Gracefully stopping VM '$vmName'..." -ForegroundColor Cyan
            # -Confirm:$false prvents prompting for confirmation
            Shutdown-VMGuest -VM $vm -Confirm:$false | Out-Null
            # Inform user that shutdown process has been initiated
            Write-Host "Shutdown signal sent to VM '$vmName'." -ForegroundColor Green
        }
    }
    catch {
        # If any error occurs during process, display to user
        Write-Host "Error stopping VM '$vmName': $_" -ForegroundColor Red
    }
}

# Changes netork connection of any specified network adapter on VM
Function Set-Network([string] $vmName, [string] $networkName, [int] $adapterIndex = 0)
{
    try {
        # Get the VM object by name
        $vm = Get-VM -Name $vmName -ErrorAction Stop
        
        # Get all network adapters for the VM
        $adapters = Get-NetworkAdapter -VM $vm -ErrorAction Stop
        
        # Check if there are any adapters
        if ($adapters.Count -eq 0) {
            Write-Host "VM '$vmName' has no network adapters." -ForegroundColor Red
            return
        }
        
        # Check if the specified adapter index is valid
        if ($adapterIndex -lt 0 -or $adapterIndex -ge $adapters.Count) {
            Write-Host "Invalid adapter index. Valid range: 0 to $($adapters.Count - 1)" -ForegroundColor Red
            return
        }
        
        # Get the specified adapter for this index
        $adapter = $adapters[$adapterIndex]
        
        # Display the current network before making changes
        Write-Host "Adapter: $($adapter.Name)" -ForegroundColor Cyan
        Write-Host "Current network: $($adapter.NetworkName)" -ForegroundColor Cyan
        
        # Inform the user about the upcoming change
        Write-Host "Changing to network: $networkName" -ForegroundColor Cyan
        
        # Change the network with Set-NetworkAdapter
        Set-NetworkAdapter -NetworkAdapter $adapter -NetworkName $networkName -Confirm:$false | Out-Null
        
        # Confirm success to user
        Write-Host "Network changed successfully." -ForegroundColor Green
    }
    catch {
        # Display errors that may have occurrsed.
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

Function Handle-SetNetwork()
{
    # Display available VMs for user to select from
    $allVMs = Get-VM
    Write-Host "Available VMs:" -ForegroundColor Cyan
    $index = 1
    foreach ($vm in $allVMs) {
        # Number each VM for easy selection
        Write-Host "[$index] $($vm.Name)"
        $index++
    }
    
    # Get VM selection and convert to array index
    $vmIndex = Read-Host "Select VM by number"
    $selectedVM = $allVMs[[int]$vmIndex - 1]
    
    # Get all network adapters for the selected VM
    $adapters = Get-NetworkAdapter -VM $selectedVM
    
    # If VM has multiple adapters, let user select which to change
    if ($adapters.Count -gt 1) {
        # Displays all adapters wit htheir current networks
        Write-Host "Network adapters for $($selectedVM.Name):" -ForegroundColor Yellow
        for ($i = 0; $i -lt $adapters.Count; $i++) {
            Write-Host "[$($i+1)] $($adapters[$i].Name) - Current network: $($adapters[$i].NetworkName)"
        }
        
        # Get adapter selection from user
        $adapterIndex = Read-Host "Select adapter by number"
        $selectedAdapterIndex = [int]$adapterIndex - 1
    } else {
        # Only one adapter, so just use index 0
        $selectedAdapterIndex = 0
        Write-Host "VM: $($selectedVM.Name)" -ForegroundColor Yellow
        Write-Host "Network adapter: $($adapters[0].Name)" -ForegroundColor Yellow
        Write-Host "Current network: $($adapters[0].NetworkName)" -ForegroundColor Yellow
    }
    
    Write-Host ""  # Add blank line for readability
    
    # Display available networks - excluding Management Network, which is not for VMs
    $networks = Get-VirtualPortGroup | Where-Object { $_.Name -ne "Management Network" }
    Write-Host "Available networks:" -ForegroundColor Cyan
    $index = 1
    foreach ($network in $networks) {
        # Number each network for easy selection
        Write-Host "[$index] $($network.Name)"
        $index++
    }
    
    # Get network selection from user
    $networkIndex = Read-Host "Select network by number"
    $selectedNetwork = $networks[[int]$networkIndex - 1]
    
    # CCall the Set-Network function with parameters
    Set-Network -vmName $selectedVM.Name -networkName $selectedNetwork.Name -adapterIndex $selectedAdapterIndex
}