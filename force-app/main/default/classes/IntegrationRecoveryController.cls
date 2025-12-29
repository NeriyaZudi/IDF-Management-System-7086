public with sharing class IntegrationRecoveryController {

    // 1. Run Immediate Batch (Manual Button)
    @AuraEnabled
    public static void runRecoveryNow() {
        Database.executeBatch(new IntegrationRecoveryBatch(), 50);
    }

    // 2. Schedule Automatic Jobs
    @AuraEnabled
    public static void scheduleAutoRecovery() {
        IntegrationRecoveryBatch p = new IntegrationRecoveryBatch();
        try {
            Integer jobCount = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Integration Retry Job%'];
            if(jobCount > 0) {
                throw new AuraHandledException('Recovery jobs are already running!');
            }
            System.schedule('Integration Retry Job 00', '0 0 * * * ?', p);
            System.schedule('Integration Retry Job 15', '0 15 * * * ?', p);
            System.schedule('Integration Retry Job 30', '0 30 * * * ?', p);
            System.schedule('Integration Retry Job 45', '0 45 * * * ?', p);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // 3. Check Status
    @AuraEnabled(cacheable=true)
    public static Boolean isRecoveryScheduled() {
        Integer jobCount = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Integration Retry Job%'];
        return jobCount > 0;
    }

    // 4. Get Recent Fail Requests 
    @AuraEnabled(cacheable=true)
    public static List<Integration_Request__c> getRecentFailedRequests() {
        return [
            SELECT Id, Name, SObjectApiName__c, SystemKey__c, LastErrorMessage__c, NextRunAt__c 
            FROM Integration_Request__c 
            WHERE Status__c = 'FailedTemporary' 
            ORDER BY LastModifiedDate DESC 
            LIMIT 3
        ];
    }
}