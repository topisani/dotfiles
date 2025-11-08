pragma Singleton
import Quickshell
import Quickshell.Bluetooth as QsBl

Singleton {
    property QsBl.BluetoothAdapter defaultAdapter: QsBl.Bluetooth.defaultAdapter

    property string stateString: (() => {
            switch (Bluetooth.defaultAdapter?.state) {
            case QsBl.BluetoothAdapterState.Blocked:
                return "Blocked";
            case QsBl.BluetoothAdapterState.Enabling:
                return "Enabling";
            case QsBl.BluetoothAdapterState.Enabled:
                return "Enabled";
            case QsBl.BluetoothAdapterState.Disabled:
                return "Disabled";
            case QsBl.BluetoothAdapterState.Disabling:
                return "Disabling";
            }
            return "Unavailable";
        })()
}
