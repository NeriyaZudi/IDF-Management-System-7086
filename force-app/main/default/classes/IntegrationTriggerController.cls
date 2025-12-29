public with sharing class IntegrationTriggerController {

    // --- WRAPPERS (Unchanged) ---
    public class TriggerWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String objectName;
        @AuraEnabled public String triggerField;
        @AuraEnabled public String triggerValue;
        @AuraEnabled public String systemLabel;
        @AuraEnabled public String systemDevName; 
        
        public TriggerWrapper(Integration_Trigger_Config__mdt t) {
            this.id = t.Id;
            this.label = t.Label;
            this.objectName = t.Object_API_Name__c;
            this.triggerField = t.Trigger_Field__c;
            this.triggerValue = t.Trigger_Value__c;
            this.systemLabel = t.Integration_System__r.Label;
            this.systemDevName = t.Integration_System__r.DeveloperName;
        }
    }

    public class MappingWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String sourceField;
        @AuraEnabled public String targetKey;
        
        public MappingWrapper(Field_Mapping__mdt fm) {
            this.id = fm.Id;
            this.sourceField = fm.Source_Field_API__c;
            this.targetKey = fm.Target_JSON_Key__c;
        }
    }

    public class ComboboxOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public ComboboxOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    // --- READ METHODS (Unchanged) ---
    @AuraEnabled(cacheable=true)
    public static List<TriggerWrapper> getTriggers() {
        List<TriggerWrapper> result = new List<TriggerWrapper>();
        for(Integration_Trigger_Config__mdt t : [
            SELECT Id, Label, Object_API_Name__c, Trigger_Field__c, Trigger_Value__c, 
                   Integration_System__r.Label, Integration_System__r.DeveloperName 
            FROM Integration_Trigger_Config__mdt
        ]) {
            result.add(new TriggerWrapper(t));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<ComboboxOption> getSystemOptions() {
        List<ComboboxOption> options = new List<ComboboxOption>();
        for(Integration_System__mdt s : [SELECT Label, DeveloperName FROM Integration_System__mdt WHERE Is_Active__c = TRUE]) {
            options.add(new ComboboxOption(s.Label, s.DeveloperName));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<MappingWrapper> getFieldMappings(String systemDevName, String objectName) {
        List<MappingWrapper> result = new List<MappingWrapper>();
        if (String.isBlank(systemDevName) || String.isBlank(objectName)) return result;

        String query = 'SELECT Id, Source_Field_API__c, Target_JSON_Key__c FROM Field_Mapping__mdt ' + 
                       'WHERE Integration_System__r.DeveloperName = :systemDevName ' +
                       'AND Object_API_Name__c = :objectName';
        try {
            for(Field_Mapping__mdt fm : Database.query(query)) {
                result.add(new MappingWrapper(fm));
            }
        } catch(Exception e) {
            System.debug('Mapping Fetch Error: ' + e.getMessage());
        }
        return result;
    }

    // --- WRITE METHODS ---

    @AuraEnabled
    public static void createTriggerMetadata(String objectName, String triggerField, String triggerValue, String systemDevName) {
        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();

        // 1. Create Trigger Config
        Metadata.CustomMetadata triggerRecord = new Metadata.CustomMetadata();
        
        String rawName = objectName + '_' + triggerField + '_' + systemDevName;
        String cleanName = sanitizeName(rawName);
        if(cleanName.length() > 30) cleanName = cleanName.substring(0, 30);
        
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0,4);
        triggerRecord.fullName = 'Integration_Trigger_Config__mdt.TRG_' + cleanName + '_' + uniqueSuffix;
        triggerRecord.label = objectName + ' ' + triggerField + ' Trigger';
        
        Map<String, Object> triggerFields = new Map<String, Object>{
            'Object_API_Name__c' => objectName,
            'Trigger_Field__c' => triggerField,
            'Trigger_Value__c' => triggerValue,
            'Integration_System__c' => systemDevName
        };
        for (String key : triggerFields.keySet()) {
            Metadata.CustomMetadataValue val = new Metadata.CustomMetadataValue();
            val.field = key;
            val.value = triggerFields.get(key);
            triggerRecord.values.add(val);
        }
        mdContainer.addMetadata(triggerRecord);

        // 2. Auto-Create Default Mapping using the TRIGGER FIELD
        Metadata.CustomMetadata mappingRecord = new Metadata.CustomMetadata();
        
        String rawMapName = objectName + '_' + triggerField + '_' + systemDevName;
        String cleanMapName = sanitizeName(rawMapName);
        if(cleanMapName.length() > 30) cleanMapName = cleanMapName.substring(0, 30);

        String mapUniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0,4);
        mappingRecord.fullName = 'Field_Mapping__mdt.MAP_' + cleanMapName + '_' + mapUniqueSuffix;
        mappingRecord.label = objectName + ' ' + triggerField + ' Map';

        Map<String, Object> mapFields = new Map<String, Object>{
            'Object_API_Name__c' => objectName,
            'Source_Field_API__c' => triggerField, // Use the Trigger Field!
            'Target_JSON_Key__c' => triggerField.toLowerCase(), // Default JSON key is lowercase field name
            'Integration_System__c' => systemDevName
        };
        for (String key : mapFields.keySet()) {
            Metadata.CustomMetadataValue val = new Metadata.CustomMetadataValue();
            val.field = key;
            val.value = mapFields.get(key);
            mappingRecord.values.add(val);
        }
        mdContainer.addMetadata(mappingRecord);

        deployMetadata(mdContainer);
    }

    @AuraEnabled
    public static void createFieldMapping(String systemDevName, String objectName, String sourceField, String targetKey) {
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        
        String rawName = objectName + '_' + sourceField + '_' + systemDevName;
        String cleanName = sanitizeName(rawName);
        if(cleanName.length() > 30) cleanName = cleanName.substring(0, 30);
        
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0,4);
        customMetadata.fullName = 'Field_Mapping__mdt.MAP_' + cleanName + '_' + uniqueSuffix;
        customMetadata.label = objectName + ' ' + sourceField + ' Map';
        
        Map<String, Object> fields = new Map<String, Object>{
            'Object_API_Name__c' => objectName,
            'Source_Field_API__c' => sourceField,
            'Target_JSON_Key__c' => targetKey,
            'Integration_System__c' => systemDevName
        };

        for (String key : fields.keySet()) {
            Metadata.CustomMetadataValue val = new Metadata.CustomMetadataValue();
            val.field = key;
            val.value = fields.get(key);
            customMetadata.values.add(val);
        }

        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        mdContainer.addMetadata(customMetadata);
        deployMetadata(mdContainer);
    }

    private static void deployMetadata(Metadata.DeployContainer mdContainer) {
        if(!Test.isRunningTest()) {
            Metadata.Operations.enqueueDeployment(mdContainer, null);
        }
    }

    private static String sanitizeName(String input) {
        if (input == null) return '';
        String sanitized = input.replaceAll('[^a-zA-Z0-9]', '_');
        while (sanitized.contains('__')) {
            sanitized = sanitized.replace('__', '_');
        }
        if (sanitized.endsWith('_')) {
            sanitized = sanitized.substring(0, sanitized.length() - 1);
        }
        if (sanitized.startsWith('_')) {
            sanitized = sanitized.substring(1);
        }
        return sanitized;
    }
}