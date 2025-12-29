public with sharing class IntegrationRecoveryBatch implements Database.Batchable<SObject>, Schedulable {

    // 1. START: Find the records that are ready to retry
    public Database.QueryLocator start(Database.BatchableContext BC) {
        DateTime now = System.now();
        
        return Database.getQueryLocator([
            SELECT Id 
            FROM Integration_Request__c 
            WHERE Status__c = 'FailedTemporary' 
            AND NextRunAt__c <= :now
        ]);
    }

    // 2. EXECUTE: Pass them back to the Worker
    public void execute(Database.BatchableContext BC, List<Integration_Request__c> scope) {
        Set<Id> reqIds = new Map<Id, Integration_Request__c>(scope).keySet();
        
        if (!reqIds.isEmpty()) {
            System.debug('>>> Recovery Batch found ' + reqIds.size() + ' records. Re-enqueuing Worker.');
            System.enqueueJob(new IntegrationWorker(reqIds));
        }
    }

    // 3. FINISH
    public void finish(Database.BatchableContext BC) {
        System.debug('>>> Recovery Batch Finished.');
    }
    
    // 4. SCHEDULABLE 
    public void execute(SchedulableContext sc) {
        Integer itemsToProcess = [
            SELECT COUNT() 
            FROM Integration_Request__c 
            WHERE Status__c = 'FailedTemporary' 
            AND NextRunAt__c <= :System.now()
        ];

        if (itemsToProcess > 0) {
            Database.executeBatch(new IntegrationRecoveryBatch(), 50); 
        }
    }
}