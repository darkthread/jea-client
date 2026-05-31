<#
.SYNOPSIS
    管理 JEA Endpoint 的完整生命週期（建立、註冊、取消、刪除、列出、啟用 HTTPS）

.DESCRIPTION
    透過 ParameterSet 控制四種執行模式：
      Create                （預設）建立 .psrc 角色能力檔與 .pssc 工作階段設定檔，均置於 Module 目錄
      Register              使用 .pssc 檔案向 WinRM 註冊 JEA Endpoint
      Unregister            從 WinRM 取消已註冊的 JEA Endpoint
      Delete                刪除 Module 目錄（含 .psrc、.pssc），若 Endpoint 仍在註冊中會提出警告
      EnableHttps           在本機建立 WinRM HTTPS Listener，並開放防火牆連入規則
      ShowHttpsCert         顯示 WinRM HTTPS Listener 目前使用的憑證詳細資訊
      ReplaceHttpsCert      替換 WinRM HTTPS Listener 使用的憑證（不需重建 Listener）
      ExportCert  找到 WinRM HTTPS Listener 目前使用的自簽憑證，匯出為 .cer 供用戶端信任

.PARAMETER EndpointName
    JEA Endpoint 名稱，例如 "ServiceAdmin"。所有模式均必填。

.PARAMETER RoleUsers
    [Create] 要指派到此角色的使用者帳號或群組清單，例如 "DOMAIN\User1"、"CLIENTPC\User2"。

.PARAMETER CmdletList
    [Create] 要允許的 Cmdlet 或函式清單，例如 "Get-Service"、"Restart-Service"。

.PARAMETER TranscriptPath
    [Create] JEA Session 稽核記錄（Transcript）的存放目錄。
    預設為 C:\ProgramData\JEAConfiguration\Transcripts（標準使用者無存取權，符合 Microsoft 安全建議）。

.PARAMETER RunAsVirtualAccountGroups
    [Create] 限制虛擬帳號所屬的本機群組清單，例如 "Administrators"、"Remote Management Users"。
    省略時沿用 New-PSSessionConfigurationFile 的預設值（虛擬帳號為本機 Administrators）。

.PARAMETER Register
    切換至 Register 模式，向 WinRM 註冊 JEA Endpoint。

.PARAMETER PsscPath
    [Register] .pssc 檔案的完整路徑。省略時使用 Create 模式產生的預設路徑。

.PARAMETER Unregister
    切換至 Unregister 模式，從 WinRM 取消 JEA Endpoint。

.PARAMETER Delete
    切換至 Delete 模式，刪除 Module 目錄及其中所有 JEA 設定檔（.psrc、.pssc、.psd1）。
    若 JEA Endpoint 仍處於已註冊狀態，將顯示警告（不中斷刪除流程）。

.PARAMETER List
    切換至 List 模式，列出本機目前已透過 WinRM 註冊的所有 JEA Endpoint。
    不需要指定 -EndpointName。

.PARAMETER EnableHttps
    切換至 EnableHttps 模式，在本機建立 WinRM HTTPS Listener 並開放防火牆連入規則。
    此設定為機器層級，與特定 JEA Endpoint 無直接耦合，但為安全 JEA 連線的必要前提。

.PARAMETER CertThumbprint
    [EnableHttps] 欲使用的憑證指紋（位於 Cert:\LocalMachine\My）。
    省略時自動建立 Self-Signed Certificate（僅適用於測試環境）。

.PARAMETER Hostname
    [EnableHttps] 憑證的 DNS 名稱。預設為本機電腦名稱（$env:COMPUTERNAME）。

.PARAMETER Port
    [EnableHttps] WinRM HTTPS 監聽埠。預設 5986。

.PARAMETER ExportCert
    [EnableHttps] 將憑證匯出為 .cer 檔案的完整路徑，供用戶端以 Import-Certificate 匯入信任。
    例如 'C:\Temp\PDC-WinRM.cer'。

