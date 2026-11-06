#!/usr/bin/python3
"""Check popup boundaries, click-away, and keyboard focus in an isolated X11 session."""
import os, re, shutil, subprocess, sys, tempfile, time
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
if os.environ.get("DWM_PANEL_POPUP_NESTED") != "1":
 nested = {**os.environ, "DWM_PANEL_POPUP_NESTED": "1"}
 raise SystemExit(subprocess.run(
  ["xvfb-run", "-a", sys.executable, str(Path(__file__).resolve())], env=nested).returncode)
shell_source=(repo/'config/quickshell/shell.qml').read_text()
selection=shell_source[shell_source.index('function selectPanelPopup'):shell_source.index('function openCommandMenu')]
for close in ('commandMenuModel.close();', 'launcherModel.close();',
              'notificationModel.closeHistory();', 'controlCenterModel.closeUtility();'):
 assert close in selection
for popup, close in (('bluetooth', 'bluetoothModel.close();'),
                     ('controlcenter', 'controlCenterModel.close();'),
                     ('controls', 'controlsModel.close();'),
                     ('network', 'networkModel.close();'),
                     ('power', 'powerMenuModel.close("panel");'),
                     ('updatecenter', 'updateCenterModel.close();')):
 assert f'if (popupId !== "{popup}") {close}' in selection
assert 'root.selectedPanelWindow = panel;' in selection
assert 'UpdateCenterWindow {' in shell_source
assert 'panelWindow: root.activePanelWindow' in shell_source
assert 'onExclusiveOpenRequested: root.selectPanelPopup(root.activePanelWindow, "updatecenter")' in shell_source
for handler, visible in (('onVisibleChanged', 'visible'),
                         ('onUtilityVisibleChanged', 'utilityVisible'),
                         ('onHistoryVisibleChanged', 'historyVisible')):
 matches = re.findall(rf'{handler}:\s*if\s*\({visible}\)\s*\{{([^}}]*)\}}', shell_source)
 assert matches, handler
 for body in matches:
  assert 'updateCenterModel.close();' in body, handler
  assert 'clipboardModel.close();' in body, handler
 if handler == 'onVisibleChanged': assert len(matches) >= 6
assert 'commandMenuModel.close();\n                clipboardModel.close();\n                updateCenterModel.close();' in shell_source
# Keep the AF_UNIX IPC path below 108 bytes even with a long HOME.
# Fixtures stay under the managed root; only this private runtime uses /tmp.
with tempfile.TemporaryDirectory(prefix='pp-', dir='/tmp') as ipc_runtime, \
     tempfile.TemporaryDirectory(prefix='panel-popup-', dir=os.environ.get('TMPDIR', str(Path.home()/'tmp'))) as temp:
 base=Path(temp); config=base/'config'; qml=config/'quickshell'; qml.mkdir(parents=True)
 runtime=Path(ipc_runtime)
 shutil.copytree(repo/'config/quickshell/core',qml/'core')
 (qml/'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
ShellRoot {
 PanelWindow { id: panel; implicitHeight: 30; anchors { top: true; left: true; right: true } color: "white"; exclusiveZone: 30 }
 ClickAwayPopup { id: popup; targetWindow: panel; visible: false; popupWidth: 280; popupHeight: 300; onDismissed: visible = false
  onVisibleChanged: if (visible) Qt.callLater(function() { card.forceActiveFocus(); })
  Rectangle { id: card; anchors.fill: parent; color: "red"; focus: true
   Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { popup.visible = false; event.accepted = true; } } } }
 IpcHandler { target: "test"; function open(): void { popup.visible = true; } function toggle(): void { popup.visible = !popup.visible; } function shown(): bool { return popup.visible; } }
}''')
 # A dwm binding toggles the popup, as Super+F1 toggles the Control Center.
 (config/'dwm-titus').mkdir()
 (config/'dwm-titus'/'hotkeys.toml').write_text('keys = [\n  { mod="SUPER", key="F1", func="spawn", cmd="quickshell ipc call test toggle" },\n]\n')
 # A plain X client that records the keys and focus changes it receives.
 (base/'client.c').write_text(r'''#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h>
