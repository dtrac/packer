$url = "<artifact repo url>"
$repo = "<repo name>"

# Ensure the build fails if there is a problem.
$ErrorActionPreference = 'Stop'

# Set variables
$curlExe = 'D:\curl\bin\curl.exe'
$packerExe = 'D:\packer\packer.exe'
$jqExe = 'D:\jq\jq-win64.exe'
$ovfToolExe = 'D:\VMware OVF Tool\ovftool.exe'
Write-Output "Username: $env:Username"

# Run the packer build
Start-Process $packerExe -ArgumentList "build -var-file=""./var/$($env:var_file).json"" ./templates/$env:type.json" -Wait -PassThru -NoNewWindow

# Exit script at this point if packer manifest file doesn't exist
if (!( Test-Path .\packer-manifest.json )){ exit 1 }

# Create OVA directory if it doesnt already exist
if (!(Test-Path .\OVA)){ New-Item -Name 'OVA' -Type directory }

# Parse the packer manifest file for the vmx files and then create an ova of each virtual machine
Write-Output "Creating OVA for each build"
$artefacts = & $jqExe '.[].builds[].files[].name' -s packer-manifest.json | ? {$_ -match '.vmx"'}

foreach ($vmx in $artefacts){
   Start-Process $ovfToolExe -ArgumentList "-tt=OVA $vmx ./OVA" -Wait -PassThru -NoNewWindow
}

# Change directory into the OVA directory
Set-Location .\OVA\

# Replace spaces with underscores in OVA filenames
foreach ($ova in (Get-ChildItem)){
    $ova | Rename-Item -NewName { $_.name -Replace ' ','_' }
}

# Upload OVAs to be stored as version controlled artefacts
$version = (get-date -Format u).Split(' ')[0]
Write-Output "Using URL: $url"


Write-Output "Using Repository: $repo"

$group = "packer.vsphere.templates"
Write-Output "Using Group: $group"

foreach ($ova in (Get-ChildItem)){
    # Replace '.ova' with '_Template'
    $upload = $ova.Name.Replace('.ova','_Template')
    Write-Output "Template Name: $upload"
    # Upload to Artifact Repo
    Start-Process $curlExe -ArgumentList "-v -F r=$repo -F hasPom=false -F e=ova -F g=$group -F a=$upload -F v=$version -F p=ova -F file=@$ova -u $($env:Username):$env:Password $url" -Wait -Passthru -NoNewWindow
}
exit 0
