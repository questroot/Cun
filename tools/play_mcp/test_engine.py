"""Opt-in actual engine end-to-end test. Requires card-demo bridge Autoload integration."""
import argparse
import hashlib
import json
from pathlib import Path
import socket
import subprocess
import sys
import time
from server import PlayService, ROOT

def digest(path):
    return {str(p.relative_to(path)):hashlib.sha256(p.read_bytes()).hexdigest() for p in path.rglob('*') if p.is_file() and '.godot' not in p.parts}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--render',action='store_true')
    options = parser.parse_args()
    sys.stdout.reconfigure(encoding='utf-8')
    service = PlayService()
    before = digest(ROOT/'card-demo')
    evidence = {}
    try:
        launched = service.call('launch',{'project':'card-demo','headless':not options.render})
        evidence['launch'] = launched
        time.sleep(.3)
        original = service.call('observe',{})
        assert original['buttons'],original
        # The shared entry now opens the game selection lobby. Enter through
        # the visible player button before checking the spirit game's bag.
        entries = [b for b in original['buttons'] if not b['disabled'] and b['text'] == '进入灵伴回合冒险']
        if entries:
            evidence['lobby'] = original
            service.call('action',{'kind':'click','button_id':entries[0]['id']})
            time.sleep(.3)
            original = service.call('observe',{})
            assert original['scene'] != evidence['lobby']['scene'],original
        # Wrong token cannot read even visible state.
        with socket.create_connection(('127.0.0.1',service.port),timeout=5) as peer:
            peer.sendall(b'{"token":"bad","method":"observe"}\n')
            denied = json.loads(peer.recv(4096))
            assert not denied['ok'] and denied['error']=='unauthorized'
        evidence['unauthorized_denied'] = True
        try:
            service.call('launch',{'project':'card-demo'})
            raise AssertionError('duplicate launch accepted')
        except ValueError:
            pass
        evidence['single_owned_process'] = True
        # Prefer ordinary bag UI rather than GM or hidden APIs.
        candidates = [b for b in original['buttons'] if not b['disabled'] and ('背包' in b['text'] or '编队' in b['text'])]
        assert candidates,original
        chosen = candidates[0]
        changed = service.call('action',{'kind':'click','button_id':chosen['id']})
        time.sleep(.3)
        changed = service.call('observe',{})
        assert changed['scene'] != original['scene'] or changed['texts'] != original['texts'], (original,changed)
        evidence['click'] = {'button':chosen,'before':original,'after':changed}
        evidence['key'] = service.call('action',{'kind':'key','key':'escape','frames':2})
        try:
            service.call('action',{'kind':'click','button_id':'-1'})
            raise AssertionError('invisible button accepted')
        except ValueError:
            pass
        evidence['invisible_button_denied'] = True
        # Query real Godot user:// in same isolated configuration without starting game.
        project = service.run_dir/'project'
        probe = project/'probe_userdir.gd'
        probe.write_text((Path(__file__).with_name('probe_userdir.gd')).read_text(encoding='utf-8'),encoding='utf-8')
        out = service.run_dir/'probe.log'
        with out.open('wb') as log:
            result = subprocess.run([str(ROOT/'.local/godot/Godot_v4.7.2-stable_win64_console.exe'),'--headless','--path',str(project),'--script',str(probe)],stdout=log,stderr=subprocess.STDOUT,timeout=10)
        assert result.returncode == 0
        text = out.read_text(encoding='utf-8')
        marker = next(line.split('USER_DIR=',1)[1] for line in text.splitlines() if 'USER_DIR=' in line)
        assert service.run_dir.name in marker, marker
        evidence['isolated_user_dir'] = marker
        evidence['source_unchanged'] = before == digest(ROOT/'card-demo')
        assert evidence['source_unchanged']
        evidence['stop'] = service.call('stop',{})
        assert evidence['stop']['stopped']
        evidence['second_stop'] = service.call('stop',{})
        evidence['render'] = options.render
        (service.run_dir/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps({'ok':True,'evidence':str((service.run_dir/'evidence.json').relative_to(ROOT)), 'scene_before':original['scene'],'scene_after':changed['scene'],'user_dir':marker},ensure_ascii=False))
    finally:
        service.stop()
if __name__ == '__main__': main()