int main(void) {
	Display *d = XOpenDisplay(NULL);
	if (!d) return 1;
	Window w = XCreateSimpleWindow(d, DefaultRootWindow(d), 0, 0, 400, 300, 0, 0, 0xffffff);
	/* A fixed size makes dwm float the client, leaving bare desktop around it. */
	XSizeHints *hints = XAllocSizeHints();
	if (!hints) return 1;
	hints->flags = PMinSize | PMaxSize;
	hints->min_width = hints->max_width = 400;
	hints->min_height = hints->max_height = 300;
	XSetWMNormalHints(d, w, hints);
	XFree(hints);
	XSelectInput(d, w, KeyPressMask | FocusChangeMask);
	XStoreName(d, w, "popup-focus-client");
	XMapWindow(d, w);
	printf("WINDOW %lu\n", w);
	fflush(stdout);
	for (;;) {
		XEvent e;
		XNextEvent(d, &e);
		if (e.type == KeyPress)
			printf("KEY %s\n", XKeysymToString(XLookupKeysym(&e.xkey, 0)));
		else if (e.type == FocusIn)
			printf("FOCUSIN\n");
		fflush(stdout);
	}
}
''')
 subprocess.run(['cc',str(base/'client.c'),'-o',str(base/'client'),'-lX11'],check=True)
 env={**os.environ,'XDG_RUNTIME_DIR':str(runtime),'HOME':str(base),'XDG_CONFIG_HOME':str(config),'XDG_DATA_HOME':str(base/'data'),'XDG_STATE_HOME':str(base/'state'),'XDG_CACHE_HOME':str(base/'cache'),'QT_QPA_PLATFORM':'xcb','QT_QPA_PLATFORMTHEME':''}
 log=(base/'runtime.log').open('w+')
 wm=subprocess.Popen([str(repo/'dwm')],env=env,stdout=log,stderr=log)
 client_log=(base/'client.log').open('w+')
 client=subprocess.Popen([str(base/'client')],env=env,stdout=client_log,stderr=log)
 shell=subprocess.Popen(['quickshell','--no-duplicate'],env=env,stdout=log,stderr=log)
 def run(*args): return subprocess.run(args,env=env,capture_output=True,text=True)
 try:
  for _ in range(100):
   if run('quickshell','ipc','call','test','open').returncode==0: break
   time.sleep(.05)
  else: raise AssertionError('IPC unavailable')
  time.sleep(.3)
  ids=run('xdotool','search','--onlyvisible','--pid',str(shell.pid)).stdout.split()
  geometries = [dict(line.split("=", 1) for line in run('xdotool', 'getwindowgeometry', '--shell', wid).stdout.splitlines()) for wid in ids]
  panel = next(g for g in geometries if int(g['HEIGHT']) == 30)
  popup = next(g for g in geometries if int(g['HEIGHT']) > 30)
  assert int(popup['Y']) == int(panel['Y']) + int(panel['HEIGHT']), "Popup covers the panel"
  assert int(popup['X']) == int(panel['X']) and popup['WIDTH'] == panel['WIDTH']
  run('xdotool', 'mousemove', '100', '100', 'click', '1').check_returncode()
  time.sleep(.1)
  assert popup['WINDOW'] in run('xdotool', 'search', '--onlyvisible', '--pid', str(shell.pid)).stdout.split(), "Content click dismissed popup"
  run('xdotool', 'mousemove', '500', '400', 'click', '1').check_returncode()
  time.sleep(.1)
  assert popup['WINDOW'] not in run('xdotool', 'search', '--onlyvisible', '--pid', str(shell.pid)).stdout.split(), "Outside click did not dismiss popup"
  run('quickshell', 'ipc', 'call', 'test', 'open').check_returncode()
  time.sleep(.1)
  run('xdotool', 'mousemove', '100', '15', 'click', '1').check_returncode()
  time.sleep(.1)
  assert popup['WINDOW'] not in run('xdotool', 'search', '--onlyvisible', '--pid', str(shell.pid)).stdout.split(), "Panel click did not dismiss popup"
  def wait_for(check, message):
   for _ in range(100):
    if check(): return
    time.sleep(.05)
   raise AssertionError(message)
  def shown(): return run('quickshell','ipc','call','test','shown').stdout.strip()=='true'
  def client_lines():
   client_log.seek(0); return client_log.read().splitlines()
  client_win=next(l.split()[1] for l in client_lines() if l.startswith('WINDOW '))
  # The raw X focus window: with the pointer away from the client, focus that
  # merely reverted to the root must not count as the client being focused.
  focus=lambda: run('xdotool','getwindowfocus','-f').stdout.strip()
  # Quickshell creates a new X window each time the popup opens.
  def popup_focused():
   wid=focus()
   if wid not in run('xdotool','search','--onlyvisible','--pid',str(shell.pid)).stdout.split(): return False
   return int(run('xdotool','getwindowgeometry','--shell',wid).stdout.split('HEIGHT=')[1].split()[0]) > 30
  # The panel click above moved focus to the panel; click the client first.
  run('xdotool','mousemove','300','300','click','1').check_returncode()
  wait_for(lambda: focus()==client_win, 'dwm did not focus the clicked client')
  # An open popup takes the keyboard: Escape closes it and never reaches the
  # client, and dwm gives focus back to the client afterwards.
  run('quickshell','ipc','call','test','open').check_returncode()
  wait_for(lambda: popup_focused(), 'The open popup did not take keyboard focus')
  # With the pointer over bare desktop, no window dwm watches sees the focus
  # revert, so dwm must restore the client's focus itself.
  client_geometry=dict(l.split('=',1) for l in run('xdotool','getwindowgeometry','--shell',client_win).stdout.splitlines())
  screen_w,screen_h=map(int,run('xdotool','getdisplaygeometry').stdout.split())
  assert int(client_geometry['X'])+int(client_geometry['WIDTH']) < screen_w-5 or int(client_geometry['Y'])+int(client_geometry['HEIGHT']) < screen_h-5, 'The client covers the screen corner'
  run('xdotool','mousemove',str(screen_w-5),str(screen_h-5)).check_returncode()
  run('xdotool','key','Escape').check_returncode()
  wait_for(lambda: not shown(), 'Escape did not close the popup')
  wait_for(lambda: focus()==client_win, 'Focus did not return to the client after the popup closed')
  run('xdotool','key','a').check_returncode()
  wait_for(lambda: 'KEY a' in client_lines(), 'The client did not receive keys after the popup closed')
  assert 'KEY Escape' not in client_lines(), 'Escape for the popup reached the client'
  # dwm's key bindings still work while the popup holds the keyboard, so the
  # binding that opened it also closes it.
  run('xdotool','key','super+F1').check_returncode()
  wait_for(shown, 'The dwm binding did not open the popup')
  wait_for(lambda: popup_focused(), 'The popup opened by a binding did not take keyboard focus')
  run('xdotool','key','super+F1').check_returncode()
  wait_for(lambda: not shown(), 'The dwm binding did not close the focused popup')
  wait_for(lambda: focus()==client_win, 'Focus did not return to the client after the binding closed the popup')
  assert wm.poll() is None and shell.poll() is None
  print('Panel remains outside popup; content, desktop and panel click behavior: PASS')
  print('Popup keyboard focus, Escape, binding toggle and focus return: PASS')
 finally:
  shell.terminate(); shell.wait(timeout=5); client.terminate(); client.wait(timeout=5)
  wm.terminate(); wm.wait(timeout=5); client_log.close()
  log.seek(0); print(log.read()); log.close()
