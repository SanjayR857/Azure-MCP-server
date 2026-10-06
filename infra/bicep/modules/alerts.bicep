param containerAppName string
param actionGroupId string = ''

resource containerApp 'Microsoft.App/containerApps@2024-03-01' existing = {
  name: containerAppName
}

var actionsList = empty(actionGroupId) ? [] : [
  {
    actionGroupId: actionGroupId
  }
]

// 1. Restart / Crash alert (Severity 1 - Error)
resource restartAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${containerAppName}-alert-restarts'
  location: 'global'
  properties: {
    description: 'Triggers when Container App restarts more than 2 times in 5 minutes (possible crash loop).'
    severity: 1
    enabled: true
    scopes: [
      containerApp.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighRestartCount'
          metricName: 'RestartCount'
          operator: 'GreaterThan'
          threshold: 2
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: actionsList
  }
}

// 2. High CPU Utilization (> 80%) (Severity 2 - Warning)
resource highCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${containerAppName}-alert-cpu'
  location: 'global'
  properties: {
    description: 'Triggers when Container App CPU usage exceeds 80%.'
    severity: 2
    enabled: true
    scopes: [
      containerApp.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'CpuPercentage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: actionsList
  }
}

// 3. High Memory Utilization (> 80%) (Severity 2 - Warning)
resource highMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${containerAppName}-alert-memory'
  location: 'global'
  properties: {
    description: 'Triggers when Container App memory usage exceeds 80%.'
    severity: 2
    enabled: true
    scopes: [
      containerApp.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighMemory'
          metricName: 'MemoryPercentage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: actionsList
  }
}

// 4. High Response Time (> 2000 ms) (Severity 3 - Informational / Performance Warning)
resource highLatencyAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${containerAppName}-alert-latency'
  location: 'global'
  properties: {
    description: 'Triggers when Container App average response time exceeds 2000 milliseconds.'
    severity: 3
    enabled: true
    scopes: [
      containerApp.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighResponseTime'
          metricName: 'ResponseTime'
          operator: 'GreaterThan'
          threshold: 2000
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: actionsList
  }
}
