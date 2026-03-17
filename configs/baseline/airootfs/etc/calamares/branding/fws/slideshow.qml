/* ============================================================
   FWS Linux — slideshow.qml
   Affiché pendant l'installation
   ============================================================ */

import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        if (presentation.currentSlide < slides.count - 1)
            presentation.currentSlide++
        else
            presentation.currentSlide = 0
    }

    Timer {
        id: timer
        interval: 4000
        repeat: true
        running: true
        onTriggered: nextSlide()
    }

    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#1a1a2e"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "🚀 Bienvenue sur FWS Linux"
                    color: "#00d4ff"
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Un système rapide, léger et puissant."
                    color: "#e0e0e0"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#16213e"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "⚡ Basé sur Arch Linux"
                    color: "#00d4ff"
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Accès à l'AUR et aux derniers paquets."
                    color: "#e0e0e0"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#0f3460"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "🛡️ Sécurité & Stabilité"
                    color: "#00d4ff"
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "FWS est conçu pour être robuste et fiable."
                    color: "#e0e0e0"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#1a1a2e"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "✅ Installation en cours..."
                    color: "#00d4ff"
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Merci de patienter, FWS s'installe sur votre machine."
                    color: "#e0e0e0"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
