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

# Edite este mapa para alterar cargo/data/empresa de cada boss.
$bossMap = @(
    @{ Number = 1; Role = "Entrar no mercado de trabalho"; DateCompany = "06/2022 - DiamondBigger"; Image = "boss-1-entrar-mercado.png" }
    @{ Number = 2; Role = "Estágio"; DateCompany = "06/2022 - DiamondBigger"; Image = "boss-2-estagio.png" }
    @{ Number = 3; Role = "Assistente"; DateCompany = "10/2025 - Capgemini"; Image = "boss-3-assistente.png" }
    @{ Number = 4; Role = "Desenvolvedor Júnior"; DateCompany = "MM/AAAA - Empresa"; Image = "boss-4-junior.png" }
    @{ Number = 5; Role = "Desenvolvedor Pleno"; DateCompany = "MM/AAAA - Empresa"; Image = "boss-5-pleno.png" }
    @{ Number = 6; Role = "Desenvolvedor Sênior"; DateCompany = "MM/AAAA - Empresa"; Image = "boss-6-senior.png" }
    @{ Number = 7; Role = "Tech Lead / Engenheiro"; DateCompany = "MM/AAAA - Empresa"; Image = "boss-7-tech-lead-engenheiro.png" }
)

function Get-CompletedMonths([datetime]$start, [datetime]$end) {
    if ($end -lt $start) { return 0 }
    $months = (($end.Year - $start.Year) * 12) + ($end.Month - $start.Month)
    if ($end.Day -lt $start.Day) { $months -= 1 }
    return [Math]::Max(0, $months)
}

function Get-Age([datetime]$birth, [datetime]$today) {
    $age = $today.Year - $birth.Year
    if (($today.Month -lt $birth.Month) -or (($today.Month -eq $birth.Month) -and ($today.Day -lt $birth.Day))) { $age -= 1 }
    return [Math]::Max(0, $age)
}

function Clamp100([int]$value) { return [Math]::Min(100, [Math]::Max(0, $value)) }

function MakeBar([int]$value) {
    $filled = [Math]::Floor($value / 10)
    $empty = 10 - $filled
    return ("█" * $filled) + ("░" * $empty)
}

function HudLine([string]$label, [string]$value) {
    $text = "║ $label$value"
    return $text.PadRight(21) + "║"
}

function UrlEncode([string]$value) {
    return [uri]::EscapeDataString($value) -replace "\+", "%20"
}

# Leitura do estado atual do checklist (aceita [x]/[X])
$checkedByBoss = @{}
foreach ($boss in $bossMap) {
    $pattern = "(?im)^-\s*\[([x ])\]\s*Boss\s+$($boss.Number):"
    $m = [regex]::Match($readme, $pattern)
    if ($m.Success -and $m.Groups[1].Value.ToLower() -eq "x") {
        $checkedByBoss[$boss.Number] = $true
    } else {
        $checkedByBoss[$boss.Number] = $false
    }
}

$promotionsCompleted = ($checkedByBoss.Values | Where-Object { $_ }).Count
$characterLevel = [Math]::Min(7, 1 + $promotionsCompleted)

if ($promotionsCompleted -eq 0) {
    $currentRole = "Aprendiz"
} else {
    $currentRole = ($bossMap[$promotionsCompleted - 1]).Role
}

$rankOrder = @("E", "D", "C", "B", "A", "S", "SS")
$rankIndex = [Math]::Min($promotionsCompleted, ($rankOrder.Count - 1))
$rank = $rankOrder[$rankIndex]

$today = Get-Date
$age = Get-Age -birth $birthDate -today $today
$vida = Clamp100 ($age * 2)
$currentCompanyMonths = Get-CompletedMonths -start $currentCompanyStart -end $today
$agilidade = Clamp100 ($otherCompanyMonths + $currentCompanyMonths)
$ataque = Clamp100 (10 + ($characterLevel * 12))
$defesa = Clamp100 (8 + ($characterLevel * 12))

$attributesBlock = [string]::Join("`n", @(
    '```text'
    "ATAQUE    [$(MakeBar $ataque)] $ataque"
    "DEFESA    [$(MakeBar $defesa)] $defesa"
    "VIDA      [$(MakeBar $vida)] $vida"
    "AGILIDADE [$(MakeBar $agilidade)] $agilidade"
    '```'
))
$readme = [regex]::Replace($readme, '(?s)```text\s*ATAQUE.*?```', $attributesBlock, 1)

