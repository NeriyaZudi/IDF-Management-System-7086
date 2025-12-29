public with sharing class IntegrationMappingController {

    public class MappingWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String sourceField;
        @AuraEnabled public String targetKey;
        @AuraEnabled public Boolean active;
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;

        public MappingWrapper(Field_Mapping__mdt fm) {
            this.id = fm.Id;
            this.sourceField = fm.Source_Field_API__c;
            this.targetKey = fm.Target_JSON_Key__c;
            this.active = fm.Active__c;
            this.developerName = fm.DeveloperName;
            this.label = fm.Label;
        }
    }

    // --- READ ---
    @AuraEnabled(cacheable=true)
    public static List<MappingWrapper> getFieldMappings(String systemDevName, String objectName) {
        List<MappingWrapper> result = new List<MappingWrapper>();
        if (String.isBlank(systemDevName) || String.isBlank(objectName)) return result;

        // Filter by Active__c = TRUE so "deleted" ones don't show up
        String query = 'SELECT Id, Label, DeveloperName, Source_Field_API__c, Target_JSON_Key__c, Active__c ' + 
                       'FROM Field_Mapping__mdt ' + 
                       'WHERE Integration_System__r.DeveloperName = :systemDevName ' +
                       'AND Object_API_Name__c = :objectName ' + 
                       'AND Active__c = TRUE'; 
        try {
            for(Field_Mapping__mdt fm : Database.query(query)) {
                result.add(new MappingWrapper(fm));
            }
        } catch(Exception e) {
            System.debug('Mapping Fetch Error: ' + e.getMessage());
        }
        return result;
    }

    // --- CREATE (With Duplicate Check) ---
    @AuraEnabled
    public static void createFieldMapping(String systemDevName, String objectName, String sourceField, String targetKey) {
        
        // 1. DUPLICATE CHECK
        // We check if an active mapping for this source field already exists
        List<Field_Mapping__mdt> duplicates = [
            SELECT Id FROM Field_Mapping__mdt 
            WHERE Integration_System__r.DeveloperName = :systemDevName
            AND Object_API_Name__c = :objectName
            AND Source_Field_API__c = :sourceField
            AND Active__c = TRUE
            LIMIT 1
        ];

        if (!duplicates.isEmpty()) {
            // This throws an error the LWC can catch
            throw new AuraHandledException('Duplicate Error: The field "' + sourceField + '" is already mapped for this object.');
        }

        // 2. CREATE LOGIC
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
            'Integration_System__c' => systemDevName,
            'Active__c' => true 
        };

        for (String key : fields.keySet()) {
            Metadata.CustomMetadataValue val = new Metadata.CustomMetadataValue();
            val.field = key;
            val.value = fields.get(key);
            customMetadata.values.add(val);
        }

        deployMetadata(customMetadata);
    }

    // --- DELETE (Soft Delete) ---
    @AuraEnabled
    public static void deleteFieldMapping(String developerName, String label, String sourceField, String targetKey) {
        // We "delete" by updating the record to Active__c = false
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        customMetadata.fullName = 'Field_Mapping__mdt.' + developerName;
        customMetadata.label = label; 

        // We must re-submit existing required values to avoid wiping them
        Map<String, Object> fields = new Map<String, Object>{
            'Source_Field_API__c' => sourceField,
            'Target_JSON_Key__c' => targetKey,
            'Active__c' => false // THE SOFT DELETE
        };

        for (String key : fields.keySet()) {
            Metadata.CustomMetadataValue val = new Metadata.CustomMetadataValue();
            val.field = key;
            val.value = fields.get(key);
            customMetadata.values.add(val);
        }

        deployMetadata(customMetadata);
    }

    // --- HELPERS ---
    private static void deployMetadata(Metadata.CustomMetadata customMetadata) {
        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        mdContainer.addMetadata(customMetadata);
        if(!Test.isRunningTest()) {
            Metadata.Operations.enqueueDeployment(mdContainer, null);
        }
    }

    private static String sanitizeName(String input) {
        if (input == null) return '';
        String sanitized = input.replaceAll('[^a-zA-Z0-9]', '_');
        while (sanitized.contains('__')) sanitized = sanitized.replace('__', '_');
        if (sanitized.endsWith('_')) sanitized = sanitized.substring(0, sanitized.length() - 1);
        if (sanitized.startsWith('_')) sanitized = sanitized.substring(1);
        return sanitized;
    }
}