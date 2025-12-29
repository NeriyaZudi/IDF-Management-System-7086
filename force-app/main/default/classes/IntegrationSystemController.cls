public with sharing class IntegrationSystemController {

    public class SystemWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String developerName; 
        @AuraEnabled public String endpoint;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Integer maxRetries;
        
        public SystemWrapper(Integration_System__mdt s) {
            this.id = s.Id;
            this.label = s.Label;
            this.developerName = s.DeveloperName;
            this.endpoint = s.Endpoint__c;
            this.active = s.Is_Active__c;
            this.maxRetries = (Integer)s.Max_Retries__c;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SystemWrapper> getSystems() {
        List<SystemWrapper> result = new List<SystemWrapper>();
        
        List<Integration_System__mdt> records = [
            SELECT Id, Label, DeveloperName, Endpoint__c, Is_Active__c, Max_Retries__c 
            FROM Integration_System__mdt
            ORDER BY Label ASC
        ];

        for(Integration_System__mdt s : records) {
            result.add(new SystemWrapper(s));
        }
        return result;
    }

    @AuraEnabled
    public static void createSystemMetadata(String label, String endpoint, Integer retries) {
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        
        String devName = label.replaceAll('[^a-zA-Z0-9]', '_');
        if (devName.length() > 35) devName = devName.substring(0, 35);
        
        customMetadata.fullName = 'Integration_System__mdt.' + devName;
        customMetadata.label = label;
        
        Metadata.CustomMetadataValue endpointField = new Metadata.CustomMetadataValue();
        endpointField.field = 'Endpoint__c';
        endpointField.value = endpoint;
        customMetadata.values.add(endpointField);
        
        Metadata.CustomMetadataValue retriesField = new Metadata.CustomMetadataValue();
        retriesField.field = 'Max_Retries__c';
        retriesField.value = retries;
        customMetadata.values.add(retriesField);
        
        Metadata.CustomMetadataValue activeField = new Metadata.CustomMetadataValue();
        activeField.field = 'Is_Active__c';
        activeField.value = true;
        customMetadata.values.add(activeField);

        deployMetadata(customMetadata);
    }

    @AuraEnabled
    public static void deactivateSystemMetadata(String label, String developerName, String endpoint, Integer retries) {
        updateSystemStatus(label, developerName, endpoint, retries, false);
    }

    @AuraEnabled
    public static void activateSystemMetadata(String label, String developerName, String endpoint, Integer retries) {
        updateSystemStatus(label, developerName, endpoint, retries, true);
    }

    private static void updateSystemStatus(String label, String developerName, String endpoint, Integer retries, Boolean isActive) {
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        
        customMetadata.fullName = 'Integration_System__mdt.' + developerName;
        customMetadata.label = label;
        
        Metadata.CustomMetadataValue endpointField = new Metadata.CustomMetadataValue();
        endpointField.field = 'Endpoint__c';
        endpointField.value = endpoint;
        customMetadata.values.add(endpointField);
        
        Metadata.CustomMetadataValue retriesField = new Metadata.CustomMetadataValue();
        retriesField.field = 'Max_Retries__c';
        retriesField.value = retries;
        customMetadata.values.add(retriesField);
        
        Metadata.CustomMetadataValue activeField = new Metadata.CustomMetadataValue();
        activeField.field = 'Is_Active__c';
        activeField.value = isActive; 
        customMetadata.values.add(activeField);

        deployMetadata(customMetadata);
    }

    private static void deployMetadata(Metadata.CustomMetadata customMetadata) {
        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        mdContainer.addMetadata(customMetadata);
        
        if(!Test.isRunningTest()) {
            Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
        }
    }
}