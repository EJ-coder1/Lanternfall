#!/bin/sh
# Headless tests. Usage: GODOT=/path/to/godot sh tests/run_tests.sh
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import > /dev/null 2>&1
RESULT=0
for scene in res://tests/test_scene.tscn res://tests/flow_scene.tscn; do
    echo "=== $scene"
    OUT=$("$GODOT" --headless --path . "$scene" 2>&1)
    STATUS=$?
    echo "$OUT"
    # Ignore harmless shutdown leak notices; any other printed engine/script error fails the run.
    if echo "$OUT" | grep -v -E "still in use at exit|leaked|ObjectDB|_free_rids|cleanup \(|clear \(" | grep -qE "SCRIPT ERROR|Parse Error|ERROR:"; then
        echo "Engine or script errors were printed above."
        RESULT=1
    fi
    [ $STATUS -ne 0 ] && RESULT=1
done
exit $RESULT
