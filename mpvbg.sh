#!/usr/bin/env sh

USAGE="usage: mpvbg.sh [OPTIONS] -- [MPV_OPTIONS]
    -f, --fit       Default aspect ratio correction. Will cause
                      letterboxing/pillarboxing if video aspect
                      ratio does not match the monitor.
    -s, --stretch   Disables aspect ratio correction.
    -c, --crop      Crops off the edges of the video to correct
                      the aspect ratio.
    -h, --help      Show this usage information.
    
    config file ~/.mpvbgrc can be used to pass options to this
      command and/or to mpv. The expected format of ~/.mpvbgrc
      is as follows:

    [mpvbg]
    --mpvbg_option
    [mpv]
    --mpv_option
    "
MPVBG_OPTIONS="" 
MPV_OPTIONS=""
MPVBGRC_SECTION=""
while read -u 3 line;
do
    case `echo $line | sed -r 's/^\s*\[(mpv(bg)?)\]\s*$/\1/'` in
        mpvbg)
            MPVBGRC_SECTION=mpvbg
            ;;
        mpv)
            MPVBGRC_SECTION=mpv
            ;;
        *)
            case $MPVBGRC_SECTION in
                mpvbg)
                    MPVBG_OPTIONS="$MPVBG_OPTIONS $line"
                    ;;
                mpv)
                    MPV_OPTIONS="$MPV_OPTIONS $line"
                    ;;
            esac
            ;;
    esac
done 3<~/.mpvbgrc

ASPECT_RATIO_OPTION=fit
GET_MPV_OPTIONS=false
MPVBG_OPTIONS="$MPVBG_OPTIONS $@"
for option in $MPVBG_OPTIONS
do
    if $GET_MPV_OPTIONS
    then
        MPV_OPTIONS="$MPV_OPTIONS $option"
    else
    case $option in
        -f|--fit)
            ASPECT_RATIO_OPTION=fit
            ;;
        -s|--stretch)
            ASPECT_RATIO_OPTION=stretch
            ;;
        -c|--crop)
            ASPECT_RATIO_OPTION=crop
            ;;
        -h|--help)
            echo "$USAGE"
            exit
            ;;
        --)
            GET_MPV_OPTIONS=true
            ;;
        *)
            echo Invalid Options in command line or config file ~/.mpvbgrc
            echo "$USAGE"
            exit
            ;;
    esac
    fi
done
WIDTH=$(xrandr --current | sed -r -n 's/.*current ([0-9]+) x ([0-9]+).*/\1/p')
HEIGHT=$(xrandr --current | sed -r -n 's/.*current ([0-9]+) x ([0-9]+).*/\2/p')
MONITORS=$(xrandr --current | sed -r -n 's/.*connected (primary )?([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*/vec4(\4.0,\5.0,\2.0,\3.0),/p' | sed '$ s/.$//')
MONITOR_COUNT=$(xrandr --current | sed -r -n 's/.*connected (primary )?([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*/vec4(\4.0,\5.0,\2.0,\3.0),/p' | wc -l)
SHADERFILE=`mktemp` || exit 1

case $ASPECT_RATIO_OPTION in
    fit)
        ASPECT_RATIO_CORRECTION_LINE="pos3 = correctAspectFit(pos3, srcAspect, monAspect);"
        ;;
    stretch)
        ASPECT_RATIO_CORRECTION_LINE=""
        ;;
    crop)
        ASPECT_RATIO_CORRECTION_LINE="pos3 = correctAspectCrop(pos3, srcAspect, monAspect);"
        ;;
esac

echo "
//!HOOK MAIN
//!BIND MAIN
//!SAVE MAIN
//!WIDTH $WIDTH
//!HEIGHT $HEIGHT
vec4 monitors[$MONITOR_COUNT] = vec4[]($MONITORS);

bool isWithinMonitorBounds(vec2 p, vec4 monitor) {
    return (p.x >= monitor.x) && (p.y >= monitor.y) && (p.x <= monitor.z+monitor.x) && (p.y <= monitor.w+monitor.y);
}

vec2 correctAspectCrop(vec2 p, float srcAspect, float monAspect) {
    if (srcAspect > monAspect) {
        p.x *= monAspect/srcAspect;
        p.x -= 0.5*(monAspect/srcAspect - 1.0);
    } else {
        p.y *= srcAspect/monAspect;
        p.y -= 0.5*(srcAspect/monAspect - 1.0);
    }
    return p;
}

vec2 correctAspectFit(vec2 p, float srcAspect, float monAspect) {
    if (srcAspect > monAspect) {
        p.y *= srcAspect/monAspect;
        p.y += 0.5*(1.0 - srcAspect/monAspect);
    } else {
        p.x *= monAspect/srcAspect;
        p.x += 0.5*(1.0 - monAspect/srcAspect);
    }
    return p;
}
vec4 hook() {
    vec2 pos = MAIN_pos;
    vec2 pos2 = pos*target_size;
    vec2 pos3 = vec2(0.0);
    for (int i = 0; i < monitors.length(); i++) {
        vec4 monitor = monitors[i];
        if (isWithinMonitorBounds(pos2, monitor)) {
            pos3 = (pos2 - monitor.xy) / monitor.zw;
            float srcAspect = input_size.x/input_size.y;
            float monAspect = monitor.z/monitor.w;
            $ASPECT_RATIO_CORRECTION_LINE
        }
    }
    if (pos3.x < 0.0 || pos3.x > 1.0 || pos3.y < 0.0 || pos3.y > 1.0) {
        return vec4(0.0,0.0,0.0,1.0);
    }
    return MAIN_tex(pos3);
}" > $SHADERFILE

xwinwrap -ni -b -ov -fs -- mpv -fs --keepaspect=no -wid=$(xwinwrap -- echo WID) --glsl-shader=$SHADERFILE $MPV_OPTIONS

rm $SHADERFILE
