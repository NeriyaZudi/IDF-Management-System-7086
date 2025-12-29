import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import getSoldiers from '@salesforce/apex/EquipmentSignatureController.getSoldiers';
import createSignatures from '@salesforce/apex/EquipmentSignatureController.createSignatures';

export default class SignatureFormEquipmentPage extends LightningElement {
    @api recordId;       // Equipment__c Id
    @api objectApiName;  // אמור להיות Equipment__c, אבל לא חובה להשתמש

    @track soldierOptions = [];

    selectedSoldierId;
    location = '';
    comments = '';
    isLoading = false;

    // טעינת חיילים לרשימה
    @wire(getSoldiers)
    wiredSoldiers({ data, error }) {
        if (data) {
            this.soldierOptions = data;
        } else if (error) {
            console.error('Error loading soldiers', error);
            this.showToast('שגיאה', 'שגיאה בטעינת רשימת החיילים', 'error');
        }
    }

    // לחצן חתימה – מנוטרל אם אין חייל נבחר או בזמן שמירה
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

        if (!this.recordId) {
            this.showToast('שגיאה', 'לא נמצא מזהה ציוד (recordId)', 'error');
            return;
        }

        this.isLoading = true;

        try {
            // אנחנו חותמים על פריט אחד – מעבירים List עם element אחד
            await createSignatures({
                soldierId: this.selectedSoldierId,
                equipmentIds: [this.recordId],
                location: this.location,
                comments: this.comments
            });

            this.showToast('הצלחה', 'החתימה נשמרה בהצלחה והציוד עודכן', 'success');

            // סגירת המודאל (Quick Action)
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
