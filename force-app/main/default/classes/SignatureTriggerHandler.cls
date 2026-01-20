public with sharing class SignatureTriggerHandler {

    public static void afterInsert(List<Signature__c> newList) {
        reconcileEquipment(getEquipmentIds(newList, null));
        reconcileNightDevices(getNightDeviceIds(newList, null));
    }

    public static void afterUpdate(List<Signature__c> newList, List<Signature__c> oldList) {
        reconcileEquipment(getEquipmentIds(newList, oldList));
        reconcileNightDevices(getNightDeviceIds(newList, oldList));
    }

    public static void afterDelete(List<Signature__c> oldList) {
        reconcileEquipment(getEquipmentIds(null, oldList));
        reconcileNightDevices(getNightDeviceIds(null, oldList));
    }

    public static void afterUndelete(List<Signature__c> newList) {
        reconcileEquipment(getEquipmentIds(newList, null));
        reconcileNightDevices(getNightDeviceIds(newList, null));
    }

    // --- Logic for Equipment (Equipment__c) ---

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
        ];

        if (equipmentList.isEmpty()) return;

        // *** CHANGE 1: Added Returned_Time__c to the query ***
        Map<Id, Signature__c> mapIdToSig = new Map<Id, Signature__c>();
        for (Signature__c sig : [
            SELECT Id, Equipment__c, Soldier__c, Location_at_Signature__c, Returned_Time__c
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
            
            // *** CHANGE 2: Check if Returned_Time__c is empty ***
            if (lastSig != null && lastSig.Returned_Time__c == null) {
                // Case: Found a signature and it is NOT returned yet (Open)
                eq.Current_Holder__c   = lastSig.Soldier__c;
                eq.Current_Location__c = lastSig.Location_at_Signature__c;
                eq.Status__c           = 'חייל חתום';
            } else {
                // Case: No signature found OR the latest signature has a Returned Date
                eq.Current_Holder__c   = null; 
                // You might want to clear location or set it to a warehouse default
                eq.Current_Location__c = 'בפלוגה צאלים'; 
                eq.Status__c           = 'בטחונית'; // Or 'Available' / 'returned'
            }
            updates.add(eq);
        }

        if (!updates.isEmpty()) update updates;
    }

    // --- Logic for Night Devices (Night_Device__c) ---

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

        List<Night_Device__c> deviceList = [
            SELECT Id, Status__c, Current_Soldier_Holder__c, Current_Location__c
            FROM Night_Device__c
            WHERE Id IN :deviceIds
        ];

        if (deviceList.isEmpty()) return;

        Map<Id, Signature__c> mapIdToSig = new Map<Id, Signature__c>();
        
        // *** CHANGE 3: Added Returned_Time__c to the query ***
        for (Signature__c sig : [
            SELECT Id, Night_Device__c, Soldier__c, Location_at_Signature__c, Returned_Time__c
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
            
            // *** CHANGE 4: Check if Returned_Time__c is empty ***
            if (lastSig != null && lastSig.Returned_Time__c == null) {
                // Case: Soldier is holding the device
                dev.Current_Soldier_Holder__c = lastSig.Soldier__c;
                dev.Current_Location__c       = lastSig.Location_at_Signature__c;
                dev.Status__c                 = 'חייל חתום';
            } else {
                // Case: Returned or no history
                dev.Current_Soldier_Holder__c = null;
                dev.Current_Location__c       = 'בפלוגה בצאלים';
                dev.Status__c                 = 'בטחונית'; // Or 'Available'
            }
            updates.add(dev);
        }

        if (!updates.isEmpty()) update updates;
    }
}