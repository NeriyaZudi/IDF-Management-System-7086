import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader'; 
import lottieJs from '@salesforce/resourceUrl/lottie'; 
import ANIMATION_DATA from '@salesforce/resourceUrl/AllClearAnimation'; 
import runRecoveryNow from '@salesforce/apex/IntegrationRecoveryController.runRecoveryNow';
import scheduleAutoRecovery from '@salesforce/apex/IntegrationRecoveryController.scheduleAutoRecovery';
import isRecoveryScheduled from '@salesforce/apex/IntegrationRecoveryController.isRecoveryScheduled';
import getRecentFailedRequests from '@salesforce/apex/IntegrationRecoveryController.getRecentFailedRequests';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const COLUMNS = [
    { label: 'Request', fieldName: 'Name' },
    { label: 'System', fieldName: 'SystemKey__c' },
    { label: 'Object', fieldName: 'SObjectApiName__c' },
    { label: 'Error', fieldName: 'LastErrorMessage__c' },
    { label: 'Next Retry', fieldName: 'NextRunAt__c', type: 'date', 
      typeAttributes: { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' } }
];

export default class IntegrationRecoveryManager extends NavigationMixin(LightningElement) {
    @track isScheduled = false;
    @track recentFailures = [];
    columns = COLUMNS;
    wiredFailuresResult;
    
    lottieInitialized = false; 
    animationInstance;

    @wire(isRecoveryScheduled)
    wiredStatus({ error, data }) {
        if (data !== undefined) this.isScheduled = data;
    }

    @wire(getRecentFailedRequests)
    wiredRequests(result) {
        this.wiredFailuresResult = result;
        if (result.data) {
            this.recentFailures = result.data;
            this.handleAnimationLogic();
        }
    }

    renderedCallback() {
        this.handleAnimationLogic();
    }

    handleAnimationLogic() {
        if (!this.lottieInitialized) {
            this.lottieInitialized = true;
            loadScript(this, lottieJs)
                .then(() => {
                    this.initializeLottie();
                })
                .catch(error => console.error('Lottie Load Error', error));
        } else {
            this.initializeLottie();
        }
    }

    initializeLottie() {
        const container = this.template.querySelector('.lottie-container');

        if (container && window.lottie && !this.animationInstance) {
            if(this.animationInstance) this.animationInstance.destroy();
            this.animationInstance = window.lottie.loadAnimation({
                container: container, 
                renderer: 'svg',
                loop: true,
                autoplay: true,
                path: ANIMATION_DATA 
            });
        }
        else if (!container && this.animationInstance) {
            this.animationInstance.destroy();
            this.animationInstance = null;
        }
    }

    
    handleRunNow() {
        runRecoveryNow()
            .then(() => {
                this.showToast('Success', 'Recovery Batch Enqueued successfully.', 'success');
                return refreshApex(this.wiredFailuresResult);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    handleSchedule() {
        scheduleAutoRecovery()
            .then(() => {
                this.showToast('Success', 'Automation Activated!', 'success');
                this.isScheduled = true;
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            });
    }

    handleNavigateToListView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Integration_Request__c',
                actionName: 'list'
            },
            state: { filterName: 'Recent' }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}