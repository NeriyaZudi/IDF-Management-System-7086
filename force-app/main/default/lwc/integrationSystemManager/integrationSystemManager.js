import { LightningElement, wire, track } from 'lwc';
import getSystems from '@salesforce/apex/IntegrationSystemController.getSystems';
import createSystemMetadata from '@salesforce/apex/IntegrationSystemController.createSystemMetadata';
import deactivateSystemMetadata from '@salesforce/apex/IntegrationSystemController.deactivateSystemMetadata';
import activateSystemMetadata from '@salesforce/apex/IntegrationSystemController.activateSystemMetadata';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const ACTIONS = [
    { label: 'Deactivate System', name: 'deactivate' },
    { label: 'Reactivate System', name: 'reactivate' }
];

export default class IntegrationSystemManager extends LightningElement {
    @track systems;
    
    // Modal States
    @track isAddModalOpen = false;
    @track isDeactivateModalOpen = false;
    @track isReactivateModalOpen = false;
    
    @track selectedSystem = {};
    wiredSystemsResult;

    columns = [
        { label: 'System Name', fieldName: 'label' },
        { label: 'Endpoint', fieldName: 'endpoint' },
        { 
            label: 'Max Retries', 
            fieldName: 'maxRetries', 
            type: 'number',
            cellAttributes: { alignment: 'left' } // Fixes the alignment to LTR
        },
        { label: 'Active', fieldName: 'active', type: 'boolean' },
        { type: 'action', typeAttributes: { rowActions: ACTIONS } }
    ];

    @wire(getSystems)
    wiredSystems(result) {
        this.wiredSystemsResult = result;
        if (result.data) {
            this.systems = result.data;
        } else if (result.error) {
            this.showToast('Error', 'Failed to load systems', 'error');
        }
    }

    // --- MODAL HANDLERS ---
    openAddModal() { this.isAddModalOpen = true; }
    closeAddModal() { this.isAddModalOpen = false; }
    closeDeactivateModal() { this.isDeactivateModalOpen = false; this.selectedSystem = {}; }
    closeReactivateModal() { this.isReactivateModalOpen = false; this.selectedSystem = {}; }

    // --- ROW ACTION HANDLER ---
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        this.selectedSystem = row;

        if (actionName === 'deactivate') {
            if (!row.active) {
                this.showToast('Info', 'System is already inactive.', 'info');
                return;
            }
            this.isDeactivateModalOpen = true;
        } 
        else if (actionName === 'reactivate') {
            if (row.active) {
                this.showToast('Info', 'System is already active.', 'info');
                return;
            }
            this.isReactivateModalOpen = true;
        }
    }

    // --- APEX ACTIONS ---

    handleSaveNew() {
        const name = this.template.querySelector('[data-id="sysName"]').value;
        const endpoint = this.template.querySelector('[data-id="sysEndpoint"]').value;
        const retries = this.template.querySelector('[data-id="sysRetries"]').value;

        if(!name || !endpoint || !retries) {
            this.showToast('Error', 'Please fill all fields', 'error');
            return;
        }

        createSystemMetadata({ label: name, endpoint: endpoint, retries: parseInt(retries) })
            .then(() => {
                this.showToast('Success', 'Object Integration Create Successfully. Table will update shortly...', 'success');
                this.closeAddModal();
                this.triggerDoubleRefresh();
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    handleDeactivateConfirm() {
        deactivateSystemMetadata({ 
            label: this.selectedSystem.label, 
            developerName: this.selectedSystem.developerName,
            endpoint: this.selectedSystem.endpoint, 
            retries: this.selectedSystem.maxRetries 
        })
        .then(() => {
            this.showToast('Success', 'Deactivation Done. Table will update shortly...', 'success');
            this.closeDeactivateModal();
            this.triggerDoubleRefresh();
        })
        .catch(error => {
            this.showToast('Error', error.body.message, 'error');
        });
    }

    handleReactivateConfirm() {
        activateSystemMetadata({ 
            label: this.selectedSystem.label, 
            developerName: this.selectedSystem.developerName,
            endpoint: this.selectedSystem.endpoint, 
            retries: this.selectedSystem.maxRetries 
        })
        .then(() => {
            this.showToast('Success', 'Reactivation Done. Table will update shortly...', 'success');
            this.closeReactivateModal();
            this.triggerDoubleRefresh();
        })
        .catch(error => {
            this.showToast('Error', error.body.message, 'error');
        });
    }

    // --- HELPERS ---

    triggerDoubleRefresh() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => refreshApex(this.wiredSystemsResult), 3000);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => refreshApex(this.wiredSystemsResult), 8000);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}