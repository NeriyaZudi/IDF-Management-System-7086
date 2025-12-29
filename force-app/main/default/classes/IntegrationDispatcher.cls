public with sharing class IntegrationDispatcher {

    public class Request {
        @InvocableVariable(label='Record ID' required=true)
        public Id recordId;
        
        @InvocableVariable(label='Object API Name' required=true)
        public String objectApiName;
        
        @InvocableVariable(label='Trigger Field' required=true)
        public String triggerField; 
        
        @InvocableVariable(label='Trigger Value' required=true)
        public String triggerValue; 
    }

    @InvocableMethod(label='Dispatch Integrations' description='Evaluates metadata and creates integration requests')
    public static void dispatch(List<Request> requests) {
        if (requests.isEmpty()) return;
        
        // 1. Bulkify: Collect keys to query Metadata
        Request firstReq = requests[0]; // Assuming homogeneous batch from Flow
        
        // 2. Query Metadata to find matching Systems
        List<Integration_Trigger_Config__mdt> configs = [
            SELECT Id, 
                   Integration_System__r.Label, 
                   Integration_System__r.Max_Retries__c,
                   Integration_System__r.Endpoint__c
            FROM Integration_Trigger_Config__mdt
            WHERE Object_API_Name__c = :firstReq.objectApiName
            AND Trigger_Field__c = :firstReq.triggerField
            AND Trigger_Value__c = :firstReq.triggerValue
            AND Integration_System__r.Is_Active__c = TRUE
        ];

        if (configs.isEmpty()) return;

        // 3. Create Persistent "Integration Request" Records
        List<Integration_Request__c> newRequests = new List<Integration_Request__c>();
        
        for (Request r : requests) {
            for (Integration_Trigger_Config__mdt config : configs) {
                Integration_Request__c intReq = new Integration_Request__c();
                intReq.SObjectApiName__c = r.objectApiName;
                intReq.RecordId__c = r.recordId;
                intReq.SystemKey__c = config.Integration_System__r.Label; 
                intReq.Status__c = 'Pending';
                intReq.AttemptCount__c = 0;
                intReq.Max_Retries__c = config.Integration_System__r.Max_Retries__c;  // Snapshot the max retries from config to the record
                
                newRequests.add(intReq);
            }
        }
        
        insert newRequests;
        
        // 4. Fire the Queueable Worker immediately pass the IDs of the new records 
        if (!newRequests.isEmpty()) {
            Set<Id> reqIds = new Map<Id, Integration_Request__c>(newRequests).keySet();
            System.enqueueJob(new IntegrationWorker(reqIds));
        }
    }
}