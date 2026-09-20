import QtQuick

// Program dosya işlemlerinin akışı: kaydet, farklı kaydet, aç, yeni, sil.
//
// Açık programda kaydedilmemiş değişiklik varken başka bir program açılırsa, yeni
// program başlatılırsa ya da uygulama kapatılırsa önce sorulur:
// KAYDET / KAYDETME / İPTAL. Kaydetmek için ad gerekiyorsa ad penceresi açılır;
// o ad başka bir programınsa üzerine yazmadan önce onay istenir.
//
// Pencereler (popup) burada durur. TASARIM sayfası ve ana pencere yalnızca bu
// nesnenin fonksiyonlarını çağırır; dosya işlerini C++'taki ProgramStore yapar.
Item {
    id: manager

    required property BendProgram program
    required property ProgramStore store

    // Soru yanıtlanınca (ya da kayıt bitince) yapılacak iş: "open", "new", "close" ya da "".
    property string pending: ""
    property string pendingName: ""

    // Onay penceresi şu an neyi soruyor: "unsaved", "overwrite", "remove" ya da "error".
    property string confirmKind: ""
    property string saveName: ""   // üzerine yazma onayı bekleyen ad
    property string removeName: "" // silme onayı bekleyen program

    // Kayıttan hemen sonra kısa bir süre "Kaydedildi" göstermek için.
    property bool justSaved: false

    // KAYDET'e basılabilir mi? Değişiklik varsa ya da program hiç kaydedilmediyse.
    readonly property bool canSave: manager.program.modified || manager.store.currentName.length === 0

    // Kapanış onaylandı: ana pencere artık kapanabilir.
    signal closeApproved()

    // ---------------- Dışarıdan çağrılanlar ----------------

    function showPrograms() {
        programsDialog.open()
    }

    function save() {
        // Hiç kaydedilmemiş programın adı yok: önce ad sorulur.
        if (manager.store.currentName.length === 0) {
            manager.askName(qsTr("Programı kaydet"))
            return
        }
        if (!manager.store.save()) {
            manager.showError(manager.store.lastError)
            return
        }
        manager.saved()
        manager.finish()
    }

    function saveAs() {
        manager.pending = ""
        manager.askName(qsTr("Farklı kaydet"))
    }

    function openProgram(name: string) {
        manager.run("open", name)
    }

    function newProgram() {
        manager.run("new", "")
    }

    function requestClose() {
        manager.run("close", "")
    }

    function removeProgram(name: string) {
        manager.removeName = name
        manager.confirm("remove", qsTr("Program silinsin mi?"),
                        qsTr("«%1» silinecek. Bu işlem geri alınamaz.").arg(name),
                        qsTr("SİL"), "", qsTr("İPTAL"), Theme.danger)
    }

    // ---------------- İç akış ----------------

    // İşi hemen yap; kaydedilmemiş değişiklik varsa önce sor.
    function run(action: string, name: string) {
        manager.pending = action
        manager.pendingName = name
        if (!manager.program.modified) {
            manager.finish()
            return
        }
        manager.confirm("unsaved", qsTr("Kaydedilmemiş değişiklikler"),
                        qsTr("«%1» programında kaydedilmemiş değişiklikler var.").arg(manager.program.name),
                        qsTr("KAYDET"), qsTr("KAYDETME"), qsTr("İPTAL"), Theme.ok)
    }

    // Bekleyen işi yap (yoksa hiçbir şey yapma).
    function finish() {
        const action = manager.pending
        manager.pending = ""
        if (action === "open") {
            if (manager.store.open(manager.pendingName))
                programsDialog.close()
            else
                manager.showError(manager.store.lastError)
        } else if (action === "new") {
            manager.store.newProgram()
            programsDialog.close()
        } else if (action === "close") {
            manager.closeApproved()
        }
    }

    function askName(title: string) {
        nameDialog.title = title
        nameDialog.initialName = manager.program.name
        nameDialog.open()
    }

    // Ad penceresinde KAYDET: başka bir programın üzerine yazılacaksa önce sor.
    function saveWithName(name: string) {
        if (manager.store.wouldOverwrite(name)) {
            manager.saveName = name
            manager.confirm("overwrite", qsTr("Bu adda bir program var"),
                            qsTr("«%1» zaten kayıtlı. Üzerine yazılsın mı?").arg(name.trim()),
                            qsTr("ÜZERİNE YAZ"), "", qsTr("İPTAL"), Theme.danger)
            return
        }
        manager.writeAs(name)
    }

    function writeAs(name: string) {
        if (!manager.store.saveAs(name)) {
            manager.showError(manager.store.lastError)
            return
        }
        manager.saved()
        manager.finish()
    }

    function removeSelected() {
        if (manager.store.remove(manager.removeName))
            programsDialog.clearSelection()
        else
            manager.showError(manager.store.lastError)
    }

    function saved() {
        manager.justSaved = true
        savedTimer.restart()
    }

    // Bir işlem yapılamadıysa nedenini göster; bekleyen iş iptal olur.
    function showError(text: string) {
        manager.pending = ""
        manager.confirm("error", qsTr("İşlem yapılamadı"), text, qsTr("TAMAM"), "", "", Theme.navSelected)
    }

    function confirm(kind: string, title: string, message: string,
                     acceptText: string, discardText: string, rejectText: string, accent: color) {
        manager.confirmKind = kind
        confirmDialog.title = title
        confirmDialog.message = message
        confirmDialog.acceptText = acceptText
        confirmDialog.discardText = discardText
        confirmDialog.rejectText = rejectText
        confirmDialog.acceptAccent = accent
        confirmDialog.open()
    }

    ConfirmDialog {
        id: confirmDialog

        onAccepted: {
            if (manager.confirmKind === "unsaved")
                manager.save()
            else if (manager.confirmKind === "overwrite")
                manager.writeAs(manager.saveName)
            else if (manager.confirmKind === "remove")
                manager.removeSelected()
        }
        onDiscarded: {
            if (manager.confirmKind === "unsaved")
                manager.finish()
        }
        onRejected: {
            // Vazgeçildi: bekleyen iş (aç, yeni, kapat) de iptal.
            if (manager.confirmKind === "unsaved" || manager.confirmKind === "overwrite")
                manager.pending = ""
        }
    }

    NameDialog {
        id: nameDialog

        store: manager.store
        onNameAccepted: name => manager.saveWithName(name)
        onCancelled: manager.pending = ""
    }

    ProgramsDialog {
        id: programsDialog

        store: manager.store
        onOpenRequested: name => manager.openProgram(name)
        onNewRequested: manager.newProgram()
        onSaveAsRequested: manager.saveAs()
        onRemoveRequested: name => manager.removeProgram(name)
    }

    Timer {
        id: savedTimer

        interval: 2500
        onTriggered: manager.justSaved = false
    }
}
