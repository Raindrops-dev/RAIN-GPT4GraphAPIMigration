#Functions required for this project

#Function to pull the help for a given command, clean it up and return it as a string without newlines or tabs or other formatting
function Get-HelpString {
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The command to get the help for")]
        [string]$Command
    )

    $help = Get-Help $Command -Full
    $help = $help | Out-String
    $help = $help -replace "`r`n", " "
    $help = $help -replace "`t", " "
    $help = $help -replace " {2,}", " "
    return $help
}

#Function to parse https://learn.microsoft.com/en-us/powershell/microsoftgraph/azuread-msoline-cmdlet-map?view=graph-powershell-1.0&source=docs , extract the tables and return them as a psobject
function Get-CommandMapping {
    #Table Headers
    $Headers = @("Old", "New")

    # Make the web request and get the parsed HTML
    $url = "https://learn.microsoft.com/en-us/powershell/microsoftgraph/azuread-msoline-cmdlet-map?view=graph-powershell-1.0&source=docs"
    $response = Invoke-WebRequest -Uri $url
    $parsedHtml = $response.ParsedHtml

    # Find all table elements in the HTML
    $tables = $parsedHtml.getElementsByTagName('table')

    # Extract the tables
    $allTableData = @()
    foreach ($table in $tables) {
        $rows = $table.getElementsByTagName('tr')

        # Create a PowerShell object for each row in the table
        for ($j = 1; $j -lt $rows.length; $j++) {
            $row = $rows.item($j)
            $cells = $row.getElementsByTagName('td')

            $rowData = New-Object PSObject
            for ($k = 0; $k -lt $cells.length; $k++) {
                #$cells.length
                #$headers.length
                if ($k -lt $headers.length) {
                    try {
                        $rowData | Add-Member -Type NoteProperty -Name $headers[$k] -Value $cells[$k].innerText.Trim()
                    }
                    catch {
                        try {
                            # Code that might cause the error
                            $rowData | Add-Member -Type NoteProperty -Name $headers[$k] -Value $cells[$k].innerText.Trim()
                        }
                        catch [System.Management.Automation.RuntimeException] {
                            if ($_.FullyQualifiedErrorId -eq "InvokeMethodOnNull") {
                                $rowData | Add-Member -Type NoteProperty -Name $headers[$k] -Value $null
                            }
                        }

                    }
                }
            }

            $allTableData += $rowData
        }
    }
    return $allTableData
}

function Get-AzureADMSOLCommands {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ScriptContent
    )

    begin {
        $regex = "(?i)((Get|Set|New|Remove)-((AzureAD|MSOL)[\w-]+))"
    }

    process {
        $matches = [regex]::Matches($scriptContent, $regex)

        $commands = $matches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique

        return $commands
    }
}

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
        "Content-Type"  = "application/json";
        "Authorization" = "Bearer $APIkey"
    }
    #Defining the request body
    $RequestBody = [ordered]@{
        "model"    = "gpt-4";
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

    return $content
}