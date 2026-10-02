/*
    SPDX-License-Identifier: GPL-2.0-or-later
    QR code of a text (KDE's Prison), in its own file so that a missing
    Prison module only disables the QR button.
*/
import QtQuick
import org.kde.prison as Prison

Prison.Barcode {
    barcodeType: Prison.Barcode.QRCode
}
