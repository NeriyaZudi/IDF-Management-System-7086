public with sharing class SignatureTriggerHandler {

    public static void afterInsert(List<Signature__c> newList) {
        reconcileEquipment(getEquipmentIds(newList, null));
    }

    public static void afterUpdate(List<Signature__c> newList, List<Signature__c> oldList) {
        reconcileEquipment(getEquipmentIds(newList, oldList));
    }

    public static void afterDelete(List<Signature__c> oldList) {
        reconcileEquipment(getEquipmentIds(null, oldList));
    }

    public static void afterUndelete(List<Signature__c> newList) {
        reconcileEquipment(getEquipmentIds(newList, null));
    }

    // אוסף את כל ה-Equipment__c שנפגעו מהשינוי ב-Signature__c
    private static Set<Id> getEquipmentIds(List<Signature__c> newList, List<Signature__c> oldList) {
        Set<Id> equipmentIds = new Set<Id>();

        if (newList != null) {
            for (Signature__c s : newList) {
                if (s.Equipment__c != null) {
                    equipmentIds.add(s.Equipment__c);
                }
            }
        }

        if (oldList != null) {
            for (Signature__c s : oldList) {
                if (s.Equipment__c != null) {
                    equipmentIds.add(s.Equipment__c);
                }
            }
        }

        return equipmentIds;
    }

    // מחשב מחדש את מצב ה-Equipment על בסיס החתימה האחרונה (לפי Signed_Time__c)
    private static void reconcileEquipment(Set<Id> equipmentIds) {
        if (equipmentIds == null || equipmentIds.isEmpty()) {
            return;
        }

        // שואב את הציוד הרלוונטי
        List<Equipment__c> equipmentList = [
            SELECT Id, Status__c, Current_Holder__c, Current_Location__c
            FROM Equipment__c
            WHERE Id IN :equipmentIds
            FOR UPDATE
        ];

        if (equipmentList.isEmpty()) {
            return;
        }

        // שואב את כל החתימות לכל הציוד הרלוונטי, מסודר מהחדשה לישנה
        Map<Id, Signature__c> equipmentIdToLatestSignature = new Map<Id, Signature__c>();

        for (Signature__c sig : [
            SELECT Id,
                   Equipment__c,
                   Soldier__c,
                   Signed_Time__c,
                   Location_at_Signature__c
            FROM Signature__c
            WHERE Equipment__c IN :equipmentIds
            ORDER BY Signed_Time__c DESC, CreatedDate DESC
        ]) {
            if (!equipmentIdToLatestSignature.containsKey(sig.Equipment__c)) {
                // רשומה ראשונה לכל ציוד היא האקטואלית ביותר
                equipmentIdToLatestSignature.put(sig.Equipment__c, sig);
            }
        }

        List<Equipment__c> updates = new List<Equipment__c>();

        for (Equipment__c eq : equipmentList) {
            Signature__c lastSig = equipmentIdToLatestSignature.get(eq.Id);

            if (lastSig != null) {
                // יש חתימה – הציוד אצל חייל
                eq.Current_Holder__c   = lastSig.Soldier__c;
                eq.Current_Location__c = lastSig.Location_at_Signature__c;
                eq.Status__c           = 'חייל חתום'; // תוודא שהערך הזה קיים ב-Picklist
            } else {
                // אין חתימות לציוד הזה – אין חייל חתום כרגע
                eq.Current_Holder__c = null;

                // כאן אני *לא* נוגע ב-Status__c כדי לא להרוס סטטוסים מיוחדים
                // כמו 'זוכה', 'מחלקת קשר' וכו'. אם תרצה ערך ברירת מחדל (למשל 'פנוי'),
                // תוכל להוסיף כאן:
                // eq.Status__c = 'פנוי';
                //
                // לגבי המיקום – תלוי בך אם לאפס או להשאיר:
                // eq.Current_Location__c = null; // או 'מחסן' וכו'
            }

            updates.add(eq);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}
