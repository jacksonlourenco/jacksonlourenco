Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$readmePath = Join-Path $PSScriptRoot "..\\README.md"
$readmePath = [System.IO.Path]::GetFullPath($readmePath)
$readme = Get-Content -Raw -Path $readmePath

# ---- Config fixa ----
$birthDate = Get-Date "2001-05-19"
$otherCompanyMonths = 13
$currentCompanyStart = Get-Date "2025-10-01"
# ---------------------

$bossMap = @(
    @{ Number = 1; Role = "Entrar no mercado de trabalho" }
    @{ Number = 2; Role = "Estagio" }
    @{ Number = 3; Role = "Assistente" }
    @{ Number = 4; Role = "Desenvolvedor Junior" }
    @{ Number = 5; Role = "Desenvolvedor Pleno" }
    @{ Number = 6; Role = "Desenvolvedor Senior" }
    @{ Number = 7; Role = "Tech Lead / Engenheiro" }
)

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

function HudLine([string]$label, [string]$value) {
    $text = "║ $label$value"
    return $text.PadRight(21) + "║"
}

# Conta bosses concluidos via checklist do README (aceita [x] e [X], com espacos variaveis)
$checkedBosses = [regex]::Matches($readme, '(?im)^-\s*\[[x]\]\s*Boss\s+\d+:').Count
$promotionsCompleted = [Math]::Min([Math]::Max(0, $checkedBosses), 7)

# Nivel de personagem sobe conforme bosses concluidos (1..7)
$characterLevel = [Math]::Min(7, 1 + $promotionsCompleted)

# Cargo atual conforme ultimo boss concluido
if ($promotionsCompleted -eq 0) {
    $currentRole = "Aprendiz"
} else {
    $currentRole = ($bossMap[$promotionsCompleted - 1]).Role
}

# Rank por promoções concluidas (0..6): E, D, C, B, A, S, SS
$rankOrder = @("E", "D", "C", "B", "A", "S", "SS")
$rankIndex = [Math]::Min($promotionsCompleted, ($rankOrder.Count - 1))
$rank = $rankOrder[$rankIndex]

$today = Get-Date
$age = Get-Age -birth $birthDate -today $today
$vida = Clamp100 ($age * 2)
$currentCompanyMonths = Get-CompletedMonths -start $currentCompanyStart -end $today
$agilidade = Clamp100 ($otherCompanyMonths + $currentCompanyMonths)

# Ataque e Defesa baseados no nivel do personagem (1..7), com teto 100.
$ataque = Clamp100 (10 + ($characterLevel * 12))
$defesa = Clamp100 (8 + ($characterLevel * 12))

$lines = @(
    '```text'
    "ATAQUE    [$(MakeBar $ataque)] $ataque"
    "DEFESA    [$(MakeBar $defesa)] $defesa"
    "VIDA      [$(MakeBar $vida)] $vida"
    "AGILIDADE [$(MakeBar $agilidade)] $agilidade"
    '```'
)
$attributesBlock = [string]::Join("`n", $lines)

# Atualiza atributos
$readme = [regex]::Replace($readme, '(?s)```text\s*ATAQUE.*?```', $attributesBlock, 1)

# Atualiza status HUD
$rankLine = HudLine "Rank: " $rank
$roleLine = HudLine "Cargo: " $currentRole
$readme = [regex]::Replace($readme, '║ Rank:.*?║', $rankLine, 1)
if ($readme -match '║ Cargo:.*?║') {
    $readme = [regex]::Replace($readme, '║ Cargo:.*?║', $roleLine, 1)
} else {
    $readme = $readme -replace '(?m)(║ Rank:.*?║\r?\n)', ('$1' + $roleLine + "`n")
}

# Atualiza avatar de level e legenda
$readme = [regex]::Replace($readme, 'assets/images/level-\d+\.png', "assets/images/level-$characterLevel.png", 1)
$readme = [regex]::Replace($readme, '> Nível \d+:.*', "> Nível ${characterLevel}: evolução por boss concluído", 1)

Set-Content -Path $readmePath -Value $readme -Encoding utf8
Write-Host "README atualizado: level=$characterLevel, rank=$rank, cargo=$currentRole, bosses=$promotionsCompleted"
