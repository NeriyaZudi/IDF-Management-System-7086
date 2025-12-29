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

        // 3. Dynamic Data Loading
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
            
            Set<String> fieldsToQuery = new Set<String>{'Id'}; 
            
            //Filter fields by Object Name 
            for (List<Field_Mapping__mdt> mapList : mappingMap.values()) {
                for (Field_Mapping__mdt fm : mapList) {
                    // Only add fields that belong to the current Object (e.g., Account)
                    if (fm.Object_API_Name__c == objName) {
                        fieldsToQuery.add(fm.Source_Field_API__c);
                    }
                }
            }

            System.debug('@@ Querying ' + objName + ' fields: ' + fieldsToQuery);

            String query = 'SELECT ' + String.join(new List<String>(fieldsToQuery), ',') + 
                           ' FROM ' + objName + 
                           ' WHERE Id IN :idsToQuery';
            
            try {
                List<SObject> results = Database.query(query);
                for (SObject s : results) {
                    sourceDataMap.put(s.Id, s);
                }
            } catch (Exception e) {
                System.debug('Query failed for object ' + objName + ': ' + e.getMessage());
            }
        }

        // 4. Processing Loop
        List<Integration_Request__c> requestsToUpdate = new List<Integration_Request__c>();
        List<Integration_Attempt__c> attemptsToInsert = new List<Integration_Attempt__c>();

        for (Integration_Request__c req : requests) {
            SObject sourceRecord = sourceDataMap.get(req.RecordId__c);
            
            if (sourceRecord == null) {
                req.Status__c = 'FailedPermanent';
                req.LastErrorMessage__c = 'Source Record not found or Query Failed';
                requestsToUpdate.add(req);
                continue;
            }

            Integration_System__mdt sysConfig = systemMap.get(req.SystemKey__c);
            List<Field_Mapping__mdt> mappings = mappingMap.get(req.SystemKey__c);
            
            Map<String, Object> jsonMap = new Map<String, Object>();
            if (mappings != null) {
                for (Field_Mapping__mdt fm : mappings) {
                    // --- FIX: Ensure we only map fields for this specific object ---
                    if (fm.Object_API_Name__c == req.SObjectApiName__c) {
                        try {
                            jsonMap.put(fm.Target_JSON_Key__c, sourceRecord.get(fm.Source_Field_API__c));
                        } catch(Exception e) {
                            jsonMap.put(fm.Target_JSON_Key__c, null); 
                        }
                    }
                }
            }
            String payload = JSON.serialize(jsonMap);
            
            HttpResponse res;
            try {
                // Using endpoint from config
                res = IntegrationMockService.performMockCallout(sysConfig.Endpoint__c, payload);
            } catch (Exception e) {
                res = new HttpResponse();
                res.setStatusCode(500); 
                res.setBody('System Exception: ' + e.getMessage());
            }

            Integration_Attempt__c attempt = new Integration_Attempt__c();
            attempt.Integration_Request__c = req.Id;
            attempt.Timestamp__c = System.now();
            attempt.HttpStatusCode__c = res.getStatusCode();
            attempt.ResponseSnippet__c = res.getBody().left(255);
            
            Integer code = res.getStatusCode();
            req.LastHttpStatusCode__c = code;
            req.LastErrorMessage__c = res.getBody().left(255);

            if (code >= 200 && code < 300) {
                req.Status__c = 'Success';
                attempt.IsRetryable__c = false;
            }
            else if (code == 503 || code == 504 || code == 408) {
                attempt.IsRetryable__c = true;
                if (req.AttemptCount__c < req.Max_Retries__c) {
                    req.Status__c = 'FailedTemporary';
                    req.AttemptCount__c++;
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
        for(Integration_System__mdt s : [SELECT Label, Endpoint__c, Max_Retries__c FROM Integration_System__mdt]) {
            m.put(s.Label, s);
        }
        return m;
    }

    private Map<String, List<Field_Mapping__mdt>> getFieldMappings() {
        Map<String, List<Field_Mapping__mdt>> m = new Map<String, List<Field_Mapping__mdt>>();
        
        // ADDED: Object_API_Name__c to the query
        for (Field_Mapping__mdt fm : [SELECT Integration_System__r.Label, Source_Field_API__c, Target_JSON_Key__c, Object_API_Name__c FROM Field_Mapping__mdt]) {
            String key = fm.Integration_System__r.Label;
            if (!m.containsKey(key)) m.put(key, new List<Field_Mapping__mdt>());
            m.get(key).add(fm);
        }
        return m;
    }
}