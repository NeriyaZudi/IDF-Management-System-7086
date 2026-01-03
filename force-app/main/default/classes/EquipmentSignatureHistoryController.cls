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
    public static List<SignatureHistoryRow> getSignatureHistory(Id recordId) {
        if (recordId == null) {
            return new List<SignatureHistoryRow>();
        }

        // 1. זיהוי סוג האובייקט ממנו הגיעה הקריאה
        String sObjName = recordId.getSobjectType().getDescribe().getName();
        
        List<Signature__c> signatures = new List<Signature__c>();

        // 2. שאילתה דינמית בהתאם לסוג האובייקט
        if (sObjName == 'Equipment__c') {
            signatures = [
                SELECT Id, Soldier__r.Name, Soldier__r.Phone_Number__c, Soldier__r.Unit__c,
                       Signed_Time__c, Location_at_Signature__c, Comments__c
                FROM Signature__c
                WHERE Equipment__c = :recordId
                ORDER BY Signed_Time__c DESC, CreatedDate DESC
            ];
        } else if (sObjName == 'Night_Device__c') {
            signatures = [
                SELECT Id, Soldier__r.Name, Soldier__r.Phone_Number__c, Soldier__r.Unit__c,
                       Signed_Time__c, Location_at_Signature__c, Comments__c
                FROM Signature__c
                WHERE Night_Device__c = :recordId
                ORDER BY Signed_Time__c DESC, CreatedDate DESC
            ];
        } else {
            // אם זה לא אחד מהשניים, נחזיר רשימה ריקה
            return new List<SignatureHistoryRow>();
        }

        // 3. המרה למבנה הטבלה
        List<SignatureHistoryRow> result = new List<SignatureHistoryRow>();
        for (Signature__c s : signatures) {
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