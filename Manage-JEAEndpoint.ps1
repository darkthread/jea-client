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
      ExportSelfSignedCert  找到 WinRM HTTPS Listener 目前使用的自簽憑證，匯出為 .cer 供用戶端信任

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

.PARAMETER ExportSelfSignedCert
    切換至 ExportSelfSignedCert 模式，自動查詢 WinRM HTTPS Listener 目前使用的憑證，
    若確認為自簽憑證（Issuer = Subject），則匯出為 .cer 檔。

.PARAMETER ExportPath
    [ExportSelfSignedCert] 匯出 .cer 檔案的完整路徑。預設為 '$env:TEMP\WinRM-HTTPS.cer'。

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
    .\Manage-JEAEndpoint.ps1 -ExportSelfSignedCert
    將 WinRM HTTPS 目前使用的自簽憑證匯出至 %TEMP%\WinRM-HTTPS.cer。

.EXAMPLE
    .\Manage-JEAEndpoint.ps1 -ExportSelfSignedCert -ExportPath 'C:\Share\PDC-WinRM.cer'
    將自簽憑證匯出至指定路徑，方便複製到用戶端執行 Import-Certificate。
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

    # ── ExportSelfSignedCert 模式專用 ───────────────────────────────
    [Parameter(ParameterSetName = 'ExportSelfSignedCert', Mandatory = $true)]
    [switch]$ExportSelfSignedCert,

    [Parameter(ParameterSetName = 'ExportSelfSignedCert')]
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
    [string]$ExportCert
)
$PSErrorActionPreference = 'Stop'  # 全局設定錯誤動作為 Stop，確保例外能被捕獲
# ── 各模式共用路徑（.pssc 固定放在 Module 目錄，方便 Delete 一併清除）──
# EnableHttps 模式下 EndpointName 為選填，僅在有值時計算路徑
if ($EndpointName) {
    $modulePath      = "$env:ProgramFiles\WindowsPowerShell\Modules\$EndpointName"
    $defaultPsscPath = Join-Path $modulePath "$EndpointName.pssc"
}

