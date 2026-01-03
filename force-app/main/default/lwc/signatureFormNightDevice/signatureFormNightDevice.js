import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi'; 

// --- שינוי: ייבוא שדות של Night_Device__c ---
import NAME_FIELD from '@salesforce/schema/Night_Device__c.Name';
import SERIAL_FIELD from '@salesforce/schema/Night_Device__c.Serial_Number__c';

// --- שינוי: ייבוא מהקונטרולר החדש ---
import getSoldiers from '@salesforce/apex/NightDeviceSignatureController.getSoldiers';
import createSignatures from '@salesforce/apex/NightDeviceSignatureController.createSignatures';

export default class SignatureFormNightDevice extends LightningElement {
    @api recordId;
    @api objectApiName; // Night_Device__c

    @track soldierOptions = [];
    selectedSoldierId;
    location = '';
    comments = '';
    isLoading = false;

    // שליפת המידע על האמצעי לילה
    @wire(getRecord, { recordId: '$recordId', fields: [NAME_FIELD, SERIAL_FIELD] })
    device;

    get deviceTitle() {
        if (this.device.data) {
            const name = getFieldValue(this.device.data, NAME_FIELD);
            const serial = getFieldValue(this.device.data, SERIAL_FIELD);
            
            if (serial) {
                return `${name} - מספר צ': ${serial}`;
            }
            return name;
        }
        return 'טוען נתונים...';
    }

    @wire(getSoldiers)
    wiredSoldiers({ data, error }) {
        if (data) {
            this.soldierOptions = data;
        } else if (error) {
            console.error('Error loading soldiers', error);
            this.showToast('שגיאה', 'שגיאה בטעינת רשימת החיילים', 'error');
        }
    }

    get isSignDisabled() {
        return !this.selectedSoldierId || this.isLoading;
    }

    handleSoldierChange(event) {
        this.selectedSoldierId = event.detail.value;
    }

    handleLocationChange(event) {
        this.location = event.detail.value;
    }

    handleCommentsChange(event) {
        this.comments = event.detail.value;
    }

    async handleSign() {
        if (this.isSignDisabled) {
            this.showToast('שגיאה', 'יש לבחור חייל לפני חתימה', 'error');
            return;
        }

        this.isLoading = true;

        try {
            // שימוש בפונקציה מהקונטרולר החדש (פרמטר deviceIds)
            await createSignatures({
                soldierId: this.selectedSoldierId,
                deviceIds: [this.recordId],
                location: this.location,
                comments: this.comments
            });

            this.showToast('הצלחה', 'החתימה נשמרה בהצלחה והאמצעי עודכן', 'success');

            try {
                await notifyRecordUpdateAvailable([{recordId: this.recordId}]);
            } catch(refreshError) {
                console.error('Refresh failed', refreshError);
            }

            this.dispatchEvent(new CloseActionScreenEvent());

        } catch (error) {
            console.error('Error in createSignatures', error);
            let message = 'שגיאה בשמירת החתימה';
            if (error && error.body && error.body.message) {
                message = error.body.message;
            }
            this.showToast('שגיאה', message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}