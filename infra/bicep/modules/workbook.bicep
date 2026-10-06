param workbookDisplayName string = 'Azure MCP Server - Inspection & Observability'
param location string = resourceGroup().location
param workspaceId string

var workbookData = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 1
      content: {
        json: '# Azure Remote MCP Server - Observability and Live Inspection\nComprehensive real-time health, request analytics, resource utilization, and console log inspection for your Model Context Protocol server running on Azure Container Apps.'
      }
      name: 'title'
    }
    {
      type: 9
      content: {
        version: 'KqlParameterItem/1.0'
        parameters: [
          {
            id: 'timeRange'
            name: 'TimeRange'
            type: 4
            isRequired: true
            value: {
              durationMs: 86400000
            }
            typeSettings: {
              selectableValues: [
                {
                  durationMs: 300000
                  createdTime: '2026-10-06T00:00:00.000Z'
                  isCurrent: false
                  label: 'Last 5 minutes'
                }
                {
                  durationMs: 3600000
                  createdTime: '2026-10-06T00:00:00.000Z'
                  isCurrent: false
                  label: 'Last 1 hour'
                }
                {
                  durationMs: 14400000
                  createdTime: '2026-10-06T00:00:00.000Z'
                  isCurrent: false
                  label: 'Last 4 hours'
                }
                {
                  durationMs: 86400000
                  createdTime: '2026-10-06T00:00:00.000Z'
                  isCurrent: true
                  label: 'Last 24 hours'
                }
                {
                  durationMs: 604800000
                  createdTime: '2026-10-06T00:00:00.000Z'
                  isCurrent: false
                  label: 'Last 7 days'
                }
              ]
            }
            timeContext: {
              durationMs: 86400000
            }
          }
          {
            id: 'searchFilter'
            name: 'SearchFilter'
            type: 1
            isRequired: false
            value: ''
            description: 'Filter logs by keyword or regex'
          }
        ]
        style: 'pills'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
      name: 'parameters'
    }
    {
      type: 1
      content: {
        json: '### Request Activity and Health Summary'
      }
      name: 'metrics_header'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'ContainerAppConsoleLogs_CL\n| where TimeGenerated {TimeRange}\n| summarize TotalLogs = count(),\n    HealthChecks = countif(Log_s contains "/health"),\n    McpRequests = countif(Log_s contains "/mcp"),\n    Errors = countif(Log_s contains "ERROR" or Log_s contains "error" or Log_s contains "Exception")\n| project TotalLogs, HealthChecks, McpRequests, Errors'
        size: 4
        title: 'Activity Counters'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'tiles'
        tileSettings: {
          titleContent: {
            columnMatch: 'TotalLogs'
            formatter: 1
          }
          showBorder: true
        }
      }
      name: 'summary_tiles'
    }
    {
      type: 1
      content: {
        json: '### Request Volume Over Time'
      }
      name: 'traffic_chart_header'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'ContainerAppConsoleLogs_CL\n| where TimeGenerated {TimeRange}\n| summarize\n    HealthChecks = countif(Log_s contains "/health"),\n    McpRequests = countif(Log_s contains "/mcp"),\n    Other = countif(not(Log_s contains "/health" or Log_s contains "/mcp"))\n    by bin(TimeGenerated, 5m)'
        size: 0
        title: 'HTTP Requests by Route (5m Bins)'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'barchart'
      }
      name: 'requests_barchart'
    }
    {
      type: 1
      content: {
        json: '### Live Console Logs Inspection\nFilter and inspect container output logs in real-time.'
      }
      name: 'logs_header'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'ContainerAppConsoleLogs_CL\n| where TimeGenerated {TimeRange}\n| where isempty("{SearchFilter}") or Log_s contains "{SearchFilter}"\n| project TimeGenerated, ContainerName_s, Log_s\n| order by TimeGenerated desc\n| take 250'
        size: 0
        title: 'Recent Container Console Logs'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'table'
        gridSettings: {
          formatters: [
            {
              columnMatch: 'TimeGenerated'
              formatter: 6
            }
            {
              columnMatch: 'Log_s'
              formatter: 1
            }
          ]
        }
      }
      name: 'console_logs_grid'
    }
    {
      type: 1
      content: {
        json: '### Container System Events and Lifecycle\nContainer startup, readiness/liveness probe transitions, and replica scaling events.'
      }
      name: 'system_logs_header'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'ContainerAppSystemLogs_CL\n| where TimeGenerated {TimeRange}\n| project TimeGenerated, ContainerAppName_s, EventSource_s, Type_s, Reason_s, Log_s\n| order by TimeGenerated desc\n| take 100'
        size: 0
        title: 'System Lifecycle and Probe Events'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'table'
      }
      name: 'system_logs_grid'
    }
  ]
}

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, 'mcp-server-inspection-workbook')
  location: location
  kind: 'shared'
  properties: {
    displayName: workbookDisplayName
    category: 'workbook'
    sourceId: workspaceId
    serializedData: string(workbookData)
  }
}

output workbookId string = workbook.id