switch ($PSCmdlet.ParameterSetName) {

    # ════════════════════════════════════════════════════════════
    # Create：建立 .psrc 與 .pssc
    # ════════════════════════════════════════════════════════════
    'Create' {
        # 1. 設定 JEA Role Capability 的模組路徑
        # JEA 需要將 Role Capability 檔案放在有效 PS Module 路徑中的 'RoleCapabilities' 資料夾內。
        $roleCapPath = Join-Path $modulePath "RoleCapabilities"

        if (-not (Test-Path $roleCapPath)) {
            Write-Host "Creating module directory: $roleCapPath" -ForegroundColor Cyan
            New-Item -Path $roleCapPath -ItemType Directory -Force | Out-Null
            # 建立一個假的 manifest，讓它能被識別為模組
            New-ModuleManifest -Path (Join-Path $modulePath "$EndpointName.psd1") `
                               -RootModule "" -Description "JEA Module for $EndpointName" `
                               -WarningAction SilentlyContinue
        }

        # 2. 建立 Role Capability 檔案 (.psrc)
        $psrcFilePath = Join-Path $roleCapPath "$EndpointName.psrc"
        Write-Host "Generating Role Capability File: $psrcFilePath" -ForegroundColor Cyan

        New-PSRoleCapabilityFile -Path $psrcFilePath `
                                 -VisibleCmdlets $CmdletList `
                                 -Description "Role capability for $EndpointName"

        # 3. 建立 Session Configuration 檔案 (.pssc)
        Write-Host "Generating Session Configuration File: $defaultPsscPath" -ForegroundColor Cyan

        $roleDefinitions = @{}
        foreach ($user in $RoleUsers) {
            $roleDefinitions[$user] = @{ RoleCapabilities = $EndpointName }
        }

        if (-not (Test-Path $TranscriptPath)) {
            New-Item $TranscriptPath -ItemType Directory -Force | Out-Null
        }

        $psscParams = @{
            Path               = $defaultPsscPath
            SessionType        = 'RestrictedRemoteServer'
            RunAsVirtualAccount = $true
            RoleDefinitions    = $roleDefinitions
            TranscriptDirectory = $TranscriptPath
        }
        if ($PSBoundParameters.ContainsKey('RunAsVirtualAccountGroups')) {
            $psscParams['RunAsVirtualAccountGroups'] = $RunAsVirtualAccountGroups
        }
        New-PSSessionConfigurationFile @psscParams

        Write-Host "`n[Create] 完成！" -ForegroundColor Green
        Write-Host "  .psrc : $psrcFilePath" -ForegroundColor Gray
        Write-Host "  .pssc : $defaultPsscPath" -ForegroundColor Gray
        Write-Host "下一步：執行 -Register 以向 WinRM 註冊此 Endpoint。" -ForegroundColor Yellow
    }

    # ════════════════════════════════════════════════════════════
    # Register：向 WinRM 註冊 JEA Endpoint
    # ════════════════════════════════════════════════════════════
    'Register' {
        $resolvedPssc = if ($PSBoundParameters.ContainsKey('PsscPath')) { $PsscPath } else { $defaultPsscPath }

        if (-not (Test-Path $resolvedPssc)) {
            Write-Error "找不到 .pssc 檔案：$resolvedPssc`n請先執行 Create 模式，或透過 -PsscPath 指定正確路徑。"
            return
        }

        # 驗證 .pssc 內容正確性（Microsoft 建議在 Register 前執行）
        Write-Host "Validating session configuration file..." -ForegroundColor Cyan
        if (-not (Test-PSSessionConfigurationFile -Path $resolvedPssc)) {
            Write-Error ".pssc 檔案驗證失敗，請檢查設定內容：$resolvedPssc"
            return
        }

        Write-Host "Registering JEA Endpoint '$EndpointName' using: $resolvedPssc" -ForegroundColor Yellow
        Write-Host "注意：這會重新啟動 WinRM 服務。" -ForegroundColor Magenta

        if ($PSCmdlet.ShouldProcess($EndpointName, 'Register-PSSessionConfiguration')) {
            Register-PSSessionConfiguration -Name $EndpointName -Path $resolvedPssc -Force
            Write-Host "`n[Register] 完成！JEA Endpoint '$EndpointName' 已就緒。" -ForegroundColor Green
            Write-Host "連線指令：Enter-PSSession -ComputerName localhost -ConfigurationName $EndpointName" -ForegroundColor Gray
        }
    }

    # ════════════════════════════════════════════════════════════
    # Unregister：從 WinRM 取消 JEA Endpoint
    # ════════════════════════════════════════════════════════════
    'Unregister' {
        $existing = Get-PSSessionConfiguration -Name $EndpointName -ErrorAction SilentlyContinue
        if (-not $existing) {
            Write-Warning "找不到已註冊的 JEA Endpoint：$EndpointName"
            return
        }

        Write-Host "Unregistering JEA Endpoint '$EndpointName'..." -ForegroundColor Yellow
        Write-Host "注意：這會重新啟動 WinRM 服務。" -ForegroundColor Magenta

        if ($PSCmdlet.ShouldProcess($EndpointName, 'Unregister-PSSessionConfiguration')) {
            Unregister-PSSessionConfiguration -Name $EndpointName -Force
            Write-Host "`n[Unregister] 完成！JEA Endpoint '$EndpointName' 已移除。" -ForegroundColor Green
        }
    }

    # ════════════════════════════════════════════════════════════
    # Delete：刪除 Module 目錄（含 .psrc、.pssc、.psd1）
    # ════════════════════════════════════════════════════════════
    'Delete' {
        # 若 Endpoint 仍在 WinRM 中註冊，提出警告（不中斷流程）
        $registered = Get-PSSessionConfiguration -Name $EndpointName -ErrorAction SilentlyContinue
        if ($registered) {
            Write-Warning "JEA Endpoint '$EndpointName' 仍處於已註冊狀態。建議先執行 -Unregister 再刪除設定檔。"
        }

        if (-not (Test-Path $modulePath)) {
            Write-Warning "找不到 Module 目錄，可能已刪除：$modulePath"
            return
        }

        Write-Host "Deleting Module directory: $modulePath" -ForegroundColor Yellow

        if ($PSCmdlet.ShouldProcess($modulePath, 'Remove-Item -Recurse')) {
            Remove-Item -Path $modulePath -Recurse -Force
            Write-Host "`n[Delete] 完成！已移除：$modulePath" -ForegroundColor Green
        }
    }

    # ════════════════════════════════════════════════════════════
    # List：列出所有已註冊的 JEA Endpoint
    # ════════════════════════════════════════════════════════════
    'List' {
        $allEndpoints = Get-PSSessionConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.Permission -and $_.Name -notmatch '^microsoft\.' }

        if (-not $allEndpoints) {
            Write-Host '目前沒有已註冊的 JEA Endpoint。' -ForegroundColor Yellow
            return
        }

        Write-Host "`n已註冊的 JEA Endpoint：" -ForegroundColor Cyan
        $allEndpoints | ForEach-Object {
            $psscFile = Join-Path "$env:ProgramFiles\WindowsPowerShell\Modules\$($_.Name)" "$($_.Name).pssc"
            [PSCustomObject]@{
                Name        = $_.Name
                Enabled     = $_.Enabled
                RunAsUser   = $_.RunAsUser
                PSScExists  = (Test-Path $psscFile)
                ConfigPath  = $_.ConfigFilePath
            }
        } | Format-Table -AutoSize
    }

    # ════════════════════════════════════════════════════════════
    # ExportSelfSignedCert：找出 WinRM HTTPS 自簽憑證並匯出
    # ════════════════════════════════════════════════════════════
    'ExportSelfSignedCert' {
        # 1. 查詢 WinRM HTTPS Listener 取得憑證指紋
        $listenerSelector = @{ Address = '*'; Transport = 'HTTPS' }
        $listener = $null
        try {
            $listener = Get-WSManInstance -ResourceURI 'winrm/config/Listener' `
                                          -SelectorSet $listenerSelector -ErrorAction Stop
        } catch {
            Write-Error "找不到 WinRM HTTPS Listener，請先執行 -EnableHttps。"
            return
        }

        $thumbprint = $listener.CertificateThumbprint
        if (-not $thumbprint) {
            Write-Error "WinRM HTTPS Listener 未設定憑證指紋。"
            return
        }

        # 2. 取得憑證物件
        $cert = Get-Item "Cert:\LocalMachine\My\$thumbprint" -ErrorAction SilentlyContinue
        if (-not $cert) {
            Write-Error "在 Cert:\LocalMachine\My 找不到指紋為 '$thumbprint' 的憑證。"
            return
        }

        # 3. 確認為自簽（Issuer = Subject）
        if ($cert.Subject -ne $cert.Issuer) {
            Write-Warning "此憑證非自簽（Issuer 與 Subject 不同），通常不需要手動匯入信任。"
            Write-Host "  Subject : $($cert.Subject)" -ForegroundColor Gray
            Write-Host "  Issuer  : $($cert.Issuer)"  -ForegroundColor Gray
            return
        }

        # 4. 匯出 DER 編碼的 .cer（不含私鑰）
        $certBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        [System.IO.File]::WriteAllBytes($ExportPath, $certBytes)

        Write-Host "`n[ExportSelfSignedCert] 完成！" -ForegroundColor Green
        Write-Host "  Subject   : $($cert.Subject)"                          -ForegroundColor Gray
        Write-Host "  指紋      : $thumbprint"                                -ForegroundColor Gray
        Write-Host "  到期日    : $($cert.NotAfter.ToString('yyyy-MM-dd'))"   -ForegroundColor Gray
        Write-Host "  匯出路徑  : $ExportPath"                                -ForegroundColor Cyan
        Write-Host "`n  於用戶端以系統管理員執行以下指令匯入信任：" -ForegroundColor Yellow
        Write-Host "    Import-Certificate -FilePath '$ExportPath' -CertStoreLocation Cert:\LocalMachine\Root" -ForegroundColor Gray
    }

    # ════════════════════════════════════════════════════════════
    # EnableHttps：建立 WinRM HTTPS Listener 並開放防火牆
    # ════════════════════════════════════════════════════════════
    'EnableHttps' {
        # 0. 檢查是否已存在 WinRM HTTPS Listener
        # Get-WSManInstance 在找不到資源時拋出終止性例外，必須以 try/catch 攔截
        $listenerSelector = @{ Address = '*'; Transport = 'HTTPS' }
        $existing = $null
        try {
            $existing = Get-WSManInstance -ResourceURI 'winrm/config/Listener' `
                                          -SelectorSet $listenerSelector -ErrorAction Stop
        } catch {
            # 錯誤碼 2150858752 = 資源不存在，屬預期情況，忽略即可
            $existing = $null
        }
        if ($existing) {
            # 取得已使用的憑證資訊
            $existingCert = Get-Item "Cert:\LocalMachine\My\$($existing.CertificateThumbprint)" -ErrorAction SilentlyContinue

            Write-Host "`n[EnableHttps] WinRM HTTPS 接聽程式已存在，無需重新設定。" -ForegroundColor Green
            Write-Host "  Port      : $($existing.Port)" -ForegroundColor Gray
            Write-Host "  Hostname  : $($existing.Hostname)" -ForegroundColor Gray
            Write-Host "  憑證指紋  : $($existing.CertificateThumbprint)" -ForegroundColor Gray
            if ($existingCert) {
                Write-Host "  憑證主體  : $($existingCert.Subject)" -ForegroundColor Gray
                Write-Host "  憑證到期  : $($existingCert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
            }
            # 匯出憑證（如有指定 -ExportCert）
            if ($PSBoundParameters.ContainsKey('ExportCert') -and $existingCert) {
                $certBytes = $existingCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
                [System.IO.File]::WriteAllBytes($ExportCert, $certBytes)
                Write-Host "  憑證已匯出 : $ExportCert" -ForegroundColor Cyan
                Write-Host "  用戶端匯入 : Import-Certificate -FilePath '$ExportCert' -CertStoreLocation Cert:\LocalMachine\Root" -ForegroundColor Gray
            }
            # 連線提示（Self-Signed 憑證需特別處理 CA 信任）
            $isSelfSigned = $existingCert -and ($existingCert.Subject -eq $existingCert.Issuer)
            if ($isSelfSigned) {
                Write-Host "`n  ※ Self-Signed 憑證 — 用戶端需擇一處理 CA 信任：" -ForegroundColor Yellow
                Write-Host "  選項 1 略過 CA 驗證（僅限內部可信環境）：" -ForegroundColor Gray
                Write-Host "    `$so = New-PSSessionOption -SkipCACheck -SkipCNCheck" -ForegroundColor Gray
                if ($EndpointName) {
                    Write-Host "    Enter-PSSession -ComputerName $($existing.Hostname) -UseSSL -Port $($existing.Port) -ConfigurationName $EndpointName -SessionOption `$so" -ForegroundColor Gray
                } else {
                    Write-Host "    Enter-PSSession -ComputerName $($existing.Hostname) -UseSSL -Port $($existing.Port) -SessionOption `$so" -ForegroundColor Gray
                }
                Write-Host "  選項 2 在用戶端匯入憑證後直接連線（建議）：" -ForegroundColor Gray
                Write-Host "    Import-Certificate -FilePath '<.cer 路徑>' -CertStoreLocation Cert:\LocalMachine\Root" -ForegroundColor Gray
                if ($EndpointName) {
                    Write-Host "    Enter-PSSession -ComputerName $($existing.Hostname) -UseSSL -Port $($existing.Port) -ConfigurationName $EndpointName" -ForegroundColor Gray
                } else {
                    Write-Host "    Enter-PSSession -ComputerName $($existing.Hostname) -UseSSL -Port $($existing.Port)" -ForegroundColor Gray
                }
            } else {
                if ($EndpointName) {
                    Write-Host "  連線指令  : Enter-PSSession -ComputerName $($existing.Hostname) -UseSSL -Port $($existing.Port) -ConfigurationName $EndpointName" -ForegroundColor Gray
                } else {
                    Write-Host "  連線指令  : Enter-PSSession -ComputerName $($existing.Hostname) -UseSSL -Port $($existing.Port)" -ForegroundColor Gray
                }
            }
            Write-Host "`n若要更換憑證或變更設定，請先手動移除現有接聽程式：" -ForegroundColor Yellow
            Write-Host "  Remove-WSManInstance winrm/config/Listener -SelectorSet @{Address='*';Transport='HTTPS'}" -ForegroundColor Gray
            return
        }

        # 1. 取得或建立憑證
        if ($PSBoundParameters.ContainsKey('CertThumbprint')) {
            $cert = Get-Item "Cert:\LocalMachine\My\$CertThumbprint" -ErrorAction Stop
            Write-Host "使用既有憑證：$($cert.Subject) [$CertThumbprint]" -ForegroundColor Cyan
        } else {
            Write-Host "建立 Self-Signed Certificate（DNS=$Hostname）..." -ForegroundColor Cyan
            Write-Warning "Self-Signed 憑證僅適用於測試環境。正式環境請使用 CA 簽發的憑證並指定 -CertThumbprint。"
            $cert = New-SelfSignedCertificate -DnsName $Hostname `
                                              -CertStoreLocation 'Cert:\LocalMachine\My' `
                                              -NotAfter (Get-Date).AddYears(3) `
                                              -KeyUsage DigitalSignature, KeyEncipherment `
                                              -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.1')
        }

        # 2. 建立 WinRM HTTPS Listener
        if ($PSCmdlet.ShouldProcess("WinRM HTTPS Listener (Port $Port)", 'New-WSManInstance')) {
            New-WSManInstance -ResourceURI 'winrm/config/Listener' `
                              -SelectorSet $listenerSelector `
                              -ValueSet @{
                                  Hostname             = $Hostname
                                  CertificateThumbprint = $cert.Thumbprint
                                  Port                 = $Port
                              } | Out-Null

            # 3. 開放防火牆連入規則
            $fwRuleName = "WinRM-HTTPS-$Port"
            if (Get-NetFirewallRule -Name $fwRuleName -ErrorAction SilentlyContinue) {
                Write-Host "防火牆規則 '$fwRuleName' 已存在，跳過建立。" -ForegroundColor Gray
            } else {
                New-NetFirewallRule -Name $fwRuleName `
                                    -DisplayName "WinRM HTTPS (Port $Port)" `
                                    -Protocol TCP -LocalPort $Port `
                                    -Action Allow -Direction Inbound | Out-Null
                Write-Host "已建立防火牆規則：$fwRuleName" -ForegroundColor Cyan
            }

            Write-Host "`n[EnableHttps] 完成！" -ForegroundColor Green
            Write-Host "  憑證指紋 : $($cert.Thumbprint)" -ForegroundColor Gray
            Write-Host "  Hostname  : $Hostname" -ForegroundColor Gray
            Write-Host "  Port      : $Port" -ForegroundColor Gray
            # 匯出憑證（如有指定 -ExportCert）
            if ($PSBoundParameters.ContainsKey('ExportCert')) {
                $certBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
                [System.IO.File]::WriteAllBytes($ExportCert, $certBytes)
                Write-Host "  憑證已匯出 : $ExportCert" -ForegroundColor Cyan
                Write-Host "  用戶端匯入 : Import-Certificate -FilePath '$ExportCert' -CertStoreLocation Cert:\LocalMachine\Root" -ForegroundColor Gray
            }
            # 連線提示（Self-Signed 憑證需特別處理 CA 信任）
            $isSelfSigned = ($cert.Subject -eq $cert.Issuer)
            if ($isSelfSigned) {
                Write-Host "`n  ※ Self-Signed 憑證 — 用戶端需擇一處理 CA 信任：" -ForegroundColor Yellow
                Write-Host "  選項 1 略過 CA 驗證（僅限內部可信環境）：" -ForegroundColor Gray
                Write-Host "    `$so = New-PSSessionOption -SkipCACheck -SkipCNCheck" -ForegroundColor Gray
                if ($EndpointName) {
                    Write-Host "    Enter-PSSession -ComputerName $Hostname -UseSSL -Port $Port -ConfigurationName $EndpointName -SessionOption `$so" -ForegroundColor Gray
                } else {
                    Write-Host "    Enter-PSSession -ComputerName $Hostname -UseSSL -Port $Port -SessionOption `$so" -ForegroundColor Gray
                }
                Write-Host "  選項 2 在用戶端匯入憑證後直接連線（建議）：" -ForegroundColor Gray
                Write-Host "    # 先以 -ExportCert 匯出，再於用戶端以系統管理員執行：" -ForegroundColor Gray
                Write-Host "    Import-Certificate -FilePath '<.cer 路徑>' -CertStoreLocation Cert:\LocalMachine\Root" -ForegroundColor Gray
                if ($EndpointName) {
                    Write-Host "    Enter-PSSession -ComputerName $Hostname -UseSSL -Port $Port -ConfigurationName $EndpointName" -ForegroundColor Gray
                } else {
                    Write-Host "    Enter-PSSession -ComputerName $Hostname -UseSSL -Port $Port" -ForegroundColor Gray
                }
            } else {
                if ($EndpointName) {
                    Write-Host "  連線指令  : Enter-PSSession -ComputerName $Hostname -UseSSL -Port $Port -ConfigurationName $EndpointName" -ForegroundColor Gray
                } else {
                    Write-Host "  連線指令  : Enter-PSSession -ComputerName $Hostname -UseSSL -Port $Port" -ForegroundColor Gray
                }
            }
        }
    }
}
