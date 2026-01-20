public with sharing class SoldierSignaturesController {
    
    @AuraEnabled(cacheable=true)
    public static List<Signature__c> getSignatures(Id soldierId) {
        return [
            SELECT Id, 
                   Signed_Time__c, 
                   Location_at_Signature__c, 
                   Comments__c,
                   // שדות ציוד קשר
                   Equipment__c, 
                   Equipment__r.Name,
                   Equipment__r.Serial_Number__c, // <--- הוספנו כאן
                   // שדות אמר"ל
                   Night_Device__c, 
                   Night_Device__r.Name,
                   Night_Device__r.Serial_Number__c // <--- הוספנו כאן
            FROM Signature__c
            WHERE Soldier__c = :soldierId
            ORDER BY Signed_Time__c DESC
        ];
    }
}