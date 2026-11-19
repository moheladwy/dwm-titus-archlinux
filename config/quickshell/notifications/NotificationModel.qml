import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.core

pragma ComponentBehavior: Bound

Scope {
    id: root

    property var notifications: []
    property var history: []
    // Notifications that are still open and carry actions, by item key. Kept
    // out of history because history is saved as JSON.
    property var actionable: ({})
    property bool historyVisible: false
    // The notification center dropped down from the panel bell.
    property bool panelVisible: false
    // Desktop state (running windows and focus), used to bring a
    // notification's app forward when its own action is no longer available.
    property var desktopState: null
    // Entries newer than this were not yet seen in the notification center.
    property real seenAt: 0
    readonly property int unreadCount: root.history.filter(entry => (entry.timestamp || 0) > root.seenAt).length
    property int sequence: 0
    readonly property string sessionKey: Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    property bool doNotDisturb: false
    property int popupTimeoutMs: 6000
    property string policyState: "loading"
    readonly property bool initialLoading: policyState === "loading" || policyState === "defaults" || policySaving
    property string policyDetail: "Loading notification policy"
    property bool policySaving: false
    property bool policyReloadPending: false
    property bool confirmedDoNotDisturb: false
    property int confirmedPopupTimeoutMs: 6000

    readonly property int criticalTimeoutMs: 10000
    readonly property int maxVisible: 4
    readonly property int maxHistory: 50
    readonly property var popupTimeoutOptions: [4000, 6000, 10000]
    readonly property bool popupSuppressed: root.policyState === "loading"
        || root.policyState === "partial"
        || root.policyState === "unavailable"
        || root.policySaving || root.doNotDisturb
    readonly property bool policyMutationReady: !root.policySaving
        && (root.policyState === "available" || root.policyState === "defaults")
    readonly property bool policyResetReady: !root.policySaving
        && root.policyState !== "loading"
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configuredConfigHome: Quickshell.env("XDG_CONFIG_HOME") || ""
    readonly property string configHome: root.configuredConfigHome.startsWith("/")
        ? root.configuredConfigHome : root.homeDir + "/.config"
    readonly property string configDir: root.configHome + "/dwm-titus"
    readonly property string policyPath: root.configDir + "/notification-settings.json"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/dwm-titus"
    readonly property string historyPath: cacheDir + "/notification-history.json"

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", configDir, cacheDir])

    function validPopupTimeout(value) {
        return root.popupTimeoutOptions.indexOf(value) >= 0;
    }

    function usePolicyDefaults() {
        root.doNotDisturb = false;
        root.popupTimeoutMs = 6000;
    }

    function dismissNonCriticalPopups() {
        const current = root.notifications.slice();
        for (const item of current) {
            if (item.urgencyName !== "critical") root.closeItem(item, false);
        }
    }

    function applyDoNotDisturb(enabled) {
        root.doNotDisturb = enabled;
        if (enabled) root.dismissNonCriticalPopups();
    }

    function beginPolicyReload(dismissExisting) {
        root.policyState = "loading";
        root.policyDetail = "Reloading notification policy";
        if (dismissExisting !== false) root.dismissNonCriticalPopups();
        policyFile.reload();
    }

    function loadPolicy() {
        let policy = null;
        try {
            policy = JSON.parse(policyFile.text());
        } catch (error) {
            root.usePolicyDefaults();
            root.dismissNonCriticalPopups();
            root.policyState = "partial";
            root.policyDetail = "Saved notification policy could not be parsed; safe defaults are active until reset";
            return;
        }
        if (policy === null || typeof policy !== "object" || Array.isArray(policy)
                || policy.version !== 1 || typeof policy.doNotDisturb !== "boolean"
                || !root.validPopupTimeout(policy.popupTimeoutMs)) {
            root.usePolicyDefaults();
            root.dismissNonCriticalPopups();
            root.policyState = "partial";
            root.policyDetail = "Saved notification policy is invalid; safe defaults are active until reset";
            return;
        }
        root.applyDoNotDisturb(policy.doNotDisturb);
        root.popupTimeoutMs = policy.popupTimeoutMs;
        if (root.policySaving) return;
        root.confirmedDoNotDisturb = root.doNotDisturb;
        root.confirmedPopupTimeoutMs = root.popupTimeoutMs;
        root.policyState = "available";
        root.policyDetail = "Managed notification policy is active";
    }

    function savePolicy() {
        root.policySaving = true;
        root.policyState = "saving";
        root.policyDetail = "Saving notification policy";
        policyFile.setText(JSON.stringify({
            "version": 1,
            "doNotDisturb": root.doNotDisturb,
            "popupTimeoutMs": root.popupTimeoutMs
        }) + "\n");
    }

    function setDoNotDisturb(enabled) {
        if (!root.policyMutationReady || root.doNotDisturb === enabled) return;
        root.applyDoNotDisturb(enabled);
        root.savePolicy();
    }

    function setPopupTimeout(value) {
        if (!root.policyMutationReady || !root.validPopupTimeout(value)
                || root.popupTimeoutMs === value) return;
        root.popupTimeoutMs = value;
        root.savePolicy();
    }

    function resetPolicy() {
        if (!root.policyResetReady) return;
        if ((root.policyState === "available" || root.policyState === "defaults")
                && !root.doNotDisturb
                && root.popupTimeoutMs === 6000) return;
        root.usePolicyDefaults();
        root.savePolicy();
    }

    function policyStatus() {
        return "notification-policy\t1\t" + Quickshell.processId + "\t"
            + (root.policyMutationReady ? "available" : "unavailable");
    }

    function urgencyName(urgency) {
        if (urgency === NotificationUrgency.Critical) {
            return "critical";
        }
        if (urgency === NotificationUrgency.Low) {
            return "low";
        }
        return "normal";
    }

    function snapshot(notification, key) {
        const actions = (notification.actions || []).map(action => ({
            "identifier": action.identifier,
            "text": action.text
        }));
        const critical = notification.urgency === NotificationUrgency.Critical;
        return {
            "key": key,
            "notification": notification,
            "appName": notification.appName || "Notification",
            "summary": notification.summary || "",
            "body": notification.body || "",
            "urgency": notification.urgency,
            "urgencyName": root.urgencyName(notification.urgency),
            "desktopEntry": notification.desktopEntry || "",
            "appIcon": notification.appIcon || "",
            "transient": notification.transient === true,
            "diagnose": root.diagnoseArgs(notification.appName,
                (notification.hints || {})["x-dwm-titus-diagnose"]),
            "actions": actions,
            "hasDefaultAction": actions.some(action => action.identifier === "default"),
            // A critical notification that asks for a decision stays up until
            // the user answers or dismisses it.
            "timeoutMs": critical && actions.length > 0 ? 0
                : critical ? root.criticalTimeoutMs : root.popupTimeoutMs
        };

    }

    function add(notification) {
        if (!notification) return;
        notification.tracked = true;
        root.sequence += 1;
        const key = root.sessionKey + "-" + notification.id + "-" + root.sequence;
        const item = root.snapshot(notification, key);
        let closed = false;
        let watchedActions = [];
        function refresh() {
            if (closed) return;
            // Action objects can be reused when only their label changes.
            const currentActions = notification.actions || [];
            for (const action of watchedActions) {
                if (action && action.textChanged && currentActions.indexOf(action) < 0)
                    action.textChanged.disconnect(scheduleRefresh);
            }
            for (const action of currentActions) {
                if (watchedActions.indexOf(action) < 0) action.textChanged.connect(scheduleRefresh);
            }
            watchedActions = currentActions.slice();
            const updated = root.snapshot(notification, key);
            const visible = root.notifications.some(n => n.key === key);
            root.notifications = root.notifications.map(n => n.key === key ? updated : n);
            if (updated.actions.length > 0) root.rememberActionable(key, notification);
            else root.forgetActionable(key);
            root.addHistory(updated);
            if (!root.keepsOpen(updated)
                    && ((root.popupSuppressed && updated.urgencyName !== "critical") || !visible))
                notification.expire();
        };
        // Quickshell may emit label signals while it is still replacing the
        // list. Refresh once after the whole update, not from partial state.
        function scheduleRefresh() { Qt.callLater(refresh); }
        notification.actionsChanged.connect(scheduleRefresh);
        notification.urgencyChanged.connect(scheduleRefresh);
        notification.appNameChanged.connect(scheduleRefresh);
        notification.summaryChanged.connect(scheduleRefresh);
        notification.bodyChanged.connect(scheduleRefresh);
        watchedActions = (notification.actions || []).slice();
        for (const action of watchedActions) action.textChanged.connect(scheduleRefresh);

        notification.closed.connect(() => {
            closed = true;
            root.remove(item.key);
            root.forgetActionable(item.key);
        });
        if (item.actions.length > 0) root.rememberActionable(item.key, notification);
        root.addHistory(item);

        if (root.popupSuppressed && item.urgencyName !== "critical") {
            if (!root.keepsOpen(item)) {
                // Closing it while it is still being delivered emits no
                // closed signal, so forget it here.
                closed = true;
                root.forgetActionable(item.key);
                notification.expire();
            }
            return;
        }

        const existing = root.notifications.filter(n => n.notification && n.notification.id !== notification.id);
        const candidates = [item].concat(existing);
        const overflow = candidates.slice(root.maxVisible);
        root.notifications = candidates.slice(0, root.maxVisible);

        for (const overflowItem of overflow) {
            root.closeItem(overflowItem, root.keepsOpen(overflowItem));
        }
    }

    // A notification with actions stays open after its popup goes away, so the
    // notification center can still run them (clicking an entry runs its
    // default action, which takes you to the chat, tab or file it is about).
    // It closes when it is answered, cleared, or pushed out of the history.
    // Transient notifications ask not to be kept, so they close with their popup.
    function keepsOpen(item) {
        return item.transient !== true && (item.actions || []).length > 0;
    }

    function rememberActionable(key, notification) {
        const next = Object.assign({}, root.actionable);
        next[key] = notification;
        root.actionable = next;
    }

    function forgetActionable(key) {
        if (!(key in root.actionable)) return;
        const next = Object.assign({}, root.actionable);
        delete next[key];
        root.actionable = next;
    }

    function actionsFor(key) {
        const notification = root.actionable[key];
        if (!notification) return [];
        return (notification.actions || []).map(action => ({
            "identifier": action.identifier,
            "text": action.text
        }));
    }

    function invokeAction(key, identifier) {
        const notification = root.actionable[key];
        if (!notification) return false;
        const action = (notification.actions || []).find(candidate => candidate.identifier === identifier);
        if (!action) return false;
        // A click queued before the coalesced refresh must not run a newly
        // relabeled action under an old popup label.
        const popup = root.notifications.find(item => item.key === key);
        const shown = popup ? popup.actions.find(candidate => candidate.identifier === identifier) : null;
        if (popup && (!shown || shown.text !== action.text)) return false;
        root.remove(key);
        // Quickshell reports ActionInvoked and closes a non-resident
        // notification, which forgets it through the closed handler.
        action.invoke();
        // Ignore means the user is done with it; any other answer keeps the
        // entry in the history.
        if (identifier === "ignore") root.dropHistory(key);
        return true;
    }

    // dwm-titus crash and hang alerts carry the dwm-agent-diagnose arguments
    // in an x-dwm-titus-diagnose hint (tab-separated), so Diagnose with AI
    // keeps working from the history after the alert has closed. Returns the
    // arguments, or [] when the value is not a well-formed request.
    function diagnoseArgs(appName, value) {
        if (appName !== "dwm-titus" || typeof value !== "string" || value.length > 2048) return [];
        const fields = value.split("\t");
        if (fields.some(field => field.length > 256)) return [];
        if (fields[0] === "crash" && fields.length <= 7 && /^[0-9]+$/.test(fields[1] || "")) return fields;
        if (fields[0] === "hang" && fields.length <= 5 && /^(0x[0-9a-fA-F]+|[0-9]+)$/.test(fields[1] || ""))
            return fields;
        return [];
    }

    function savedDiagnoseArgs(entry) {
        // History loaded from disk holds Qt lists, not JavaScript arrays.
        const saved = entry && entry.diagnose && typeof entry.diagnose !== "string"
            ? Array.from(entry.diagnose) : [];
        return saved.length > 0 && saved.every(field => typeof field === "string")
            ? root.diagnoseArgs(entry.appName, saved.join("\t")) : [];
    }

    // The buttons an entry offers: the notification's own actions while it is
    // open, otherwise Diagnose with AI and Ignore for a saved dwm-titus alert.
    function entryActions(key) {
        if (root.actionable[key]) return root.actionsFor(key);
        const entry = root.history.find(item => item.key === key);
        return root.savedDiagnoseArgs(entry).length > 0 ? [
            { "identifier": "diagnose", "text": "Diagnose with AI" },
            { "identifier": "ignore", "text": "Ignore" }
        ] : [];
    }

    function runEntryAction(key, identifier) {
        if (root.actionable[key]) return root.invokeAction(key, identifier);
        const entry = root.history.find(item => item.key === key);
        const args = root.savedDiagnoseArgs(entry);
        if (args.length === 0) return false;
        if (identifier === "ignore") {
            root.dropHistory(key);
            return true;
        }
        if (identifier !== "diagnose") return false;
        Quickshell.execDetached(Commands.helperCommand("dwm-agent-diagnose", null, args, false));
        return true;
    }

    // Removes an entry whose notification is already answered or closed.
    function dropHistory(key) {
        root.forgetActionable(key);
        if (!root.history.some(entry => entry.key === key)) return;
        root.history = root.history.filter(entry => entry.key !== key);
        root.saveHistory();
    }

    function remove(key) {
        root.notifications = root.notifications.filter(n => n.key !== key);
    }

    function clear() {
        const current = root.notifications.slice();
        root.notifications = [];

        for (const item of current) {
            root.closeItem(item, false);
        }
    }

    function addHistory(item) {
        const entry = {
            "key": item.key,
            "appName": item.appName,
            "summary": item.summary,
            "body": item.body,
            "urgency": item.urgency,
            "urgencyName": item.urgencyName,
            "desktopEntry": item.desktopEntry || "",
            "appIcon": item.appIcon || "",
            "diagnose": item.diagnose || [],
            "timestamp": Date.now()
        };

        const kept = [entry].concat(root.history.filter(previous => previous.key !== item.key));
        root.history = kept.slice(0, root.maxHistory);
        // An actionable notification pushed out of the history and not on
        // screen can no longer be answered, so close it instead of keeping it.
        for (const evicted of kept.slice(root.maxHistory)) {
            if (root.notifications.some(n => n.key === evicted.key)) continue;
            const notification = root.actionable[evicted.key];
            if (notification) notification.dismiss();
        }
        root.saveHistory();
    }

    function clearHistory() {
        for (const key of Object.keys(root.actionable)) {
            const notification = root.actionable[key];
            if (notification) notification.dismiss();
        }
        root.actionable = {};
        root.history = [];
        root.saveHistory();
    }

    // Clears the given history entries. A notification that is still open is
    // dismissed too, so its app knows it was cleared.
    function removeHistory(keys) {
        const removed = (keys || []).filter(key => root.history.some(entry => entry.key === key));
        if (removed.length === 0) return;
        for (const key of removed) {
            const popup = root.notifications.find(item => item.key === key);
            const notification = root.actionable[key];
            if (popup) root.closeItem(popup, false);
            else if (notification) notification.dismiss();
            root.forgetActionable(key);
        }
        root.history = root.history.filter(entry => removed.indexOf(entry.key) < 0);
        root.saveHistory();
    }

    function markSeen() {
        const newest = root.history.reduce((latest, entry) => Math.max(latest, entry.timestamp || 0), 0);
        if (newest <= root.seenAt) return;
        root.seenAt = newest;
        root.saveHistory();
    }

    function closeHistory() {
        root.historyVisible = false;
    }

    function openHistory() {
        root.historyVisible = true;
        root.markSeen();
    }

    function toggleHistory() {
        if (root.historyVisible) root.closeHistory();
        else root.openHistory();
    }

    function closePanel() {
        root.panelVisible = false;
    }

    function openPanel() {
        root.panelVisible = true;
        root.markSeen();
    }

    function togglePanel() {
        if (root.panelVisible) root.closePanel();
        else root.openPanel();
    }

    // Lower-case names a window class of the notification's app could have:
    // its desktop entry id (and that id's last reverse-DNS part), the entry's
    // StartupWMClass, and its app name.
    function sourceNames(entry) {
        const names = [];
        function addName(value) {
            const name = (value || "").toString().trim().toLowerCase();
            if (name.length === 0) return;
            for (const candidate of [name, name.replace(/\s+/g, "-"), name.split(".").pop()])
                if (candidate.length > 0 && names.indexOf(candidate) < 0) names.push(candidate);
        }
        addName(entry.desktopEntry);
        addName(entry.appName);
        const app = root.sourceApp(entry);
        if (app) {
            addName(app.id);
            addName(app.startupClass);
        }
        return names;
    }

    function sourceApp(entry) {
        const desktopEntry = (entry.desktopEntry || "").toString();
        const byId = desktopEntry.length > 0 ? DesktopEntries.byId(desktopEntry) : null;
        if (byId) return byId;
        const name = (entry.appName || "").toString();
        return name.length > 0 ? DesktopEntries.heuristicLookup(name) : null;
    }

    // The first open window of the notification's app, or "".
    function sourceWindow(entry) {
        const apps = root.desktopState ? (root.desktopState.runningApps || []) : [];
        const names = root.sourceNames(entry);
        const match = apps.find(app => {
            const appClass = (app.appClass || "").toLowerCase();
            return names.indexOf(appClass) >= 0 || names.indexOf(appClass.split(".").pop()) >= 0;
        });
        return match ? match.windowId : "";
    }

    // Takes the user to what a notification is about. A notification that is
    // still open runs its default action, which lets the app show the exact
    // chat, tab or file. The app's window is then brought forward (dwm only
    // marks an app's own focus request as urgent). When the window is closed,
    // the app is started instead. Returns what it did.
    function openSource(key) {
        const entry = root.history.find(item => item.key === key);
        if (!entry) return "missing";
        const ranAction = root.actionsFor(key).some(action => action.identifier === "default")
            && root.invokeAction(key, "default");
        const windowId = root.sourceWindow(entry);
        if (windowId.length > 0 && root.desktopState) {
            root.desktopState.focusWindow(windowId);
            return ranAction ? "action" : "window";
        }
        if (ranAction) return "action";
        const app = root.sourceApp(entry);
        if (app && !app.noDisplay) {
            app.execute();
            return "launch";
        }
        return "none";
    }

    function historyLatestSummary() {
        return root.history.length > 0 ? root.history[0].summary : "";
    }

    function loadHistory() {
        root.history = (historyFile.notifications || []).slice(0, root.maxHistory);
        root.seenAt = Number(historyFile.seenAt) || 0;
    }

    function saveHistory() {
        historyFile.notifications = root.history;
        historyFile.seenAt = root.seenAt;
        historyFile.writeAdapter();
    }

    function closeItem(item, expired) {
        if (!item) {
            return;
        }

        root.remove(item.key);
        if (!item.notification) {
            return;
        }

        // Leaves the popup list but stays open, so its actions remain
        // available from the history.
        if (expired && root.keepsOpen(item)) {
            if (!root.history.some(entry => entry.key === item.key)) item.notification.dismiss();
            return;
        }

        if (expired) {
            item.notification.expire();
        } else {
            item.notification.dismiss();
        }
    }

    function dismiss(key) {
        root.closeItem(root.notifications.find(n => n.key === key), false);
    }

    function expire(key) {
        root.closeItem(root.notifications.find(n => n.key === key), true);
    }

    FileView {
        id: policyFile

        path: root.policyPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadPolicy()
        onFileChanged: {
            if (root.policySaving) root.policyReloadPending = true;
            else root.beginPolicyReload(false);
        }
        onSaved: {
            root.confirmedDoNotDisturb = root.doNotDisturb;
            root.confirmedPopupTimeoutMs = root.popupTimeoutMs;
            root.policySaving = false;
            if (root.policyReloadPending) {
                root.policyReloadPending = false;
                root.policyState = "loading";
                root.policyDetail = "Reloading notification policy";
                Qt.callLater(policyFile.reload);
            } else {
                root.policyState = "available";
                root.policyDetail = "Managed notification policy is active";
            }
        }
        onSaveFailed: error => {
            root.applyDoNotDisturb(root.confirmedDoNotDisturb);
            root.popupTimeoutMs = root.confirmedPopupTimeoutMs;
            root.policySaving = false;
            if (root.policyReloadPending) {
                root.policyReloadPending = false;
                root.policyState = "loading";
                root.policyDetail = "Reloading notification policy after save error " + error;
                Qt.callLater(policyFile.reload);
            } else {
                root.policyState = "unavailable";
                root.policyDetail = "Notification policy could not be saved (error " + error + ")";
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.usePolicyDefaults();
                root.policyState = "defaults";
                root.policyDetail = "Default notification policy is active";
                Qt.callLater(root.savePolicy);
            } else {
                root.applyDoNotDisturb(root.confirmedDoNotDisturb);
                root.popupTimeoutMs = root.confirmedPopupTimeoutMs;
                root.dismissNonCriticalPopups();
                root.policyState = "unavailable";
                root.policyDetail = "Notification policy could not be loaded";
            }
        }
    }

    FileView {
        id: historyFile

        property alias notifications: historyAdapter.notifications
        property alias seenAt: historyAdapter.seenAt

        path: root.historyPath
        printErrors: false
        onLoaded: root.loadHistory()
        onLoadFailed: error => {
            if (error === 2) {
                root.saveHistory();
            }
        }

        // qmllint disable unresolved-type
        adapter: JsonAdapter {
            id: historyAdapter

            property var notifications: []
            property real seenAt: 0
        }
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: false
        persistenceSupported: true

        onNotification: notification => root.add(notification)
    }
}
