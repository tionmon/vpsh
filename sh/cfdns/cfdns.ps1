# Cloudflare DNS 记录管理脚本 (PowerShell 版本)
# 支持批量添加、删除、查询 DNS 记录
# 作者: VPS脚本合集
# 版本: 1.0

param(
    [string]$Action,
    [string]$Zone,
    [string]$File,
    [switch]$Help,
    [switch]$Config,
    [switch]$List,
    [switch]$Add,
    [switch]$Delete,
    [switch]$Batch,
    [switch]$Example
)

# 配置文件路径
$ConfigFile = "$env:USERPROFILE\.cfdns_config.json"

# 颜色函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# 显示帮助信息
function Show-Help {
    Write-ColorOutput "Cloudflare DNS 记录管理脚本 (PowerShell 版本)" "Blue"
    Write-ColorOutput "使用方法:" "Green"
    Write-Host "  .\cfdns.ps1 [选项] [参数]"
    Write-Host ""
    Write-ColorOutput "选项:" "Green"
    Write-Host "  -Help               显示帮助信息"
    Write-Host "  -Config             配置 Cloudflare API 信息"
    Write-Host "  -List               列出所有 DNS 记录"
    Write-Host "  -Add                添加 DNS 记录"
    Write-Host "  -Delete             删除 DNS 记录"
    Write-Host "  -Batch              批量操作模式"
    Write-Host "  -Zone <域名>        指定域名区域"
    Write-Host "  -File <文件>        指定批量操作文件"
    Write-Host "  -Example            创建示例文件"
    Write-Host ""
    Write-ColorOutput "示例:" "Green"
    Write-Host "  .\cfdns.ps1 -Config                          # 配置 API 信息"
    Write-Host "  .\cfdns.ps1 -List -Zone example.com         # 列出 example.com 的所有记录"
    Write-Host "  .\cfdns.ps1 -Add -Zone example.com          # 交互式添加记录"
    Write-Host "  .\cfdns.ps1 -Batch -File records.csv       # 批量添加记录"
    Write-Host "  .\cfdns.ps1 -Batch -File delete.csv        # 批量删除记录"
    Write-Host "  .\cfdns.ps1 -Delete -Zone example.com       # 交互式删除记录"
    Write-Host "  .\cfdns.ps1 -Example                        # 创建示例文件"
}

# 配置 Cloudflare API
function Set-ApiConfig {
    Write-ColorOutput "配置 Cloudflare API 信息" "Blue"
    Write-ColorOutput "请在 Cloudflare 控制台获取以下信息:" "Yellow"
    Write-Host "1. 登录 https://dash.cloudflare.com/"
    Write-Host "2. 进入 'My Profile' -> 'API Tokens'"
    Write-Host "3. 创建自定义令牌或使用全局 API 密钥"
    Write-Host ""
    
    $email = Read-Host "请输入您的 Cloudflare 邮箱"
    $apiKey = Read-Host "请输入您的 Global API Key 或 API Token" -AsSecureString
    $apiKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey))
    $defaultZone = Read-Host "请输入默认域名 (可选)"
    
    # 保存配置
    $config = @{
        CF_EMAIL = $email
        CF_API_KEY = $apiKeyPlain
        DEFAULT_ZONE = $defaultZone
    }
    
    $config | ConvertTo-Json | Out-File -FilePath $ConfigFile -Encoding UTF8
    Write-ColorOutput "配置已保存到 $ConfigFile" "Green"
}

# 加载配置
function Get-ApiConfig {
    if (-not (Test-Path $ConfigFile)) {
        Write-ColorOutput "错误: 配置文件不存在" "Red"
        Write-ColorOutput "请先运行: .\cfdns.ps1 -Config" "Yellow"
        exit 1
    }
    
    try {
        $config = Get-Content $ConfigFile | ConvertFrom-Json
        if (-not $config.CF_EMAIL -or -not $config.CF_API_KEY) {
            Write-ColorOutput "错误: 配置信息不完整" "Red"
            Write-ColorOutput "请重新配置: .\cfdns.ps1 -Config" "Yellow"
            exit 1
        }
        return $config
    }
    catch {
        Write-ColorOutput "错误: 配置文件格式错误" "Red"
        Write-ColorOutput "请重新配置: .\cfdns.ps1 -Config" "Yellow"
        exit 1
    }
}

