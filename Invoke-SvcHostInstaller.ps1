
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
    [string]$Description
    )
    
    #Checks are below hereeeee
    $PossibleGroups = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SVCHOST" | Select -ExpandProperty Property

    #First check if the request service group exsists
    if(!$PossibleGroups.Contains($ServicePrimaryGroup)){
        Write-Error -Exception "Bad Service Group" -Message "Requested service group not found."
    }

    $SvcPath = "C:\Windows\System32\svchost.exe -k " + $ServicePrimaryGroup

    #Create the service using New-Service
    #many change this later
    New-Service -Name $ServiceName -DisplayName $DisplayName -BinaryPathName $SvcPath -StartupType Automatic

    $BasePath = "HKLM:\SYSTEM\CurrentControlSet\Services\" + $ServiceName
    $RegPath = $BasePath + "\Parameters"

    #Create the "Parameters" Key bc by default it is not created with New-Service
    New-Item $RegPath

    #Create the value ServiceDLL
    #MUST BE FULL PATH
    New-ItemProperty -Path $RegPath -PropertyType ExpandString -Name ServiceDll -Value $ServiceDll

    #Set the service type to WIN32_SHARED_PROCESS (0x20)
    Set-ItemProperty -Path $BasePath -Name Type -Value 0x20

    $GroupRegLocation = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SVCHOST"

    $GroupMems = Get-ItemProperty $GroupRegLocation -Name $ServicePrimaryGroup | select -ExpandProperty $ServicePrimaryGroup
    $GroupMems += "`n"
    $GroupMems += $ServiceName
    Set-ItemProperty $GroupRegLocation -Name $ServicePrimaryGroup -Value $GroupMems
}