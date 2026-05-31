# Manage-JEAEndpoint.ps1 使用說明書

## 概觀

`Manage-JEAEndpoint.ps1` 是一支 PowerShell 管理腳本，用於在 Windows 伺服器上管理 **Just Enough Administration（JEA）** 工作階段設定（Session Configuration）的完整生命週期，涵蓋建立設定檔、向 WinRM 註冊、取消註冊、刪除設定檔、列出現有端點、啟用 WinRM HTTPS 接聽程式、匯出自我簽署憑證供用戶端信任，以及檢視與替換 WinRM HTTPS 所使用的憑證。

> **參考文件**：[Just Enough Administration - PowerShell | Microsoft Learn](https://learn.microsoft.com/powershell/scripting/security/remoting/jea/overview)

---

## 先決條件

| 項目 | 需求 |
|---|---|
| 作業系統 | Windows Server 2016 / Windows 10 或更新版本 |
| PowerShell 版本 | Windows PowerShell 5.1 或 PowerShell 7+ |
| 執行身分 | **系統管理員（Administrator）**，腳本已內建 `#Requires -RunAsAdministrator` |
| WinRM | 必須已啟用（`Enable-PSRemoting`） |

---

## 執行模式總覽

腳本透過參數集（Parameter Set）切換模式，每次執行只能使用一種模式。

| 模式 | 觸發參數 | 用途 |
|---|---|---|
| **Create**（預設） | 無（提供 `-EndpointName`、`-RoleUsers`、`-CmdletList`） | 建立角色能力檔（.psrc）與工作階段設定檔（.pssc） |
| **Register** | `-Register` | 向 WinRM 註冊 JEA 工作階段設定 |
| **Unregister** | `-Unregister` | 從 WinRM 取消 JEA 工作階段設定 |
| **Delete** | `-Delete` | 刪除模組目錄及其中所有 JEA 設定檔 |
| **List** | `-List` | 列出本機已註冊的所有 JEA 工作階段設定 |
| **EnableHttps** | `-EnableHttps` | 建立 WinRM HTTPS 接聽程式並設定防火牆規則 |
| **ShowHttpsCert** | `-ShowHttpsCert` | 顯示 WinRM HTTPS Listener 目前使用憑證的詳細資訊 |
| **ReplaceHttpsCert** | `-ReplaceHttpsCert` | 將 WinRM HTTPS Listener 的憑證原地替換為新憑證（不需重建 Listener） |
| **ExportCert** | `-ExportCert` | 找到 WinRM HTTPS 目前使用的自我簽署憑證並匯出為 .cer，供用戶端匯入信任 |

---

## 參數說明

### 共用參數

| 參數 | 類型 | 必填模式 | 說明 |
|---|---|---|---|
| `-EndpointName` | `String` | Create / Register / Unregister / Delete（EnableHttps 選填） | JEA 工作階段設定名稱，同時作為 PowerShell 模組名稱與角色能力名稱（三者必須一致）。在 EnableHttps 模式指定時，腳本會在完成訊息中附上包含 `-ConfigurationName` 的連線指令。 |

### Create 模式

| 參數 | 類型 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `-RoleUsers` | `String[]` | 是 | — | 指派到此角色的使用者或群組，格式為 `DOMAIN\User` 或 `COMPUTERNAME\Group`。 |
| `-CmdletList` | `String[]` | 是 | — | 允許此角色執行的 Cmdlet 或函式清單，例如 `"Get-Service","Restart-Service"`。 |
| `-TranscriptPath` | `String` | 否 | `C:\ProgramData\JEAConfiguration\Transcripts` | 工作階段文字記錄（Transcript）的存放目錄。預設路徑對標準使用者無存取權限，符合 Microsoft 安全建議。 |
| `-RunAsVirtualAccountGroups` | `String[]` | 否 | （虛擬帳號屬於本機 Administrators） | 限制虛擬帳號（Virtual Account）所屬的本機群組。指定後虛擬帳號只具備該群組的權限，可實現最小權限原則。 |

### Register 模式

| 參數 | 類型 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `-Register` | `Switch` | 是 | — | 切換至 Register 模式。 |
| `-PsscPath` | `String` | 否 | `%ProgramFiles%\WindowsPowerShell\Modules\<EndpointName>\<EndpointName>.pssc` | 指定自訂的工作階段設定檔（.pssc）路徑，省略時使用 Create 模式產生的預設路徑。 |

### Unregister 模式

| 參數 | 類型 | 必填 | 說明 |
|---|---|---|---|
| `-Unregister` | `Switch` | 是 | 切換至 Unregister 模式，從 WinRM 取消工作階段設定。此動作會重新啟動 WinRM 服務。 |

### Delete 模式

| 參數 | 類型 | 必填 | 說明 |
|---|---|---|---|
| `-Delete` | `Switch` | 是 | 切換至 Delete 模式，刪除 `%ProgramFiles%\WindowsPowerShell\Modules\<EndpointName>` 目錄及其中所有 JEA 設定檔（.psrc、.pssc、.psd1）。若工作階段設定仍處於已註冊狀態，會顯示警告（不中斷刪除流程）。 |

### List 模式

| 參數 | 類型 | 必填 | 說明 |
|---|---|---|---|
| `-List` | `Switch` | 是 | 切換至 List 模式，列出本機所有已註冊的自訂 JEA 工作階段設定（系統內建的 `microsoft.*` 端點不顯示）。 |

### EnableHttps 模式

| 參數 | 類型 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `-EnableHttps` | `Switch` | 是 | — | 切換至 EnableHttps 模式。 |
| `-CertThumbprint` | `String` | 否 | （自動建立自我簽署憑證） | 位於 `Cert:\LocalMachine\My` 的憑證指紋。**正式環境請使用 CA 簽發的憑證**並透過此參數指定，省略時腳本會自動建立僅供測試用的自我簽署憑證。 |
| `-Hostname` | `String` | 否 | `$env:COMPUTERNAME` | WinRM HTTPS 接聽程式與憑證所使用的 DNS 名稱。**跨網域情境請指定用戶端可解析的 FQDN**，否則用戶端連線時會因名稱不符而驗證失敗。 |
| `-Port` | `Int` | 否 | `5986` | WinRM HTTPS 接聽埠，有效範圍 1–65535。 |
| `-ExportCert` | `String` | 否 | — | 同步將憑證匯出為 .cer 檔案的完整路徑，供用戶端以 `Import-Certificate` 匯入信任後直接連線（不需 `-SkipCACheck`）。 |

### ExportCert 模式

| 參數 | 類型 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `-ExportCert` | `Switch` | 是 | — | 切換至 ExportCert 模式。 |
| `-ExportPath` | `String` | 否 | `%TEMP%\WinRM-HTTPS.cer` | 匯出 .cer 檔案的完整路徑。匯出的是 DER 編碼的公鑰憑證，不含私鑰，可安全傳遞給用戶端。 |

### ShowHttpsCert 模式

| 參數 | 類型 | 必填 | 說明 |
|---|---|---|---|
| `-ShowHttpsCert` | `Switch` | 是 | 切換至 ShowHttpsCert 模式，對現行 WinRM HTTPS Listener 使用的憑證進行唯讀查詢。輸出包含 Listener 的 Address、Transport、Hostname、Port、Enabled，以及憑證的 Subject、Issuer、指紋、生效日、到期日、狀態、是否自簽、SAN 與 EKU。 |

### ReplaceHttpsCert 模式

| 參數 | 類型 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `-ReplaceHttpsCert` | `Switch` | 是 | — | 切換至 ReplaceHttpsCert 模式。使用 `Set-WSManInstance` 原地更新 Listener 的 `CertificateThumbprint`，不會刪除重建 Listener，現有 TCP 連線不受影響。 |
| `-NewCertThumbprint` | `String` | 否 | （重新建立自簽憑證） | 位於 `Cert:\LocalMachine\My` 的新憑證指紋。推薦用於透過 CA 更新憑證的情境。省略時腳本會以 `-NewHostname` 重建一張 Self-Signed Certificate。 |
| `-NewHostname` | `String` | 否 | （沿用現行 Listener 的 Hostname） | 重建自簽憑證時使用的 DNS 名稱。僅在未指定 `-NewCertThumbprint` 時生效。 |
| `-RemoveOldCert` | `Switch` | 否 | — | 替換完成後刪除舊憑證。為避免誤刪 CA 簽發的憑證，**僅當舊憑證為自簽時才會實際刪除**，其餘情況顯示提示訊息並保留舊憑證。 |

---

## 一般參數支援

腳本支援 PowerShell 一般參數（Common Parameters）：

- **`-WhatIf`**：預覽動作，不實際執行（適用於 Register、Unregister、Delete、EnableHttps、ReplaceHttpsCert 模式；ShowHttpsCert 與 ExportCert 模式不適用）。
- **`-Confirm`**：執行前要求確認。
- **`-Verbose`**：顯示詳細執行訊息。

---

## 典型使用流程

### 完整部署流程

```
Step 1: Create   → 產生設定檔
Step 2: Register → 向 WinRM 註冊
Step 3: 驗證連線
```

### 完整移除流程

```
Step 1: Unregister → 從 WinRM 取消
Step 2: Delete     → 清除設定檔目錄
```

---

## 使用範例

### 範例 1：建立 JEA 工作階段設定

建立 `HelpDesk` 端點，允許服務台人員查詢及重啟服務：

```powershell
.\Manage-JEAEndpoint.ps1 -EndpointName HelpDesk `
    -RoleUsers "CORP\HelpDeskTeam" `
    -CmdletList "Get-Service", "Restart-Service", "Get-EventLog"
```

此指令會在以下路徑建立檔案：

```
C:\Program Files\WindowsPowerShell\Modules\HelpDesk\
    HelpDesk.psd1                         # 模組資訊清單
    HelpDesk.pssc                         # 工作階段設定檔
    RoleCapabilities\
        HelpDesk.psrc                     # 角色能力檔
C:\ProgramData\JEAConfiguration\Transcripts\  # 文字記錄目錄
```

---

### 範例 2：指定自訂文字記錄路徑與虛擬帳號群組

```powershell
.\Manage-JEAEndpoint.ps1 -EndpointName NetworkOps `
    -RoleUsers "CORP\NetworkTeam" `
    -CmdletList "Get-NetAdapter", "Restart-NetAdapter", "Get-NetIPAddress" `
    -TranscriptPath "D:\AuditLogs\JEA" `
    -RunAsVirtualAccountGroups "Network Configuration Operators"
```

> **說明**：`-RunAsVirtualAccountGroups` 將虛擬帳號限制在指定的本機群組，避免虛擬帳號取得完整 Administrators 權限，符合最小權限原則。

---

### 範例 3：向 WinRM 註冊工作階段設定

```powershell
.\Manage-JEAEndpoint.ps1 -EndpointName HelpDesk -Register
```

腳本會先執行 `Test-PSSessionConfigurationFile` 驗證 .pssc 內容，通過後再呼叫 `Register-PSSessionConfiguration`。**此動作會重新啟動 WinRM 服務。**

---

### 範例 4：使用自訂 .pssc 路徑註冊

```powershell
.\Manage-JEAEndpoint.ps1 -EndpointName HelpDesk -Register `
    -PsscPath "\\FileServer\JEAConfigs\HelpDesk.pssc"
```

---

### 範例 5：預覽註冊動作（不實際執行）

```powershell
.\Manage-JEAEndpoint.ps1 -EndpointName HelpDesk -Register -WhatIf
```

---

### 範例 6：驗證連線

```powershell
# 建立 JEA 工作階段
$session = New-PSSession -ComputerName localhost -ConfigurationName HelpDesk

# 確認可用的指令
Invoke-Command -Session $session -ScriptBlock { Get-Command }

# 結束工作階段
Remove-PSSession $session
```

---

### 範例 7：取消已註冊的工作階段設定

```powershell
.\Manage-JEAEndpoint.ps1 -EndpointName HelpDesk -Unregister
```

---

### 範例 8：刪除所有設定檔

```powershell
# 建議先 Unregister，再 Delete
.\Manage-JEAEndpoint.ps1 -EndpointName HelpDesk -Unregister
.\Manage-JEAEndpoint.ps1 -EndpointName HelpDesk -Delete
```

若在仍處於已註冊狀態下執行 `-Delete`，腳本會顯示警告但仍繼續刪除設定檔目錄。

---

### 範例 9：列出所有已註冊的 JEA 工作階段設定

```powershell
.\Manage-JEAEndpoint.ps1 -List
```

輸出範例：

```
已註冊的 JEA Endpoint：

Name       Enabled RunAsUser PSScExists ConfigPath
----       ------- --------- ---------- ----------
HelpDesk   True              True       C:\Program Files\WindowsPow...
NetworkOps True              True       C:\Program Files\WindowsPow...
```

| 欄位 | 說明 |
|---|---|
| `Name` | 工作階段設定名稱 |
| `Enabled` | 是否啟用 |
| `RunAsUser` | 執行身分（虛擬帳號時為空） |
| `PSScExists` | 模組目錄內的 .pssc 檔是否存在 |
| `ConfigPath` | .pssc 實際路徑 |

---

### 範例 10：啟用 WinRM HTTPS（測試環境）

```powershell
.\Manage-JEAEndpoint.ps1 -EnableHttps
```

腳本會自動建立自我簽署憑證（3 年有效期，含 Server Authentication EKU），建立 HTTPS 接聽程式，並新增防火牆規則開放連接埠 5986。

> **警告**：自我簽署憑證僅適用於測試環境，正式環境請使用 CA 簽發的憑證。

執行後，腳本會自動偵測到自我簽署憑證並顯示兩種用戶端處理方式（見範例 13）。

---

### 範例 11：啟用 WinRM HTTPS（正式環境，使用 CA 憑證）

```powershell
.\Manage-JEAEndpoint.ps1 -EnableHttps `
    -CertThumbprint 'A1B2C3D4E5F6...' `
    -Hostname 'server01.corp.contoso.com' `
    -Port 5986
```

---

### 範例 12：透過 HTTPS 連線至 JEA 端點

```powershell
Enter-PSSession -ComputerName server01.corp.contoso.com `
                -UseSSL -Port 5986 `
                -ConfigurationName HelpDesk
```

---

### 範例 13：匯出自我簽署憑證並分發給用戶端信任

**步驟 1（伺服器端）**：匯出 WinRM HTTPS 目前使用的自我簽署憑證：

```powershell
# 匯出至預設路徑（%TEMP%\WinRM-HTTPS.cer）
.\Manage-JEAEndpoint.ps1 -ExportCert

# 或指定路徑
.\Manage-JEAEndpoint.ps1 -ExportCert -ExportPath 'C:\Share\PDC-WinRM.cer'
```

**步驟 2（用戶端，以系統管理員執行）**：將 .cer 匯入信任的根憑證授權單位：

```powershell
Import-Certificate -FilePath 'C:\Share\PDC-WinRM.cer' `
                   -CertStoreLocation Cert:\LocalMachine\Root
```

**步驟 3**：之後即可正常連線，不需額外參數：

```powershell
Enter-PSSession -ComputerName PDC -UseSSL -ConfigurationName HelpDesk
```

> **補充**：若無法預先分發憑證，可在用戶端改用 `-SkipCACheck -SkipCNCheck` 略過 CA 驗證（僅限內部可信環境）：
>
> ```powershell
> $so = New-PSSessionOption -SkipCACheck -SkipCNCheck
> Enter-PSSession -ComputerName PDC -UseSSL -ConfigurationName HelpDesk -SessionOption $so
> ```

---

### 範例 14：啟用 HTTPS 時同步匯出憑證

```powershell
.\Manage-JEAEndpoint.ps1 -EnableHttps -ExportCert 'C:\Share\PDC-WinRM.cer'
```

在首次啟用 WinRM HTTPS 的同時，自動將自我簽署憑證匯出至指定路徑，省去事後再執行 `-ExportCert` 的步驟。

---

### 範例 15：跨網域連線（明確指定帳號密碼）

當用戶端與伺服器不在同一 AD 網域，或位於工作群組（Workgroup）環境時，Kerberos 無法自動通過身分驗證，必須以 `-Credential` 明確提供遠端電腦可識別的帳號。

#### 互動式輸入（推薦）

```powershell
# 彈出 Get-Credential 對話框，輸入遠端電腦的本機或網域帳號
$cred = Get-Credential -Message "請輸入 PDC 的帳號密碼" -UserName "PDC\Administrator"

# 透過 HTTP（跨網域需在用戶端先設定 TrustedHosts，見下方補充）
Enter-PSSession -ComputerName PDC `
                -ConfigurationName HelpDesk `
                -Credential $cred

# 透過 HTTPS（跨網域建議）
Enter-PSSession -ComputerName PDC `
                -UseSSL -Port 5986 `
                -ConfigurationName HelpDesk `
                -Credential $cred

# 若使用自我簽署憑證且未匯入用戶端
Enter-PSSession -ComputerName PDC -UseSSL `
                -ConfigurationName HelpDesk `
                -Credential $cred `
                -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
```

#### 搭配 New-PSSession 在批次腳本中使用

```powershell
$cred    = Get-Credential -UserName "PDC\Administrator"
$session = New-PSSession -ComputerName PDC `
                         -UseSSL -Port 5986 `
                         -ConfigurationName HelpDesk `
                         -Credential $cred

Invoke-Command -Session $session -ScriptBlock { Get-Service WinRM }
Remove-PSSession $session
```

#### 驗證方式選擇

| 情境 | 建議連線方式 | 說明 |
|---|---|---|
| 相同 AD 網域 | `-UseSSL`，默認 Kerberos | 不需 `-Credential`，以當前使用者身分驗證 |
| 跨網域 / 工作群組 + HTTPS（**推薦**） | `-UseSSL -Credential $cred` | SSL 憑證並可信賴時認證資訊受加密保護 |
| 跨網域 / 工作群組 + HTTP | `-Credential $cred` + TrustedHosts | 需在用戶端設定 `TrustedHosts`；**認證資訊未加密**，僅限可信網路 |

#### 跨網域 HTTP 連線前置：設定 TrustedHosts（仅限 HTTP）

用戶端預設不信任任何跨網域的 HTTP 遠端主機，需先以系統管理員執行：

```powershell
# 只信任特定主機（推薦）
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'PDC' -Concatenate -Force

# 查詢現有設定
Get-Item WSMan:\localhost\Client\TrustedHosts
```

> HTTPS 連線以憑證識別伺服器身分，**不需**設定 TrustedHosts。

> **安全提示**：跨網域連線請務必搭配 `-UseSSL`，確保帳號密碼在傳輸過程中受到加密保護。  
> 請勿在腳本中以明文儲存密碼；自動化場景建議搭配 Windows Credential Manager 或 Azure Key Vault。

---

### 範例 16：檢視目前 WinRM HTTPS 使用的憑證

```powershell
.\Manage-JEAEndpoint.ps1 -ShowHttpsCert
```

輸出範例：

```
[ShowHttpsCert] WinRM HTTPS Listener 設定：
  Address   : *
  Transport : HTTPS
  Hostname  : pdc.corp.contoso.com
  Port      : 5986
  Enabled   : true

憑證詳細資訊：
  Subject   : CN=pdc.corp.contoso.com
  Issuer    : CN=pdc.corp.contoso.com
  指紋      : F1E2D3C4B5A6...
  生效日    : 2025-01-01 00:00
  到期日    : 2028-01-01 00:00
  狀態      : 有效（剩餘 730 天）
  是否自簽  : True
  SAN       : DNS Name=pdc.corp.contoso.com
  EKU       : Server Authentication (1.3.6.1.5.5.7.3.1)
```

> 適合用於排查連線錯誤（例如憑證即將到期、Hostname 與用戶端不一致）時快速確認伺服器目前實際採用的憑證設定。

---

### 範例 17：更換 WinRM HTTPS 憑證

#### 17a. 改用 CA 簽發的新憑證（推薦）

```powershell
# 先將新憑證匯入 Cert:\LocalMachine\My（例如透過 Import-PfxCertificate），取得指紋後：
.\Manage-JEAEndpoint.ps1 -ReplaceHttpsCert -NewCertThumbprint 'A1B2C3D4E5F6...'
```

腳本會：

1. 顯示現行憑證資訊（Subject、指紋、到期日）。
2. 以 `Set-WSManInstance` 原地更新 Listener 的 `CertificateThumbprint`，**不會** 移除並重建 Listener，現有 TCP 連線不中斷。
3. 顯示新憑證的 Subject、指紋、到期日，並列出後續連線指令範例。

#### 17b. 重新建立 Self-Signed 憑證並替換（測試環境）

```powershell
# 沿用現行 Listener 的 Hostname 重新建立自簽憑證
.\Manage-JEAEndpoint.ps1 -ReplaceHttpsCert

# 或指定新的 DNS 名稱（例如改用 FQDN）
.\Manage-JEAEndpoint.ps1 -ReplaceHttpsCert -NewHostname 'pdc.corp.contoso.com'

# 替換完成後一併刪除舊的自簽憑證
.\Manage-JEAEndpoint.ps1 -ReplaceHttpsCert -NewHostname 'pdc.corp.contoso.com' -RemoveOldCert
```

> **提醒**：更換自簽憑證後，先前已匯入用戶端 `Cert:\LocalMachine\Root` 的舊憑證將失效，需重新執行 `-ExportCert` 並在用戶端重新匯入，或改用 `-SkipCACheck -SkipCNCheck`。

#### 17c. 預覽更換動作

```powershell
.\Manage-JEAEndpoint.ps1 -ReplaceHttpsCert -NewCertThumbprint 'A1B2C3D4E5F6...' -WhatIf
```

---

## 設定檔說明

### 角色能力檔（Role Capability File, .psrc）

- 路徑：`%ProgramFiles%\WindowsPowerShell\Modules\<EndpointName>\RoleCapabilities\<EndpointName>.psrc`
- 定義角色可執行的 Cmdlet、函式、外部命令、別名、提供者等。
- 參考：[JEA 角色能力 | Microsoft Learn](https://learn.microsoft.com/powershell/scripting/security/remoting/jea/role-capabilities)

### 工作階段設定檔（Session Configuration File, .pssc）

- 路徑：`%ProgramFiles%\WindowsPowerShell\Modules\<EndpointName>\<EndpointName>.pssc`
- 定義工作階段類型（`RestrictedRemoteServer`）、虛擬帳號設定、角色對應（Role Definitions）、文字記錄目錄等。
- 參考：[JEA 工作階段設定 | Microsoft Learn](https://learn.microsoft.com/powershell/scripting/security/remoting/jea/session-configurations)

### 模組資訊清單（Module Manifest, .psd1）

- 路徑：`%ProgramFiles%\WindowsPowerShell\Modules\<EndpointName>\<EndpointName>.psd1`
- PowerShell 模組探索（Module Discovery）的必要檔案，讓 JEA 能找到 `RoleCapabilities` 目錄。

---

## 名稱一致性說明

`-EndpointName` 的值會同時成為以下三個元素的名稱，**三者必須完全一致**，否則 JEA 的角色能力解析將會失敗：

```
WinRM 工作階段設定名稱  ←→  PowerShell 模組目錄名稱  ←→  .psrc 角色能力名稱
         ↑                           ↑                          ↑
    -EndpointName               $EndpointName               $EndpointName
```

---

## 安全性注意事項

- 腳本需以 **系統管理員** 身分執行（`#Requires -RunAsAdministrator`）。
- 文字記錄（Transcript）預設存放於 `C:\ProgramData\JEAConfiguration\Transcripts`，標準使用者無法存取，確保稽核記錄不被竄改。
- 使用 `-RunAsVirtualAccountGroups` 可將虛擬帳號限制在指定群組，避免授予不必要的完整 Administrator 權限。
- 正式環境請使用 CA 簽發的憑證啟用 WinRM HTTPS，勿使用自我簽署憑證。
- 執行 Register 與 Unregister 模式時，WinRM 服務會重新啟動，現有遠端工作階段將中斷。

---

## 疑難排解

| 問題 | 可能原因 | 解決方法 |
|---|---|---|
| `Register` 失敗，提示找不到 .pssc | 未執行 `Create` 模式，或指定了錯誤的 `-PsscPath` | 先執行 `Create` 模式，或使用 `-PsscPath` 指定正確路徑 |
| `.pssc 檔案驗證失敗` | .pssc 格式錯誤 | 手動執行 `Test-PSSessionConfigurationFile -Path <path>` 檢查錯誤 |
| 連線時提示找不到角色能力 | `EndpointName`、模組目錄名稱、.psrc 名稱不一致 | 確認三者完全相同，或刪除後重新執行 `Create` |
| WinRM HTTPS 連線被拒 | 憑證缺少 Server Authentication EKU | 使用本腳本重新建立憑證，或手動確認憑證含有 OID `1.3.6.1.5.5.7.3.1` |
| `Enter-PSSession -UseSSL` 拋出「SSL certificate is signed by an unknown certificate authority」 | 用戶端未信任伺服器的自我簽署憑證 | 在伺服器執行 `-ExportCert` 匯出憑證，再於用戶端以管理員執行 `Import-Certificate -FilePath <.cer路徑> -CertStoreLocation Cert:\LocalMachine\Root`；或暫時使用 `New-PSSessionOption -SkipCACheck -SkipCNCheck` |
| 想確認伺服器目前實際使用的 HTTPS 憑證 / 排查名稱不符 | 不確定 Listener 對應哪一張憑證 | 執行 `-ShowHttpsCert` 列出 Listener 設定與憑證的 Subject、SAN、到期日 |
| 憑證即將到期或需要從自簽換成 CA 簽發 | 需要更換 Listener 使用的憑證 | 將新憑證匯入 `Cert:\LocalMachine\My` 後，執行 `-ReplaceHttpsCert -NewCertThumbprint <新指紋>`；測試環境可直接 `-ReplaceHttpsCert` 重新建立自簽 |
| `Delete` 後端點仍可連線 | 未先執行 `Unregister`，WinRM 仍持有設定 | 執行 `-Unregister` 再執行 `-Delete` |