$readme = [regex]::Replace($readme, '║ Rank:.*?║', (HudLine "Rank: " $rank), 1)
$roleLine = HudLine "Cargo: " $currentRole
if ($readme -match '║ Cargo:.*?║') {
    $readme = [regex]::Replace($readme, '║ Cargo:.*?║', $roleLine, 1)
} else {
    $readme = $readme -replace '(?m)(║ Rank:.*?║\r?\n)', ('$1' + $roleLine + "`n")
}

$readme = [regex]::Replace($readme, 'assets/images/level-\d+\.png', "assets/images/level-$characterLevel.png", 1)
$readme = [regex]::Replace($readme, '> Nível \d+:.*', "> Nível ${characterLevel}: evolução por boss concluído", 1)

# Regenera bloco de bosses com data/empresa
$bossLines = foreach ($boss in $bossMap) {
    $checked = if ($checkedByBoss[$boss.Number]) { "x" } else { " " }
    "- [$checked] Boss $($boss.Number): $($boss.Role) - $($boss.DateCompany)"
}
$bossBlock = [string]::Join("`n", @("<!-- BOSSES:START -->") + $bossLines + @("<!-- BOSSES:END -->"))
$readme = [regex]::Replace($readme, '(?s)<!-- BOSSES:START -->.*?<!-- BOSSES:END -->', $bossBlock, 1)

# Regenera galeria dinamica com vermelho quando concluido
$cards = @()
foreach ($boss in $bossMap) {
    $done = $checkedByBoss[$boss.Number]
    $nameColor = if ($done) { "ef4444" } else { "334155" }
    $metaColor = if ($done) { "ef4444" } else { "64748b" }
    $statusText = if ($done) { "CONCLUÍDO" } else { "PENDENTE" }
    $statusColor = if ($done) { "ef4444" } else { "475569" }

    $badgeName = "https://img.shields.io/badge/Boss%20$($boss.Number)-$(UrlEncode $boss.Role)-${nameColor}?style=for-the-badge"
    $badgeMeta = "https://img.shields.io/badge/$(UrlEncode $boss.DateCompany)-${metaColor}?style=flat-square"
    $badgeStatus = "https://img.shields.io/badge/$([uri]::EscapeDataString($statusText))-${statusColor}?style=flat-square"

    $card = @"
      <img src="$badgeName" alt="Boss $($boss.Number)" /><br/>
      <img src="$badgeMeta" alt="Data e empresa" /><br/>
      <img src="$badgeStatus" alt="Status" /><br/>
      <img src="assets/images/$($boss.Image)" width="170" alt="Boss $($boss.Number) - $($boss.Role)" />
"@
    $cards += $card.TrimEnd()
}

$row1 = @"
    <td align="center">
$($cards[0])
    </td>
    <td align="center">
$($cards[1])
    </td>
    <td align="center">
$($cards[2])
    </td>
"@

$row2 = @"
    <td align="center">
$($cards[3])
    </td>
    <td align="center">
$($cards[4])
    </td>
    <td align="center">
$($cards[5])
    </td>
"@

$row3 = @"
      <img src="https://img.shields.io/badge/Boss%207-$(UrlEncode $($bossMap[6].Role))-$(if($checkedByBoss[7]){'ef4444'}else{'334155'})?style=for-the-badge" alt="Boss 7" /><br/>
      <img src="https://img.shields.io/badge/$(UrlEncode $($bossMap[6].DateCompany))-$(if($checkedByBoss[7]){'ef4444'}else{'64748b'})?style=flat-square" alt="Data e empresa" /><br/>
      <img src="https://img.shields.io/badge/$([uri]::EscapeDataString($(if($checkedByBoss[7]){'CONCLUÍDO'}else{'PENDENTE'})))-$(if($checkedByBoss[7]){'ef4444'}else{'475569'})?style=flat-square" alt="Status" /><br/>
      <img src="assets/images/$($bossMap[6].Image)" width="170" alt="Boss 7 - $($bossMap[6].Role)" />
"@
$gallery = @"
<!-- BOSS_GALLERY:START -->
<table>
  <tr>
$row1
  </tr>
  <tr>
$row2
  </tr>
  <tr>
    <td align="center" colspan="3">
$row3
    </td>
  </tr>
</table>
<!-- BOSS_GALLERY:END -->
"@
$readme = [regex]::Replace($readme, '(?s)<!-- BOSS_GALLERY:START -->.*?<!-- BOSS_GALLERY:END -->', $gallery.Trim(), 1)

Set-Content -Path $readmePath -Value $readme -Encoding utf8
Write-Host "README atualizado: level=$characterLevel, rank=$rank, cargo=$currentRole, bosses=$promotionsCompleted"
