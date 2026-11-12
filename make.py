"""Usage: python3 make.py sheet|render|channel [story-id-substring ...]"""
import os
import subprocess
import sys

import skia

import audio
from engine import FPS, H, W, Timeline, avatar
from stories import CHANNEL, STORIES

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output')


def ts(t, sep=','):
    ms = int(round(t * 1000))
    return '%02d:%02d:%02d%s%03d' % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, sep, ms % 1000)


def write_text(story, tl, d):
    base = os.path.join(d, story['id'])
    with open(base + '_subtitles_RU.srt', 'w') as f:
        for i, (a, b, txt) in enumerate(tl.subs, 1):
            f.write('%d\n%s --> %s\n%s\n\n' % (i, ts(a), ts(b), txt))
    with open(base + '_script_RU.txt', 'w') as f:
        f.write(story['title'] + '\n' + '=' * len(story['title']) + '\n\n')
        for row in tl.script:
            if row[0] == 'rule':
                f.write('\n%s\n\n' % row[1])
            else:
                f.write('%s  %s: %s\n' % (ts(row[0])[:8], row[1], row[2]))
    with open(base + '_caption_RU.txt', 'w') as f:
        f.write(story['caption'] + '\n')


def sheet(story, d):
    tl = Timeline(story)
    beats = tl.beats
    cols, rows, tw_, th = 6, 3, 300, 533
    n = cols * rows
    idx = sorted({round(i * (len(beats) - 1) / (n - 1)) for i in range(n)})
    surf = skia.Surface(cols * tw_, rows * th)
    cv = surf.getCanvas()
    for k, i in enumerate(idx):
        b = beats[i]
        t = b['t0'] + (b['t1'] - b['t0']) * 0.8
        tl.frame(t)
        img = tl.frame(t, True).makeImageSnapshot()
        cv.drawImageRect(img, skia.Rect.MakeXYWH((k % cols) * tw_, (k // cols) * th, tw_, th),
                         skia.SamplingOptions(skia.FilterMode.kLinear))
    path = os.path.join(d, story['id'] + '_sheet.jpg')
    surf.makeImageSnapshot().save(path, skia.kJPEG)
    print('%s: %.1fs, %d beats -> %s' % (story['id'], tl.total, len(beats), path))


def render(story, d):
    tl = Timeline(story)
    write_text(story, tl, d)
    wav = os.path.join(d, 'audio.wav')
    audio.build(tl, wav, seed=sum(map(ord, story['id'])))
    procs = []
    for kind in ('CLEAN', 'SUBS_RU'):
        procs.append(subprocess.Popen(
            ['ffmpeg', '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'bgra', '-s', '%dx%d' % (W, H), '-r', str(FPS),
             '-i', '-', '-i', wav, '-c:v', 'libx264', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p',
             '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart',
             os.path.join(d, '%s_%s.mp4' % (story['id'], kind))], stdin=subprocess.PIPE))
    for i in range(int(tl.total * FPS)):
        t = i / FPS
        procs[0].stdin.write(tl.frame(t).toarray().tobytes())
        procs[1].stdin.write(tl.frame(t, True).toarray().tobytes())
    for p in procs:
        p.stdin.close()
        if p.wait():
            raise SystemExit('ffmpeg failed for ' + story['id'])
    os.remove(wav)
    print('%s: %.1fs rendered' % (story['id'], tl.total), flush=True)


def main():
    cmd, filt = sys.argv[1], sys.argv[2:]
    if cmd == 'channel':
        d = os.path.join(OUT, 'channel')
        os.makedirs(d, exist_ok=True)
        avatar(os.path.join(d, 'avatar.png'))
        with open(os.path.join(d, 'channel_RU.txt'), 'w') as f:
            f.write(CHANNEL)
        return
    for fn in STORIES:
        story = fn()
        if filt and not any(x in story['id'] for x in filt):
            continue
        if cmd == 'sheet':
            os.makedirs('/tmp/sheets', exist_ok=True)
            sheet(story, '/tmp/sheets')
        else:
            d = os.path.join(OUT, story['id'])
            os.makedirs(d, exist_ok=True)
            render(story, d)


if __name__ == '__main__':
    main()
