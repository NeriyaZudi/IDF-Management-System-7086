@isTest
private class IntegrationFrameworkTest {

    // 1. SETUP: Create the Trigger Data
    @testSetup
    static void setupData() {
        // We create an Opportunity that matches our Metadata Trigger Criteria
        Opportunity opp = new Opportunity(
            Name = 'Test Integration Opp',
            StageName = 'Prospecting', // Start at a non-trigger stage
            CloseDate = Date.today().addDays(30),
            Amount = 50000,
            Type = 'New Customer'
        );
        insert opp;
    }

    // 2. TEST: The Real-Time Logic (Dispatcher + Worker)
    @isTest
    static void testIntegrationEndToEnd() {
        // Fetch the data created in setup
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Simulate what the Flow does: Build the Request object
        IntegrationDispatcher.Request req = new IntegrationDispatcher.Request();
        req.recordId = opp.Id;
        req.objectApiName = 'Opportunity';
        req.triggerField = 'StageName';
        req.triggerValue = 'Contracting'; // This matches our Metadata
        
        Test.startTest();
            // A. Execute Dispatcher
            IntegrationDispatcher.dispatch(new List<IntegrationDispatcher.Request>{ req });
            
            // B. Force Async to Run (Queueable)
            // Test.stopTest() forces all asynchronous jobs to complete immediately
        Test.stopTest();
        
        // C. ASSERTIONS: Did it create the right records?
        List<Integration_Request__c> requests = [
            SELECT SystemKey__c, Status__c, NextRunAt__c, AttemptCount__c 
            FROM Integration_Request__c 
            ORDER BY SystemKey__c
        ];
        
        // We expect 3 requests (Billing, Doc, DWH) based on your metadata
        System.assertEquals(3, requests.size(), 'Should create exactly 3 integration requests');
        
        for (Integration_Request__c r : requests) {
            // Test Happy Path (Billing)
            if (r.SystemKey__c.contains('Billing')) {
                System.assertEquals('Success', r.Status__c, 'Billing should succeed (200 OK)');
            }
            // Test Permanent Failure (Doc Service)
            else if (r.SystemKey__c.contains('Document')) {
                System.assertEquals('FailedPermanent', r.Status__c, 'Doc Service should fail permanently (400 Bad Request)');
            }
            // Test Temporary Failure + Retry Logic (DWH)
            else if (r.SystemKey__c.contains('Warehouse')) {
                System.assertEquals('FailedTemporary', r.Status__c, 'DWH should fail temporarily (503)');
                System.assertNotEquals(null, r.NextRunAt__c, 'NextRunAt should be populated for retry');
                System.assertEquals(1, r.AttemptCount__c, 'Attempt count should be 1');
            }
        }
    }

    // 3. TEST: The Recovery Logic (Batch)
    @isTest
    static void testBatchRecovery() {
        // A. Manually create a "Stuck" record
        // We simulate a record that failed 10 minutes ago and is waiting
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Integration_Request__c stuckReq = new Integration_Request__c(
            SObjectApiName__c = 'Opportunity',
            RecordId__c = opp.Id,
            SystemKey__c = 'Data Warehouse', // Matches Config Key
            Status__c = 'FailedTemporary',
            AttemptCount__c = 1,
            Max_Retries__c = 3,
            NextRunAt__c = System.now().addMinutes(-10) // Scheduled in the PAST
        );
        insert stuckReq;
        
        Test.startTest();
            // B. Run the Batch
            IntegrationRecoveryBatch batch = new IntegrationRecoveryBatch();
            Database.executeBatch(batch);
        Test.stopTest();
        
        // C. ASSERTIONS
        // 1. Check that an Attempt was logged
        List<Integration_Attempt__c> attempts = [SELECT Id FROM Integration_Attempt__c WHERE Integration_Request__c = :stuckReq.Id];
        System.assertEquals(1, attempts.size(), 'Batch should have triggered a new execution attempt');
        
        // 2. Check that the Request was updated
        Integration_Request__c updatedReq = [SELECT AttemptCount__c, NextRunAt__c FROM Integration_Request__c WHERE Id = :stuckReq.Id];
        System.assertEquals(2, updatedReq.AttemptCount__c, 'Attempt count should increment to 2');
        
        // NextRunAt should be in the future now (current time + backoff)
        System.assert(updatedReq.NextRunAt__c > System.now(), 'NextRunAt should be pushed to the future');
    }
}