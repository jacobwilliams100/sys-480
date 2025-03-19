# 480driver.ps1
# Author: Jacob Williams
# For SYS-480-01, Spring 2025 at Champlain College
# Based on Devin Paden's example version
# Written with assistance from Claude AI
# Purpose: Main driver script for VM management in vSphere environment


# Import the custom utilities module with all our functions
Import-Module ./480-utils.psm1 -Force

# Display the welcome banner
480Banner

# Load configuration from JSON file
$conf = Get-480Config "./480.json"

# Keep trying to connect until successful
$connected = $false
while (-not $connected) {
    try {
        # Attempt to connect to vCenter directly
        # -ErrorAction Stop ensures the catch block will be executed on failure
        $connection = Connect-VIServer -Server $conf.vcenter_server -ErrorAction Stop
        $connected = $true  # Connection successful
    }
    catch {
        # If connection fails (wrong username/password), prompt to try again
        Write-Host "Failed to connect. Please try again with new credentials." -ForegroundColor Red
        # Brief pause to let user see the error message
        Start-Sleep -Seconds 2
    }
}

$continue = $true
while ($continue) {
    # Display menu options
    Write-Host "0. Exit"
    Write-Host "1. Select a VM"
    Write-Host "2. Clone a VM"
    Write-Host "3. Create a New Network"
    Write-Host "4. Get VM IP/MAC Address"
    Write-Host "5. VM Power Management"
    Write-Host "6. Change VM Network"
    $choice = Read-Host "Choose an option"

    # Process user's choice
    if ($choice -eq "0") {
        # Exit option
        $continue = $false
        Write-Host "Exiting..."
    }
    elseif ($choice -eq "1") {
        # VM selection option
        Write-Host "Selecting your VM"
        # Use the folder from configuration file
        Select-VM -folder $conf.vm_folder
    }
    elseif ($choice -eq "2") {
        # VM cloning option
        Write-Host "Clone VM"
        # Pass all required parameters from configuration
        Clone-480VM -folder $conf.vm_folder -esxiHost $conf.esxi_host -datastore $conf.default_datastore
    }
    elseif ($choice -eq "3") {
        # #Network creation option
        Handle-NetworkCreation -esxiHost $conf.esxi_host
    }
    elseif ($choice -eq "4") {
        # Get VM IP/MAC option
        Handle-IPLookup -folder $conf.vm_folder
    }
    elseif ($choice -eq "5") {
        # VM power management option
        Handle-VMPower
    }
    elseif ($choice -eq "6") {
        # Change VM network option
        Handle-SetNetwork
    }
    else {
        # Invalid option handling - loop will continue and prompt again
        Write-Host "Invalid option. Please try again." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
    
    # Add a blank line between iterations for better readability
    if ($continue) {
        Write-Host ""
    }
}
if ($global:DefaultVIServer) {
    Disconnect-VIServer -Confirm:$false
}