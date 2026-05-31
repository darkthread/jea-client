# == JEA Server Side ==

# 啟用 WinRM HTTPS
.\Manage-JEAEndpoint.ps1 -EnableHttps

# 建立 NetworkOps 的 JEA Endpoint，允許指定 Cmdlet 並指派給 UTOPIA\jeffrey 使用者帳號
.\Manage-JEAEndpoint.ps1 -EndpointName NetworkOps `
    -RoleUsers "UTOPIA\jeffrey" `
    -CmdletList "Get-NetAdapter", "Get-NetIPAddress" `
    -RunAsVirtualAccountGroups "Network Configuration Operators"

# 註冊 NetworkOps 的 JEA Endpoint
.\Manage-JEAEndpoint.ps1 -EndpointName NetworkOps -Register

# == JEA Client Side ==
Enter-PSSession -ComputerName PDC `
    -ConfigurationName NetworkOps `
    -Credential (Get-Credential UTOPIA\jeffrey) `
    -UseSSL `
    -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)