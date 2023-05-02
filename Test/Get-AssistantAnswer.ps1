#Defining default parameter
Param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Command = "What are the basic python imports?"
)

#Defining functions
function Get-OpenAIAnswer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$APIkey,
        [Parameter(Mandatory = $true, Position = 1)]
        [System.Object[]]$Request
    )
    #Defining the request headers
    $Headers = [ordered]@{
        "Content-Type"  = "application/json; charset=utf-8";
        "Authorization" = "Bearer $APIkey"
    }
    #Defining the request body
    $RequestBody = [ordered]@{
        "model"    = "gpt-3.5-turbo";
        "messages" = $Request
    } | ConvertTo-Json -Depth 99

    #Accounting for error "That model is currently overloaded with other requests." and retrying it query failed. Retry after 1 second for up to 5 times
    for ($i = 0; $i -lt 5; $i++) {
        try {
            #Using stopwatch to measure the time it takes to get a response from OpenAI
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            #Doing the API call
            $response = Invoke-WebRequest https://api.openai.com/v1/chat/completions -Method POST -Body $RequestBody -Headers $Headers
            #Stopping the stopwatch
            $sw.Stop()
            #Writing the time it took to get a response from OpenAI in seconds
            #Write-Host "Time to get a response from OpenAI: $($sw.Elapsed.TotalSeconds) seconds" -ForegroundColor Green
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

    return $content
}

Clear-Host

#Defining basic variables
$RootDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$ErrorActionPreference = "Stop"

# import the openai api key from a JSON file
$keyJson = Get-Content "$RootDir\config.json" | ConvertFrom-Json
$token = $keyJson.api_key

#Preparing the request
$request = @()
$SystemMessage = @{
    "role"    = "system";
    "content" = "You are a helpful assistant. Answer in Markdown format. Answer as concisely as possible."
}
$request += $SystemMessage

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