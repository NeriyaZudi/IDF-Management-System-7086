import { LightningElement, wire, track } from 'lwc';
import getTriggers from '@salesforce/apex/IntegrationTriggerController.getTriggers';
import getSystemOptions from '@salesforce/apex/IntegrationTriggerController.getSystemOptions';
import createTriggerMetadata from '@salesforce/apex/IntegrationTriggerController.createTriggerMetadata';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const ACTIONS = [
    { label: 'Map Fields', name: 'map_fields' }
];

export default class IntegrationTriggerManager extends LightningElement {
    @track triggers;
    @track systemOptions = [];
    @track isAddModalOpen = false;
    selectedSystem = '';
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
    wiredOptions({ data }) {
        if (data) this.systemOptions = data;
    }

    // --- COMMUNICATION LOGIC ---
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'map_fields') {
            // FIRE EVENT TO PARENT
            const selectEvent = new CustomEvent('triggerselect', {
                detail: row
            });
            this.dispatchEvent(selectEvent);
        }
    }

    // --- ADD MODAL LOGIC (Standard) ---
    openAddModal() { this.isAddModalOpen = true; }
    closeAddModal() { this.isAddModalOpen = false; }
    handleSystemChange(event) { this.selectedSystem = event.detail.value; }

    handleSave() {
        const objectName = this.template.querySelector('[data-id="trgObject"]').value;
        const fieldName = this.template.querySelector('[data-id="trgField"]').value;
        const fieldValue = this.template.querySelector('[data-id="trgValue"]').value;

        if (!objectName || !fieldName || !this.selectedSystem) return;

        createTriggerMetadata({ objectName, triggerField: fieldName, triggerValue: fieldValue, systemDevName: this.selectedSystem })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'New Object Trigger Integration Created', variant: 'success' }));
                this.closeAddModal();
                setTimeout(() => refreshApex(this.wiredTriggersResult), 4000);
            });
    }
}