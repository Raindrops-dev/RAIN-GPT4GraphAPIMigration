<#
    .SYNOPSIS
        This script takes as input a powershell command using the old Azure AD or MSOL PowerShell modules and converts it to use the new Microsoft Graph PowerShell module.

    .DESCRIPTION
        The goal of these scripts to is to leverage the power of GPT4 to speed up and automate the process of migrating code from the old Azure AD or MSOL PowerShell modules to the new Microsoft Graph PowerShell module.

    .PARAMETER Command
        The command to be converted.

    .EXAMPLE
        PS> .\Migrate-CommandToGraphAPI.ps1 -Command "Get-AzureADUser -ObjectId 12345678-1234-1234-1234-123456789012"

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
    [Parameter(Mandatory = $true, HelpMessage = "The command to be converted.")]
    [string]$Command = "Get-AzureADUser -ObjectId 12345678-1234-1234-1234-123456789012"
)

Clear-Host

$ErrorActionPreference = "Stop"

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
Write-Host "Importing Command..."
$ScriptTosend = @()
$ScriptTosend += "Command To Update:"
$ScriptTosend += "$Command"

#Getting the list of commands from the script
Write-Host "Getting commands from script..."
$ScriptCommands = Get-AzureADMSOLCommands -ScriptContent $Command

#For each command, getting the corresponding Microsoft Graph command and throw an error if no match is found. Create a variable containing these matches
Write-Host "Getting corresponding Microsoft Graph commands..."
$GraphCommands = @()
foreach ($Command in $ScriptCommands) {
    $GraphCommand = $CommandMapping | Where-Object { $_.Old -eq $Command } | Select-Object -ExpandProperty New
    Write-Host "Match found for $($Command): $($GraphCommand)"
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
            "content" = "You are a helpful assistant. You will be provided documentation about new Powershell Microsoft Graph commands to replace old AzureAD/MSOL commands in a powershell script and a powershell script. You will use this information to rewrite the script using these new commands taking into consideration the parameters and the logic of the script and then provide the updated script as output. If the script consists of a single command, provide a single command as output."
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