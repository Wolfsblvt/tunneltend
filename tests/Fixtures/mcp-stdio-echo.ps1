#requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Response {
    param([Parameter(Mandatory)][hashtable]$Response)
    $json = $Response | ConvertTo-Json -Compress -Depth 20
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()
}

while ($null -ne ($line = [Console]::In.ReadLine())) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    $request = $null
    try {
        $request = $line | ConvertFrom-Json -AsHashtable -Depth 20
    }
    catch {
        Write-Response @{
            jsonrpc = '2.0'
            id = $null
            error = @{ code = -32700; message = 'Parse error' }
        }
        continue
    }

    $method = [string]$request.method
    if ($method.StartsWith('notifications/', [StringComparison]::Ordinal)) {
        continue
    }

    $id = if ($request.Contains('id')) { $request.id } else { $null }
    switch ($method) {
        'initialize' {
            $protocol = '2025-06-18'
            if ($request.params -is [System.Collections.IDictionary] -and
                $request.params.Contains('protocolVersion') -and
                -not [string]::IsNullOrWhiteSpace([string]$request.params.protocolVersion)) {
                $protocol = [string]$request.params.protocolVersion
            }
            Write-Response @{
                jsonrpc = '2.0'
                id = $id
                result = @{
                    protocolVersion = $protocol
                    capabilities = @{ tools = @{ listChanged = $false } }
                    serverInfo = @{ name = 'tunneltend-echo-fixture'; version = '1.0.0' }
                    instructions = 'Call the echo tool with a text argument.'
                }
            }
        }
        'ping' {
            Write-Response @{ jsonrpc = '2.0'; id = $id; result = @{} }
        }
        'tools/list' {
            Write-Response @{
                jsonrpc = '2.0'
                id = $id
                result = @{
                    tools = @(
                        @{
                            name = 'echo'
                            description = 'Returns the supplied text.'
                            inputSchema = @{
                                type = 'object'
                                properties = @{ text = @{ type = 'string' } }
                                required = @('text')
                                additionalProperties = $false
                            }
                        }
                    )
                }
            }
        }
        'tools/call' {
            $name = [string]$request.params.name
            if ($name -ne 'echo') {
                Write-Response @{
                    jsonrpc = '2.0'
                    id = $id
                    error = @{ code = -32602; message = "Unknown tool '$name'." }
                }
                continue
            }
            $text = [string]$request.params.arguments.text
            Write-Response @{
                jsonrpc = '2.0'
                id = $id
                result = @{
                    content = @(@{ type = 'text'; text = $text })
                    structuredContent = @{ text = $text }
                    isError = $false
                }
            }
        }
        'resources/list' {
            Write-Response @{ jsonrpc = '2.0'; id = $id; result = @{ resources = @() } }
        }
        'prompts/list' {
            Write-Response @{ jsonrpc = '2.0'; id = $id; result = @{ prompts = @() } }
        }
        default {
            Write-Response @{
                jsonrpc = '2.0'
                id = $id
                error = @{ code = -32601; message = "Method '$method' not found." }
            }
        }
    }
}
