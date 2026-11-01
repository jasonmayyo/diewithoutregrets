"""Record the two real, read-only native intro previews for the HTML gallery."""
import argparse
import signal
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--simulator', required=True)
parser.add_argument('--only', choices=['how-guard', 'how-study'], nargs='+')
args = parser.parse_args()
root = Path(__file__).resolve().parent / 'animations'
root.mkdir(exist_ok=True)

for key, screen in [('how-guard', 824), ('how-study', 825)]:
    if args.only and key not in args.only:
        continue
    subprocess.run(['xcrun', 'simctl', 'launch', '--terminate-running-process', args.simulator,
                    'com.jasonmayo.diewithoutregrets', '-hasCompletedOnboarding', 'NO',
                    '-sg-onboarding-screen-capture', str(screen)],
                   check=True, stdout=subprocess.DEVNULL, timeout=45)
    time.sleep(1 if key == 'how-study' else 8)
    path = root / f'{key}.mp4'
    path.unlink(missing_ok=True)
    recorder = subprocess.Popen(['xcrun', 'simctl', 'io', args.simulator,
                                 'recordVideo', '--codec=h264', str(path)],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        time.sleep(15 if key == 'how-study' else 9)
    finally:
        recorder.send_signal(signal.SIGINT)
        output, _ = recorder.communicate(timeout=30)
    if recorder.returncode != 0 or not path.exists() or path.stat().st_size < 100_000:
        raise RuntimeError(f'Capture failed for {key}: {output}')
    print(f'Recorded {key}: {path.stat().st_size // 1024} KB', flush=True)
