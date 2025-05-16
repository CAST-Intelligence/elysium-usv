// Management Groups Module for Elysium USV
// This module creates the hierarchy of management groups for the USV deployment
targetScope = 'tenant'

// Parameters
@description('Prefix for all management group names - useful for creating test structures with unique names')
param mgPrefix string = ''

// Management group structure variables
var mgStructure = {
  root: {
    name: '${mgPrefix}ROOT'
    displayName: 'USV Root'
  }
  elysium: {
    name: '${mgPrefix}ELYSIUM'
    displayName: 'USV Elysium'
    parent: '${mgPrefix}ROOT'
  }
  prod: {
    name: '${mgPrefix}PROD'
    displayName: 'USV Production'
    parent: '${mgPrefix}ELYSIUM'
  }
  test: {
    name: '${mgPrefix}TEST'
    displayName: 'USV Test Environment'
    parent: '${mgPrefix}ELYSIUM'
  }
  shared: {
    name: '${mgPrefix}SHARED'
    displayName: 'USV Shared'
    parent: '${mgPrefix}ELYSIUM'
  }
  prodInfra: {
    name: '${mgPrefix}PROD-INFRA'
    displayName: 'USV Production Infrastructure'
    parent: '${mgPrefix}PROD'
  }
  prodApp: {
    name: '${mgPrefix}PROD-APP'
    displayName: 'USV Production Application'
    parent: '${mgPrefix}PROD'
  }
  prodData: {
    name: '${mgPrefix}PROD-DATA'
    displayName: 'USV Production Data'
    parent: '${mgPrefix}PROD'
  }
  testInfra: {
    name: '${mgPrefix}TEST-INFRA'
    displayName: 'USV Test Environment Infrastructure'
    parent: '${mgPrefix}TEST'
  }
  testApp: {
    name: '${mgPrefix}TEST-APP'
    displayName: 'USV Test Environment Application'
    parent: '${mgPrefix}TEST'
  }
  testData: {
    name: '${mgPrefix}TEST-DATA'
    displayName: 'USV Test Environment Data'
    parent: '${mgPrefix}TEST'
  }
  monitor: {
    name: '${mgPrefix}MONITOR'
    displayName: 'USV Monitoring'
    parent: '${mgPrefix}SHARED'
  }
  security: {
    name: '${mgPrefix}SECURITY'
    displayName: 'USV Security'
    parent: '${mgPrefix}SHARED'
  }
}

// Create the root management group
resource rootMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.root.name
  properties: {
    displayName: mgStructure.root.displayName
    details: {
      parent: {}
    }
  }
}

// Level 1 - Elysium MG
resource elysiumMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.elysium.name
  properties: {
    displayName: mgStructure.elysium.displayName
    details: {
      parent: {
        id: rootMG.id
      }
    }
  }
}

// Level 2 - Environment MGs
resource prodMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.prod.name
  properties: {
    displayName: mgStructure.prod.displayName
    details: {
      parent: {
        id: elysiumMG.id
      }
    }
  }
}

resource testMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.test.name
  properties: {
    displayName: mgStructure.test.displayName
    details: {
      parent: {
        id: elysiumMG.id
      }
    }
  }
}

resource sharedMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.shared.name
  properties: {
    displayName: mgStructure.shared.displayName
    details: {
      parent: {
        id: elysiumMG.id
      }
    }
  }
}

// Level 3 - Component MGs
resource prodInfraMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.prodInfra.name
  properties: {
    displayName: mgStructure.prodInfra.displayName
    details: {
      parent: {
        id: prodMG.id
      }
    }
  }
}

resource prodAppMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.prodApp.name
  properties: {
    displayName: mgStructure.prodApp.displayName
    details: {
      parent: {
        id: prodMG.id
      }
    }
  }
}

resource prodDataMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.prodData.name
  properties: {
    displayName: mgStructure.prodData.displayName
    details: {
      parent: {
        id: prodMG.id
      }
    }
  }
}

resource testInfraMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.testInfra.name
  properties: {
    displayName: mgStructure.testInfra.displayName
    details: {
      parent: {
        id: testMG.id
      }
    }
  }
}

resource testAppMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.testApp.name
  properties: {
    displayName: mgStructure.testApp.displayName
    details: {
      parent: {
        id: testMG.id
      }
    }
  }
}

resource testDataMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.testData.name
  properties: {
    displayName: mgStructure.testData.displayName
    details: {
      parent: {
        id: testMG.id
      }
    }
  }
}

resource monitorMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.monitor.name
  properties: {
    displayName: mgStructure.monitor.displayName
    details: {
      parent: {
        id: sharedMG.id
      }
    }
  }
}

resource securityMG 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: mgStructure.security.name
  properties: {
    displayName: mgStructure.security.displayName
    details: {
      parent: {
        id: sharedMG.id
      }
    }
  }
}

// Output all the management group resource IDs for use in other modules
output rootMgId string = rootMG.id
output elysiumMgId string = elysiumMG.id
output prodMgId string = prodMG.id
output testMgId string = testMG.id
output sharedMgId string = sharedMG.id
output prodInfraMgId string = prodInfraMG.id
output prodAppMgId string = prodAppMG.id
output prodDataMgId string = prodDataMG.id
output testInfraMgId string = testInfraMG.id
output testAppMgId string = testAppMG.id
output testDataMgId string = testDataMG.id
output monitorMgId string = monitorMG.id
output securityMgId string = securityMG.id

// Output management group names for reference
output mgNames object = mgStructure