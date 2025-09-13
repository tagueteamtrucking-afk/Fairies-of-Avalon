[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Prompt,
  [string]$OutFile,
  [string]$Model    = $env:LLM_MODEL,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if (-not $Model -or [string]::IsNullOrEmpty($Model)) {
  # Conservative, low-cost default; change via repo variable LLM_MODEL if you want
  $Model = "gpt-4o-mini"
}

$haveOpenAI = -not [string]::IsNullOrEmpty($env:OPENAI_API_KEY)

# If DryRun requested OR no provider keys found => write prompt echo to file (audit trail)
if ($DryRun.IsPresent -or -not $haveOpenAI) {
  $content = @"
### LLM Bridge (DRY RUN)
model: $Model
provider: openai
---
PROMPT
------
$Prompt
"@
  if ($OutFile) {
    Set-Content -Path $OutFile -Value $content -Encoding utf8NoBOM
  } else {
    Write-Output $content
  }
  exit 0
}

# Live call (OpenAI Chat Completions)
$headers = @{
  "Authorization" = "Bearer $($env:OPENAI_API_KEY)"
  "Content-Type"  = "application/json"
}

$body = @{
  model = $Model
  messages = @(
    @{
      role    = "system"
      content = "You are an expert repo workflow architect. Output clear, minimal, actionable text without code fences unless asked."
    },
    @{
      role    = "user"
      content = $Prompt
    }
  )
  temperature = 0.2
}

try {
  $resp = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
                            -Method POST `
                            -Headers $headers `
                            -Body   (($body | ConvertTo-Json -Depth 8))
  $text = $resp.choices[0].message.content
  if ($OutFile) {
    Set-Content -Path $OutFile -Value $text -Encoding utf8NoBOM
  } else {
    Write-Output $text
  }
} catch {
  $msg = "LLM Bridge call failed: $($_ | Out-String)"
  Write-Warning $msg
  if ($OutFile) {
    Set-Content -Path $OutFile -Value "### ERROR\n$msg" -Encoding utf8NoBOM
  }
  exit 1
}
