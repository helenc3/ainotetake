// Runs md() straight out of index.html. `node test.js`
const src = require('fs').readFileSync(__dirname + '/index.html', 'utf8');
const md = eval('(' + src.slice(src.indexOf('function md(')).replace(/<\/script>[\s\S]*$/, '') + ')');
const assert = require('assert');
assert.equal(md('## Key points'), '<h2 style="font-size:17px;text-transform:none;letter-spacing:0;opacity:1">Key points</h2>');
assert.equal(md('- a\n- b'), '<ul><li style="margin-left:0px">a</li>\n<li style="margin-left:0px">b</li></ul>');
assert.ok(md('  - deep').includes('margin-left:24px'));
assert.equal(md('**bold**'), '<p><strong>bold</strong></p>');
assert.ok(md('<img onerror=x>').startsWith('<p>&lt;img'), 'must escape html');
console.log('ok');
