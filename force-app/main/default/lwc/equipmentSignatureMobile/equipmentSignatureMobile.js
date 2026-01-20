import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// ייבוא Apex
import getSoldiers from '@salesforce/apex/EquipmentSignatureController.getSoldiers';
import getEquipmentById from '@salesforce/apex/EquipmentSignatureController.getEquipmentById'; // הפונקציה החדשה
import createSignatures from '@salesforce/apex/EquipmentSignatureController.createSignatures';

export default class EquipmentSignatureMobile extends LightningElement {
    @api recordId;
    
    // ניהול חיילים וחיפוש
    @track allSoldiers = [];      // כל החיילים שחזרו מהשרת
    @track filteredSoldiers = []; // הרשימה המוצגת (אחרי סינון)
    soldierSearchTerm = '';       // מה שהמשתמש מקליד
    selectedSoldierId;            // ה-ID שנבחר
    showSoldierList = false;      // האם להציג את הרשימה

    // פרטי הציוד
    @track equipment;
    
    location = '';
    comments = '';
    isLoading = false;

    // שליפת ה-ID מה-URL
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
        }
    }

    // טעינת החיילים (פעם אחת)
    @wire(getSoldiers)
    wiredSoldiers({ data, error }) {
        if (data) {
            // המרה לפורמט נוח לחיפוש
            this.allSoldiers = data.map(soldier => ({
                id: soldier.value, 
                label: soldier.label, // שם החייל
                subLabel: soldier.description || '' // יחידה/פרטים נוספים אם יש
            }));
            this.filteredSoldiers = [...this.allSoldiers];
        } else if (error) {
            console.error(error);
        }
    }

    // טעינת הציוד הספציפי
    @wire(getEquipmentById, { equipmentId: '$recordId' })
    wiredEquipment({ data, error }) {
        if (data) {
            this.equipment = data;
        } else if (error) {
            this.showToast('שגיאה', 'לא ניתן לטעון את פרטי הציוד', 'error');
        }
    }

    // --- לוגיקה של חיפוש חייל ---

    handleSearch(event) {
        const searchTerm = event.target.value;
        this.soldierSearchTerm = searchTerm;
        this.selectedSoldierId = null; // איפוס בחירה אם מקלידים מחדש
        this.showSoldierList = true;

        if (searchTerm) {
            this.filteredSoldiers = this.allSoldiers.filter(soldier => 
                soldier.label.toLowerCase().includes(searchTerm.toLowerCase())
            );
        } else {
            this.filteredSoldiers = [...this.allSoldiers];
        }
    }

    selectSoldier(event) {
        const soldierId = event.currentTarget.dataset.id;
        const selectedSoldier = this.allSoldiers.find(s => s.id === soldierId);
        
        if (selectedSoldier) {
            this.soldierSearchTerm = selectedSoldier.label;
            this.selectedSoldierId = soldierId;
            this.showSoldierList = false; // הסתרת הרשימה
        }
    }

    handleFocus() {
        this.showSoldierList = true;
    }

    get isSoldierListEmpty() {
        return this.filteredSoldiers.length === 0;
    }

    // --- סוף לוגיקה של חיפוש ---

    handleLocationChange(e) { this.location = e.detail.value; }
    handleCommentsChange(e) { this.comments = e.detail.value; }

    get isSignDisabled() {
        return !this.selectedSoldierId || !this.equipment || this.isLoading;
    }

    async handleSign() {
        this.isLoading = true;
        try {
            await createSignatures({
                soldierId: this.selectedSoldierId,
                equipmentIds: [this.recordId], // שולחים רק את הציוד הנוכחי במערך
                location: this.location,
                comments: this.comments
            });

            this.showToast('הצלחה', 'חתימה בוצעה בהצלחה', 'success');
            
            // חזרה אחורה לדף הציוד
            window.history.back();

        } catch (error) {
            let msg = error.body?.message || 'שגיאה לא ידועה';
            this.showToast('שגיאה', msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}