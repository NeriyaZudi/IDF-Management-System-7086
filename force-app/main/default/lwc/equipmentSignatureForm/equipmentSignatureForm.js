import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import getSoldiers from '@salesforce/apex/EquipmentSignatureController.getSoldiers';
import getAvailableEquipment from '@salesforce/apex/EquipmentSignatureController.getAvailableEquipment';
import createSignatures from '@salesforce/apex/EquipmentSignatureController.createSignatures';

export default class EquipmentSignatureForm extends LightningElement {
    @api recordId;       // ה-id של הרשומה שממנה נפתחה ה-action
    @api objectApiName;  // Soldier__c / Equipment__c / Signature__c וכו'

    @track soldierOptions = [];
    @track equipmentData = [];
    @track equipmentError;

    selectedSoldierId;
    selectedEquipmentIds = [];
    location = '';
    comments = '';
    isLoading = false;

    // עמודות לטבלת הציוד
    columns = [
        { label: 'שם ציוד', fieldName: 'name' },
        { label: 'מספר סידורי', fieldName: 'serialNumber' },
        { label: 'סוג', fieldName: 'type' },
        { label: 'סטטוס', fieldName: 'status' },
        { label: 'מיקום נוכחי', fieldName: 'currentLocation' }
    ];

    // האם אנחנו רצים מתוך דף חייל?
    get isSoldierContext() {
        return this.objectApiName === 'Soldier__c';
    }

    // האם אנחנו רצים מתוך דף ציוד?
    get isEquipmentContext() {
        return this.objectApiName === 'Equipment__c';
    }

    // ברגע שהקומפוננטה נטענת – נגדיר ברירת מחדל לפי ההקשר
    connectedCallback() {
        // אם נפתחנו מתוך Soldier__c – נגדיר את החייל הנבחר כברירת מחדל
        if (this.isSoldierContext && !this.selectedSoldierId && this.recordId) {
            this.selectedSoldierId = this.recordId;
        }

        // אם נפתחנו מתוך Equipment__c – אפשר בעתיד להשתמש ב-recordId כדי
        // להדגיש/לקבע את הציוד הזה. כרגע רק נשמור את ה-id אם נרצה להשתמש בו.
        if (this.isEquipmentContext && this.recordId) {
            // לדוגמה: אפשר בהמשך לסמן אוטומטית את הפריט הזה בטבלה.
            // כרגע לא חובה לעשות כלום – נשאיר כהערה לעתיד.
        }
    }

    // טעינת חיילים
    @wire(getSoldiers)
    wiredSoldiers({ data, error }) {
        if (data) {
            this.soldierOptions = data;

            // אם אנחנו על Soldier__c והחייל עוד לא נבחר – נבחר אוטומטית
            if (this.isSoldierContext && this.recordId && !this.selectedSoldierId) {
                this.selectedSoldierId = this.recordId;
            }
        } else if (error) {
            console.error('Error loading soldiers', error);
            this.showToast('שגיאה', 'שגיאה בטעינת רשימת החיילים', 'error');
        }
    }

    // טעינת ציוד פנוי
    @wire(getAvailableEquipment)
    wiredEquipment({ data, error }) {
        if (data) {
            this.equipmentData = data;
            this.equipmentError = undefined;
        } else if (error) {
            console.error('Error loading equipment', error);
            this.equipmentError = 'שגיאה בטעינת ציוד פנוי';
        }
    }

    // כפתור חתימה נגיש רק אם יש חייל נבחר וציוד נבחר ולא בזמן טעינה
    get isSignDisabled() {
        return !this.selectedSoldierId || this.selectedEquipmentIds.length === 0 || this.isLoading;
    }

    // שינוי חייל (כשמרימים action ממקום שאינו Soldier__c)
    handleSoldierChange(event) {
        this.selectedSoldierId = event.detail.value;
    }

    // שינוי מיקום טקסטואלי
    handleLocationChange(event) {
        this.location = event.detail.value;
    }

    // שינוי הערות
    handleCommentsChange(event) {
        this.comments = event.detail.value;
    }

    // בחירת שורות בטבלת הציוד
    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        this.selectedEquipmentIds = selectedRows.map(row => row.id);
    }

    // לחיצה על "חתום על הציוד"
    async handleSign() {
        if (this.isSignDisabled) {
            this.showToast('שגיאה', 'יש לבחור חייל וציוד לפני חתימה', 'error');
            return;
        }

        this.isLoading = true;

        try {
            await createSignatures({
                soldierId: this.selectedSoldierId,
                equipmentIds: this.selectedEquipmentIds,
                location: this.location,
                comments: this.comments
            });

            this.showToast('הצלחה', 'החתימה נשמרה בהצלחה והציוד עודכן', 'success');

            // איפוס בחירה בסיסי
            this.selectedEquipmentIds = [];
            this.comments = '';

            // ריענון רשימת הציוד הפנוי (קריאה אימפרטיבית)
            const result = await getAvailableEquipment();
            this.equipmentData = result;

            // אם הקומפוננטה רצה כ-Quick Action – נסגור את המודאל
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

    // פונקציית עזר לטוסטים
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