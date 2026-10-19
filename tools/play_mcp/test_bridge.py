"""Actual Godot bridge security/visible-UI fixture (not card-demo gameplay)."""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
import uuid
from server import ROOT, RUNTIME


def main():
    run = RUNTIME / ('bridge-'+uuid.uuid4().hex)
    run.mkdir(parents=True)
    (run/'project.godot').write_text('[application]\nconfig/name="Bridge fixture"\nrun/main_scene="res://main.tscn"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CunPlay/'+run.name+'"\n[autoload]\nBridge="*res://bridge.gd"\n[display]\nwindow/size/viewport_width=640\nwindow/size/viewport_height=480\n',encoding='utf-8')
    shutil.copyfile(Path(__file__).with_name('bridge.gd'),run/'bridge.gd')
    (run/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="Fixture" type="Control"]\nscript=ExtResource("1")\n',encoding='utf-8')
    (run/'main.gd').write_text('extends Control\nfunc _ready() -> void:\n\tvar shown := Label.new()\n\tshown.text = "Visible text"\n\tadd_child(shown)\n\tvar partial := Label.new()\n\tpartial.text = "SeenSECRET_UNREVEALED"\n\tpartial.visible_characters = 4\n\tpartial.position.y = 30\n\tadd_child(partial)\n\tvar hidden := Label.new()\n\thidden.text = "SECRET_CLUE"\n\thidden.hide()\n\tadd_child(hidden)\n\tvar parent := Control.new()\n\tparent.hide()\n\tadd_child(parent)\n\tvar hidden_button := Button.new()\n\thidden_button.text = "SECRET_BUTTON"\n\tparent.add_child(hidden_button)\n\tvar button := Button.new()\n\tbutton.position = Vector2(50,50)\n\tbutton.size = Vector2(150,50)\n\tbutton.text = "Click me"\n\tbutton.pressed.connect(func(): shown.text = "Clicked via real input")\n\tadd_child(button)\n',encoding='utf-8')
    with (run/'main.gd').open('a',encoding='utf-8') as f:
        f.write('''	var clip := Control.new()
	clip.position = Vector2(20,200)
	clip.size = Vector2(200,20)
	clip.clip_contents = true
	add_child(clip)
	var cropped := Button.new()
	cropped.text = "Partially clipped"
	cropped.position = Vector2(0,10)
	cropped.size = Vector2(160,50)
	cropped.pressed.connect(func(): get_child(0).text = "Clipped button received real click")
	clip.add_child(cropped)
	var outside := Button.new()
	outside.text = "SECRET_CLIPPED"
	outside.position = Vector2(0,80)
	clip.add_child(outside)
	add_to_group("cun_play_visible")
	var gm := Button.new()
	gm.text = "GM blocked"
	gm.position = Vector2(300,100)
	gm.size = Vector2(120,40)
	gm.set_meta("cun_play_blocked", true)
	add_child(gm)
var physical_frames := 0
var released := false
func _process(_delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_W):
		physical_frames += 1
	elif physical_frames > 0:
		released = true
func play_visible() -> Dictionary:
	return {"description": "Fixture drawn marker at screen 20,20", "physical_frames": physical_frames, "released": released}
''')
    with socket.socket() as reserved:
        reserved.bind(('127.0.0.1',0)); port = reserved.getsockname()[1]
    token = 'fixture-'+uuid.uuid4().hex
    env = dict(os.environ,CUN_PLAY_PORT=str(port),CUN_PLAY_TOKEN=token)
    def request(method, params=None, secret=token, raw=None):
        with socket.create_connection(('127.0.0.1',port),timeout=2) as peer:
            peer.settimeout(3)
            peer.sendall(raw if raw is not None else json.dumps({'token':secret,'method':method,'params':params or {}}).encode()+b'\n')
            data = b''
            while b'\n' not in data:
                block = peer.recv(4096)
                if not block: return None
                data += block
            return json.loads(data)
    with (run/'engine.log').open('wb') as log:
        process = subprocess.Popen([str(ROOT/'.local/godot/Godot_v4.7.2-stable_win64_console.exe'),'--headless','--resolution','640x480','--path',str(run)],env=env,stdout=log,stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic()+10
            while True:
                try:
                    observation = request('observe')['result']; break
                except OSError:
                    if time.monotonic()>deadline: raise
                    time.sleep(.1)
            assert 'SECRET' not in json.dumps(observation)
            assert 'Visible text' in observation['texts']
            assert len(observation['buttons'])==3
            cropped = next(b for b in observation['buttons'] if b['text']=='Partially clipped')
            assert cropped['rect']['height'] <= 10.1
            crop_result = request('action',{'kind':'click','button_id':cropped['id']})
            assert crop_result['ok'] and 'Clipped button received real click' in crop_result['result']['texts'], crop_result
            assert observation['visible'][0]['description'].startswith('Fixture drawn')
            blocked = next(b for b in observation['buttons'] if b.get('blocked'))
            assert blocked['disabled']
            assert not request('action',{'kind':'click','button_id':blocked['id']})['ok']
            assert not request('action',{'kind':'mouse','x':310,'y':110})['ok']
            key_result = request('action',{'kind':'key','key':'w','frames':6})
            assert key_result['ok'], key_result
            physical = key_result['result']['visible'][0]
            assert 1 <= physical['physical_frames'] <= 7 and physical['released'], physical
            assert not request('observe',secret='wrong')['ok']
            assert not request('eval')['ok']
            assert not request('action',{'kind':'key','key':'enter','frames':121})['ok']
            assert not request('action',{'kind':'click','button_id':'invalid'})['ok']
            changed = request('action',{'kind':'click','button_id':observation['buttons'][0]['id']})
            assert changed['ok'] and 'Clicked via real input' in changed['result']['texts'],changed
            try:
                assert request('observe',raw=b'x'*65537+b'\n') is None
            except ConnectionResetError:
                pass
        finally:
            process.terminate(); process.wait(timeout=10)
        env.pop('CUN_PLAY_TOKEN')
        disabled = subprocess.Popen([str(ROOT/'.local/godot/Godot_v4.7.2-stable_win64_console.exe'),'--headless','--resolution','640x480','--path',str(run)],env=env,stdout=log,stderr=subprocess.STDOUT)
        try:
            time.sleep(.5)
            assert disabled.poll() is None
            try:
                socket.create_connection(('127.0.0.1',port),timeout=.3).close()
                raise AssertionError('listened without token')
            except (ConnectionRefusedError, TimeoutError):
                pass
        finally:
            disabled.terminate(); disabled.wait(timeout=10)
    print(json.dumps({'ok':True,'tests':['hidden labels/buttons excluded','wrong token rejected','eval rejected','frames bounded','invisible button rejected','real input click changed label','oversized request closed','no token no listener','fixed visible provider','blocked GM click and mouse','physical key held and released'],'evidence':str(run.relative_to(ROOT))}))

if __name__ == '__main__': main()
