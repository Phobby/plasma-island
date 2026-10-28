/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Settings → Diagnostics → Feedback (FeedbackForm.qml): without an address
    nothing is sent and GitHub is offered; with one, Send posts exactly what
    "What is sent" shows, through the real relay (tests/feedback-server.mjs,
    started by tools/run-tests, with a stand-in Telegram) into the chat, the
    report only when ticked; a second one from the same computer is asked to
    wait; no connection says so and keeps the text.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 700
    height: 900

    readonly property string relay: "http://127.0.0.1:47391/"

    FeedbackForm { id: none; width: 600; endpoint: "" }
    FeedbackForm { id: nowhere; width: 600; y: 100; endpoint: "http://127.0.0.1:1/" }
    FeedbackForm {
        id: first
        width: 600; y: 300
        endpoint: root.relay
        reportText: () => "Dynamic Island diagnostics\nisland: 0.2.2"
        meta: ({ island: "0.2.2", language: "en", session: "Wayland" })
    }
    FeedbackForm { id: second; width: 600; y: 600; endpoint: root.relay }

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

        function test_without_an_address() {
            compare(none.configured, false);
            verify(findChild(none, "feedbackIntro").text.indexOf("GitHub") >= 0);
            compare(findChild(none, "feedbackSend").visible, false);
            type(none, "hello");
            none.send();
            compare(none.requests, 0);
        }

        function test_nothing_written_nothing_sent() {
            compare(first.built.ok, false);
            compare(findChild(first, "feedbackSend").enabled, false);
            first.send();
            compare(first.requests, 0);
        }

        function test_no_connection_keeps_the_text() {
            type(nowhere, "Is anybody there?");
            nowhere.send();
            tryCompare(nowhere, "state", "failed", 10000);
            compare(findChild(nowhere, "feedbackMessage").text, "Is anybody there?");
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
            // (one a minute from here: the button waits)
            compare(findChild(first, "feedbackSend").enabled, false);

            ask("GET", "/calls");
            const calls = JSON.parse(text);
            compare(calls.length, 2);
            compare(calls[0].method, "sendMessage");
            compare(calls[0].chat, "42");
            compare(calls[0].text, "Dynamic Island feedback\nisland 0.2.2 · en · Wayland\nanswer to: @someone\n\nThe notch is lovely");
            compare(calls[1].method, "sendDocument");
            compare(calls[1].file, "Dynamic Island diagnostics\nisland: 0.2.2");

            // the same computer a moment later: asked to wait, the text kept
            type(second, "And another thing");
            second.send();
            tryCompare(second, "state", "busy", 10000);
            compare(findChild(second, "feedbackMessage").text, "And another thing");
            ask("GET", "/calls");
            compare(JSON.parse(text).length, 2);
        }

        function test_no_report_unless_ticked() {
            findChild(first, "feedbackWithReport").checked = false;
            type(first, "hi");
            compare(first.built.body.report, "");
            type(first, "");
        }
    }
}
