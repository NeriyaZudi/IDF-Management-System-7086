public with sharing class SignatureTriggerHandler {

    public static void afterInsert(List<Signature__c> newList) {
        reconcileEquipment(getEquipmentIds(newList, null));
        reconcileNightDevices(getNightDeviceIds(newList, null)); // תוספת
    }

    public static void afterUpdate(List<Signature__c> newList, List<Signature__c> oldList) {
        reconcileEquipment(getEquipmentIds(newList, oldList));
        reconcileNightDevices(getNightDeviceIds(newList, oldList)); // תוספת
    }

    public static void afterDelete(List<Signature__c> oldList) {
        reconcileEquipment(getEquipmentIds(null, oldList));
        reconcileNightDevices(getNightDeviceIds(null, oldList)); // תוספת
    }

    public static void afterUndelete(List<Signature__c> newList) {
        reconcileEquipment(getEquipmentIds(newList, null));
        reconcileNightDevices(getNightDeviceIds(newList, null)); // תוספת
    }

    // --- לוגיקה לציוד רגיל (Equipment__c) ---

    private static Set<Id> getEquipmentIds(List<Signature__c> newList, List<Signature__c> oldList) {
        Set<Id> ids = new Set<Id>();
        if (newList != null) {
            for (Signature__c s : newList) {
                if (s.Equipment__c != null) ids.add(s.Equipment__c);
            }
        }
        if (oldList != null) {
            for (Signature__c s : oldList) {
                if (s.Equipment__c != null) ids.add(s.Equipment__c);
            }
        }
        return ids;
    }

    private static void reconcileEquipment(Set<Id> equipmentIds) {
        if (equipmentIds == null || equipmentIds.isEmpty()) return;

        List<Equipment__c> equipmentList = [
            SELECT Id, Status__c, Current_Holder__c, Current_Location__c
            FROM Equipment__c
            WHERE Id IN :equipmentIds
        ]; // הסרתי FOR UPDATE למניעת נעילות מיותרות אם לא חובה

        if (equipmentList.isEmpty()) return;

        // שליפת החתימה האחרונה לציוד זה
        Map<Id, Signature__c> mapIdToSig = new Map<Id, Signature__c>();
        for (Signature__c sig : [
            SELECT Id, Equipment__c, Soldier__c, Location_at_Signature__c
            FROM Signature__c
            WHERE Equipment__c IN :equipmentIds
            ORDER BY Signed_Time__c DESC, CreatedDate DESC
        ]) {
            if (!mapIdToSig.containsKey(sig.Equipment__c)) {
                mapIdToSig.put(sig.Equipment__c, sig);
            }
        }

        List<Equipment__c> updates = new List<Equipment__c>();
        for (Equipment__c eq : equipmentList) {
            Signature__c lastSig = mapIdToSig.get(eq.Id);
            if (lastSig != null) {
                eq.Current_Holder__c   = lastSig.Soldier__c;
                eq.Current_Location__c = lastSig.Location_at_Signature__c;
                eq.Status__c           = 'חייל חתום';
            } else {
                eq.Current_Holder__c = null;
                // אופציונלי: eq.Status__c = 'פנוי';
            }
            updates.add(eq);
        }

        if (!updates.isEmpty()) update updates;
    }

    // --- לוגיקה לאמצעי לילה (Night_Device__c) ---

    private static Set<Id> getNightDeviceIds(List<Signature__c> newList, List<Signature__c> oldList) {
        Set<Id> ids = new Set<Id>();
        if (newList != null) {
            for (Signature__c s : newList) {
                if (s.Night_Device__c != null) ids.add(s.Night_Device__c);
            }
        }
        if (oldList != null) {
            for (Signature__c s : oldList) {
                if (s.Night_Device__c != null) ids.add(s.Night_Device__c);
            }
        }
        return ids;
    }

    private static void reconcileNightDevices(Set<Id> deviceIds) {
        if (deviceIds == null || deviceIds.isEmpty()) return;

        // הנחה: לאובייקט Night_Device__c יש שדות זהים (Status__c, Current_Holder__c, וכו')
        List<Night_Device__c> deviceList = [
            SELECT Id, Status__c, Current_Soldier_Holder__c, Current_Location__c
            FROM Night_Device__c
            WHERE Id IN :deviceIds
        ];

        if (deviceList.isEmpty()) return;

        Map<Id, Signature__c> mapIdToSig = new Map<Id, Signature__c>();
        
        // שימו לב: כאן אנחנו מסננים לפי Night_Device__c
        for (Signature__c sig : [
            SELECT Id, Night_Device__c, Soldier__c, Location_at_Signature__c
            FROM Signature__c
            WHERE Night_Device__c IN :deviceIds
            ORDER BY Signed_Time__c DESC, CreatedDate DESC
        ]) {
            if (!mapIdToSig.containsKey(sig.Night_Device__c)) {
                mapIdToSig.put(sig.Night_Device__c, sig);
            }
        }

        List<Night_Device__c> updates = new List<Night_Device__c>();
        for (Night_Device__c dev : deviceList) {
            Signature__c lastSig = mapIdToSig.get(dev.Id);
            if (lastSig != null) {
                dev.Current_Soldier_Holder__c   = lastSig.Soldier__c;
                dev.Current_Location__c = lastSig.Location_at_Signature__c;
                dev.Status__c           = 'חייל חתום';
            } else {
                dev.Current_Soldier_Holder__c = null;
            }
            updates.add(dev);
        }

        if (!updates.isEmpty()) update updates;
    }
}