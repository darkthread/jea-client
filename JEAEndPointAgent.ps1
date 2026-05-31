<#
.SYNOPSIS
    快速建立、註冊及取消 JEA Endpoint

.DESCRIPTION
    透過 ParameterSet 控制四種執行模式：
      Create     （預設）建立 .psrc 角色能力檔與 .pssc 工作階段設定檔，均置於 Module 目錄
      Register   使用 .pssc 檔案向 WinRM 註冊 JEA Endpoint
      Unregister 從 WinRM 取消已註冊的 JEA Endpoint
      Delete     刪除 Module 目錄（含 .psrc、.pssc），若 Endpoint 仍在註冊中會提出警告

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

.EXAMPLE
    .\JEAEndPointAgent.ps1 -EndpointName ServiceAdmin -RoleUsers "DOMAIN\User1" -CmdletList "Get-Service","Restart-Service"
    建立 ServiceAdmin 的 .psrc 與 .pssc 設定檔（存放於 Module 目錄）。

.EXAMPLE
    .\JEAEndPointAgent.ps1 -EndpointName ServiceAdmin -Register
    使用 Create 產生的 .pssc 註冊 JEA Endpoint。

.EXAMPLE
    .\JEAEndPointAgent.ps1 -EndpointName ServiceAdmin -Register -PsscPath "C:\Custom\ServiceAdmin.pssc"
    使用指定的 .pssc 路徑註冊 JEA Endpoint。

.EXAMPLE
    .\JEAEndPointAgent.ps1 -EndpointName ServiceAdmin -Unregister
    取消已註冊的 JEA Endpoint。

.EXAMPLE
    .\JEAEndPointAgent.ps1 -EndpointName ServiceAdmin -Unregister -WhatIf
    預覽取消動作，不實際執行。

.EXAMPLE
    .\JEAEndPointAgent.ps1 -EndpointName ServiceAdmin -Delete
    刪除 ServiceAdmin 的 Module 目錄（含 .psrc、.pssc）。

.EXAMPLE
    .\JEAEndPointAgent.ps1 -EndpointName ServiceAdmin -Delete -WhatIf
    預覽刪除動作，不實際執行。
#>
#Requires -RunAsAdministrator
[CmdletBinding(DefaultParameterSetName = 'Create', SupportsShouldProcess = $true)]
Param(
    # ── 所有模式共用 ────────────────────────────────────────────
    [Parameter(ParameterSetName = 'Create',      Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'Register',    Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'Unregister',  Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'Delete',      Mandatory = $true, Position = 0)]
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
    [switch]$Delete
)

# ── 各模式共用路徑（.pssc 固定放在 Module 目錄，方便 Delete 一併清除）──
$modulePath      = "$env:ProgramFiles\WindowsPowerShell\Modules\$EndpointName"
$defaultPsscPath = Join-Path $modulePath "$EndpointName.pssc"

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
                               -RootModule "" -Description "JEA Module for $EndpointName"
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
}
