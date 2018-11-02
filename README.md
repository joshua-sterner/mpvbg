# mpvbg
Play a video in your desktop background using mpv and xwinwrap, duplicating the video across all monitors.
Requires xwinwrap, mpv and xrandr.

usage: mpvbg.sh [OPTIONS] -- [MPV_OPTIONS]
    -f, --fit       Default aspect ratio correction. Will cause
                      letterboxing/pillarboxing if video aspect
                      ratio does not match the monitor.
    -s, --stretch   Disables aspect ratio correction.
    -c, --crop      Crops off the edges of the video to correct
                      the aspect ratio.
    -h, --help      Show this usage information.
