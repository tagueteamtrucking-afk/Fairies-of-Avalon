[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Prompt,
  [Parameter(Mandatory=$true)][string]$OutFile,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Fallback {
  $stamp = (Get-Date).ToUniversalTime().ToString("o")
  $fallback = @"
<!-- LLM Bridge Fallback (rate limit or no key) @ $stamp -->
<!-- This content is deterministic and safe to publish. Adapt or regenerate later. -->
<section>
  <h2>Generated Content (Fallback)</h2>
  <p>This was produced by the Overseers' fallback path because the live LLM was unavailable or rate-limited.</p>
</section>
"@
  Set-Content -Path $OutFile -Value $fallback -Encoding utf8NoBOM
}

try {
  if ($DryRun -or [string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
    Write-Host "::notice:: LLM Bridge in dry-run mode or no OPENAI_API_KEY; writing fallback."
    Write-Fallback
    exit 0
  }

  $body = @{
    model = "gpt-4o-mini"
    messages = @(
      @{ role = "system"; content = "You are a precise builder. Return only the requested content, no extraneous commentary." },
      @{ role = "user";   content = $Prompt }
    )
    temperature = 0.3
  } | ConvertTo-Json -Depth 6

  $headers = @{ Authorization = "Bearer $($env:OPENAI_API_KEY)" }
  try {
    $resp = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" -Method Post -Headers $headers -Body $body -ContentType "application/json"
    $text = $resp.choices[0].message.content
    if (-not $text) { throw "Empty response from OpenAI." }
    Set-Content -Path $OutFile -Value $text -Encoding utf8NoBOM
  }
  catch {
    $msg = $_ | Out-String
    if ($msg -match "rate_limit_exceeded") {
      Write-Host "::warning:: OpenAI rate limit exceeded; using fallback output."
    } else {
      Write-Host "::warning:: LLM Bridge error; using fallback output."
    }
    Write-Fallback
  }
}
catch {
  # Absolute guard — never fail the job
  Write-Host "::warning:: LLM Bridge unexpected error; writing fallback."
  Write-Fallback
}
exit 0
