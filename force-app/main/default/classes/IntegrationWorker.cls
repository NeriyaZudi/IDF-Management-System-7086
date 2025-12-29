public with sharing class IntegrationWorker implements Queueable, Database.AllowsCallouts {

    private Set<Id> requestIds;

    public IntegrationWorker(Set<Id> requestIds) {
        this.requestIds = requestIds;
    }

    public void execute(QueueableContext context) {
        // 1. Fetch Scope
        List<Integration_Request__c> requests = getIntegrationRequests();
        if(requests.isEmpty()) return;

        // 2. Load Metadata Config
        Map<String, Integration_System__mdt> systemMap = getSystemMetadata();
        Map<String, List<Field_Mapping__mdt>> mappingMap = getFieldMappings();

        // 3. Load Source Data (Dynamic Query)
        Map<Id, SObject> sourceDataMap = fetchSourceRecords(requests, mappingMap);

        // 4. Process Logic
        List<Integration_Request__c> requestsToUpdate = new List<Integration_Request__c>();
        List<Integration_Attempt__c> attemptsToInsert = new List<Integration_Attempt__c>();

        for (Integration_Request__c req : requests) {
            processSingleRequest(req, sourceDataMap, systemMap, mappingMap, requestsToUpdate, attemptsToInsert);
        }

        // 5. DML Commit
        if(!requestsToUpdate.isEmpty()) update requestsToUpdate;
        if(!attemptsToInsert.isEmpty()) insert attemptsToInsert;
    }

    //              HELPER METHODS

    /**
     * Orchestrates the logic for a single request: Validation -> Payload -> Callout -> Response Handling
     */
    private void processSingleRequest(
        Integration_Request__c req, 
        Map<Id, SObject> sourceDataMap, 
        Map<String, Integration_System__mdt> systemMap, 
        Map<String, List<Field_Mapping__mdt>> mappingMap,
        List<Integration_Request__c> requestsToUpdate,
        List<Integration_Attempt__c> attemptsToInsert
    ) {
        SObject sourceRecord = sourceDataMap.get(req.RecordId__c);
        
        // 1. Validation Fail
        if (sourceRecord == null) {
            markAsPermanentFailure(req, 'Source Record not found or Query Failed');
            requestsToUpdate.add(req);
            return;
        }

        // 2. Build Payload
        Integration_System__mdt sysConfig = systemMap.get(req.SystemKey__c);
        String payload = constructPayload(sourceRecord, mappingMap.get(req.SystemKey__c), req.SObjectApiName__c);

        // 3. Execute Callout (Safe Try/Catch)
        HttpResponse res = safeCallout(sysConfig.Endpoint__c, payload);

        // 4. Handle Decision Logic (Success vs Retry vs Fail)
        Integration_Attempt__c attempt = createAttemptLog(req, res);
        handleResponseStatus(req, attempt, res.getStatusCode());

        requestsToUpdate.add(req);
        attemptsToInsert.add(attempt);
    }

    /**
     * dynamically builds the SOQL queries based on object types and mappings
     */
    private Map<Id, SObject> fetchSourceRecords(List<Integration_Request__c> requests, Map<String, List<Field_Mapping__mdt>> mappingMap) {
        Map<Id, SObject> dataMap = new Map<Id, SObject>();
        Map<String, Set<Id>> objectToIds = new Map<String, Set<Id>>();

        // Group Ids by Object
        for (Integration_Request__c req : requests) {
            if (!objectToIds.containsKey(req.SObjectApiName__c)) {
                objectToIds.put(req.SObjectApiName__c, new Set<Id>());
            }
            objectToIds.get(req.SObjectApiName__c).add(req.RecordId__c);
        }

        // Query each object type
        for (String objName : objectToIds.keySet()) {
            Set<String> fields = new Set<String>{'Id'};
            
            // Collect fields from mappings for this specific object
            for (List<Field_Mapping__mdt> mapList : mappingMap.values()) {
                for (Field_Mapping__mdt fm : mapList) {
                    if (fm.Object_API_Name__c == objName) {
                        fields.add(fm.Source_Field_API__c);
                    }
                }
            }
            
            try {
                String query = 'SELECT ' + String.join(new List<String>(fields), ',') + 
                               ' FROM ' + String.escapeSingleQuotes(objName) + 
                               ' WHERE Id IN :idsToQuery';
                Set<Id> idsToQuery = objectToIds.get(objName);
                
                for (SObject s : Database.query(query)) {
                    dataMap.put(s.Id, s);
                }
            } catch (Exception e) {
                System.debug('Query Error for ' + objName + ': ' + e.getMessage());
            }
        }
        return dataMap;
    }

    /**
     * Generates JSON Payload from mappings
     */
    private String constructPayload(SObject record, List<Field_Mapping__mdt> mappings, String objectName) {
        Map<String, Object> jsonMap = new Map<String, Object>();
        if (mappings != null) {
            for (Field_Mapping__mdt fm : mappings) {
                if (fm.Object_API_Name__c == objectName) {
                    try {
                        jsonMap.put(fm.Target_JSON_Key__c, record.get(fm.Source_Field_API__c));
                    } catch(Exception e) {
                        jsonMap.put(fm.Target_JSON_Key__c, null); 
                    }
                }
            }
        }
        System.debug('jsonMap >>' + jsonMap);
        return JSON.serialize(jsonMap);
    }

    /**
     * Performs Callout safely
     */
    private HttpResponse safeCallout(String endpoint, String payload) {
        try {
            // In a real scenario, use: Http h = new Http(); return h.send(req);
            return IntegrationMockService.performMockCallout(endpoint, payload);
        } catch (Exception e) {
            HttpResponse errRes = new HttpResponse();
            errRes.setStatusCode(500);
            errRes.setBody('System Exception: ' + e.getMessage());
            return errRes;
        }
    }

    /**
     * Determines the next status based on HTTP Code
     */
    private void handleResponseStatus(Integration_Request__c req, Integration_Attempt__c attempt, Integer code) {
        req.LastHttpStatusCode__c = code;
        
        // SUCCESS
        if (code >= 200 && code < 300) {
            req.Status__c = 'Success';
            attempt.IsRetryable__c = false;
        }
        // TEMPORARY FAILURE (Retry)
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
        // PERMANENT FAILURE
        else {
            req.Status__c = 'FailedPermanent';
            attempt.IsRetryable__c = false;
        }
    }

    // --- Utility Methods ---

    private List<Integration_Request__c> getIntegrationRequests() {
        return [
            SELECT Id, RecordId__c, SObjectApiName__c, SystemKey__c, 
                   AttemptCount__c, Max_Retries__c, Status__c
            FROM Integration_Request__c
            WHERE Id IN :requestIds
        ];
    }

    private Integration_Attempt__c createAttemptLog(Integration_Request__c req, HttpResponse res) {
        Integration_Attempt__c attempt = new Integration_Attempt__c();
        attempt.Integration_Request__c = req.Id;
        attempt.Timestamp__c = System.now();
        attempt.HttpStatusCode__c = res.getStatusCode();
        attempt.ResponseSnippet__c = res.getBody().left(255);
        req.LastErrorMessage__c = res.getBody().left(255);
        return attempt;
    }

    private void markAsPermanentFailure(Integration_Request__c req, String errorMsg) {
        req.Status__c = 'FailedPermanent';
        req.LastErrorMessage__c = errorMsg;
    }

    private Map<String, Integration_System__mdt> getSystemMetadata() {
        Map<String, Integration_System__mdt> m = new Map<String, Integration_System__mdt>();
        for(Integration_System__mdt s : [SELECT Label, Endpoint__c, Max_Retries__c FROM Integration_System__mdt]) {
            m.put(s.Label, s);
        }
        return m;
    }

    private Map<String, List<Field_Mapping__mdt>> getFieldMappings() {
        Map<String, List<Field_Mapping__mdt>> m = new Map<String, List<Field_Mapping__mdt>>();
        for (Field_Mapping__mdt fm : [SELECT Integration_System__r.Label, Source_Field_API__c, Target_JSON_Key__c, Object_API_Name__c FROM Field_Mapping__mdt]) {
            String key = fm.Integration_System__r.Label;
            if (!m.containsKey(key)) m.put(key, new List<Field_Mapping__mdt>());
            m.get(key).add(fm);
        }
        return m;
    }
}