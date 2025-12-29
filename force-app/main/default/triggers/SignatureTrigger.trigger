trigger SignatureTrigger on Signature__c (after insert, after update, after delete, after undelete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            SignatureTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            SignatureTriggerHandler.afterUpdate(Trigger.new, Trigger.old);
        } else if (Trigger.isDelete) {
            SignatureTriggerHandler.afterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            SignatureTriggerHandler.afterUndelete(Trigger.new);
        }
    }
}
