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
function loadApp() {
  const el = () => ({ textContent: '', innerHTML: '', value: '', disabled: false,
    scrollTop: 0, focus() {}, classList: { toggle() {}, add() {}, remove() {} } });
  const nodes = {};
  const document = {
    getElementById: id => nodes[id] || (nodes[id] = el()),
    body: { classList: { toggle() {} } },
  };
  const store = {};
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
  const app = new Function('window', 'document', 'localStorage', 'navigator', 'Date',
    script + '\nreturn { start, toggleUI, nodes: null, get final() { return final },' +
             ' get want() { return want }, set want(v) { want = v } };'
  )({ SpeechRecognition: FakeSR }, document, localStorage, { language: 'en-US' }, Date);
  return { app, sessions, nodes };
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