# 获取区域 ID
function Get-ZoneId {
    param([string]$ZoneName, [object]$Config)
    
    $headers = @{
        "X-Auth-Email" = $Config.CF_EMAIL
        "X-Auth-Key" = $Config.CF_API_KEY
        "Content-Type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones?name=$ZoneName" -Headers $headers -Method Get
        
        if (-not $response.success) {
            Write-ColorOutput "错误: 无法获取区域信息" "Red"
            $response.errors | ForEach-Object { Write-Host $_.message }
            return $null
        }
        
        if ($response.result.Count -eq 0) {
            Write-ColorOutput "错误: 找不到域名 $ZoneName" "Red"
            return $null
        }
        
        return $response.result[0].id
    }
    catch {
        Write-ColorOutput "错误: API 请求失败" "Red"
        Write-Host $_.Exception.Message
        return $null
    }
}

# 列出 DNS 记录
function Get-DnsRecords {
    param([string]$ZoneName, [object]$Config)
    
    $zoneId = Get-ZoneId -ZoneName $ZoneName -Config $Config
    if (-not $zoneId) { return }
    
    Write-ColorOutput "获取 $ZoneName 的 DNS 记录..." "Blue"
    
    $headers = @{
        "X-Auth-Email" = $Config.CF_EMAIL
        "X-Auth-Key" = $Config.CF_API_KEY
        "Content-Type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records" -Headers $headers -Method Get
        
        if (-not $response.success) {
            Write-ColorOutput "错误: 无法获取 DNS 记录" "Red"
            return
        }
        
        Write-ColorOutput "DNS 记录列表:" "Green"
        Write-Host ("{0,-10} {1,-25} {2,-10} {3,-35} {4,-10}" -f "ID", "名称", "类型", "内容", "TTL")
        Write-Host ("─" * 90)
        
        $response.result | ForEach-Object {
            $shortId = $_.id.Substring(0, 8)
            Write-Host ("{0,-10} {1,-25} {2,-10} {3,-35} {4,-10}" -f $shortId, $_.name, $_.type, $_.content, $_.ttl)
        }
    }
    catch {
        Write-ColorOutput "错误: API 请求失败" "Red"
        Write-Host $_.Exception.Message
    }
}

# 添加 DNS 记录
function Add-DnsRecord {
    param(
        [string]$ZoneName,
        [string]$RecordName,
        [string]$RecordType,
        [string]$RecordContent,
        [int]$RecordTtl = 1,
        [object]$Config
    )
    
    $zoneId = Get-ZoneId -ZoneName $ZoneName -Config $Config
    if (-not $zoneId) { return $false }
    
    Write-ColorOutput "添加 DNS 记录: $RecordName.$ZoneName" "Blue"
    
    $headers = @{
        "X-Auth-Email" = $Config.CF_EMAIL
        "X-Auth-Key" = $Config.CF_API_KEY
        "Content-Type" = "application/json"
    }
    
    $body = @{
        name = $RecordName
        type = $RecordType
        content = $RecordContent
        ttl = $RecordTtl
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records" -Headers $headers -Method Post -Body $body
        
        if ($response.success) {
            Write-ColorOutput "✓ 记录添加成功" "Green"
            Write-ColorOutput "记录 ID: $($response.result.id.Substring(0, 8))" "Yellow"
            return $true
        }
        else {
            Write-ColorOutput "✗ 记录添加失败" "Red"
            $response.errors | ForEach-Object { Write-Host $_.message }
            return $false
        }
    }
    catch {
        Write-ColorOutput "✗ 记录添加失败" "Red"
        Write-Host $_.Exception.Message
        return $false
    }
}

