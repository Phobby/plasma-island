/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The settings outlive the widget (SettingsKeeper.qml): written to a file of
    the island's own, read once by a widget that is new. The widget's settings
    and the file are stood in for.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 100
    height: 100

    property var disk: ({})             // path → text
    property int writes: 0
    QtObject {
        id: tools
        function dataHome() { return "/home/someone/.local/share"; }
        function readTextFile(path, most) { return root.disk[path] || ""; }
        function writePrivateFile(path, text) { root.disk[path] = text; ++root.writes; return true; }
    }
    // a widget's settings as they come
    component Settings: QtObject {
        property bool settingsKept: false
        property bool showClock: true
        property int topMargin: 6
        property string customStyle: ""
        property bool previewActive: false
        property string previewStyle: ""
        property string installedVersion: ""
        // (as Plasma's map has them: a default beside every setting)
        property int topMarginDefault: 6
        function keys() { return ["settingsKept", "showClock", "topMargin", "topMarginDefault", "customStyle", "previewActive", "previewStyle", "installedVersion"]; }
    }
    Component { id: settingsMaker; Settings {} }
    Component { id: keeperMaker; SettingsKeeper { writeAfter: 20 } }
    readonly property string file: "/home/someone/.local/share/dynamicisland/settings.json"

    TestCase {
        name: "SettingsKeeper"
        when: windowShown

        function widget(id, local) {
            const cfg = settingsMaker.createObject(root);
            const keeper = keeperMaker.createObject(root, { cfg: cfg, local: local === undefined ? tools : local, appletId: id });
            made.push(keeper, cfg);
            return { cfg: cfg, keeper: keeper };
        }
        function kept() { return JSON.parse(root.disk[root.file]); }
        property var made: []
        function init() { root.disk = {}; root.writes = 0; }
        function cleanup() { for (const o of made) o.destroy(); made = []; wait(40); }

        function test_a_widget_from_before_only_starts_writing() {
            const w = widget(7);
            w.cfg.topMargin = 30;
            compare(w.cfg.settingsKept, true);
            tryVerify(() => root.writes === 1);
            compare(kept(), { applet: 7, values: { customStyle: "", showClock: true, topMargin: 30 } });
            // a change is written a moment later, once; what is only a preview or a note is not
            w.cfg.showClock = false; w.cfg.customStyle = "{}";
            w.cfg.previewActive = true; w.cfg.previewStyle = "x"; w.cfg.installedVersion = "0.2.2";
            tryVerify(() => root.writes === 2);
            wait(80);
            compare(root.writes, 2);
            compare(kept().values, { customStyle: "{}", showClock: false, topMargin: 30 });
        }
        function test_taken_off_and_put_back_it_comes_as_it_was() {
            const first = widget(7);
            first.cfg.topMargin = 30; first.cfg.showClock = false; first.cfg.customStyle = "{\"preset\":\"glass\"}";
            tryVerify(() => root.writes >= 1);
            let brought = -1;
            const cfg = settingsMaker.createObject(root);
            const keeper = keeperMaker.createObject(root, { appletId: 12 });
            made.push(keeper, cfg);
            keeper.restored.connect(count => brought = count);
            keeper.cfg = cfg; keeper.local = tools;
            compare([cfg.topMargin, cfg.showClock, cfg.customStyle, cfg.settingsKept], [30, false, "{\"preset\":\"glass\"}", true]);
            compare(brought, 3);
            tryVerify(() => kept().applet === 12);
        }
        function test_the_shell_starts_again_and_nothing_is_read() {
            const first = widget(7);
            first.cfg.topMargin = 30;
            tryVerify(() => root.writes >= 1);
            // the same widget, its own settings changed elsewhere meanwhile (the file is older)
            const cfg = settingsMaker.createObject(root, { settingsKept: true, topMargin: 12 });
            made.push(keeperMaker.createObject(root, { cfg: cfg, local: tools, appletId: 7 }), cfg);
            compare(cfg.topMargin, 12);
            // and a widget that is new but is the one that wrote the file reads nothing either
            const same = widget(7);
            compare(same.cfg.topMargin, 6);
        }
        function test_what_cannot_be_read_or_is_of_another_kind_is_left() {
            root.disk[root.file] = "{ not json";
            compare(widget(3).cfg.topMargin, 6);
            root.disk[root.file] = JSON.stringify({ applet: 1, values: { topMargin: "wide", showClock: 0, customStyle: "kept", gone: true, settingsKept: false, installedVersion: "9" } });
            const w = widget(4);
            compare([w.cfg.topMargin, w.cfg.showClock, w.cfg.customStyle, w.cfg.installedVersion, w.cfg.settingsKept], [6, true, "kept", "", true]);
        }
        function test_without_the_native_module_nothing_happens_until_it_is_there() {
            root.disk[root.file] = JSON.stringify({ applet: 1, values: { topMargin: 44 } });
            const w = widget(5, null);
            w.cfg.showClock = false;
            wait(60);
            compare([root.writes, w.cfg.settingsKept, w.cfg.topMargin], [0, false, 6]);
            w.keeper.local = tools;
            compare([w.cfg.topMargin, w.cfg.settingsKept], [44, true]);
        }
    }
}
