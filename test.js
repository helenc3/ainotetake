// Runs md() straight out of index.html. `node test.js`
const src = require('fs').readFileSync(__dirname + '/index.html', 'utf8');
const md = eval('(' + src.slice(src.indexOf('function md(')).replace(/<\/script>[\s\S]*$/, '') + ')');
const assert = require('assert');
assert.equal(md('## Key points'), '<h2>Key points</h2>');
assert.equal(md('- a\n- b'), '<ul><li style="margin-left:0px">a</li>\n<li style="margin-left:0px">b</li></ul>');
assert.ok(md('  - deep').includes('margin-left:24px'));
assert.equal(md('**bold**'), '<p><strong>bold</strong></p>');
assert.ok(md('<img onerror=x>').startsWith('<p>&lt;img'), 'must escape html');
console.log('ok');

// --- restart path: the ~60s cutoff is what makes a 90-min lecture work ---
// Loads the page's real script against a stub DOM + fake SpeechRecognition.
function loadApp(seed = {}) {
  const el = () => ({ textContent: '', innerHTML: '', value: '', disabled: false,
    scrollTop: 0, focus() {}, classList: { toggle() {}, add() {}, remove() {} } });
  const nodes = {};
  const document = {
    getElementById: id => nodes[id] || (nodes[id] = el()),
    body: { classList: { toggle() {} } },
  };
  const store = { ...seed };
  const localStorage = {
    getItem: k => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); },
    removeItem: k => { delete store[k]; },
  };
  const sessions = [];
  class FakeSR {
    constructor() { sessions.push(this); }
    start() { this.started = true; }
    stop() {}
    // drive it the way the browser would
    say(text, isFinal = true) {
      this.onresult({ resultIndex: 0, results: [{ 0: { transcript: text }, isFinal }] });
    }
    cutoff() { this.onend(); }
  }
  const script = src.slice(src.indexOf('<script>') + 8, src.indexOf('</script>'));
  const app = new Function('window', 'document', 'localStorage', 'navigator', 'Date', 'confirm',
    script + '\nreturn { start, toggleUI, show, showNotes, parseEnv, filename, get final() { return final },' +
             ' set final(v) { final = v }, get lectures() { return lectures },' +
             ' get cur() { return cur }, get want() { return want }, set want(v) { want = v } };'
  )({ SpeechRecognition: FakeSR }, document, localStorage, { language: 'en-US' }, Date, () => true);
  return { app, sessions, nodes, store };
}

// a cutoff mid-lecture must keep every word and duplicate none
{
  const { app, sessions } = loadApp();
  app.want = true;
  app.start();
  sessions[0].say('the mitochondrion');
  sessions[0].cutoff();
  assert.equal(sessions.length, 2, 'cutoff while recording must open a new session');
  sessions[1].say('is the powerhouse');
  assert.equal(app.final, 'the mitochondrion is the powerhouse ');
}

// interim text from a dead session must not survive into the transcript
{
  const { app, sessions } = loadApp();
  app.want = true;
  app.start();
  sessions[0].say('half a sen', false);
  sessions[0].cutoff();
  sessions[1].say('half a sentence');
  assert.equal(app.final, 'half a sentence ', 'interim text must not be double-counted');
}

// Stop means stop: no resurrection
{
  const { app, sessions } = loadApp();
  app.want = true;
  app.start();
  app.want = false;
  sessions[0].cutoff();
  assert.equal(sessions.length, 1, 'must not restart after the user stops');
}

// a session that dies instantly (offline, mic gone) must not hot-loop forever
{
  const { app, sessions, nodes } = loadApp();
  app.want = true;
  app.start();
  for (let i = 0; i < 50 && app.want; i++) sessions[sessions.length - 1].cutoff();
  assert.ok(sessions.length < 10, `gave up after ${sessions.length} sessions, not a tight loop`);
  assert.equal(app.want, false, 'must stop recording rather than pretend to listen');
  assert.ok(nodes.status.innerHTML.includes('err'), 'must tell the user it gave up');
}
console.log('ok — restart path');

