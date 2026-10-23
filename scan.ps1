param([string]$Path)
$lines = Get-Content $Path
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i] -match "deathbox"){
    Write-Host "$($i+1): $($lines[$i])"
    if($i+1 -lt $lines.Count){ Write-Host "$($i+2): $($lines[$i+1])" }
    if($i+2 -lt $lines.Count){ Write-Host "$($i+3): $($lines[$i+2])" }
    if($i+3 -lt $lines.Count){ Write-Host "$($i+4): $($lines[$i+3])" }
    if($i+4 -lt $lines.Count){ Write-Host "$($i+5): $($lines[$i+4])" }
    Write-Host ""
  }
}