# 交互式添加记录
function Add-DnsRecordInteractive {
    param([string]$ZoneName, [object]$Config)
    
    Write-ColorOutput "交互式添加 DNS 记录" "Blue"
    Write-ColorOutput "域名: $ZoneName" "Yellow"
    Write-Host ""
    
    $recordName = Read-Host "记录名称 (如: www, api, @)"
    
    Write-Host "记录类型:"
    Write-Host "  1) A (IPv4 地址)"
    Write-Host "  2) AAAA (IPv6 地址)"
    Write-Host "  3) CNAME (别名)"
    Write-Host "  4) MX (邮件交换)"
    Write-Host "  5) TXT (文本记录)"
    $typeChoice = Read-Host "请选择记录类型 (1-5)"
    
    $recordType = switch ($typeChoice) {
        "1" { "A" }
        "2" { "AAAA" }
        "3" { "CNAME" }
        "4" { "MX" }
        "5" { "TXT" }
        default {
            Write-ColorOutput "无效选择" "Red"
            return
        }
    }
    
    $recordContent = Read-Host "记录内容"
    $recordTtlInput = Read-Host "TTL (秒，默认为1即自动)"
    $recordTtl = if ($recordTtlInput) { [int]$recordTtlInput } else { 1 }
    
    Add-DnsRecord -ZoneName $ZoneName -RecordName $recordName -RecordType $recordType -RecordContent $recordContent -RecordTtl $recordTtl -Config $Config
}

# 批量删除记录
function Remove-DnsRecordsBatch {
    param([string]$FilePath, [string]$ZoneName, [object]$Config)
    
    if (-not (Test-Path $FilePath)) {
        Write-ColorOutput "错误: 文件 $FilePath 不存在" "Red"
        return
    }
    
    Write-ColorOutput "批量删除 DNS 记录" "Blue"
    Write-ColorOutput "文件: $FilePath" "Yellow"
    Write-ColorOutput "域名: $ZoneName" "Yellow"
    Write-Host ""
    
    $count = 0
    $success = 0
    
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        
        # 跳过注释行和空行
        if ($line -match "^#" -or $line -eq "") {
            return
        }
        
        $parts = $line -split ","
        if ($parts.Count -lt 1) {
            Write-ColorOutput "跳过无效行: $line" "Yellow"
            return
        }
        
        $identifier = $parts[0].Trim()
        $type = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "" }
        
        $count++
        
        # 如果 identifier 看起来像记录 ID (8位或更长的字母数字)
        if ($identifier -match "^[a-zA-Z0-9]{8,}$") {
            Write-ColorOutput "[$count] 删除记录 ID: $identifier" "Yellow"
            if (Remove-DnsRecord -ZoneName $ZoneName -RecordId $identifier -Config $Config) {
                $success++
            }
        }
        else {
            # 否则按名称和类型查找记录
            $typeText = if ($type) { $type } else { "所有" }
            Write-ColorOutput "[$count] 查找并删除记录: $identifier (类型: $typeText)" "Yellow"
            if (Remove-DnsRecordByName -ZoneName $ZoneName -RecordName $identifier -RecordType $type -Config $Config) {
                $success++
            }
        }
        
        Start-Sleep -Seconds 1  # 避免 API 限制
    }
    
    Write-Host ""
    Write-ColorOutput "批量删除完成" "Green"
    Write-ColorOutput "总计: $count 条记录，成功: $success 条" "Yellow"
}

