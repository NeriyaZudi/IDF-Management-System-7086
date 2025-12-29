public with sharing class IntegrationMockService {
    
    // Simulates an HTTP response based on the endpoint name
    public static HttpResponse performMockCallout(String endpoint, String payload) {
        HttpResponse res = new HttpResponse();
        
        // Simulate BILLING API (Happy Path)
        if (endpoint.contains('Billing')) {
            res.setStatusCode(200);
            res.setBody('{"status": "success", "invoice_id": "INV-999"}');
        }
        // Simulate TEST API (Happy Path)
        else if (endpoint.contains('Test')) {
            res.setStatusCode(200);
            res.setBody('{"status": "success", "account_rating": "Hot"}');
        }  
        // Simulate DWH API (Temporary Failure - 503) Retry Logic
        else if (endpoint.contains('DWH')) {
            res.setStatusCode(503);
            res.setBody('{"error": "Service Unavailable. Database is locked."}');
        } 
        // Simulate DOC API (Permanent Failure - 400) "Fail Fast" logic
        else if (endpoint.contains('DOC')) {
            res.setStatusCode(400);
            res.setBody('{"error": "Validation Error. Missing required field."}');
        } 
        // Default Fallback
        else {
            res.setStatusCode(500);
            res.setBody('{"error": "Unknown Endpoint"}');
        }
        
        return res;
    }
}