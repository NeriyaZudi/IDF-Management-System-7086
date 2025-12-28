import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import lottieJs from '@salesforce/resourceUrl/lottie'; 
import animationData from '@salesforce/resourceUrl/home_animation'; 

export default class HomePageAnimation extends LightningElement {
    @api height = 150; 
    
    lottieInitialized = false;
    _lottieInstance = null; 

    renderedCallback() {
        if (this.lottieInitialized) {
            return;
        }
        
        const container = this.template.querySelector('.lottie-container');
        // Ensure container exists and script isn't already loading/loaded
        if(!container || window.lottie) {
             if(window.lottie && container && !this._lottieInstance) {
                 // If JS loaded elsewhere but this instance hasn't run
                 this.initializeLottie(container);
             }
             return;
        }

        this.lottieInitialized = true;
        
        loadScript(this, lottieJs)
            .then(() => {
                // Check container again just in case DOM changed during load
                const targetContainer = this.template.querySelector('.lottie-container');
                if(targetContainer) {
                     this.initializeLottie(targetContainer);
                }
            })
            .catch(error => {
                console.error('Error loading Lottie JS library', error);
                // Allow retry next render cycle if it failed
                this.lottieInitialized = false; 
            });
    }

    initializeLottie(container) {
        // Prevent initializing multiple times on the same container
        if (this._lottieInstance) {
            return;
        }

        if (window.lottie) {
            this._lottieInstance = window.lottie.loadAnimation({
                container: container, 
                renderer: 'svg',
                loop: true,
                autoplay: true,
                path: animationData 
            });
        }
    }
    
    // Makes the container square based on height setting
    get containerStyle() {
        return `width: ${this.height}px; height: ${this.height}px;`;
    }
}