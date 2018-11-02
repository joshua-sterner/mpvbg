#!/usr/bin/env sh

MONITORS=$(xrandr --current | sed -r -n 's/.*connected (primary )?([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*/vec4(\4.0,\5.0,\2.0,\3.0),/p' | sed '$ s/.$//')
MONITOR_COUNT=$(xrandr --current | sed -r -n 's/.*connected (primary )?([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*/vec4(\4.0,\5.0,\2.0,\3.0),/p' | wc -l)
echo $MONITORS
echo $MONITOR_COUNT
SHADERFILE=`mktemp` || exit 1
echo "
//!HOOK MAIN
//!BIND MAIN
//!SAVE MAIN
vec4 monitors[$MONITOR_COUNT] = vec4[]($MONITORS);

bool isWithinMonitorBounds(vec2 p, vec4 monitor) {
    return (p.x >= monitor.x) && (p.y >= monitor.y) && (p.x <= monitor.z+monitor.x) && (p.y <= monitor.w+monitor.y);
}

vec4 hook() {
    vec2 pos = MAIN_pos;
    vec2 pos2 = pos*target_size;
    vec2 pos3 = vec2(0.0);
    for (int i = 0; i < monitors.length(); i++) {
        vec4 monitor = monitors[i];
        if (isWithinMonitorBounds(pos2, monitor)) {
            pos3 = (pos2 - monitor.xy) / monitor.zw;
        }
    }
    return MAIN_tex(pos3);
}" > $SHADERFILE


xwinwrap -ni -b -ov -fs -- mpv -fs --keepaspect=no -wid=$(xwinwrap -- echo WID) --glsl-shader=$SHADERFILE $@

rm $SHADERFILE
