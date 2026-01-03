public with sharing class NightDeviceSignatureController {

    public class SoldierOption {
        @AuraEnabled public Id value;
        @AuraEnabled public String label;
    }

    @AuraEnabled(cacheable=true)
    public static List<SoldierOption> getSoldiers() {
        List<SoldierOption> options = new List<SoldierOption>();
        // אותו קוד בדיוק כמו בקונטרולר המקורי
        for (Soldier__c s : [
            SELECT Id, Name, Personal_Number__c, Class__c 
            FROM Soldier__c 
            WHERE Status__c != 'לא בשמ"פ' 
            ORDER BY Name
        ]) {
            SoldierOption o = new SoldierOption();
            o.value = s.Id;
            String label = s.Name;
            if (String.isNotBlank(s.Personal_Number__c)) label += ' (' + s.Personal_Number__c + ')';
            if (String.isNotBlank(s.Class__c)) label += ' - ' + s.Class__c;
            o.label = label;
            options.add(o);
        }
        return options;
    }

    @AuraEnabled
    public static void createSignatures(
        Id soldierId,
        List<Id> deviceIds, // שונה מ-equipmentIds
        String location,
        String comments
    ) {
        if (soldierId == null) throw new AuraHandledException('חובה לבחור חייל.');
        if (deviceIds == null || deviceIds.isEmpty()) throw new AuraHandledException('חובה לבחור לפחות פריט אחד.');

        Soldier__c soldier = [SELECT Id, Name FROM Soldier__c WHERE Id = :soldierId LIMIT 1];
        
        Datetime nowDt = Datetime.now();
        String defaultLocation = String.isBlank(location) ? 'אצל ' + soldier.Name : location;

        List<Signature__c> signaturesToInsert = new List<Signature__c>();

        for (Id devId : deviceIds) {
            Signature__c sig = new Signature__c();
            sig.Name                   = formatSignatureName(nowDt);
            sig.Soldier__c             = soldier.Id;
            sig.Night_Device__c        = devId; // כאן השינוי: הצבעה לאמצעי לילה
            sig.Equipment__c           = null;  // וודא שזה ריק
            sig.Signed_Time__c         = nowDt;
            sig.Location_at_Signature__c = defaultLocation;
            sig.Comments__c            = comments;
            signaturesToInsert.add(sig);
        }

        if (!signaturesToInsert.isEmpty()) {
            insert signaturesToInsert;
        }
    }

    private static String formatSignatureName(Datetime dt) {
        Date d = dt.date();
        String day   = String.valueOf(d.day());
        String month = String.valueOf(d.month());
        String year  = String.valueOf(d.year()).right(2);
        return 'חתימה ' + day + '-' + month + '-' + year;
    }
}