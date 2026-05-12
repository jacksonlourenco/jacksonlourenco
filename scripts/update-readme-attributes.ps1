Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$readmePath = Join-Path $PSScriptRoot "..\\README.md"
$readmePath = [System.IO.Path]::GetFullPath($readmePath)

# ---- Config ----
$birthDate = Get-Date "2001-05-19"
$characterLevel = 1
$otherCompanyMonths = 13
$currentCompanyStart = Get-Date "2025-10-01"
# ---------------

function Get-CompletedMonths([datetime]$start, [datetime]$end) {
    if ($end -lt $start) { return 0 }
    $months = (($end.Year - $start.Year) * 12) + ($end.Month - $start.Month)
    if ($end.Day -lt $start.Day) { $months -= 1 }
    return [Math]::Max(0, $months)
}

function Get-Age([datetime]$birth, [datetime]$today) {
    $age = $today.Year - $birth.Year
    if (($today.Month -lt $birth.Month) -or (($today.Month -eq $birth.Month) -and ($today.Day -lt $birth.Day))) {
        $age -= 1
    }
    return [Math]::Max(0, $age)
}

function Clamp100([int]$value) {
    return [Math]::Min(100, [Math]::Max(0, $value))
}

function MakeBar([int]$value) {
    $filled = [Math]::Floor($value / 10)
    $empty = 10 - $filled
    return ("█" * $filled) + ("░" * $empty)
}

$today = Get-Date
$age = Get-Age -birth $birthDate -today $today
$vida = Clamp100 ($age * 2)
$currentCompanyMonths = Get-CompletedMonths -start $currentCompanyStart -end $today
$agilidade = Clamp100 ($otherCompanyMonths + $currentCompanyMonths)

# Ataque e Defesa baseados no nivel do personagem (1-10+), com teto 100.
$ataque = Clamp100 (12 + ($characterLevel * 8))
$defesa = Clamp100 (10 + ($characterLevel * 9))

$lines = @(
    '```text'
    "ATAQUE    [$(MakeBar $ataque)] $ataque"
    "DEFESA    [$(MakeBar $defesa)] $defesa"
    "VIDA      [$(MakeBar $vida)] $vida"
    "AGILIDADE [$(MakeBar $agilidade)] $agilidade"
    '```'
)
$attributesBlock = [string]::Join("`n", $lines)

$readme = Get-Content -Raw -Path $readmePath
$pattern = '(?s)```text\s*ATAQUE.*?```'
$readme = [regex]::Replace($readme, $pattern, $attributesBlock, 1)

Set-Content -Path $readmePath -Value $readme -Encoding utf8
Write-Host "Atributos do README atualizados."
