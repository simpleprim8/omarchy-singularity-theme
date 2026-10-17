#!/usr/bin/env python3
"""Run the real Plymouth interpreter with presentation-only drawing stubs.

This checks callbacks and geometry without taking over a VT or handling secrets.
The actual boot display still needs verification at the next reboot.
"""
import ctypes as C
from pathlib import Path
import tempfile
import re

plugin = C.CDLL('/usr/lib/plymouth/script.so')
pointer = C.c_void_p
class Return(C.Structure):
    _fields_ = [('kind',C.c_int),('object',pointer)]
for name, args, result in [
    ('script_parse_file',[C.c_char_p],pointer),
    ('script_parse_op_free',[pointer],None),
    ('script_state_new',[pointer],pointer),
    ('script_state_destroy',[pointer],None),
    ('script_lib_math_setup',[pointer],pointer),
    ('script_lib_math_destroy',[pointer],None),
    ('script_execute',[pointer,pointer],Return),
    ('script_obj_as_number',[pointer],C.c_double),
]:
    fn=getattr(plugin,name); fn.argtypes=args; fn.restype=result

source=Path(__file__).with_name('plymouth')/'singularity.script'
prelude='''
global.errors = 0;
global.draws = 0;
global.images = 0;
global.position_errors = 0;
global.opacity_errors = 0;
fun position(x,y,z) { if (x == NULL || y == NULL || z == NULL) { global.errors++; global.position_errors++; } global.lastx=x; global.lasty=y; global.draws++; }
fun image_size() { return 16; }
fun opacity(n) { if (n == NULL || n<0 || n>1) {global.errors++; global.opacity_errors++;} global.lastopacity=n; }
fun no_op(a,b,c,d) { }
fun text_image(text,a,b,c,d,e) { global.last_text=text; return make_image(text); }
global.stub_image.GetWidth = image_size;
global.stub_image.GetHeight = image_size;
fun make_image(a,b,c,d,e,f) { global.images++; return global.stub_image; }
global.stub_image.Scale = make_image;
fun sprite(img) {
    local.result = [];
    local.result.SetImage = no_op;
    local.result.SetPosition = position;
    local.result.SetOpacity = opacity;
    local.result.GetImage = make_image;
    return local.result;
}
Sprite = sprite;
Window.GetWidth = fun() { return 2560; };
Window.GetHeight = fun() { return 1440; };
Window.SetBackgroundTopColor = no_op;
Window.SetBackgroundBottomColor = no_op;
Plymouth.SetRefreshFunction = fun(cb) { global.on_refresh = cb; };
Plymouth.SetRefreshRate = no_op;
Plymouth.SetRootMountedFunction = fun(cb) { global.on_root = cb; };
Plymouth.SetDisplayPasswordFunction = fun(cb) { global.on_password = cb; };
Plymouth.SetDisplayNormalFunction = fun(cb) { global.on_normal = cb; };
Plymouth.SetDisplayQuestionFunction = fun(cb) { global.on_question = cb; };
Plymouth.SetMessageFunction = fun(cb) { global.on_message = cb; };
Plymouth.SetHideMessageFunction = fun(cb) { global.on_hide = cb; };
'''
checks='''
on_password("Disk unlock context",1);
if (global.last_text != "Disk unlock context") global.errors++;
for (test_i=0; test_i<100; test_i++) on_refresh();
if (global.entry_drift <= 0) global.errors++;
first_tick = global.entry_tick;
on_password("Disk unlock",20);
if (global.entry_tick != first_tick) global.errors++;
for (test_i=0; test_i<1400; test_i++) on_refresh();
if (global.count != 20 || global.entry_drift != 32) global.errors++;
if (global.frame != 0) global.errors++;
# Even long after the dots disappear, editing and submission stay native.
on_password("Disk unlock",21);
if (global.count != 21) global.errors++;
on_normal();
if (global.password_mode != 0) global.errors++;
on_password("Disk unlock",0);
if (global.entry_drift) global.errors++;
on_password("Disk unlock",5);
if (global.count != 5) global.errors++;
for (test_i=0; test_i<100; test_i++) on_refresh();
on_normal();
on_password("Stress context",10000);
if (global.count != 128) global.errors++;
for (test_i=0; test_i<700; test_i++) on_refresh();
settled_draws = global.draws;
for (test_i=0; test_i<700; test_i++) on_refresh();
if (global.draws != settled_draws) global.errors++;
on_normal();
on_root();
on_question("Recovery", "test");
on_message("Wrong passphrase — try again");
on_hide("");
if (global.draws < 2000 || global.images < 16) global.errors++;
return global.errors;
'''
with tempfile.NamedTemporaryFile(suffix='.script') as temporary:
    # Replace only the image factory; use native interpreter/math for the theme.
    body = re.sub(r'\bImage\(', 'make_image(', source.read_text().replace('Image.Text(', 'text_image('))
    temporary.write((prelude+body+checks).encode()); temporary.flush()
    op=plugin.script_parse_file(temporary.name.encode())
    assert op, 'Plymouth native parser rejected the theme or callback harness'
    state=plugin.script_state_new(None)
    math=plugin.script_lib_math_setup(state)
    result=plugin.script_execute(state,op)
    errors=plugin.script_obj_as_number(result.object)
    assert errors == 0, f'Plymouth callback checks failed: {errors}'
    plugin.script_lib_math_destroy(math)
    plugin.script_state_destroy(state)
    plugin.script_parse_op_free(op)
print('Plymouth native runtime: falling dots, static mesh, late editing, submit/retry, root-mounted success, recovery and geometry passed.')
