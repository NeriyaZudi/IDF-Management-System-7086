public with sharing class IntegrationWorker implements Queueable, Database.AllowsCallouts {

    private Set<Id> requestIds;

    public IntegrationWorker(Set<Id> requestIds) {
        this.requestIds = requestIds;
    }

    public void execute(QueueableContext context) {
        // 1. Fetch Request Records
        List<Integration_Request__c> requests = [
            SELECT Id, RecordId__c, SObjectApiName__c, SystemKey__c, 
                   AttemptCount__c, Max_Retries__c, Status__c
            FROM Integration_Request__c
            WHERE Id IN :requestIds
        ];
        
        if(requests.isEmpty()) return;

        // 2. Load Configuration
        Map<String, Integration_System__mdt> systemMap = getSystemMetadata();
        Map<String, List<Field_Mapping__mdt>> mappingMap = getFieldMappings();

        // 3. Dynamic Data Loading (The Fix)
        // We must group IDs by Object Type to build the correct queries
        Map<String, Set<Id>> objectToRecordIds = new Map<String, Set<Id>>();
        
        for (Integration_Request__c req : requests) {
            if (!objectToRecordIds.containsKey(req.SObjectApiName__c)) {
                objectToRecordIds.put(req.SObjectApiName__c, new Set<Id>());
            }
            objectToRecordIds.get(req.SObjectApiName__c).add(req.RecordId__c);
        }

        // Master Map to hold source data: <RecordId, SObject>
        Map<Id, SObject> sourceDataMap = new Map<Id, SObject>();

        for (String objName : objectToRecordIds.keySet()) {
            Set<Id> idsToQuery = objectToRecordIds.get(objName);
            
            // Collect all fields needed for this Object across all systems
            Set<String> fieldsToQuery = new Set<String>{'Id'}; // Always query Id
            
            // Iterate all mappings to find fields belonging to this Object context
            // (In a complex org, you might filter mappings by Object, but iterating all is fine here)
            for (List<Field_Mapping__mdt> mapList : mappingMap.values()) {
                for (Field_Mapping__mdt fm : mapList) {
                    // Check if mapping is relevant? 
                    // Simplified: We query the field if it exists on the object. 
                    // To be strictly safe, we'd check the Trigger Config, 
                    // but usually, field names are unique enough or valid to query.
                    fieldsToQuery.add(fm.Source_Field_API__c);
                }
            }

            // Build Dynamic Query
            String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ',') + 
                           ' FROM ' + objName + 
                           ' WHERE Id IN :idsToQuery';
            
            // Execute and store
            try {
                List<SObject> results = Database.query(query);
                for (SObject s : results) {
                    sourceDataMap.put(s.Id, s);
                }
            } catch (Exception e) {
                System.debug('Query failed for object ' + objName + ': ' + e.getMessage());
                // In production, log this as a Permanent Failure for these requests
            }
        }

        // 4. Processing Loop (Unchanged)
        List<Integration_Request__c> requestsToUpdate = new List<Integration_Request__c>();
        List<Integration_Attempt__c> attemptsToInsert = new List<Integration_Attempt__c>();

        for (Integration_Request__c req : requests) {
            SObject sourceRecord = sourceDataMap.get(req.RecordId__c);
            
            // If query failed or record deleted, mark permanent fail
            if (sourceRecord == null) {
                req.Status__c = 'FailedPermanent';
                req.LastErrorMessage__c = 'Source Record not found or Query Failed';
                requestsToUpdate.add(req);
                continue;
            }

            Integration_System__mdt sysConfig = systemMap.get(req.SystemKey__c);
            List<Field_Mapping__mdt> mappings = mappingMap.get(req.SystemKey__c);
            
            // Build JSON Payload
            Map<String, Object> jsonMap = new Map<String, Object>();
            if (mappings != null) {
                for (Field_Mapping__mdt fm : mappings) {
                    try {
                        // Dynamically get field value
                        jsonMap.put(fm.Target_JSON_Key__c, sourceRecord.get(fm.Source_Field_API__c));
                    } catch(Exception e) {
                        jsonMap.put(fm.Target_JSON_Key__c, null); // Handle missing fields gracefully
                    }
                }
            }
            String payload = JSON.serialize(jsonMap);

            // Mock Callout
            HttpResponse res;
            try {
                res = IntegrationMockService.performMockCallout(sysConfig.Endpoint__c, payload);
            } catch (Exception e) {
                res = new HttpResponse();
                res.setStatusCode(504); 
                res.setBody('System Exception: ' + e.getMessage());
            }

            // Logging & Status Updates
            Integration_Attempt__c attempt = new Integration_Attempt__c();
            attempt.Integration_Request__c = req.Id;
            attempt.Timestamp__c = System.now();
            attempt.HttpStatusCode__c = res.getStatusCode();
            attempt.ResponseSnippet__c = res.getBody().left(255);
            
            Integer code = res.getStatusCode();
            req.LastHttpStatusCode__c = code;
            req.LastErrorMessage__c = res.getBody().left(255);

            // STATUS LOGIC
            if (code >= 200 && code < 300) {
                req.Status__c = 'Success';
                attempt.IsRetryable__c = false;
            }
            else if (code == 503 || code == 504 || code == 408) {
                attempt.IsRetryable__c = true;
                if (req.AttemptCount__c < req.Max_Retries__c) {
                    req.Status__c = 'FailedTemporary';
                    req.AttemptCount__c++;
                    // Linear Backoff: 1 min, 2 min, 3 min...
                    req.NextRunAt__c = System.now().addMinutes(1 * (Integer)req.AttemptCount__c);
                } else {
                    req.Status__c = 'FailedPermanent'; 
                }
            }
            else {
                req.Status__c = 'FailedPermanent';
                attempt.IsRetryable__c = false;
            }
            
            requestsToUpdate.add(req);
            attemptsToInsert.add(attempt);
        }
        
        if(!requestsToUpdate.isEmpty()) update requestsToUpdate;
        if(!attemptsToInsert.isEmpty()) insert attemptsToInsert;
    }
    
    // --- Helpers ---
    private Map<String, Integration_System__mdt> getSystemMetadata() {
        Map<String, Integration_System__mdt> m = new Map<String, Integration_System__mdt>();
        // Querying all systems is safe for low volumes. 
        for(Integration_System__mdt s : [SELECT Label, Endpoint__c, Max_Retries__c, Timeout_Ms__c FROM Integration_System__mdt]) {
            m.put(s.Label, s);
        }
        return m;
    }

    private Map<String, List<Field_Mapping__mdt>> getFieldMappings() {
        Map<String, List<Field_Mapping__mdt>> m = new Map<String, List<Field_Mapping__mdt>>();
        // Querying all mappings ensures we have what we need for any object type.
        for (Field_Mapping__mdt fm : [SELECT Integration_System__r.Label, Source_Field_API__c, Target_JSON_Key__c FROM Field_Mapping__mdt]) {
            String key = fm.Integration_System__r.Label;
            if (!m.containsKey(key)) m.put(key, new List<Field_Mapping__mdt>());
            m.get(key).add(fm);
        }
        return m;
    }
}