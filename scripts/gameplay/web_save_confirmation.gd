extends RefCounted
## Read-only browser confirmation of a *canonical* P0 file after FileAccess
## flush and Godot's asynchronous IndexedDB sync. Never stores game state.
## Unlike a fixed delay, confirms the exact saved file hash and revision.
var request_id: int = 0
var revision: int = -1
var status: String = "idle"

const BEGIN_JS = """
(function () {
    const input = %s;
    const key = "__nileKioskSaveConfirmation";
    window[key] = {id: input.id, status: "pending"};
    const live = () => window[key] && window[key].id === input.id;
    const scan = async () => {
        if (!indexedDB.databases || !crypto.subtle) {
            throw new Error("Browser IndexedDB verification is unavailable");
        }
        const databases = await indexedDB.databases();
        for (const info of databases) {
            if (!info.name || !live()) continue;
            const db = await new Promise((resolve, reject) => {
                const request = indexedDB.open(info.name);
                request.onsuccess = () => resolve(request.result);
                request.onerror = () => reject(request.error);
            });
            try {
                if (!db.objectStoreNames.contains("FILE_DATA")) continue;
                const saved = await new Promise((resolve, reject) => {
                    const store = db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA");
                    const request = store.openCursor();
                    request.onsuccess = () => {
                        const cursor = request.result;
                        if (!cursor) { resolve(null); return; }
                        if (String(cursor.key).endsWith("/" + input.file)) {
                            resolve(cursor.value.contents);
                        } else {
                            cursor.continue();
                        }
                    };
                    request.onerror = () => reject(request.error);
                });
                if (!saved) continue;
                const bytes = saved instanceof Uint8Array ? saved : new Uint8Array(saved);
                const candidate = JSON.parse(new TextDecoder().decode(bytes));
                if (candidate.sequence !== input.revision) continue;
                const hashed = await crypto.subtle.digest("SHA-256", bytes);
                const digest = [...new Uint8Array(hashed)]
                    .map(v => v.toString(16).padStart(2, "0")).join("");
                if (digest === input.digest) return true;
            } finally {
                db.close();
            }
        }
        return false;
    };
    (async () => {
        try {
            for (let tries = 0; tries < 100; tries++) {
                if (!live()) return; // Superseded by a more recent save.
                if (await scan()) {
                    if (live()) window[key].status = "confirmed";
                    return;
                }
                await new Promise(resolve => setTimeout(resolve, 150));
            }
            if (live()) window[key].status = "unconfirmed";
        } catch (error) {
            console.warn("Nile Kiosk browser save confirmation failed:", error);
            if (live()) window[key].status = "unconfirmed";
        }
    })();
    return true;
})()
"""

func begin(path: String, saved_revision: int, digest: String) -> void:
    revision = saved_revision
    status = "pending"
    request_id += 1
    # Native saves are already read back and verified by WorldSession.save().
    if not OS.has_feature("web"): 
        status = "not_web"
        return
    if not OS.is_userfs_persistent():
        status = "unconfirmed"
        return
    # Built-in Godot Web sync is asynchronous, even after FileAccess.flush().
    # We do not claim durability until IndexedDB contains the exact SHA-256.
    JavaScriptBridge.force_fs_sync()
    var args: String = JSON.stringify({"id":request_id,"file":path.get_file(),
        "revision":saved_revision,"digest":digest})
    if JavaScriptBridge.eval(BEGIN_JS % args, true) != true:
        status = "unconfirmed"

func poll() -> String:
    if status != "pending" or not OS.has_feature("web"):
        return status
    var js: String = "(function() { const x = window.__nileKioskSaveConfirmation; return x && x.id === %d ? x.status : 'unconfirmed'; })()" % request_id
    var value: Variant = JavaScriptBridge.eval(js, true)
    if value in ["confirmed","unconfirmed"]:
        status = str(value)
    return status
