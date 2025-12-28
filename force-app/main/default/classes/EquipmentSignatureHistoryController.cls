public with sharing class EquipmentSignatureHistoryController {

    public class SignatureHistoryRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String soldierName;
        @AuraEnabled public String soldierPhone;
        @AuraEnabled public String soldierUnit;
        @AuraEnabled public Datetime signedTime;
        @AuraEnabled public String locationAtSignature;
        @AuraEnabled public String comments;
    }

    @AuraEnabled(cacheable=true)
    public static List<SignatureHistoryRow> getHistoryForEquipment(Id equipmentId) {
        if (equipmentId == null) {
            throw new AuraHandledException('חסר מזהה ציוד (equipmentId).');
        }

        List<SignatureHistoryRow> result = new List<SignatureHistoryRow>();

        for (Signature__c s : [
            SELECT Id,
                   Soldier__r.Name,
                   Soldier__r.Phone_Number__c,
                   Soldier__r.Unit__c,
                   Signed_Time__c,
                   Location_at_Signature__c,
                   Comments__c
            FROM Signature__c
            WHERE Equipment__c = :equipmentId
            ORDER BY Signed_Time__c DESC, CreatedDate DESC
        ]) {
            SignatureHistoryRow row = new SignatureHistoryRow();
            row.id                  = s.Id;
            row.soldierName         = (s.Soldier__r != null ? s.Soldier__r.Name : null);
            row.soldierPhone        = (s.Soldier__r != null ? s.Soldier__r.Phone_Number__c : null);
            row.soldierUnit         = (s.Soldier__r != null ? s.Soldier__r.Unit__c : null);
            row.signedTime          = s.Signed_Time__c;
            row.locationAtSignature = s.Location_at_Signature__c;
            row.comments            = s.Comments__c;
            result.add(row);
        }

        return result;
    }
}