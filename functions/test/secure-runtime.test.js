'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

// index.js initializes Firebase Admin before secure-runtime accesses Firestore.
require('../index');
const { _test } = require('../secure-runtime');

test('deterministic partnership IDs are stable regardless of user order', () => {
  assert.equal(_test.deterministicPartnershipId('alice', 'bob'), 'alice_bob');
  assert.equal(_test.deterministicPartnershipId('bob', 'alice'), 'alice_bob');
});

test('ordinary creative-writing language is not automatically flagged', () => {
  assert.deepEqual(
    _test.moderationFindings('I thought I would die laughing while we waited for the ride.'),
    []
  );
  assert.deepEqual(
    _test.moderationFindings('The villain tried to kill the spell, but the heroes escaped.'),
    []
  );
});

test('repeated characters are detected with a real regex backreference', () => {
  assert.ok(_test.moderationFindings('Noooooooooooo!').includes('character_repetition'));
});

test('short uppercase titles are not treated as abusive', () => {
  assert.deepEqual(_test.moderationFindings('BEST DAY EVER'), []);
});

test('long excessive capitalization is flagged', () => {
  const text = 'THIS IS A VERY LONG MESSAGE WRITTEN ALMOST ENTIRELY IN CAPITAL LETTERS';
  assert.ok(_test.moderationFindings(text).includes('excessive_caps'));
});

test('spam phrases and excessive links are detected', () => {
  assert.ok(_test.moderationFindings('Click here to get rich').includes('spam_keyword'));
  assert.ok(
    _test.moderationFindings('https://a.test https://b.test https://c.test https://d.test')
      .includes('excessive_urls')
  );
});
