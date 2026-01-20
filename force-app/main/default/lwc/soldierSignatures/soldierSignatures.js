import { LightningElement, api, wire, track } from 'lwc';
import getSignatures from '@salesforce/apex/SoldierSignaturesController.getSignatures';
import EQUIPMENT_ICON from '@salesforce/resourceUrl/Equipment_icon'; 
import NIGHT_VISION_ICON from '@salesforce/resourceUrl/Nvd_icon';

const COLUMNS = [
    { label: 'Item Name', fieldName: 'itemName', type: 'text' },
    // העמודה החדשה למספר הסידורי
    { label: 'Serial Number', fieldName: 'serialNumber', type: 'text' }, 
    { label: 'Time', fieldName: 'Signed_Time__c', type: 'date', 
      typeAttributes: { day: 'numeric', month: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' } },
    { label: 'Location', fieldName: 'Location_at_Signature__c', type: 'text' },
    { label: 'Comments', fieldName: 'Comments__c', type: 'text' }
];

export default class SoldierSignatures extends LightningElement {
    @api recordId;
    @track equipmentData = [];
    @track nightDeviceData = [];
    
    columns = COLUMNS;
    equipmentIconUrl = EQUIPMENT_ICON;
    nightDeviceIconUrl = NIGHT_VISION_ICON;

    @wire(getSignatures, { soldierId: '$recordId' })
    wiredSignatures({ error, data }) {
        if (data) {
            let tempEquipment = [];
            let tempNightDevice = [];

            data.forEach(sig => {
                let row = { ...sig };

                // לוגיקה לציוד קשר
                if (row.Equipment__c) {
                    row.itemName = row.Equipment__r ? row.Equipment__r.Name : '';
                    // חילוץ המספר הסידורי של הציוד
                    row.serialNumber = row.Equipment__r ? row.Equipment__r.Serial_Number__c : ''; 
                    tempEquipment.push(row);
                } 
                // לוגיקה לאמר"ל
                else if (row.Night_Device__c) {
                    row.itemName = row.Night_Device__r ? row.Night_Device__r.Name : '';
                    // חילוץ המספר הסידורי של האמר"ל
                    row.serialNumber = row.Night_Device__r ? row.Night_Device__r.Serial_Number__c : '';
                    tempNightDevice.push(row);
                }
            });

            this.equipmentData = tempEquipment;
            this.nightDeviceData = tempNightDevice;
        } else if (error) {
            console.error(error);
        }
    }
    
    get hasEquipment() { return this.equipmentData.length > 0; }
    get hasNightDevices() { return this.nightDeviceData.length > 0; }
}