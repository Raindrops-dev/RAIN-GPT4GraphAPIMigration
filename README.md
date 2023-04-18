# PowerShell Script Migration to Microsoft Graph PowerShell Module

This project provides a PowerShell script to migrate existing scripts using the old Azure AD or MSOL PowerShell modules to the new Microsoft Graph PowerShell module.

This is just a proof of concept for now, it's not sufficiently robust to use in production and the 8k token limit sharply limits the length of the scripts that can be converted over.

## Prerequisites

- PowerShell 5.1 or later
- Microsoft.Graph PowerShell Module

## Usage

1. Clone this repository or download the script files.
2. Copy and rename config.json.example to config.json and fill in your GPT4 API Key
3. Open PowerShell and navigate to the directory containing the script files.
4. Run the `Migrate-ScriptToGraphAPI.ps1` script, providing the required parameters:

```powershell
.\Migrate-ScriptToGraphAPI.ps1 -ScriptPath "C:\Scripts\Script1.ps1" -OutputPath "C:\Scripts\Script1-Graph.ps1"
```

This will convert the input script (`C:\Scripts\Script1.ps1`) and save the converted script to the specified output path (`C:\Scripts\Script1-Graph.ps1`).

## Parameters

- `-ScriptPath`: The path to the script to be converted (mandatory).
- `-OutputPath`: The path to the output file. If not specified, the resulting script will only be provided in the console

## Notes

This script leverages GPT4 to speed up and automate the process of migrating scripts from the old Azure AD or MSOL PowerShell modules to the new Microsoft Graph PowerShell module.
It gathers the cmdlets from the provided scripts, gets the cmdlet mapping between the old MSOL/AzureAD commands and the new Graph API ones from Microsoft Learn, gathers the Documentation for the concerned Graph API cmdlets to bypass the issue of GPT4's data being capped in 2021 and then sends an API call to GPT4 with the documentation and the script to migrate.

Warning: GPT4 API is expensive, be sure to put usage limits in the OpenAI console!

## Limitations

- Mapping into data structures might not move over as they're different between Azure AD/MSOL and Graph API and the token limit doesn't allow for also sending the documentation for the output of each cmdlet.
- GPT4 is limited to 8k tokens, which can be reached very rapidly when sending documentation about some very verbose cmdlets like Get-MgUser and a fairly long script. When that happens you'll get an error.
- The script does data cleanup on the documentation to decrease token usage but it's not always sufficient. I'm wondering if vector databases could be a solution but that's not implemented currently.
- As usual, hallucination is always a problem. Verify the resulting script VERY carefully before using it and test it extensively

## Support

For any issues or feature requests, please [create an issue on GitHub](https://github.com/Raindrops-dev/RAIN-GPT4GraphAPIMigration/issues).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Additional Resources

- [Microsoft Graph PowerShell Module](https://docs.microsoft.com/powershell/module/microsoft.graph)
- [Azure AD/MSOL to Microsoft Graph Cmdlet Map](https://learn.microsoft.com/en-us/powershell/microsoftgraph/azuread-msoline-cmdlet-map?view=graph-powershell-1.0)