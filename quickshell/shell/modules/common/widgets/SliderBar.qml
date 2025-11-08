import QtQuick
import QtQuick.Controls.Basic

Slider {
    id: root
    property alias trackColor: background.color
    property alias highlightColor: highlight.color
    property alias radius: background.radius
    wheelEnabled: true
    
    background: Rectangle {
        id: background
        height: parent.height
        width: parent.width
        color: "#555555"
        
        Rectangle {
            id: highlight
            width: root.visualPosition * parent.width
            height: parent.height
            color: "#888888"
            radius: parent.radius
        }
    }
    
    handle: Rectangle {
        color: "transparent"
        width: 0
    }
}
