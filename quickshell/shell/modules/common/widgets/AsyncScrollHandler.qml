import QtQuick

WheelHandler {
    id: root
    required property real value
    property real position: 0.0
    property real minValue: 0.0
    property real maxValue: 1.0

    signal scrolled(real value)
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onActiveChanged: position = root.value
    rotationScale: 0.1 / 360.0
    
    onWheel: function (wheel: WheelEvent) {
        let delta = wheel.angleDelta.y * rotationScale * (wheel.inverted ? -1 : 1)
        position = Math.min(root.maxValue, Math.max(root.minValue, position + delta))
        root.scrolled(position);
    }
}
