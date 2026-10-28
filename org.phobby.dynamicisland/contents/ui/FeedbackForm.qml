/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Settings → Diagnostics → Feedback: a few lines to the author, sent only
    when Send is pressed. They go to the project's feedback address
    (Project.FEEDBACK_URL, a relay of its own: tools/feedback-relay), which
    passes them on to the author's Telegram; the bot's token is kept there,
    never here. What is sent is the text, an optional way to answer, the
    island's version, language and session, and, only if ticked, the
    diagnostics report (already without the user's name, the computer's name
    and the home folder). "What is sent" shows exactly that before it leaves.

    Without an address (a copy built without one) the page says so and offers
    the issue tracker instead. Feedback.js has the rules and the limits.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Feedback.js" as Feedback
import "Project.js" as Project

ColumnLayout {
    id: form
    objectName: "feedbackForm"

    // Where it is sent; tests point it elsewhere.
    property string endpoint: Project.FEEDBACK_URL
    readonly property bool configured: Feedback.usable(endpoint)
    // The diagnostics report, made when it is asked for (configDiagnostics.qml).
    property var reportText: function() { return ""; }
    // { island, language, session }
    property var meta: ({})

    // "" | "sending" | "sent" | "busy" | "refused" | "failed"
    property string state: ""
    // Every request that was made (tests look at this).
    property int requests: 0
    property int seq: 0

    readonly property var built: Feedback.payload(message.text, contact.text, withReport.checked, withReport.checked ? form.reportText() : "", form.meta)
    readonly property bool tooLong: message.text.trim().length > Feedback.MAX_MESSAGE

    function send(): void {
        if (!configured || !built.ok || state === "sending" || pause.running) return;
        const run = ++seq;
        state = "sending";
        watchdog.restart();
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || run !== seq) return;
            watchdog.stop();
            const result = Feedback.outcome(xhr.status);
            // (the text emptied first: a change of it clears the state)
            if (result === "sent") { message.text = ""; pause.restart(); }
            form.state = result;
        };
        ++requests;
        xhr.open("POST", endpoint);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(built.body));
    }
    Timer { id: watchdog; interval: 20000; onTriggered: { ++form.seq; form.state = "failed"; } }
    // (one at a time: after a message is sent, the next can follow a minute later)
    Timer { id: pause; interval: 60000 }

    spacing: Kirigami.Units.smallSpacing

    component Hint: QQC2.Label {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 28
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.8
    }

    Kirigami.Heading {
        Layout.fillWidth: true
        level: 3
        text: Lang.i18n("Feedback")
        textFormat: Text.PlainText
    }
    Hint {
        objectName: "feedbackIntro"
        text: form.configured
              ? Lang.i18n("A few lines to the author: what you like, what is missing, what went wrong. Sent only when you press Send, through the project's feedback address to the author's Telegram; nothing else is sent, and nothing in the background.")
              : Lang.i18n("This copy of the island has no feedback address, so nothing can be sent from here. Tell the author on GitHub instead.")
    }
    QQC2.Button {
        visible: !form.configured
        icon.name: "tools-report-bug"
        text: Lang.i18n("Report a problem")
        onClicked: Qt.openUrlExternally(Project.ISSUES_URL)
    }

    ColumnLayout {
        visible: form.configured
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 30
        spacing: Kirigami.Units.smallSpacing

        QQC2.TextArea {
            id: message
            objectName: "feedbackMessage"
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            placeholderText: Lang.i18n("What would you like to tell the author?")
            Accessible.name: Lang.i18n("Feedback")
            onTextChanged: if (form.state !== "sending") form.state = ""
        }
        QQC2.Label {
            textFormat: Text.PlainText
            Layout.alignment: Qt.AlignRight
            font: Kirigami.Theme.smallFont
            color: form.tooLong ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            opacity: form.tooLong ? 1 : 0.7
            text: Lang.i18n("%1 / %2", message.text.trim().length, Feedback.MAX_MESSAGE)
        }
        QQC2.TextField {
            id: contact
            objectName: "feedbackContact"
            Layout.fillWidth: true
            maximumLength: Feedback.MAX_CONTACT
            placeholderText: Lang.i18n("How to answer you (optional): a Telegram name or an e-mail address")
            Accessible.name: Lang.i18n("How to answer you (optional)")
        }
        QQC2.CheckBox {
            id: withReport
            objectName: "feedbackWithReport"
            text: Lang.i18n("Add the diagnostics report (without your user name, the computer's name and your home folder)")
            Accessible.name: text
        }
        RowLayout {
            Layout.fillWidth: true
            QQC2.Button {
                objectName: "feedbackSend"
                icon.name: "document-send"
                text: form.state === "sending" ? Lang.i18n("Sending…") : Lang.i18n("Send")
                enabled: form.built.ok && form.state !== "sending" && !pause.running
                onClicked: form.send()
            }
            QQC2.ToolButton {
                id: showSent
                objectName: "feedbackPreviewButton"
                checkable: true
                icon.name: "view-preview"
                text: Lang.i18n("What is sent")
                enabled: form.built.ok
            }
            Item { Layout.fillWidth: true }
        }
        QQC2.TextArea {
            objectName: "feedbackPreview"
            visible: showSent.checked && form.built.ok
            Layout.fillWidth: true
            readOnly: true
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.WrapAnywhere
            font: Kirigami.Theme.fixedWidthFont
            text: Feedback.preview(form.built.body)
            Accessible.name: Lang.i18n("What is sent")
        }
        Hint {
            objectName: "feedbackState"
            visible: text.length > 0
            opacity: 1
            color: form.state === "sent" ? Kirigami.Theme.positiveTextColor
                 : form.state === "busy" || form.state === "refused" || form.state === "failed" || form.tooLong ? Kirigami.Theme.negativeTextColor
                 : Kirigami.Theme.textColor
            text: form.tooLong ? Lang.i18n("That is longer than %1 characters: shorten it a little.", Feedback.MAX_MESSAGE)
                : form.state === "sending" ? Lang.i18n("Sending…")
                : form.state === "sent" ? Lang.i18n("Sent. Thank you!")
                : form.state === "busy" ? Lang.i18n("The feedback address asks to wait: try again in a minute.")
                : form.state === "refused" ? Lang.i18n("The feedback address did not take it. Shorten it, or tell the author on GitHub.")
                : form.state === "failed" ? Lang.i18n("It could not be sent: no connection, or the feedback address did not answer. What you wrote is still here: try again later.")
                : pause.running ? Lang.i18n("The next one can be sent in a minute.")
                : ""
        }
    }
}
