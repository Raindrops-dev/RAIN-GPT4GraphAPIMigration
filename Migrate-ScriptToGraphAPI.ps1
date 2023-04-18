<#
    .SYNOPSIS
        This scripts take as input a powershell script using the old Azure AD or MSOL PowerShell modules and converts it to use the new Microsoft Graph PowerShell module.

    .DESCRIPTION
        The goal of these scripts to is to leverage the power of GPT4 to speed up and automate the process of migrating scripts from the old Azure AD or MSOL PowerShell modules to the new Microsoft Graph PowerShell module.

    .PARAMETER ScriptPath
        The path to the script to be converted.

    .PARAMETER OutputPath
        The path to the output file. If not specified, the script will be saved in the same folder as the original script.

    .EXAMPLE
        PS> .\Migrate-ScriptToGraphAPI.ps1 -ScriptPath "C:\Scripts\Script1.ps1" -OutputPath "C:\Scripts\Script1-Graph.ps1"

    .NOTES
        Author: Padure Sergio
        Version: 1.0
        Date: 2023-04-16
        Requirements: Microsoft.Graph PowerShell Module
        Update History:
            1.0 - Initial Release

    .LINK
        https://docs.microsoft.com/powershell/module/microsoft.graph
        https://learn.microsoft.com/en-us/powershell/microsoftgraph/azuread-msoline-cmdlet-map?view=graph-powershell-1.0
#>

Param(
    [Parameter(Mandatory = $true, HelpMessage = "The path to the script to be converted.")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ScriptPath = ".\Test\testmd.ps1",

    [Parameter(Mandatory = $false, HelpMessage = "The path to the output file. If not specified, the script will be saved in the same folder as the original script.")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$OutputPath
)

Clear-Host

#Importing the functions from the functions.psm1 file
Write-Host "Importing functions..."
$RootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$null = Import-Module "$RootDir\functions.psm1" -Force

#Importing configuration from the json file
Write-Host "Importing configuration..."
$ConfigFile = Get-Content -Path "$RootDir\config.json" | ConvertFrom-Json
$token = $ConfigFile.api_key

#Importing markdown data for matching commands between AzureAD/MSOL and Microsoft Graph
Write-Host "Importing command mapping..."
$CommandMapping = Get-CommandMapping

#Importing the script to be converted as raw text
Write-Host "Importing script..."
$ScriptTosend = @()
$ScriptTosend += "Script To Update:"
$RawScript = Get-Content -Path $ScriptPath -Raw
$ScriptTosend += $RawScript

#Getting the list of commands from the script
Write-Host "Getting commands from script..."
$ScriptCommands = Get-AzureADMSOLCommands -ScriptContent $RawScript

#For each command, getting the corresponding Microsoft Graph command and throw an error if no match is found. Create a variable containing these matches
Write-Host "Getting corresponding Microsoft Graph commands..."
$GraphCommands = @()
foreach ($Command in $ScriptCommands) {
    $GraphCommand = $CommandMapping | Where-Object { $_.Old -eq $Command } | Select-Object -ExpandProperty New
    if ($GraphCommand) {
        $GraphCommands += $GraphCommand
    }
    else {
        throw "No match found for $($Command)"
    }
}

#For each command, getting the help text, cleaning it up using Get-HelpString and then adding it all as raw text to a variable
Write-Host "Getting help text for Microsoft Graph commands..."
$GraphHelpText = @()
$GraphHelpText += "Documentation:"
foreach ($Command in $GraphCommands) {
    $HelpText = Get-HelpString -Command $Command
    $GraphHelpText += $HelpText
}

#Starting GPT4 code
#Defining GPT4 Request
Write-Host "Starting GPT4 request..."
$FinalRequest = @()
$FinalRequest += $GraphHelpText
$FinalRequest += $ScriptTosend

#Defining the request headers
$Headers = [ordered]@{
    "Content-Type"  = "application/json";
    "Authorization" = "Bearer $token"
}

#Defining the request body
Write-Host "Defining the request body..."
$RequestBody = [ordered]@{
    "model"    = "gpt-4";
    "messages" = @(
        @{
            "role"    = "system";
            "content" = "You are a helpful assistant. You will be provided documentation about new Powershell Microsoft Graph commands to replace old AzureAD/MSOL commands in a powershell script and a powershell script. You will use this information to rewrite the script using these new commands taking into consideration the parameters and the logic of the script and then provide the updated script as output."
        }, @{
            "role"    = "user";
            "content" = "$FinalRequest"
        }
    )
} | ConvertTo-Json -Depth 99
$RequestBody

#Accounting for error "That model is currently overloaded with other requests." and retrying it query failed. Retry after 1 second for up to 5 times
Write-Host "Accounting for error 'That model is currently overloaded with other requests.' and retrying it query failed. Retry after 1 second for up to 5 times..."
for ($i = 0; $i -lt 5; $i++) {
    try {
        #Using stopwatch to measure the time it takes to get a response from OpenAI
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        #Doing the API call
        $response = Invoke-WebRequest https://api.openai.com/v1/chat/completions -Method POST -Body $RequestBody -Headers $Headers
        #Stopping the stopwatch
        $sw.Stop()
        #Writing the time it took to get a response from OpenAI in seconds
        Write-Host "Time to get a response from OpenAI: $($sw.Elapsed.TotalSeconds) seconds" -ForegroundColor Green
        break
    }
    catch {
        Write-Warning "That model is currently overloaded with other requests. Retrying in 1 second..."
        Write-Output $_.Exception.Response
        Start-Sleep -Seconds 1
    }
}
  
# echo the 'content' field of the response which is in JSON format
$content = ConvertFrom-Json $response.Content | Select-Object -ExpandProperty choices | Select-Object -ExpandProperty message | Select-Object -ExpandProperty content
Write-Host "Your query was:" -ForegroundColor Green
Write-Output $FinalRequest
Write-Host "The response from OpenAI was:" -ForegroundColor Green
Write-Output $content

#Saving the output to a file
Write-Output "Checking if the output path has been provided to save the output to a file..."
if ($OutputPath) {
    Write-Output "Output path has been provided. Saving the output to a file..."
    $content | Out-File -FilePath $OutputPath -Force
}
else {
    Write-Warning "No output path has been provided. Stopping at providing code in the console."
}