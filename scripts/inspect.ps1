<#
.SYNOPSIS
    Real-time Inspection tool for Azure Remote MCP Server in Azure Cloud.
.DESCRIPTION
    Inspects container app status, health probe latency, Application Insights telemetry,
    Log Analytics console logs, and Azure Monitor alerts.
.PARAMETER ResourceGroup
    The Azure resource group (default: 'azure-mcp-server').
.PARAMETER ContainerAppName
    The Container App name (default: 'azure-mcp-server').
.PARAMETER WorkspaceName
    The Log Analytics workspace name (default: 'azure-mcp-law').
.PARAMETER AppInsightsName
    The Application Insights name (default: 'azure-mcp-insights').
.PARAMETER Tail
    Stream live container console logs in real time.
.PARAMETER ErrorsOnly
    Filter Log Analytics queries for errors only.
.PARAMETER LogLines
    Number of recent log lines to display (default: 20).
#>
param(
    [string]$ResourceGroup = "azure-mcp-server",
    [string]$ContainerAppName = "azure-mcp-server",
    [string]$WorkspaceName = "azure-mcp-law",
    [string]$AppInsightsName = "azure-mcp-insights",
    [switch]$Tail,
    [switch]$ErrorsOnly,
    [int]$LogLines = 20
)

$ErrorActionPreference = "Continue"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " AZURE REMOTE MCP SERVER - LIVE INSPECTION" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Azure Authentication Check
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "[!] Not authenticated to Azure. Run 'az login' first." -ForegroundColor Red
    exit 1
}
Write-Host "Subscription:  $($account.name) ($($account.id))" -ForegroundColor Gray
Write-Host "Resource Group:$ResourceGroup" -ForegroundColor Gray
Write-Host "Timestamp:     $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC'))" -ForegroundColor Gray
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Gray

# 2. Container App Inspection
Write-Host "`n[1/6] Container App Status:" -ForegroundColor Yellow
$appJson = az containerapp show --name $ContainerAppName --resource-group $ResourceGroup -o json 2>$null
if (-not $appJson) {
    Write-Host "[-] Container App '$ContainerAppName' not found in '$ResourceGroup'." -ForegroundColor Red
    exit 1
}
$app = $appJson | ConvertFrom-Json

$fqdn = $app.properties.configuration.ingress.fqdn
$provState = $app.properties.provisioningState
$runningStatus = $app.properties.runningStatus
$image = $app.properties.template.containers[0].image
$latestRevision = $app.properties.latestRevisionName

$provColor = if ($provState -eq 'Succeeded') {'Green'} else {'Red'}
$runColor = if ($runningStatus -eq 'Running') {'Green'} else {'Yellow'}

Write-Host "  * Provisioning State: " -NoNewline; Write-Host $provState -ForegroundColor $provColor
Write-Host "  * Running Status:     " -NoNewline; Write-Host $runningStatus -ForegroundColor $runColor
Write-Host "  * Current Image:      $image" -ForegroundColor Gray
Write-Host "  * Latest Revision:    $latestRevision" -ForegroundColor Gray
Write-Host "  * Ingress FQDN:       https://$fqdn" -ForegroundColor Cyan

# Replica Inspection
$replicasJson = az containerapp replica list --name $ContainerAppName --resource-group $ResourceGroup -o json 2>$null
if ($replicasJson) {
    $replicas = $replicasJson | ConvertFrom-Json
    Write-Host "  * Active Replicas:    $($replicas.Count)" -ForegroundColor Green
    foreach ($rep in $replicas) {
        Write-Host "    - Replica: $($rep.name) (Containers: $($rep.properties.containers.Count))" -ForegroundColor DarkGray
    }
}

# 3. Live Health Probe Inspection
Write-Host "`n[2/6] Health Check Probe (HTTP GET /health):" -ForegroundColor Yellow
$healthUrl = "https://$fqdn/health"
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $response = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 10 -Method Get
    $stopwatch.Stop()
    $latencyMs = $stopwatch.ElapsedMilliseconds
    Write-Host "  * URL:      $healthUrl" -ForegroundColor Gray
    Write-Host "  * Status:   200 OK (Latency: ${latencyMs}ms)" -ForegroundColor Green
    Write-Host "  * Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
    $stopwatch.Stop()
    Write-Host "  * URL:      $healthUrl" -ForegroundColor Gray
    Write-Host "  * Status:   FAILED ($($_.Exception.Message)) [${stopwatch.ElapsedMilliseconds}ms]" -ForegroundColor Red
}

