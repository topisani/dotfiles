import Gio from 'gi://Gio'
import GLib from 'gi://GLib'

export function Scroller() {
    const decoder = new TextDecoder();
    const mode_label = Widget.Label({
        class_name: "scroller-mode",
        label: ''
    });
    const overview_label = Widget.Label({
        class_name: "scroller-overview",
        label: ''
    });
    const scroller = Widget.Box({
        class_name: "scroller",
        children: [
            mode_label,
            overview_label,
        ],
    })
    function event_decode(data) {
        const text = decoder.decode(data);
        console.log(text)
        if (text.startsWith("scroller>>mode,")) {
            const mode = text.substring(15).trim();
            if (mode == "row")
                mode_label.label = " ";
            else
                mode_label.label = " ";
        } else if (text.startsWith("scroller>>overview,")) {
            if (text.substring(19) == 1) {
                overview_label.label = "🐦";
            } else {
                overview_label.label = "";
            }
        }
    }
    function connection() {
        const HIS = GLib.getenv('HYPRLAND_INSTANCE_SIGNATURE');
        const XDG_RUNTIME_DIR = GLib.getenv('XDG_RUNTIME_DIR') || '/';
        const sock = (pre) => `${pre}/hypr/${HIS}/.socket2.sock`;
        const path = GLib.file_test(sock(XDG_RUNTIME_DIR), GLib.FileTest.EXISTS)?
            sock(XDG_RUNTIME_DIR) : sock('/tmp');

        return new Gio.SocketClient()
            .connect(new Gio.UnixSocketAddress({ path }), null);
    }
    let listener = new Gio.DataInputStream({
        close_base_stream: true,
        base_stream: connection().get_input_stream(),
    });
    function watch_socket(sstream) {
        sstream.read_line_async(0, null, (stream, result) => {
            if (!stream)
                return console.error('Error reading Hyprland socket');

            const [line] = stream.read_line_finish(result);
            event_decode(line);
            watch_socket(stream);
        });
    }
    watch_socket(listener);
    return scroller;
}