// --- multiple lectures ---
// a transcript saved by the old single-lecture build must survive the upgrade
{
  const { app, store } = loadApp({ transcript: 'osmosis is passive', notes: '## Summary\nosmosis' });
  assert.equal(app.lectures.length, 1, 'old transcript becomes one lecture');
  assert.equal(app.final, 'osmosis is passive', 'must not lose the existing transcript');
  assert.equal(app.lectures[0].notes, '## Summary\nosmosis');
  assert.ok(!('transcript' in store), 'old keys cleaned up after migration');
  assert.ok(JSON.parse(store.lectures)[0].transcript, 'migrated lecture is persisted');
}

// a new lecture must not append onto the last one
{
  const { app, sessions, nodes } = loadApp();
  app.want = true; app.start();
  sessions[0].say('lecture one');
  app.want = false;
  nodes.new.onclick();
  assert.equal(app.lectures.length, 2);
  assert.equal(app.final, '', 'new lecture starts empty');
  app.want = true; app.start();
  sessions[sessions.length - 1].say('lecture two');
  assert.equal(app.final, 'lecture two ');
  const one = app.lectures.find(l => l.transcript.startsWith('lecture one'));
  assert.equal(one.transcript, 'lecture one ', 'the earlier lecture is untouched');
}

// switching back restores that lecture's transcript and notes
{
  const { app, sessions, nodes } = loadApp();
  app.want = true; app.start();
  sessions[0].say('first');
  app.showNotes('## Summary\nfirst notes');
  app.want = false;
  nodes.new.onclick();
  const firstId = app.lectures.find(l => l.transcript.startsWith('first')).id;
  nodes.lectures.value = String(firstId);
  nodes.lectures.onchange();
  assert.equal(app.final, 'first ', 'switching back restores the transcript');
  assert.ok(nodes.notes.innerHTML.includes('first notes'), 'and its notes');
}

// pressing New twice must not pile up blank lectures
{
  const { app, nodes } = loadApp();
  nodes.new.onclick();
  nodes.new.onclick();
  assert.equal(app.lectures.length, 1, 'an untouched lecture is already new');
}

// delete removes only the open lecture, and never leaves zero
{
  const { app, sessions, nodes } = loadApp();
  app.want = true; app.start();
  sessions[0].say('keep me');
  app.want = false;
  nodes.new.onclick();
  app.want = true; app.start();
  sessions[sessions.length - 1].say('delete me');
  app.want = false;
  nodes.clear.onclick();
  assert.equal(app.lectures.length, 1, 'only the open lecture is deleted');
  assert.equal(app.lectures[0].transcript, 'keep me ');
  nodes.clear.onclick();
  assert.equal(app.lectures.length, 1, 'deleting the last one leaves a fresh empty lecture');
  assert.equal(app.lectures[0].transcript, '');
}

// recording must not be switchable out from under itself
{
  const { app, nodes } = loadApp();
  app.want = true; app.toggleUI();
  assert.ok(nodes.lectures.disabled && nodes.new.disabled, 'locked while recording');
  app.want = false; app.toggleUI();
  assert.ok(!nodes.lectures.disabled, 'unlocked after stopping');
}
console.log('ok — lectures');

// --- .env prefill: the key field is the only place a key is typed, so parsing must be boring ---
{
  const { app } = loadApp();
  const env = app.parseEnv([
    '# comment',
    'GROQ_API_KEY=gsk_abc123',
    '  export GEMINI_API_KEY = "quoted value" ',
    'EMPTY=',
    'not a line',
  ].join('\n'));
  assert.equal(env.GROQ_API_KEY, 'gsk_abc123');
  assert.equal(env.GEMINI_API_KEY, 'quoted value', 'export prefix, spaces and quotes stripped');
  assert.equal(env.EMPTY, '');
  assert.ok(!('comment' in env) && !('not' in env));
  assert.ok(app.filename('notes').endsWith('-notes.md'), 'saved file is named by lecture date');
}
console.log('ok — env');
