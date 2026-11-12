"""Joins the clips recorded by tool/record_gameplay.mjs into the Play Store
preview video: 1080 x 1920, H.264, 30 fps, no audio, 20-60 s.

    python tool/make_video.py <recording dir> <output.mp4>

The recording dir holds marks.json and clips/<name>/*.webm.
"""
import glob
import json
import os
import subprocess
import sys

ORDER = ['a_first', 'b_winter', 'c_convoy', 'd_tour', 'e_dawn']
# Longest stretch kept from each clip (seconds), so the video stays tight.
CAP = {'a_first': 22, 'b_winter': 7, 'c_convoy': 6, 'd_tour': 14, 'e_dawn': 5.5}
FADE = 0.5


def main(rec, out):
    marks = json.load(open(os.path.join(rec, 'marks.json')))
    inputs, durations = [], []
    for name in ORDER:
        files = glob.glob(os.path.join(rec, 'clips', name, '*.webm'))
        if not files:
            sys.exit(f'missing clip {name}')
        m = marks[name]
        start = max(0.0, m['start'])
        dur = min(m['end'] - start, CAP[name])
        inputs += ['-ss', f'{start:.2f}', '-t', f'{dur:.2f}', '-i', files[0]]
        durations.append(dur)

    # Constant frame rate and timebase before xfade (see references/gotchas.md).
    parts = [f'[{i}:v]setpts=PTS-STARTPTS,fps=30,scale=1080:1920:flags=lanczos,settb=AVTB,format=yuv420p[v{i}]'
             for i in range(len(ORDER))]
    last, offset = 'v0', durations[0] - FADE
    for i in range(1, len(ORDER)):
        tag = f'x{i}'
        parts.append(f'[{last}][v{i}]xfade=transition=fade:duration={FADE}:offset={offset:.2f}[{tag}]')
        last = tag
        offset += durations[i] - FADE
    total = sum(durations) - FADE * (len(ORDER) - 1)
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', *inputs, '-filter_complex', ';'.join(parts),
           '-map', f'[{last}]', '-an', '-c:v', 'libx264', '-preset', 'slow', '-crf', '20',
           '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out]
    subprocess.run(cmd, check=True)
    print(f'{out}: {total:.1f} s, {os.path.getsize(out) // 1024} KB')
    if not 20 <= total <= 60:
        sys.exit(f'video is {total:.1f} s; Play wants 20-60 s')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
