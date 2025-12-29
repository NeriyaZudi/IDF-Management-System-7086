public with sharing class IntegrationRecoveryBatch implements Database.Batchable<SObject>, Schedulable {

    // 1. START: Find the records that are ready to retry
    public Database.QueryLocator start(Database.BatchableContext BC) {
        DateTime now = System.now();
        
        // We query records that failed temporarily AND whose wait time is over
        return Database.getQueryLocator([
            SELECT Id 
            FROM Integration_Request__c 
            WHERE Status__c = 'FailedTemporary' 
            AND NextRunAt__c <= :now
        ]);
    }

    // 2. EXECUTE: Pass them back to the Worker
    public void execute(Database.BatchableContext BC, List<Integration_Request__c> scope) {
        // Collect the IDs found
        Set<Id> reqIds = new Map<Id, Integration_Request__c>(scope).keySet();
        
        if (!reqIds.isEmpty()) {
            System.debug('>>> Recovery Batch found ' + reqIds.size() + ' records. Re-enqueuing Worker.');
            
            // We reuse the exact same logic from Step 2!
            // The Worker will re-query these records, check AttemptCount, and try again.
            System.enqueueJob(new IntegrationWorker(reqIds));
        }
    }

    // 3. FINISH: Cleanup or Notification (Optional)
    public void finish(Database.BatchableContext BC) {
        System.debug('>>> Recovery Batch Finished.');
    }
    
    // 4. SCHEDULABLE: Allows this to run on a timer
    public void execute(SchedulableContext sc) {
        // We set a batch size of 50 to be safe with Callout Limits
        Database.executeBatch(new IntegrationRecoveryBatch(), 50); 
    }
}