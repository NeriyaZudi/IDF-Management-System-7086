public with sharing class SignatureReturnController {
    
    @AuraEnabled(cacheable=true)
    public static Signature__c getActiveSignature(Id itemId) {
        // We check both lookup fields. Since 'itemId' is unique, it will only match one field or the other.
        List<Signature__c> sigs = [
            SELECT Id, Soldier__c, Soldier__r.Name, Signed_Time__c 
            FROM Signature__c 
            WHERE (Equipment__c = :itemId OR Night_Device__c = :itemId)
            AND Returned_Time__c = NULL
            ORDER BY Signed_Time__c DESC 
            LIMIT 1
        ];
        
        return sigs.isEmpty() ? null : sigs[0];
    }
}