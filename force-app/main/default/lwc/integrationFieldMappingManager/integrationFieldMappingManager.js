import { LightningElement, api, wire, track } from 'lwc';
import getFieldMappings from '@salesforce/apex/IntegrationTriggerController.getFieldMappings';
import createFieldMapping from '@salesforce/apex/IntegrationTriggerController.createFieldMapping';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class IntegrationFieldMappingManager extends LightningElement {
    // These come from the Parent
    @api systemDevName; 
    @api systemLabel;   
    @api objectName;    

    @track mappings = [];
    wiredMappingsResult;
    
    newSource = '';
    newTarget = '';

    columns = [
        { label: 'Salesforce Field', fieldName: 'sourceField' },
        { label: 'Target JSON Key', fieldName: 'targetKey' }
    ];

    // Computed property to check if user selected something
    get hasSelection() {
        return this.systemDevName && this.objectName;
    }

    // Reactively fetch data when props change
    @wire(getFieldMappings, { systemDevName: '$systemDevName', objectName: '$objectName' })
    wiredMappings(result) {
        this.wiredMappingsResult = result;
        if (result.data) {
            this.mappings = result.data;
        }
    }

    handleSourceChange(e) { this.newSource = e.detail.value; }
    handleTargetChange(e) { this.newTarget = e.detail.value; }

    handleSaveMapping() {
        if(!this.newSource || !this.newTarget) return;

        createFieldMapping({
            systemDevName: this.systemDevName,
            objectName: this.objectName,
            sourceField: this.newSource,
            targetKey: this.newTarget
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'New Field Mapping Created', variant: 'success' }));
            this.newSource = '';
            this.newTarget = '';
            setTimeout(() => refreshApex(this.wiredMappingsResult), 4000);
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body.message, variant: 'error' }));
        });
    }
}