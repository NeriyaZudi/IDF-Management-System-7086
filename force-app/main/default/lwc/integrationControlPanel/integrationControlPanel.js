import { LightningElement, track } from 'lwc';

export default class IntegrationControlPanel extends LightningElement {
    
    // State variables to hold selected row data
    @track selectedObject;
    @track selectedSystemDevName;
    @track selectedSystemLabel;

    // Handler for the event fired by the Child (Trigger Manager)
    handleTriggerSelect(event) {
        const row = event.detail;
        
        // Update state, which flows down to the other Child (Mapping Manager)
        this.selectedObject = row.objectName;
        this.selectedSystemDevName = row.systemDevName;
        this.selectedSystemLabel = row.systemLabel;
    }
}