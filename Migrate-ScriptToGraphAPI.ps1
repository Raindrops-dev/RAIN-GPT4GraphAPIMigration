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

#Preparing the request
$request = @()
$SystemMessage = @{
    "role"    = "system";
    "content" = "You are a powershell, Azure AD and Microsoft 365 expert. You will be provided documentation about new Powershell Microsoft Graph commands to replace old AzureAD/MSOL commands in a powershell script and a powershell script. You will use this information to rewrite the script using these new commands taking into consideration the parameters and the logic of the script and then provide the updated script as output. Try to keep output length comparable to the length of the source script. Let's work this out in a step by step way to be sure we have the right answer."
}
$request += $SystemMessage

#Importing markdown data for matching commands between AzureAD/MSOL and Microsoft Graph
Write-Host "Importing command mapping..."
$CommandMapping = Get-CommandMapping

#Importing the script to be converted as raw text
Write-Host "Importing script..."
$ScriptTosend = @()
$ScriptTosend += "Script To Update:"
$RawScript = Get-Content -Path $ScriptPath -Raw
$ScriptTosend += $RawScript

$RawScript

#Getting the list of commands from the script
Write-Host "Getting commands from script..."
$ScriptCommands = Get-AzureADMSOLCommands -ScriptContent $RawScript
$ScriptCommands

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
$GraphCommands

#For each command, getting the help text, cleaning it up using Get-HelpString and then adding it all as raw text to a variable
Write-Host "Getting help text for Microsoft Graph commands..."
$GraphHelpText = @()
$GraphHelpText += "Documentation:"
foreach ($Command in $GraphCommands) {
    $HelpText = Get-HelpString -Command $Command
    $GraphHelpText += $HelpText
}

#Adding the help text to the request
$request += @{
    "role"    = "user";
    "content" = $GraphHelpText
}

#Adding the script to the request
$request += @{
    "role"    = "user";
    "content" = "Script To Update: $RawScript"
}

#Starting GPT4 code
Write-Host "Starting GPT4 request..."
$request

#Sending request
$AssistantResponse = Get-OpenAIAnswer -APIkey $token -Request $request
Write-Host $AssistantResponse -ForegroundColor Green

#Starting Reflection
Write-Output "Starting reflection..."
$request += @{
    "role"    = "assistant";
    "content" = $AssistantResponse
}

$request += @{
    "role"    = "user";
    "content" = "Is the provided code correct?"
}

$AssistantResponse = Get-OpenAIAnswer -APIkey $token -Request $request
Write-Host $AssistantResponse -ForegroundColor Green

$request += @{
    "role"    = "assistant";
    "content" = $AssistantResponse
}

#Starting open communication
while ($true) {
    #Getting the user's prompt
    $userprompt = Read-Host "Please provide your prompt"
    $UserMessage = @{
        "role"    = "user";
        "content" = $userprompt
    }
    $request += $UserMessage
    
    #Outputting the current request for debugging purposes
    Write-Output "Current request:"
    Write-Output $request

    #Sending request
    #Using stopwatch to measure the time it takes to get a response from OpenAI
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    #Doing the API call
    $AssistantResponse = Get-OpenAIAnswer -APIkey $token -Request $request
    #Stopping the stopwatch
    $sw.Stop()
    #Writing the time it took to get a response from OpenAI in seconds
    Write-Host "Time to get a response from OpenAI: $($sw.Elapsed.TotalSeconds) seconds" -ForegroundColor Red

    #Adding the answer to the request
    $AssistantMessage = @{
        "role"    = "assistant";
        "content" = $AssistantResponse
    }
    $request += $AssistantMessage

    #Providing the user with the answer
    Write-Host $AssistantResponse -ForegroundColor Green

}

