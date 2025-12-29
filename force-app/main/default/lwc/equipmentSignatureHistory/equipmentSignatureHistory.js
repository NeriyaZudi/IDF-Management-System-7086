import { LightningElement, api, wire } from 'lwc';
import getHistoryForEquipment from '@salesforce/apex/EquipmentSignatureHistoryController.getHistoryForEquipment';

export default class EquipmentSignatureHistory extends LightningElement {
    @api recordId; // Equipment__c Id

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

    @wire(getHistoryForEquipment, { equipmentId: '$recordId' })
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