.PARAMETER ExportCert
    切換至 ExportCert 模式，自動查詢 WinRM HTTPS Listener 目前使用的憑證，
    若確認為自簽憑證（Issuer = Subject），則匯出為 .cer 檔。

.PARAMETER ExportPath
    [ExportCert] 匯出 .cer 檔案的完整路徑。預設為 '$env:TEMP\WinRM-HTTPS.cer'。

.PARAMETER ShowHttpsCert
    切換至 ShowHttpsCert 模式，顯示目前 WinRM HTTPS Listener 所使用憑證的詳細資訊
    （Subject、Issuer、指紋、有效期間、SAN、EKU、是否自簽等）。

.PARAMETER ReplaceHttpsCert
    切換至 ReplaceHttpsCert 模式，將 WinRM HTTPS Listener 現行憑證替換為指定的
    `-NewCertThumbprint`；若未指定則重新建立一張 Self-Signed Certificate。替換過程
    使用 Set-WSManInstance 原地更新，不需刪除與重建 Listener。

.PARAMETER NewCertThumbprint
    [ReplaceHttpsCert] 新憑證的指紋（位於 Cert:\LocalMachine\My）。
    省略時腳本會以 `-Hostname` 重新建立 Self-Signed Certificate。

.PARAMETER RemoveOldCert
    [ReplaceHttpsCert] 替換完成後，若舊憑證為自簽且不再被使用，則從
    Cert:\LocalMachine\My 中刪除。CA 簽發憑證不會被刪除。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EndpointName ServiceAdmin -RoleUsers "DOMAIN\User1" -CmdletList "Get-Service","Restart-Service"
    建立 ServiceAdmin 的 .psrc 與 .pssc 設定檔（存放於 Module 目錄）。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EndpointName ServiceAdmin -Register
    使用 Create 產生的 .pssc 註冊 JEA Endpoint。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EndpointName ServiceAdmin -Register -PsscPath "C:\Custom\ServiceAdmin.pssc"
    使用指定的 .pssc 路徑註冊 JEA Endpoint。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EndpointName ServiceAdmin -Unregister
    取消已註冊的 JEA Endpoint。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EndpointName ServiceAdmin -Unregister -WhatIf
    預覽取消動作，不實際執行。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EndpointName ServiceAdmin -Delete
    刪除 ServiceAdmin 的 Module 目錄（含 .psrc、.pssc）。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EndpointName ServiceAdmin -Delete -WhatIf
    預覽刪除動作，不實際執行。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EnableHttps
    自動建立 Self-Signed 憑證並啟用 WinRM HTTPS（port 5986）。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EnableHttps -CertThumbprint 'A1B2C3...' -Port 5986
    使用既有憑證啟用 WinRM HTTPS。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EnableHttps -WhatIf
    預覽 EnableHttps 動作，不實際執行。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -EnableHttps -ExportCert 'C:\Temp\PDC-WinRM.cer'
    啟用 WinRM HTTPS 並將 Self-Signed 憑證匯出為 .cer 檔，供用戶端以 Import-Certificate 匯入信任後直接連線。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -List
    列出本機所有已註冊的 JEA Endpoint。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -ExportCert
    將 WinRM HTTPS 目前使用的自簽憑證匯出至 %TEMP%\WinRM-HTTPS.cer。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -ExportCert -ExportPath 'C:\Share\PDC-WinRM.cer'
    將自簽憑證匯出至指定路徑，方便複製到用戶端執行 Import-Certificate。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -ShowHttpsCert
    顯示目前 WinRM HTTPS Listener 使用憑證的詳細資訊。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -ReplaceHttpsCert -NewCertThumbprint 'F1E2D3...'
    將 WinRM HTTPS Listener 改用指定的新憑證。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -ReplaceHttpsCert -Hostname 'pdc.contoso.com' -RemoveOldCert
    重新建立一張含 FQDN 的 Self-Signed Certificate 並替換舊憑證，同時刪除舊的自簽憑證。
