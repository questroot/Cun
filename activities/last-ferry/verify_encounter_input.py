"""Known-route encounter QA via normal public inputs only; no screenshot or state injection."""
import argparse
import hashlib
import json
import sys
import time
import traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/play_mcp'))
from server import PlayService


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(strategy, render):
    s = PlayService()
    receipts, checkpoints, failures = [], {}, []
    source_hashes = {name: digest(ROOT / 'activities/last-ferry/game' / name)
                     for name in ('main.gd', 'story_state.gd')}
    def call(name, arguments):
        start = time.perf_counter()
        row = {'name': name, 'arguments': arguments, 'start_unix': time.time()}
        try:
            result = s.call(name, arguments)
            row['result'] = result
            return result
        except Exception as exc:
            row['error'] = repr(exc)
            raise
        finally:
            row['elapsed_ms'] = (time.perf_counter() - start) * 1000
            receipts.append(row)
    def obs():
        return call('observe', {})
    def world(o):
        return o['visible'][0]
    def text(o):
        return json.dumps(o, ensure_ascii=False)
    def check(value, label):
        if not value:
            failures.append(label)
        print(('PASS ' if value else 'FAIL ') + strategy + ': ' + label, flush=True)
    def key(k, frames=1):
        return call('action', {'kind': 'key', 'key': k, 'frames': frames})
    def click(prefix):
        o = obs()
        for _ in range(9):
            b = next((b for b in o['buttons'] if b['text'].startswith(prefix)), None)
            if b:
                return call('action', {'kind': 'click', 'button_id': b['id']})
            down = next((b for b in o['buttons'] if b['text'] == '向下翻阅'), None)
            if not down:
                break
            call('action', {'kind': 'click', 'button_id': down['id']})
            o = obs()
        raise AssertionError(('button not found', prefix, o))
    def walk(axis, target):
        speed, cap, previous = 200., 400, None
        for _ in range(24):
            p = world(obs())['player_screen']
            d = target - p[axis]
            if abs(d) < 8:
                return
            if previous is not None and previous * d < 0:
                cap = max(30, cap // 2)
            duration = min(cap, max(20, int(abs(d) / speed * 800)))
            k = ('d' if d > 0 else 'a') if axis == 'x' else ('s' if d > 0 else 'w')
            call('action', {'kind': 'key', 'key': k, 'duration_ms': duration})
            after = world(obs())['player_screen']
            dist = abs(after[axis] - p[axis])
            if dist > 1:
                speed = max(80., min(800., dist / (duration / 1000)))
            previous = d
        raise AssertionError(('movement failed', axis, target, after))
    def go(x, y):
        walk('y', 400)
        walk('x', x)
        walk('y', y)
    def snap(label):
        o = obs()
        checkpoints[label] = o
        return o
    def reload(label):
        before = snap(label + '_before')
        click('保存')
        click('读取')
        click('确认')
        after = snap(label + '_after')
        check(world(after)['player_screen'] == world(before)['player_screen'], label + ' restores location')
        check(not world(after)['modal_open'], label + ' closes confirmation')
        check(world(after).get('visible_first_meet') == world(before).get('visible_first_meet'), label + ' preserves visible meeting')
        return after
    def meeting(label):
        o = snap(label)
        w = world(o)
        m = w.get('visible_first_meet', {})
        check(bool(m) and not w['modal_open'], label + ' nonmodal meeting visible')
        check(not any(k in text(m) for k in ('"active"', '"identified"', '"settled"')), label + ' no internal flags')
        names = [a['name'] for a in m.get('actors', [])]
        check(names.count('许澄') == 1 and names.count('沈渡') == 1, label + ' one of each encounter actor')
        for name in names:
            check(not any(v.get('title') == name for v in w.get('objects', [])), label + ' no duplicate object actor ' + name)
        check('最后那声又破了' in text(m) and '屋顶还漏' in text(m), label + ' sustained fragments')
        check('末班交回岸棚' in text(m), label + ' carved plaque visible')
        check('visible_ferry_tag' not in w, label + ' no automatic tag acceptance')
        return o
    def journal(label):
        click('记录')
        o = snap(label)
        check('visible_first_meet' not in world(o), label + ' modal filters meeting')
        # Read only currently visible public text; no raw save access.
        result = '\n'.join(o['texts'])
        key('esc')
        return result
    result = {'strategy': strategy, 'source_hashes_before_launch': source_hashes,
              'method': 'normal fresh Xu; public launch/observe/action/stop only; known route not blind play'}
    try:
        call('launch', {'project': 'last-ferry', 'headless': not render})
        result['copy_hashes'] = {name: digest(s.run_dir / 'project' / name) for name in source_hashes}
        check(source_hashes == result['copy_hashes'], 'launch copy matches recorded main/story hashes')
        click('许宁 ·')
        go(320, 375); key('e'); click('坐一会儿')
        go(450, 575); key('e')
        go(750, 390); key('e')
        click('准备好了'); click('确认')
        go(750, 565); key('e')
        go(165, 460)
        check(not world(obs())['modal_open'], 'willow listening nonmodal')
        go(330, 500)
        check('热的留着呢' in text(obs()), 'stair listening heard')
        go(460, 335); click('先站在干阶听河声')
        key('2'); key('1'); key('1'); key('3')
        wrong = snap('wrong_whistle')
        check('visible_first_meet' not in world(wrong) and '原样送回来' in text(wrong), 'wrong rhythm safe and unrecognized')
        check('侵入 0 / 2' in text(wrong), 'wrong rhythm no invasion')
        key('4'); key('1'); key('1'); key('2'); key('3')
        meeting('recognized_ashore')
        reload('mid_recognition')
        click('当前目标')
        modal = snap('help_modal')
        check(world(modal)['modal_open'] and 'visible_first_meet' not in world(modal), 'help modal filters meeting')
        key('esc')
        if strategy == 'boat':
            go(700, 330); key('e'); click('许宁独有：踏上')
            check(world(obs())['location'] == '夜船·靠岸侧舷', 'normal boarding')
            meeting('on_deck')
            reload('mid_deck')
            # Far from plaque, E must not offer take; near plaque E must offer it.
            go(130, 440); key('e')
            far = snap('far_from_plaque')
            check(not any('听沈渡说明这块木牌' in b['text'] for b in far['buttons']), 'distant plaque not interactable by E')
            if world(far)['modal_open']:
                key('esc')
            go(450, 540); key('e')
            check(world(obs())['location'] == '旧石阶', 'return without taking tag')
        go(150, 550)
        settled = snap('dry_ground_retreat')
        m = world(settled).get('visible_first_meet', {})
        check(bool(m) and not m.get('fragments') and '留在舷边守船' in text(m), 'dry-ground retreat settles sustained poses')
        check('没有催' in text(settled) and 'visible_ferry_tag' not in world(settled), 'settles without accepting tag')
        check(any(v['title'] == '靠岸夜船' for v in world(settled)['objects']), 'retreat does not release boat')
        reload('settled')
        go(460, 335); go(150, 550)
        first_journal = journal('journal_after_reentry')
        check(first_journal.count('你退到旧阶后方的干地') == 1, 'one retreat journal after reload/reentry')
        go(460, 335); key('e')
        talk = snap('revisit_conversation')
        check(any('先谈旧屋漏雨' in b['text'] for b in talk['buttons']), 'life conversation remains available')
        check(any('问他：你希望这一程' in b['text'] for b in talk['buttons']), 'wish remains explicit separate choice')
        key('esc')
        if strategy == 'boat':
            go(700, 330); key('e'); click('许宁独有：踏上')
            go(685, 440); key('e')
            near = snap('near_plaque')
            check(any('听沈渡说明这块木牌' in b['text'] for b in near['buttons']), 'near plaque offers actual acceptance')
            click('听沈渡说明')
            carried = snap('tag_carried')
            check('visible_ferry_tag' in world(carried) and 'plaque' not in world(carried).get('visible_first_meet', {}), 'carried tag not duplicated as displayed plaque')
            check(not any(v['title'] == '舷边刻着字的木渡牌' for v in world(carried)['objects']), 'carried tag removes take-object duplicate')
            reload('carried')
            key('e'); click('还没决定')
            put_back = snap('tag_put_back')
            check('visible_ferry_tag' not in world(put_back) and 'plaque' in world(put_back).get('visible_first_meet', {}), 'put-back restores unique plaque')
        result['completed_route'] = True
    except Exception:
        result['exception'] = traceback.format_exc()
        failures.append(result['exception'])
        print(result['exception'], flush=True)
    finally:
        try:
            result['stop'] = call('stop', {})
        except Exception:
            result['stop_exception'] = traceback.format_exc()
            failures.append(result['stop_exception'])
        finally:
            s.stop()
            result.update(failures=failures, ok=not failures, checkpoints=checkpoints, receipts=receipts)
            if s.run_dir:
                out = s.run_dir / ('encounter-' + strategy + '-evidence.json')
                out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
                print(json.dumps({'strategy': strategy, 'ok': result['ok'], 'failures': len(failures), 'evidence': str(out)}, ensure_ascii=False), flush=True)
    return result['ok']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--strategy', choices=('shore', 'boat', 'both'), default='both')
    args = parser.parse_args()
    outcomes = [run(strategy, args.render) for strategy in (('shore', 'boat') if args.strategy == 'both' else (args.strategy,))]
    return 0 if all(outcomes) else 1


if __name__ == '__main__':
    raise SystemExit(main())
