function Install-SvcHostService{
    Param(
    [Parameter( Position = 0, Mandatory = $true )]
    [String]$ServiceName,

    [Parameter( Position = 1, Mandatory = $true )]
    [String]$DisplayName,

    [Parameter( Position = 2, Mandatory = $true )]
    [String]$ServiceDll,

    [Parameter( Position = 3, Mandatory = $true )]
    [String]$ServicePrimaryGroup,

    [Parameter( Position = 4, Mandatory = $false )]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$Description = "Example of a Service Loaded via SVCHOST"
    )

    if(!$PSBoundParameters.ContainsKey('Description')){
        Write-Warning "Description is set to the default. This is NOT opsec :eyes:"
    }

    #Check for older versions of powershell since the "Requires" thing is >=4
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    
    if(!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
         Write-Error -Exception "Not Running as Administrator" -Message "Please run this script as an administrator."
        Exit
    }

    #Checks are below hereeeee
    $PossibleGroups = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SVCHOST" | Select-Object -ExpandProperty Property

    #First check if the request service group exsists
    if(!$PossibleGroups -contains $ServicePrimaryGroup){
        Write-Error -Exception "Bad Service Group" -Message "Requested service group not found."
        Exit
    }

    #Check if the service already exsists
    $ServiceCheck = Get-Service -ServiceName $ServiceName -ErrorAction "SilentlyContinue"

    #get the full path and make sure it exsits
    $FullPath = Get-Item $ServiceDll | Select-Object FullName
    $Temp = Test-Path $FullPath.FullName
    if(!$Temp){
        Write-Error -Exception "File Note Found" -Message "The Requested Dll was not found."
        Exit
    }

    $DllName = Get-Item $ServiceDll | Select-Object Name
    $FullSystemPath = "C:\Windows\System32\" + $DllName.Name

    #Move it to system32 to be nice :)
    Copy-Item -Path $FullPath.FullName -Destination  $FullSystemPath -Force

    $SvcPath = "C:\Windows\System32\svchost.exe -k " + $ServicePrimaryGroup

    if($ServiceCheck){
        Write-Error -Exception "Bad Service Name" -Message "Requested service name already in use."
        Exit
    }

    #Create the service using New-Service
    #many change this later
    New-Service -Name $ServiceName -DisplayName $DisplayName -BinaryPathName $SvcPath -StartupType Automatic -Description $Description

    $BasePath = "HKLM:\SYSTEM\CurrentControlSet\Services\" + $ServiceName
    $RegPath = $BasePath + "\Parameters"

    #Create the "Parameters" Key bc by default it is not created with New-Service
    New-Item $RegPath

    #Create the value ServiceDLL
    #MUST BE FULL PATH
    New-ItemProperty -Path $RegPath -PropertyType ExpandString -Name ServiceDll -Value $FullSystemPath

    #Set the service type to WIN32_SHARED_PROCESS (0x20)
    Set-ItemProperty -Path $BasePath -Name Type -Value 0x20

    #https://stackoverflow.com/questions/27238523/editing-a-multistring-array-for-a-registry-value-in-powershell
    $GroupRegLocation = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\SVCHOST"
    
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', "")
    $key = $reg.OpenSubKey($GroupRegLocation, $true)
    $arr = $key.GetValue($ServicePrimaryGroup)

    $arr += $ServiceName

    $key.SetValue($ServicePrimaryGroup, [string[]]$arr, 'MultiString')

    Start-Service $ServiceName | Out-Null

    Get-Service $ServiceName
}