# 根据名称删除记录
function Remove-DnsRecordByName {
    param([string]$ZoneName, [string]$RecordName, [string]$RecordType, [object]$Config)
    
    $zoneId = Get-ZoneId -ZoneName $ZoneName -Config $Config
    if (-not $zoneId) { return $false }
    
    # 构建查询参数
    $queryParams = "name=$RecordName"
    if ($RecordType) {
        $queryParams += "&type=$RecordType"
    }
    
    $headers = @{
        "X-Auth-Email" = $Config.CF_EMAIL
        "X-Auth-Key" = $Config.CF_API_KEY
        "Content-Type" = "application/json"
    }
    
    try {
        # 获取匹配的记录
        $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?$queryParams" -Headers $headers -Method Get
        
        if (-not $response.success) {
            Write-ColorOutput "✗ 查询记录失败" "Red"
            return $false
        }
        
        if ($response.result.Count -eq 0) {
            Write-ColorOutput "  未找到匹配的记录" "Yellow"
            return $false
        }
        
        # 删除所有匹配的记录
        $deleted = 0
        foreach ($record in $response.result) {
            if (Remove-DnsRecord -ZoneName $ZoneName -RecordId $record.id -Config $Config) {
                $deleted++
            }
            Start-Sleep -Milliseconds 500
        }
        
        if ($deleted -gt 0) {
            Write-ColorOutput "  删除了 $deleted 条匹配记录" "Green"
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        Write-ColorOutput "✗ 查询记录失败" "Red"
        Write-Host $_.Exception.Message
        return $false
    }
}

# 批量添加记录
function Add-DnsRecordsBatch {
    param([string]$FilePath, [string]$ZoneName, [object]$Config)
    
    if (-not (Test-Path $FilePath)) {
        Write-ColorOutput "错误: 文件 $FilePath 不存在" "Red"
        return
    }
    
    Write-ColorOutput "批量添加 DNS 记录" "Blue"
    Write-ColorOutput "文件: $FilePath" "Yellow"
    Write-ColorOutput "域名: $ZoneName" "Yellow"
    Write-Host ""
    
    $count = 0
    $success = 0
    
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        
        # 跳过注释行和空行
        if ($line -match "^#" -or $line -eq "") {
            return
        }
        
        $parts = $line -split ","
        if ($parts.Count -lt 3) {
            Write-ColorOutput "跳过无效行: $line" "Yellow"
            return
        }
        
        $name = $parts[0].Trim()
        $type = $parts[1].Trim()
        $content = $parts[2].Trim()
        $ttl = if ($parts.Count -gt 3 -and $parts[3].Trim()) { [int]$parts[3].Trim() } else { 1 }
        
        $count++
        Write-ColorOutput "[$count] 添加记录: $name.$ZoneName" "Yellow"
        
        if (Add-DnsRecord -ZoneName $ZoneName -RecordName $name -RecordType $type -RecordContent $content -RecordTtl $ttl -Config $Config) {
            $success++
        }
        
        Start-Sleep -Seconds 1  # 避免 API 限制
    }
    
    Write-Host ""
    Write-ColorOutput "批量操作完成" "Green"
    Write-ColorOutput "总计: $count 条记录，成功: $success 条" "Yellow"
}

# 删除 DNS 记录
function Remove-DnsRecord {
    param([string]$ZoneName, [string]$RecordId, [object]$Config)
    
    $zoneId = Get-ZoneId -ZoneName $ZoneName -Config $Config
    if (-not $zoneId) { return $false }
    
    Write-ColorOutput "删除 DNS 记录: $RecordId" "Blue"
    
    $headers = @{
        "X-Auth-Email" = $Config.CF_EMAIL
        "X-Auth-Key" = $Config.CF_API_KEY
        "Content-Type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$RecordId" -Headers $headers -Method Delete
        
        if ($response.success) {
            Write-ColorOutput "✓ 记录删除成功" "Green"
            return $true
        }
        else {
            Write-ColorOutput "✗ 记录删除失败" "Red"
            $response.errors | ForEach-Object { Write-Host $_.message }
            return $false
        }
    }
    catch {
        Write-ColorOutput "✗ 记录删除失败" "Red"
        Write-Host $_.Exception.Message
        return $false
    }
}

