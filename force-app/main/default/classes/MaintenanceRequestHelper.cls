public with sharing class MaintenanceRequestHelper {
    
    public static void updateWorkOrders(List<Case> newCaseList) {
        // Maintenance RequestのType (種別) がRepair (リペア) か Routine Maintenance (定期メンテナンス) 
        // の既存メンテナンスリクストがクローズされた際、将来の定期メンテナンスのための
        // 新しいメンテナンスリクストを作成します
        
        Set<Id> closedCaseIdSet = new Set<Id>();
        for(Case c : newCaseList){
            if(c.Status == 'Closed' && (c.Type == 'Repair' || c.Type == 'Routine Maintenance')){
                closedCaseIdSet.add(c.Id);
            }
        }

        Map<Id, Decimal> requestToCycleMap = new Map<Id, Decimal>(); 
        List<AggregateResult> groupedResults = [
            SELECT 
                Maintenance_Request__c,
                MIN(Equipment__r.Maintenance_Cycle__c) cycle
            FROM Equipment_Maintenance_Item__c
            WHERE Maintenance_Request__c IN :closedCaseIdSet
            GROUP BY Maintenance_Request__c
        ];

        for(AggregateResult ar : groupedResults){
            requestToCycleMap.put(
                (Id)ar.get('Maintenance_Request__c'),
                (Decimal)ar.get('cycle')
            );
        }

        Map<Id, List<Equipment_Maintenance_Item__c>> requestIdToEquipmentMap = new Map<Id, List<Equipment_Maintenance_Item__c>>();
        List<Case> maintenanceRequestInsert = new List<Case>();

        for(Case caseRecord : [SELECT Id, Vehicle__c, (SELECT Id, Equipment__c, Quantity__c FROM Equipment_Maintenance_Items__r) FROM Case WHERE Id IN :closedCaseIdSet]){
            requestIdToEquipmentMap.put(caseRecord.Id, caseRecord.Equipment_Maintenance_Items__r);

            Case nc = new Case();
            nc.ParentId = caseRecord.Id;
            nc.Vehicle__c = caseRecord.Vehicle__c;
            nc.Origin = 'Web';
            nc.Subject = 'Routine Maintenance';
            nc.Type = 'Routine Maintenance';
            nc.Date_Reported__c = Date.Today();
            Integer addDays = 0;

            if(requestToCycleMap.containsKey(caseRecord.Id)){
                addDays = Integer.valueOf(requestToCycleMap.get(caseRecord.Id));
            }
            nc.Date_Due__c = Date.Today().addDays(addDays);
            maintenanceRequestInsert.add(nc);
        }
        insert maintenanceRequestInsert;

        List<Equipment_Maintenance_Item__c> itemList = new List<Equipment_Maintenance_Item__c>();
        for(Case nc : maintenanceRequestInsert){
            for(Equipment_Maintenance_Item__c item : requestIdToEquipmentMap.get(nc.ParentId)){
                Equipment_Maintenance_Item__c itemClone = item.clone();
                itemClone.Maintenance_Request__c = nc.Id;
                itemList.add(itemClone);
            }
        }
        insert itemList;
    }        
    
}