import { LightningElement, api, wire, track } from 'lwc';
// UPDATED IMPORTS: Pointing to new controller
import getFieldMappings from '@salesforce/apex/IntegrationMappingController.getFieldMappings';
import createFieldMapping from '@salesforce/apex/IntegrationMappingController.createFieldMapping';
import deleteFieldMapping from '@salesforce/apex/IntegrationMappingController.deleteFieldMapping';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Row Actions Definition
const ACTIONS = [
    { label: 'Remove Mapping', name: 'delete' }
];

export default class IntegrationFieldMappingManager extends LightningElement {
    @api systemDevName; 
    @api systemLabel;   
    @api objectName;    

    @track mappings = [];
    @track isLoading = false; // Added loading state
    wiredMappingsResult;
    
    newSource = '';
    newTarget = '';

    columns = [
        { label: 'Salesforce Field', fieldName: 'sourceField' },
        { label: 'Target JSON Key', fieldName: 'targetKey' },
        {
            type: 'action',
            typeAttributes: { rowActions: ACTIONS }
        }
    ];

    get hasSelection() {
        return this.systemDevName && this.objectName;
    }

    @wire(getFieldMappings, { systemDevName: '$systemDevName', objectName: '$objectName' })
    wiredMappings(result) {
        this.wiredMappingsResult = result;
        if (result.data) {
            this.mappings = result.data;
        }
    }

    handleSourceChange(e) { this.newSource = e.detail.value; }
    handleTargetChange(e) { this.newTarget = e.detail.value; }

    // --- HANDLE ROW ACTIONS (DELETE) ---
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'delete') {
            this.handleDelete(row);
        }
    }

    handleDelete(row) {
        this.isLoading = true;
        deleteFieldMapping({
            developerName: row.developerName,
            label: row.label,
            sourceField: row.sourceField,
            targetKey: row.targetKey
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({ 
                title: 'Success', 
                message: 'Field removed. Table will update shortly...', 
                variant: 'success' 
            }));
            this.triggerRefresh();
        })
        .catch(error => {
            this.dispatchEvent(new ShowToastEvent({ 
                title: 'Error', 
                message: error.body ? error.body.message : error.message, 
                variant: 'error' 
            }));
            this.isLoading = false;
        });
    }

    // --- HANDLE CREATE ---
    handleSaveMapping() {
        if(!this.newSource || !this.newTarget) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Warning', message: 'Both fields are required', variant: 'warning' }));
            return;
        }

        this.isLoading = true;

        createFieldMapping({
            systemDevName: this.systemDevName,
            objectName: this.objectName,
            sourceField: this.newSource,
            targetKey: this.newTarget
        })
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({ 
                title: 'Success', 
                message: 'New Field Mapping Created', 
                variant: 'success' 
            }));
            
            // Clear inputs
            this.newSource = '';
            this.newTarget = '';
            
            this.triggerRefresh();
        })
        .catch(error => {
            // Handles Duplicate Error here
            this.dispatchEvent(new ShowToastEvent({ 
                title: 'Error', 
                message: error.body ? error.body.message : error.message, 
                variant: 'error' 
            }));
            this.isLoading = false;
        });
    }

    triggerRefresh() {
        // Refresh 3 times to catch the async metadata deployment
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => refreshApex(this.wiredMappingsResult), 2000);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => refreshApex(this.wiredMappingsResult), 5000);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            refreshApex(this.wiredMappingsResult);
            this.isLoading = false;
        }, 8000);
    }
}