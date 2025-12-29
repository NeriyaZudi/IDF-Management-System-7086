import { LightningElement, wire, track } from 'lwc';
import getTriggers from '@salesforce/apex/IntegrationTriggerController.getTriggers';
import getSystemOptions from '@salesforce/apex/IntegrationTriggerController.getSystemOptions';
import getObjectOptions from '@salesforce/apex/IntegrationTriggerController.getObjectOptions'; // NEW IMPORT
import createTriggerMetadata from '@salesforce/apex/IntegrationTriggerController.createTriggerMetadata';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const ACTIONS = [
    { label: 'Map Fields', name: 'map_fields' }
];

export default class IntegrationTriggerManager extends LightningElement {
    @track triggers;
    @track systemOptions = [];
    @track objectOptions = []; // NEW TRACKED VARIABLE
    @track isAddModalOpen = false;
    
    selectedSystem = '';
    selectedObject = ''; // NEW SELECTION STATE
    
    wiredTriggersResult;

    columns = [
        { label: 'Object', fieldName: 'objectName' },
        { label: 'System', fieldName: 'systemLabel' },
        { type: 'action', typeAttributes: { rowActions: ACTIONS } }
    ];

    @wire(getTriggers)
    wiredTriggers(result) {
        this.wiredTriggersResult = result;
        if (result.data) this.triggers = result.data;
    }

    @wire(getSystemOptions)
    wiredSysOptions({ data }) {
        if (data) this.systemOptions = data;
    }

    // NEW WIRE: Fetch Object List
    @wire(getObjectOptions)
    wiredObjOptions({ data }) {
        if (data) this.objectOptions = data;
    }

    // --- HANDLERS ---
    
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'map_fields') {
            this.dispatchEvent(new CustomEvent('triggerselect', { detail: row }));
        }
    }

    openAddModal() { this.isAddModalOpen = true; }
    closeAddModal() { 
        this.isAddModalOpen = false; 
        this.selectedSystem = '';
        this.selectedObject = '';
    }
    
    handleSystemChange(event) { this.selectedSystem = event.detail.value; }
    handleObjectChange(event) { this.selectedObject = event.detail.value; } // NEW HANDLER

    handleSave() {
        // Validation
        const fieldName = this.template.querySelector('[data-id="trgField"]').value;
        const fieldValue = this.template.querySelector('[data-id="trgValue"]').value;

        if (!this.selectedObject || !fieldName || !this.selectedSystem) {
             this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Please select an Object, System and Field.', variant: 'error' }));
             return;
        }

        createTriggerMetadata({ 
            objectName: this.selectedObject, // Use the selected combobox value
            triggerField: fieldName, 
            triggerValue: fieldValue, 
            systemDevName: this.selectedSystem 
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'New Object Trigger Integration Created', variant: 'success' }));
            this.closeAddModal();
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => refreshApex(this.wiredTriggersResult), 4000);
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body.message, variant: 'error' }));
        });
    }
}