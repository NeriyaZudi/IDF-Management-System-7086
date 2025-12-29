public with sharing class EquipmentSignatureController {

    public class SoldierOption {
        @AuraEnabled public Id value;
        @AuraEnabled public String label;
    }

    public class EquipmentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String serialNumber;
        @AuraEnabled public String type;
        @AuraEnabled public String status;
        @AuraEnabled public String currentLocation;
    }

    @AuraEnabled(cacheable=true)
    public static List<SoldierOption> getSoldiers() {
        List<SoldierOption> options = new List<SoldierOption>();

        for (Soldier__c s : [SELECT Id, Name, Personal_Number__c, Unit__c FROM Soldier__c ORDER BY Name]) {
            SoldierOption o = new SoldierOption();
            o.value = s.Id;
            String label = s.Name;
            if (String.isNotBlank(s.Personal_Number__c)) {
                label += ' (' + s.Personal_Number__c + ')';
            }
            if (String.isNotBlank(s.Unit__c)) {
                label += ' - ' + s.Unit__c;
            }
            o.label = label;
            options.add(o);
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<EquipmentRow> getAvailableEquipment() {
        List<EquipmentRow> rows = new List<EquipmentRow>();

        // תעדכן את הפילטרים לפי הערכים שיש לך ב-Status__c
        for (Equipment__c e : [
            SELECT Id, Name, Serial_Number__c, Type__c, Status__c, Current_Location__c
            FROM Equipment__c
            WHERE (Status__c != 'חייל חתום' AND Status__c != 'זוכה' AND Status__c != 'מחלקת קשר')
            ORDER BY Name
        ]) {
            EquipmentRow r = new EquipmentRow();
            r.id = e.Id;
            r.name = e.Name;
            r.serialNumber = e.Serial_Number__c;
            r.type = e.Type__c;
            r.status = e.Status__c;
            r.currentLocation = e.Current_Location__c;
            rows.add(r);
        }

        return rows;
    }

    @AuraEnabled
    public static void createSignatures(
        Id soldierId,
        List<Id> equipmentIds,
        String location,
        String comments
    ) {
        if (soldierId == null) {
            throw new AuraHandledException('חובה לבחור חייל.');
        }
        if (equipmentIds == null || equipmentIds.isEmpty()) {
            throw new AuraHandledException('חובה לבחור לפחות פריט אחד.');
        }

        Soldier__c soldier = [
            SELECT Id, Name
            FROM Soldier__c
            WHERE Id = :soldierId
            LIMIT 1
        ];

        Datetime nowDt = Datetime.now();
        String defaultLocation = String.isBlank(location)
            ? 'אצל ' + soldier.Name
            : location;

        List<Signature__c> signaturesToInsert = new List<Signature__c>();

        for (Id eqId : equipmentIds) {
            Signature__c sig = new Signature__c();
            sig.Name                       = formatSignatureName(nowDt);
            sig.Soldier__c                 = soldier.Id;
            sig.Equipment__c               = eqId;
            sig.Signed_Time__c             = nowDt;
            sig.Location_at_Signature__c   = defaultLocation;
            sig.Comments__c                = comments;
            signaturesToInsert.add(sig);
        }

        if (!signaturesToInsert.isEmpty()) {
            insert signaturesToInsert;
            // מכאן והלאה ה-Trigger על Signature__c יעדכן את Equipment__c
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
