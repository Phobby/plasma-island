/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Settings → Diagnostics → Feedback (FeedbackForm.qml): without an address
    nothing is sent and GitHub is offered; with one, Send posts exactly what
    "What is sent" shows, through the real relay (tests/feedback-server.mjs,
    started by tools/run-tests, with a stand-in Telegram) into the chat, the
    report only when ticked; at most three an hour: the form counts its own,
    across a closed and reopened window, and a fourth that reaches the relay
    is refused with how long to wait; no connection says so and keeps the text.
*/
import QtQuick
import QtCore
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 700
    height: 900

    readonly property string relay: "http://127.0.0.1:47391/"
    // (a file of the test's own, never the user's settings window's)
    readonly property url memory: StandardPaths.writableLocation(StandardPaths.TempLocation) + "/tst_feedback-" + Date.now() + ".conf"

    FeedbackForm { id: none; width: 600; endpoint: ""; remember: false }
    FeedbackForm { id: nowhere; width: 600; y: 100; endpoint: "http://127.0.0.1:1/"; remember: false }
    FeedbackForm {
        id: first
        width: 600; y: 300
        endpoint: root.relay
        remember: false
        reportText: () => "Dynamic Island diagnostics\nisland: 0.2.2"
        meta: ({ island: "0.2.2", language: "en", session: "Wayland" })
    }
    FeedbackForm { id: second; width: 600; y: 600; endpoint: root.relay; remember: false }
    Component { id: remembering; FeedbackForm { width: 600; endpoint: root.relay; memoryFile: root.memory } }

    function request(method: string, path: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => { if (xhr.readyState === XMLHttpRequest.DONE) done(xhr.status, xhr.responseText); };
        xhr.open(method, root.relay.replace(/\/$/, "") + path);
        xhr.send();
    }

    TestCase {
        name: "Feedback"
        when: windowShown

        property int status: -1
        property string text: ""
        function ask(method, path) {
            status = -1;
            root.request(method, path, (s, t) => { status = s; text = t; });
            tryVerify(() => status !== -1, 5000);
        }
        function type(form, message) {
            findChild(form, "feedbackMessage").text = message;
        }
        function sendAndWait(form, message) {
            type(form, message);
            form.send();
            tryVerify(() => form.state !== "sending", 10000);
            return form.state;
        }

        function test_without_an_address() {
            compare(none.configured, false);
            verify(findChild(none, "feedbackIntro").text.indexOf("GitHub") >= 0);
            compare(findChild(none, "feedbackSend").visible, false);
            type(none, "hello");
            none.send();
            compare(none.requests, 0);
        }

        function test_nothing_written_nothing_sent() {
            const form = createTemporaryObject(remembering, root, { remember: false });
            compare(form.built.ok, false);
            compare(findChild(form, "feedbackSend").enabled, false);
            form.send();
            compare(form.requests, 0);
        }

        function test_no_connection_keeps_the_text() {
            compare(sendAndWait(nowhere, "Is anybody there?"), "failed");
            compare(findChild(nowhere, "feedbackMessage").text, "Is anybody there?");
            // (not counted: nothing went)
            compare(nowhere.sentTimes.length, 0);
        }

        function test_three_an_hour_here() {
            const form = createTemporaryObject(remembering, root, { remember: false });
            const now = Date.now();
            form.sentTimes = [now - 50 * 60000, now - 20 * 60000, now - 60000];
            form.now = now;
            type(form, "a fourth one");
            verify(form.wait > 9 * 60000 && form.wait <= 10 * 60000);
            compare(findChild(form, "feedbackSend").enabled, false);
            verify(findChild(form, "feedbackState").text.indexOf("10 min") >= 0, findChild(form, "feedbackState").text);
            form.send();
            compare(form.requests, 0);
            // the oldest is an hour old: one more may go
            form.sentTimes = [now - 61 * 60000, now - 20 * 60000, now - 60000];
            compare(form.wait, 0);
            compare(findChild(form, "feedbackSend").enabled, true);
        }

        function test_remembered_when_the_window_opens_again() {
            const now = Date.now();
            const a = createTemporaryObject(remembering, root);
            a.sentTimes = [now - 30 * 60000, now - 2000, now - 1000];
            a.keep();
            a.destroy();
            // (the window closed: the old form is gone before the new one reads)
            wait(50);
            const b = createTemporaryObject(remembering, root);
            compare(b.sentTimes.length, 3);
            verify(b.wait > 29 * 60000);
        }

        function test_sent_through_the_relay() {
            ask("GET", "/calls");
            if (status !== 200) skip("the stand-in relay is not running (tools/run-tests starts it)");
            ask("POST", "/reset");

            type(first, "The notch is lovely");
            findChild(first, "feedbackContact").text = "@someone";
            findChild(first, "feedbackWithReport").checked = true;
            const shown = JSON.parse(findChild(first, "feedbackPreview").text);
            compare(shown.message, "The notch is lovely");
            compare(shown.report, "Dynamic Island diagnostics\nisland: 0.2.2");
            compare(findChild(first, "feedbackSend").enabled, true);
            first.send();
            tryCompare(first, "state", "sent", 10000);
            compare(findChild(first, "feedbackMessage").text, "");
            compare(first.sentTimes.length, 1);

            ask("GET", "/calls");
            let calls = JSON.parse(text);
            compare(calls.length, 2);
            compare(calls[0].method, "sendMessage");
            compare(calls[0].chat, "42");
            compare(calls[0].text, "Dynamic Island feedback\nisland 0.2.2 · en · Wayland\nanswer to: @someone\n\nThe notch is lovely");
            compare(calls[1].method, "sendDocument");
            compare(calls[1].file, "Dynamic Island diagnostics\nisland: 0.2.2");
            findChild(first, "feedbackWithReport").checked = false;

            // the second and the third from this computer go; the fourth is refused by the relay
            compare(sendAndWait(second, "Two"), "sent");
            compare(sendAndWait(second, "Three"), "sent");
            compare(sendAndWait(second, "Four"), "busy");
            compare(findChild(second, "feedbackMessage").text, "Four");
            verify(second.wait > 59 * 60000, "the relay's wait: " + second.wait);
            verify(findChild(second, "feedbackState").text.indexOf("60 min") >= 0, findChild(second, "feedbackState").text);
            compare(findChild(second, "feedbackSend").enabled, false);
            ask("GET", "/calls");
            calls = JSON.parse(text);
            compare(calls.length, 4);
            compare(calls[3].text.split("\n").pop(), "Three");
        }

        function test_no_report_unless_ticked() {
            findChild(first, "feedbackWithReport").checked = false;
            type(first, "hi");
            compare(first.built.body.report, "");
            type(first, "");
        }
    }
}
