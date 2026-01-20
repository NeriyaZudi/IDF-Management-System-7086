import { LightningElement, api, wire } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Import the Apex method
import getActiveSignature from '@salesforce/apex/SignatureReturnController.getActiveSignature';

// Fields for Update
import RETURNED_TIME_FIELD from '@salesforce/schema/Signature__c.Returned_Time__c';
import ID_FIELD from '@salesforce/schema/Signature__c.Id';

export default class ReturnItem extends LightningElement {
    @api recordId; // This is now the Equipment/NightDevice Id
    signatureId;   // This will hold the ID of the found Signature
    wiredResult;   // To store the wire provision for refreshing

    // Call Apex to find the active signature for this Item
    @wire(getActiveSignature, { itemId: '$recordId' })
    wiredSignature(result) {
        this.wiredResult = result; // Cache the result for refreshApex
        if (result.data) {
            this.signatureId = result.data.Id;
        } else if (result.error) {
            console.error('Error fetching signature', result.error);
            this.signatureId = null;
        } else {
            this.signatureId = null;
        }
    }

    handleReturn() {
        if (!this.signatureId) return;

        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.signatureId;
        fields[RETURNED_TIME_FIELD.fieldApiName] = new Date().toISOString();

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Item returned successfully',
                        variant: 'success'
                    })
                );
                // Refresh the Apex cache to update the UI (Hide button, show "In Stock")
                return refreshApex(this.wiredResult);
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }
}