#>
#Requires -RunAsAdministrator
[CmdletBinding(DefaultParameterSetName = 'Create', SupportsShouldProcess = $true)]
Param(
    # ── 所有模式共用 ────────────────────────────────────────────
    [Parameter(ParameterSetName = 'Create',      Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'Register',    Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'Unregister',  Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'Delete',      Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'EnableHttps', Mandatory = $false)]  # 選填，僅供顯示連線範例
    [string]$EndpointName,


    # ── Create 模式專用 ─────────────────────────────────────────
    [Parameter(ParameterSetName = 'Create', Mandatory = $true)]
    [string[]]$RoleUsers,

    [Parameter(ParameterSetName = 'Create', Mandatory = $true)]
    [string[]]$CmdletList,

    [Parameter(ParameterSetName = 'Create')]
    [string]$TranscriptPath = 'C:\ProgramData\JEAConfiguration\Transcripts',

    [Parameter(ParameterSetName = 'Create')]
    [string[]]$RunAsVirtualAccountGroups,

    # ── Register 模式專用 ───────────────────────────────────────
    [Parameter(ParameterSetName = 'Register', Mandatory = $true)]
    [switch]$Register,

    [Parameter(ParameterSetName = 'Register')]
    [string]$PsscPath,

    # ── Unregister 模式專用 ─────────────────────────────────────
    [Parameter(ParameterSetName = 'Unregister', Mandatory = $true)]
    [switch]$Unregister,

    # ── Delete 模式專用 ──────────────────────────────────────────
    [Parameter(ParameterSetName = 'Delete', Mandatory = $true)]
    [switch]$Delete,

    # ── List 模式專用 ────────────────────────────────────────────
    [Parameter(ParameterSetName = 'List', Mandatory = $true)]
    [switch]$List,

    # ── ExportCert 模式專用 ───────────────────────────────
    [Parameter(ParameterSetName = 'ExportCert', Mandatory = $true)]
    [switch]$ExportCert,

    [Parameter(ParameterSetName = 'ExportCert')]
    [string]$ExportPath = (Join-Path $env:TEMP 'WinRM-HTTPS.cer'),

    # ── EnableHttps 模式專用 ─────────────────────────────────────
    [Parameter(ParameterSetName = 'EnableHttps', Mandatory = $true)]
    [switch]$EnableHttps,

    [Parameter(ParameterSetName = 'EnableHttps')]
    [string]$CertThumbprint,

    [Parameter(ParameterSetName = 'EnableHttps')]
    [string]$Hostname = $env:COMPUTERNAME,

    [Parameter(ParameterSetName = 'EnableHttps')]
    [ValidateRange(1, 65535)]
    [int]$Port = 5986,

    [Parameter(ParameterSetName = 'EnableHttps')]
    [string]$ExportCert,

    # ── ShowHttpsCert 模式專用 ──────────────────────────────────
    [Parameter(ParameterSetName = 'ShowHttpsCert', Mandatory = $true)]
    [switch]$ShowHttpsCert,

    # ── ReplaceHttpsCert 模式專用 ─────────────────────────────
    [Parameter(ParameterSetName = 'ReplaceHttpsCert', Mandatory = $true)]
    [switch]$ReplaceHttpsCert,

    [Parameter(ParameterSetName = 'ReplaceHttpsCert')]
    [string]$NewCertThumbprint,

    [Parameter(ParameterSetName = 'ReplaceHttpsCert')]
    [string]$NewHostname,

    [Parameter(ParameterSetName = 'ReplaceHttpsCert')]
    [switch]$RemoveOldCert
)
$ErrorActionPreference = 'Stop'

# ── Helpers ─────────────────────────────────────────────────────────────────
$Script:HttpsListenerSelector = @{ Address = '*'; Transport = 'HTTPS' }

function Write-Step  { param($Msg) Write-Host $Msg -ForegroundColor Cyan }
function Write-Done  { param($Msg) Write-Host "`n$Msg" -ForegroundColor Green }
function Write-Hint  { param($Msg) Write-Host $Msg -ForegroundColor Yellow }
function Write-Field { param($Label, $Value) Write-Host ("  {0,-10}: {1}" -f $Label, $Value) -ForegroundColor Gray }