# 交互式删除记录
function Remove-DnsRecordInteractive {
    param([string]$ZoneName, [object]$Config)
    
    Write-ColorOutput "交互式删除 DNS 记录" "Blue"
    Write-ColorOutput "域名: $ZoneName" "Yellow"
    Write-Host ""
    
    # 先列出记录
    Get-DnsRecords -ZoneName $ZoneName -Config $Config
    Write-Host ""
    
    $recordId = Read-Host "请输入要删除的记录 ID (前8位即可)"
    
    if (-not $recordId) {
        Write-ColorOutput "记录 ID 不能为空" "Red"
        return
    }
    
    $confirm = Read-Host "确认删除记录 $recordId? (y/N)"
    if ($confirm -match "^[Yy]$") {
        Remove-DnsRecord -ZoneName $ZoneName -RecordId $recordId -Config $Config
    }
    else {
        Write-ColorOutput "操作已取消" "Yellow"
    }
}

# 创建示例文件
function New-ExampleFile {
    $exampleFile = "dns_records_example.csv"
    
    $exampleContent = @"
# DNS 记录批量添加示例文件
# 格式: 记录名称,记录类型,记录内容,TTL(可选)
# 注释行以 # 开头

# A 记录示例
www,A,192.168.1.100,3600
api,A,192.168.1.101,3600
ftp,A,192.168.1.102,3600

# CNAME 记录示例
blog,CNAME,www.example.com,3600
mail,CNAME,mail.example.com,3600

# MX 记录示例
@,MX,10 mail.example.com,3600

# TXT 记录示例
@,TXT,"v=spf1 include:_spf.example.com ~all",3600
_dmarc,TXT,"v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com",3600
"@
    
    $exampleContent | Out-File -FilePath $exampleFile -Encoding UTF8
    Write-ColorOutput "示例文件已创建: $exampleFile" "Green"
    Write-ColorOutput "请编辑此文件后使用批量添加功能" "Yellow"
}

# 主函数
function Main {
    # 显示帮助
    if ($Help) {
        Show-Help
        return
    }
    
    # 配置 API
    if ($Config) {
        Set-ApiConfig
        return
    }
    
    # 创建示例文件
    if ($Example) {
        New-ExampleFile
        return
    }
    
    # 加载配置
    $config = Get-ApiConfig
    
    # 确定域名
    if (-not $Zone) {
        if ($config.DEFAULT_ZONE) {
            $Zone = $config.DEFAULT_ZONE
            Write-ColorOutput "使用默认域名: $Zone" "Yellow"
        }
        else {
            $Zone = Read-Host "请输入域名"
        }
    }
    
    if (-not $Zone) {
        Write-ColorOutput "错误: 必须指定域名" "Red"
        return
    }
    
    # 执行操作
    if ($List) {
        Get-DnsRecords -ZoneName $Zone -Config $config
    }
    elseif ($Add) {
        Add-DnsRecordInteractive -ZoneName $Zone -Config $config
    }
    elseif ($Delete) {
        Remove-DnsRecordInteractive -ZoneName $Zone -Config $config
    }
    elseif ($Batch) {
        if (-not $File) {
            Write-ColorOutput "错误: 批量操作需要指定文件" "Red"
            Write-ColorOutput "使用方法: .\cfdns.ps1 -Batch -File <文件名> -Zone <域名>" "Yellow"
            Write-ColorOutput "批量添加: 文件格式为 name,type,content,ttl" "Yellow"
            Write-ColorOutput "批量删除: 文件格式为 record_id 或 name,type" "Yellow"
            return
        }
        
        # 根据文件内容判断是添加还是删除操作
        $firstLine = (Get-Content $File | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" } | Select-Object -First 1)
        if ($firstLine) {
            $parts = $firstLine -split ","
            # 如果有3个或更多字段，认为是添加操作；否则是删除操作
            if ($parts.Count -ge 3) {
                Write-ColorOutput "检测到批量添加操作" "Blue"
                Add-DnsRecordsBatch -FilePath $File -ZoneName $Zone -Config $config
            }
            else {
                Write-ColorOutput "检测到批量删除操作" "Blue"
                Remove-DnsRecordsBatch -FilePath $File -ZoneName $Zone -Config $config
            }
        }
        else {
            Write-ColorOutput "错误: 文件为空或只包含注释" "Red"
        }
    }
    else {
        Show-Help
    }
}

# 运行主函数
Main