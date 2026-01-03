import { LightningElement, api, wire } from 'lwc';
// 1. שינוי הייבוא למתודה הגנרית החדשה
import getSignatureHistory from '@salesforce/apex/EquipmentSignatureHistoryController.getSignatureHistory';

export default class EquipmentSignatureHistory extends LightningElement {
    @api recordId; // יקבל אוטומטית גם מ-Equipment וגם מ-Night_Device

    data = [];
    error;

    columns = [
        { label: 'חייל', fieldName: 'soldierName' },
        { label: 'טלפון', fieldName: 'soldierPhone' },
        { label: 'יחידה', fieldName: 'soldierUnit' },
        {
            label: 'זמן חתימה',
            fieldName: 'signedTime',
            type: 'date',
            typeAttributes: {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            }
        },
        { label: 'מיקום בעת חתימה', fieldName: 'locationAtSignature' },
        { label: 'הערות', fieldName: 'comments' }
    ];

    // 2. שינוי שם הפרמטר שנשלח ל-Apex מ-equipmentId ל-recordId
    @wire(getSignatureHistory, { recordId: '$recordId' })
    wiredHistory({ data, error }) {
        if (data) {
            this.data = data;
            this.error = undefined;
        } else if (error) {
            console.error(error);
            this.data = [];
            this.error = 'אירעה שגיאה בטעינת היסטוריית החתימות.';
        }
    }

    get hasData() {
        return this.data && this.data.length > 0;
    }

    get noData() {
        return !this.hasData && !this.error;
    }
}