function Get-ModulePath {
    param([Parameter(Mandatory)][string]$Name)
    Join-Path "$env:ProgramFiles\WindowsPowerShell\Modules" $Name
}

function Get-DefaultPsscPath {
    param([Parameter(Mandatory)][string]$Name)
    Join-Path (Get-ModulePath $Name) "$Name.pssc"
}

# Get-WSManInstance 在資源不存在時拋出終止性例外，包成可回傳 $null 的函式。
function Get-HttpsListener {
    try   { Get-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $Script:HttpsListenerSelector -ErrorAction Stop }
    catch { $null }
}

function New-WinRMSelfSignedCert {
    param([Parameter(Mandatory)][string]$DnsName)
    Write-Step "建立 Self-Signed Certificate（DNS=$DnsName）..."
    Write-Warning 'Self-Signed 憑證僅適用於測試環境。正式環境請使用 CA 簽發的憑證。'
    New-SelfSignedCertificate -DnsName $DnsName `
                              -CertStoreLocation 'Cert:\LocalMachine\My' `
                              -NotAfter (Get-Date).AddYears(3) `
                              -KeyUsage DigitalSignature, KeyEncipherment `
                              -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.1')
}

function Show-CertDetail {
    param([Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert)
    $san = ($Cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' }).Format($false)
    $eku = ($Cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' }).Format($false)
    $isSelfSigned = $Cert.Subject -eq $Cert.Issuer
    $now = Get-Date
    $status = if ($now -lt $Cert.NotBefore) { '尚未生效' }
              elseif ($now -gt $Cert.NotAfter) { '已過期' }
              else { "有效（剩餘 $([int]($Cert.NotAfter - $now).TotalDays) 天）" }

    Write-Field 'Subject'    $Cert.Subject
    Write-Field 'Issuer'     $Cert.Issuer
    Write-Field '指紋'       $Cert.Thumbprint
    Write-Field '生效日'     $Cert.NotBefore.ToString('yyyy-MM-dd HH:mm')
    Write-Field '到期日'     $Cert.NotAfter.ToString('yyyy-MM-dd HH:mm')
    Write-Field '狀態'       $status
    Write-Field '是否自簽'   $isSelfSigned
    if ($san) { Write-Field 'SAN'   $san }
    if ($eku) { Write-Field 'EKU'   $eku }
}

function Export-CertToFile {
    param(
        [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert,
        [Parameter(Mandatory)][string]$Path
    )
    [System.IO.File]::WriteAllBytes(
        $Path,
        $Cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    )
    Write-Field '匯出路徑'  $Path
    Write-Field '用戶端匯入' "Import-Certificate -FilePath '$Path' -CertStoreLocation Cert:\LocalMachine\Root"
}

function Write-ConnectionHint {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][int]$Port,
        [string]$EndpointName,
        [bool]$IsSelfSigned
    )
    $cfg = if ($EndpointName) { " -ConfigurationName $EndpointName" } else { '' }
    $baseCmd = "Enter-PSSession -ComputerName $ComputerName -UseSSL -Port $Port$cfg"

    if (-not $IsSelfSigned) {
        Write-Field '連線指令' $baseCmd
        return
    }

    Write-Host "`n  ※ Self-Signed 憑證 — 用戶端需擇一處理 CA 信任：" -ForegroundColor Yellow
    Write-Host '  選項 1 略過 CA 驗證（僅限內部可信環境）：'      -ForegroundColor Gray
    Write-Host "    `$so = New-PSSessionOption -SkipCACheck -SkipCNCheck" -ForegroundColor Gray
    Write-Host "    $baseCmd -SessionOption `$so"                  -ForegroundColor Gray
    Write-Host '  選項 2 在用戶端匯入憑證後直接連線（建議）：'    -ForegroundColor Gray
    Write-Host "    Import-Certificate -FilePath '<.cer 路徑>' -CertStoreLocation Cert:\LocalMachine\Root" -ForegroundColor Gray
    Write-Host "    $baseCmd" -ForegroundColor Gray
}

# ── 模式共用路徑（EnableHttps / List / ExportCert 不需 EndpointName）
if ($EndpointName) {
    $modulePath      = Get-ModulePath $EndpointName
    $defaultPsscPath = Get-DefaultPsscPath $EndpointName
}

switch ($PSCmdlet.ParameterSetName) {

    # ── Create：建立 .psrc 與 .pssc ─────────────────────────────────────
    'Create' {
        $roleCapPath = Join-Path $modulePath 'RoleCapabilities'
        if (-not (Test-Path $roleCapPath)) {
            Write-Step "Creating module directory: $roleCapPath"
            New-Item -Path $roleCapPath -ItemType Directory -Force | Out-Null
            New-ModuleManifest -Path (Join-Path $modulePath "$EndpointName.psd1") `
                               -RootModule '' -Description "JEA Module for $EndpointName" `
                               -WarningAction SilentlyContinue
        }

        $psrcFilePath = Join-Path $roleCapPath "$EndpointName.psrc"
        Write-Step "Generating Role Capability File: $psrcFilePath"
        New-PSRoleCapabilityFile -Path $psrcFilePath -VisibleCmdlets $CmdletList `
                                 -Description "Role capability for $EndpointName"

        Write-Step "Generating Session Configuration File: $defaultPsscPath"
        $roleDefinitions = @{}
        foreach ($user in $RoleUsers) { $roleDefinitions[$user] = @{ RoleCapabilities = $EndpointName } }

        if (-not (Test-Path $TranscriptPath)) { New-Item $TranscriptPath -ItemType Directory -Force | Out-Null }

        $psscParams = @{
            Path                = $defaultPsscPath
            SessionType         = 'RestrictedRemoteServer'
            RunAsVirtualAccount = $true
            RoleDefinitions     = $roleDefinitions
            TranscriptDirectory = $TranscriptPath
        }
        if ($PSBoundParameters.ContainsKey('RunAsVirtualAccountGroups')) {
            $psscParams['RunAsVirtualAccountGroups'] = $RunAsVirtualAccountGroups
        }
        New-PSSessionConfigurationFile @psscParams

        Write-Done '[Create] 完成！'
        Write-Field '.psrc' $psrcFilePath
        Write-Field '.pssc' $defaultPsscPath
        Write-Hint  '下一步：執行 -Register 以向 WinRM 註冊此 Endpoint。'
    }

    # ── Register：向 WinRM 註冊 JEA Endpoint ───────────────────────────
    'Register' {
        $resolvedPssc = if ($PSBoundParameters.ContainsKey('PsscPath')) { $PsscPath } else { $defaultPsscPath }

        if (-not (Test-Path $resolvedPssc)) {
            Write-Error "找不到 .pssc 檔案：$resolvedPssc`n請先執行 Create 模式，或透過 -PsscPath 指定正確路徑。"; return
        }

        Write-Step 'Validating session configuration file...'
        if (-not (Test-PSSessionConfigurationFile -Path $resolvedPssc)) {
            Write-Error ".pssc 檔案驗證失敗，請檢查設定內容：$resolvedPssc"; return
        }

        Write-Hint "Registering JEA Endpoint '$EndpointName'（會重新啟動 WinRM 服務）..."
        if ($PSCmdlet.ShouldProcess($EndpointName, 'Register-PSSessionConfiguration')) {
            Register-PSSessionConfiguration -Name $EndpointName -Path $resolvedPssc -Force
            Write-Done "[Register] 完成！JEA Endpoint '$EndpointName' 已就緒。"
            Write-Field '連線指令' "Enter-PSSession -ComputerName localhost -ConfigurationName $EndpointName"
        }
    }

    # ── Unregister：從 WinRM 取消 JEA Endpoint ─────────────────────────
    'Unregister' {
        if (-not (Get-PSSessionConfiguration -Name $EndpointName -ErrorAction SilentlyContinue)) {
            Write-Warning "找不到已註冊的 JEA Endpoint：$EndpointName"; return
        }
        Write-Hint "Unregistering JEA Endpoint '$EndpointName'（會重新啟動 WinRM 服務）..."
        if ($PSCmdlet.ShouldProcess($EndpointName, 'Unregister-PSSessionConfiguration')) {
            Unregister-PSSessionConfiguration -Name $EndpointName -Force
            Write-Done "[Unregister] 完成！JEA Endpoint '$EndpointName' 已移除。"
        }
    }

    # ── Delete：刪除 Module 目錄 ──────────────────────────────────────
    'Delete' {
        if (Get-PSSessionConfiguration -Name $EndpointName -ErrorAction SilentlyContinue) {
            Write-Warning "JEA Endpoint '$EndpointName' 仍處於已註冊狀態。建議先執行 -Unregister 再刪除設定檔。"
        }
        if (-not (Test-Path $modulePath)) {
            Write-Warning "找不到 Module 目錄，可能已刪除：$modulePath"; return
        }
        Write-Hint "Deleting Module directory: $modulePath"
        if ($PSCmdlet.ShouldProcess($modulePath, 'Remove-Item -Recurse')) {
            Remove-Item -Path $modulePath -Recurse -Force
            Write-Done "[Delete] 完成！已移除：$modulePath"
        }
    }

    # ── List：列出所有已註冊的 JEA Endpoint ───────────────────────────
    'List' {
        $allEndpoints = Get-PSSessionConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.Permission -and $_.Name -notmatch '^microsoft\.' }
        if (-not $allEndpoints) { Write-Hint '目前沒有已註冊的 JEA Endpoint。'; return }

        Write-Step "`n已註冊的 JEA Endpoint："
        $allEndpoints | ForEach-Object {
            [PSCustomObject]@{
                Name       = $_.Name
                Enabled    = $_.Enabled
                RunAsUser  = $_.RunAsUser
                PSScExists = Test-Path (Get-DefaultPsscPath $_.Name)
                ConfigPath = $_.ConfigFilePath
            }
        } | Format-Table -AutoSize
    }

    # ── ExportCert：找出 WinRM HTTPS 自簽憑證並匯出 ──────────
    'ExportCert' {
        $listener = Get-HttpsListener
        if (-not $listener)                { Write-Error '找不到 WinRM HTTPS Listener，請先執行 -EnableHttps。'; return }
        if (-not $listener.CertificateThumbprint) { Write-Error 'WinRM HTTPS Listener 未設定憑證指紋。'; return }

        $cert = Get-Item "Cert:\LocalMachine\My\$($listener.CertificateThumbprint)" -ErrorAction SilentlyContinue
        if (-not $cert) {
            Write-Error "在 Cert:\LocalMachine\My 找不到指紋為 '$($listener.CertificateThumbprint)' 的憑證。"; return
        }
        if ($cert.Subject -ne $cert.Issuer) {
            Write-Warning '此憑證非自簽（Issuer 與 Subject 不同），通常不需要手動匯入信任。'
            Write-Field 'Subject' $cert.Subject
            Write-Field 'Issuer'  $cert.Issuer
            return
        }

        Write-Done '[ExportCert] 完成！'
        Write-Field 'Subject' $cert.Subject
        Write-Field '指紋'    $cert.Thumbprint
        Write-Field '到期日'  $cert.NotAfter.ToString('yyyy-MM-dd')
        Export-CertToFile -Cert $cert -Path $ExportPath
    }

    # ── EnableHttps：建立 WinRM HTTPS Listener 並開放防火牆 ────────────
    'EnableHttps' {
        $existing = Get-HttpsListener
        if ($existing) {
            $existingCert = Get-Item "Cert:\LocalMachine\My\$($existing.CertificateThumbprint)" -ErrorAction SilentlyContinue

            Write-Done '[EnableHttps] WinRM HTTPS 接聽程式已存在，無需重新設定。'
            Write-Field 'Port'     $existing.Port
            Write-Field 'Hostname' $existing.Hostname
            Write-Field '憑證指紋' $existing.CertificateThumbprint
            if ($existingCert) {
                Write-Field '憑證主體' $existingCert.Subject
                Write-Field '憑證到期' $existingCert.NotAfter.ToString('yyyy-MM-dd')
            }
            if ($PSBoundParameters.ContainsKey('ExportCert') -and $existingCert) {
                Export-CertToFile -Cert $existingCert -Path $ExportCert
            }

            Write-ConnectionHint -ComputerName $existing.Hostname -Port $existing.Port `
                                 -EndpointName $EndpointName `
                                 -IsSelfSigned ($existingCert -and $existingCert.Subject -eq $existingCert.Issuer)

            Write-Hint "`n若要更換憑證或變更設定，請先手動移除現有接聽程式："
            Write-Host "  Remove-WSManInstance winrm/config/Listener -SelectorSet @{Address='*';Transport='HTTPS'}" -ForegroundColor Gray
            return
        }

        # 取得或建立憑證
        if ($PSBoundParameters.ContainsKey('CertThumbprint')) {
            $cert = Get-Item "Cert:\LocalMachine\My\$CertThumbprint" -ErrorAction Stop
            Write-Step "使用既有憑證：$($cert.Subject) [$CertThumbprint]"
        } else {
            $cert = New-WinRMSelfSignedCert -DnsName $Hostname
        }

        if (-not $PSCmdlet.ShouldProcess("WinRM HTTPS Listener (Port $Port)", 'New-WSManInstance')) { return }

        New-WSManInstance -ResourceURI 'winrm/config/Listener' `
                          -SelectorSet $Script:HttpsListenerSelector `
                          -ValueSet @{
                              Hostname              = $Hostname
                              CertificateThumbprint = $cert.Thumbprint
                              Port                  = $Port
                          } | Out-Null

        # 開放防火牆連入規則
        $fwRuleName = "WinRM-HTTPS-$Port"
        if (Get-NetFirewallRule -Name $fwRuleName -ErrorAction SilentlyContinue) {
            Write-Host "防火牆規則 '$fwRuleName' 已存在，跳過建立。" -ForegroundColor Gray
        } else {
            New-NetFirewallRule -Name $fwRuleName -DisplayName "WinRM HTTPS (Port $Port)" `
                                -Protocol TCP -LocalPort $Port -Action Allow -Direction Inbound | Out-Null
            Write-Step "已建立防火牆規則：$fwRuleName"
        }

        Write-Done '[EnableHttps] 完成！'
        Write-Field '憑證指紋' $cert.Thumbprint
        Write-Field 'Hostname' $Hostname
        Write-Field 'Port'     $Port
        if ($PSBoundParameters.ContainsKey('ExportCert')) { Export-CertToFile -Cert $cert -Path $ExportCert }

        Write-ConnectionHint -ComputerName $Hostname -Port $Port `
                             -EndpointName $EndpointName `
                             -IsSelfSigned ($cert.Subject -eq $cert.Issuer)
    }

    # ── ShowHttpsCert：顯示目前 WinRM HTTPS Listener 使用的憑證詳細資訊 ─────────────
    'ShowHttpsCert' {
        $listener = Get-HttpsListener
        if (-not $listener) {
            Write-Error '找不到 WinRM HTTPS Listener，請先執行 -EnableHttps。'; return
        }
        if (-not $listener.CertificateThumbprint) {
            Write-Error 'WinRM HTTPS Listener 未設定憑證指紋。'; return
        }

        Write-Step '[ShowHttpsCert] WinRM HTTPS Listener 設定：'
        Write-Field 'Address'  $listener.Address
        Write-Field 'Transport' $listener.Transport
        Write-Field 'Hostname'  $listener.Hostname
        Write-Field 'Port'      $listener.Port
        Write-Field 'Enabled'   $listener.Enabled

        $cert = Get-Item "Cert:\LocalMachine\My\$($listener.CertificateThumbprint)" -ErrorAction SilentlyContinue
        if (-not $cert) {
            Write-Error "在 Cert:\LocalMachine\My 找不到指紋為 '$($listener.CertificateThumbprint)' 的憑證。"; return
        }

        Write-Step "`n憑證詳細資訊："
        Show-CertDetail -Cert $cert

        Write-ConnectionHint -ComputerName $listener.Hostname -Port $listener.Port `
                             -EndpointName $null `
                             -IsSelfSigned ($cert.Subject -eq $cert.Issuer)
    }

    # ── ReplaceHttpsCert：原地替換 WinRM HTTPS Listener 使用的憑證 ───────────────
    'ReplaceHttpsCert' {
        $listener = Get-HttpsListener
        if (-not $listener) {
            Write-Error '找不到 WinRM HTTPS Listener，請先執行 -EnableHttps。'; return
        }
        $oldThumb = $listener.CertificateThumbprint
        $oldCert  = if ($oldThumb) { Get-Item "Cert:\LocalMachine\My\$oldThumb" -ErrorAction SilentlyContinue } else { $null }
        $oldIsSelfSigned = $oldCert -and ($oldCert.Subject -eq $oldCert.Issuer)

        Write-Step '[ReplaceHttpsCert] 現行憑證：'
        if ($oldCert) {
            Write-Field 'Subject' $oldCert.Subject
            Write-Field '指紋'    $oldThumb
            Write-Field '到期日'  $oldCert.NotAfter.ToString('yyyy-MM-dd')
        } else {
            Write-Field '指紋' $(if ($oldThumb) { $oldThumb } else { '(無)' })
        }

        # 取得或建立新憑證
        if ($PSBoundParameters.ContainsKey('NewCertThumbprint')) {
            if ($NewCertThumbprint -eq $oldThumb) {
                Write-Hint '新憑證指紋與現行相同，無需替換。'; return
            }
            $newCert = Get-Item "Cert:\LocalMachine\My\$NewCertThumbprint" -ErrorAction Stop
            Write-Step "`n新憑證：$($newCert.Subject) [$NewCertThumbprint]"
        } else {
            $dns = if ($PSBoundParameters.ContainsKey('NewHostname')) { $NewHostname } else { $listener.Hostname }
            if (-not $dns) { $dns = $env:COMPUTERNAME }
            $newCert = New-WinRMSelfSignedCert -DnsName $dns
            Write-Field '新憑證指紋' $newCert.Thumbprint
        }

        if (-not $PSCmdlet.ShouldProcess("WinRM HTTPS Listener (Port $($listener.Port))", "Set-WSManInstance CertificateThumbprint=$($newCert.Thumbprint)")) { return }

        Set-WSManInstance -ResourceURI 'winrm/config/Listener' `
                          -SelectorSet $Script:HttpsListenerSelector `
                          -ValueSet @{ CertificateThumbprint = $newCert.Thumbprint } | Out-Null

        # 選項刪除舊的自簽憑證
        if ($RemoveOldCert -and $oldCert) {
            if ($oldIsSelfSigned) {
                Remove-Item "Cert:\LocalMachine\My\$oldThumb" -Force
                Write-Step "已刪除舊的自簽憑證：$oldThumb"
            } else {
                Write-Hint '舊憑證非自簽（可能為 CA 簽發），為保安全不予刪除。若確認不再使用，請手動移除。'
            }
        }

        Write-Done '[ReplaceHttpsCert] 完成！'
        Write-Field '新憑證指紋' $newCert.Thumbprint
        Write-Field 'Subject'    $newCert.Subject
        Write-Field '到期日'     $newCert.NotAfter.ToString('yyyy-MM-dd')

        Write-ConnectionHint -ComputerName $listener.Hostname -Port $listener.Port `
                             -EndpointName $null `
                             -IsSelfSigned ($newCert.Subject -eq $newCert.Issuer)
    }
}