# 4. Application Insights Inspection
Write-Host "`n[3/6] Application Insights Telemetry:" -ForegroundColor Yellow
$aiJson = az monitor app-insights component show --app $AppInsightsName --resource-group $ResourceGroup -o json 2>$null
if ($aiJson) {
    $ai = $aiJson | ConvertFrom-Json
    Write-Host "  * Component Name: $($ai.name)" -ForegroundColor Green
    Write-Host "  * Ingestion Mode: $($ai.ingestionMode)" -ForegroundColor Gray
    Write-Host "  * Location:       $($ai.location)" -ForegroundColor Gray
    Write-Host "  * Live Metrics:   https://portal.azure.com/#@/resource$($ai.id)/quickPulse" -ForegroundColor Cyan
    Write-Host "  * Failures Blade: https://portal.azure.com/#@/resource$($ai.id)/failures" -ForegroundColor Cyan
} else {
    Write-Host "  [-] Application Insights '$AppInsightsName' not found." -ForegroundColor Yellow
    Write-Host "      Run .\scripts\deploy-monitoring.ps1 to provision it." -ForegroundColor Gray
}

# 5. Azure Monitor Alerts Status
Write-Host "`n[4/6] Azure Monitor Metric Alerts:" -ForegroundColor Yellow
$alertsJson = az monitor metrics alert list --resource-group $ResourceGroup -o json 2>$null
if ($alertsJson) {
    $alerts = $alertsJson | ConvertFrom-Json
    if ($alerts.Count -eq 0) {
        Write-Host "  [-] No metric alerts configured yet." -ForegroundColor Yellow
    } else {
        foreach ($a in $alerts) {
            $statusColor = if ($a.enabled) {'Green'} else {'DarkGray'}
            Write-Host "  * Alert: $($a.name)" -ForegroundColor White
            Write-Host "    - Severity: $($a.severity) | Enabled: $($a.enabled) | Window: $($a.windowSize)" -ForegroundColor $statusColor
        }
    }
} else {
    Write-Host "  [-] Could not query metric alerts." -ForegroundColor DarkGray
}

# 6. Log Analytics Inspection (Console & System Logs)
Write-Host "`n[5/6] Log Analytics Inspection ($WorkspaceName):" -ForegroundColor Yellow
$workspaceJson = az monitor log-analytics workspace show --workspace-name $WorkspaceName --resource-group $ResourceGroup -o json 2>$null
if ($workspaceJson) {
    $workspace = $workspaceJson | ConvertFrom-Json
    $wsId = $workspace.customerId

    $kqlFilter = ""
    if ($ErrorsOnly) {
        $kqlFilter = '| where Log_s contains "ERROR" or Log_s contains "Error" or Log_s contains "Exception"'
    }

    $kqlQuery = "ContainerAppConsoleLogs_CL | project TimeGenerated, Log_s | order by TimeGenerated desc | take $LogLines"
    
    $logsJson = az monitor log-analytics query -w $wsId --analytics-query $kqlQuery -o json 2>$null
    if ($logsJson) {
        $logs = $logsJson | ConvertFrom-Json
        if (-not $logs -or $logs.Count -eq 0) {
            Write-Host "  No matching logs found in Log Analytics." -ForegroundColor DarkGray
        } else {
            Write-Host "  Showing latest $($logs.Count) log entries from Log Analytics:" -ForegroundColor Gray
            foreach ($entry in $logs) {
                $time = $entry.TimeGenerated
                $msg = $entry.Log_s
                $color = if ($msg -match "ERROR|error|Exception") { 'Red' } elseif ($msg -match "WARN|warning") { 'Yellow' } else { 'White' }
                Write-Host "  [$time] $msg" -ForegroundColor $color
            }
        }
    }
} else {
    Write-Host "  [-] Log Analytics workspace '$WorkspaceName' not accessible." -ForegroundColor DarkGray
}

# 7. Inspection Workbook / Portal Dashboard Link
Write-Host "`n[6/6] Inspection Dashboard & Workbooks:" -ForegroundColor Yellow
$workbooksJson = az resource list --resource-group $ResourceGroup --resource-type "Microsoft.Insights/workbooks" -o json 2>$null
if ($workbooksJson) {
    $workbooks = $workbooksJson | ConvertFrom-Json
    foreach ($wb in $workbooks) {
        $title = if ($wb.tags.'hidden-title') { $wb.tags.'hidden-title' } else { $wb.name }
        Write-Host "  * Workbook: $title" -ForegroundColor Green
        Write-Host "    Portal Link: https://portal.azure.com/#@/resource$($wb.id)" -ForegroundColor Cyan
    }
}

# Optional Live Streaming
if ($Tail) {
    Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Streaming Live Container Logs (Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    az containerapp logs show --name $ContainerAppName --resource-group $ResourceGroup --follow
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host " Inspection complete. To stream live logs in real time: .\scripts\inspect.ps1 -Tail" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor Cyan
