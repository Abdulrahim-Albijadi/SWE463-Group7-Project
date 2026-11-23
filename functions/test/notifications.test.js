'use strict';

const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const {
  buildMessage,
  customersAhead,
  entryFromData,
  planNotifications,
  processEntryWrite,
} = require('../notifications');

// Test helpers -------------------------------------------------------------

function entry(ticket, status, extra = {}) {
  return {
    id: `e${ticket}`,
    customerId: `c${ticket}`,
    queueId: 'q1',
    ticketNumber: ticket,
    joinedAt: ticket * 60000,
    status,
    nearTurnNotified: false,
    calledNotified: false,
    ...extra,
  };
}

// In-memory stand-in for Firestore and FCM. It follows the same rules the real
// dependencies follow: claim is all-or-nothing, release clears the flag.
function fakeWorld({ tokens = {}, sendFails = null } = {}) {
  const world = {
    entries: new Map(),
    tokens: { ...tokens },
    sent: [],
    sendFails,
    queue: { name: 'Campus Barber' },
  };
  world.deps = {
    loadEntries: async (queueId) =>
      [...world.entries.values()]
        .filter((e) => e.queueId === queueId)
        .map((e) => ({ ...e })),
    getQueue: async () => world.queue,
    getToken: async (customerId) => world.tokens[customerId] || null,
    claim: async (entryId, flag) => {
      const stored = world.entries.get(entryId);
      if (!stored || stored[flag] === true) return false;
      stored[flag] = true;
      return true;
    },
    release: async (entryId, flag) => {
      world.entries.get(entryId)[flag] = false;
    },
    clearToken: async (customerId) => {
      delete world.tokens[customerId];
    },
    send: async (message) => {
      if (world.sendFails) throw world.sendFails;
      world.sent.push(message);
    },
  };
  // Applies a write like Firestore would and runs the function on it.
  world.write = async (next) => {
    const before = world.entries.has(next.id)
      ? { ...world.entries.get(next.id) }
      : null;
    const stored = { ...(before || {}), ...next };
    world.entries.set(next.id, stored);
    return processEntryWrite({ before, after: { ...stored } }, world.deps);
  };
  return world;
}

const allTokens = { c1: 't1', c2: 't2', c3: 't3', c4: 't4' };

// Decision logic -----------------------------------------------------------

describe('customersAhead', () => {
  it('counts the called customer as ahead', () => {
    const entries = [
      entry(1, 'called'),
      entry(2, 'waiting'),
      entry(3, 'waiting'),
    ];
    assert.equal(customersAhead(entries, 'e3'), 2);
  });

  it('orders by joining time and uses the ticket number as a tie-break', () => {
    const entries = [
      entry(2, 'waiting', { joinedAt: 5 }),
      entry(1, 'waiting', { joinedAt: 5 }),
    ];
    assert.equal(customersAhead(entries, 'e1'), 0);
    assert.equal(customersAhead(entries, 'e2'), 1);
  });

  it('is null for finished entries', () => {
    assert.equal(customersAhead([entry(1, 'served')], 'e1'), null);
  });
});

describe('planNotifications', () => {
  it('plans near turn for a waiting customer with two ahead', () => {
    const entries = [
      entry(1, 'waiting', { nearTurnNotified: true }),
      entry(2, 'waiting', { nearTurnNotified: true }),
      entry(3, 'waiting'),
    ];
    const plan = planNotifications({
      before: null,
      after: entries[2],
      entries,
    });
    assert.deepEqual(
      plan.map((p) => [p.type, p.entry.id, p.customersAhead]),
      [['nearTurn', 'e3', 2]],
    );
  });

  it('does not plan near turn with three ahead', () => {
    const entries = [
      entry(1, 'waiting', { nearTurnNotified: true }),
      entry(2, 'waiting', { nearTurnNotified: true }),
      entry(3, 'waiting', { nearTurnNotified: true }),
      entry(4, 'waiting'),
    ];
    const plan = planNotifications({
      before: null,
      after: entries[3],
      entries,
    });
    assert.deepEqual(plan, []);
  });

  it('plans near turn when a customer joins with only one ahead', () => {
    const entries = [
      entry(1, 'waiting', { nearTurnNotified: true }),
      entry(2, 'waiting'),
    ];
    const plan = planNotifications({
      before: null,
      after: entries[1],
      entries,
    });
    assert.equal(plan.length, 1);
    assert.equal(plan[0].customersAhead, 1);
  });

  it('plans near turn when two customers leave at once and the count drops', () => {
    // Four waiting, so customer 4 had three ahead. Customers 2 and 3 leave and
    // customer 3's write is the last one seen.
    const before = entry(3, 'waiting', { nearTurnNotified: true });
    const after = entry(3, 'left', { nearTurnNotified: true });
    const entries = [
      entry(1, 'waiting', { nearTurnNotified: true }),
      entry(2, 'left', { nearTurnNotified: true }),
      after,
      entry(4, 'waiting'),
    ];
    const plan = planNotifications({ before, after, entries });
    assert.deepEqual(
      plan.map((p) => [p.type, p.entry.id, p.customersAhead]),
      [['nearTurn', 'e4', 1]],
    );
  });

  it('plans called when the entry changes from waiting to called', () => {
    const before = entry(1, 'waiting', { nearTurnNotified: true });
    const after = entry(1, 'called', { nearTurnNotified: true });
    const plan = planNotifications({ before, after, entries: [after] });
    assert.deepEqual(
      plan.map((p) => [p.type, p.entry.id]),
      [['called', 'e1']],
    );
  });

  it('does not plan anything when the status did not change', () => {
    // This is what happens after the function writes a sent flag.
    const before = entry(1, 'waiting');
    const after = entry(1, 'waiting', { nearTurnNotified: true });
    assert.deepEqual(
      planNotifications({ before, after, entries: [after] }),
      [],
    );
  });

  it('does not plan served, skipped or left changes as messages', () => {
    for (const status of ['served', 'skipped', 'left']) {
      const before = entry(1, 'called', {
        nearTurnNotified: true,
        calledNotified: true,
      });
      const after = { ...before, status };
      assert.deepEqual(
        planNotifications({ before, after, entries: [after] }),
        [],
      );
    }
  });

  it('plans nothing when the entry was deleted', () => {
    assert.deepEqual(
      planNotifications({ before: entry(1, 'waiting'), after: null, entries: [] }),
      [],
    );
  });
});

describe('buildMessage', () => {
  it('writes the near turn message', () => {
    const message = buildMessage(
      { type: 'nearTurn', entry: entry(12, 'waiting'), customersAhead: 2 },
      'Campus Barber',
      'tok',
    );
    assert.equal(message.token, 'tok');
    assert.equal(message.notification.title, 'Your turn is near');
    assert.equal(
      message.notification.body,
      'Ticket #12 at Campus Barber. Only 2 customers ahead. Please be ready.',
    );
    assert.deepEqual(message.data, {
      type: 'nearTurn',
      entryId: 'e12',
      queueId: 'q1',
    });
  });

  it('writes the singular and the next-in-line texts', () => {
    const one = buildMessage(
      { type: 'nearTurn', entry: entry(2, 'waiting'), customersAhead: 1 },
      'Campus Barber',
      'tok',
    );
    const zero = buildMessage(
      { type: 'nearTurn', entry: entry(1, 'waiting'), customersAhead: 0 },
      'Campus Barber',
      'tok',
    );
    assert.match(one.notification.body, /Only 1 customer ahead\./);
    assert.match(zero.notification.body, /You are next\./);
  });

  it('writes the called message and falls back when the queue is unknown', () => {
    const message = buildMessage(
      { type: 'called', entry: entry(12, 'called') },
      null,
      'tok',
    );
    assert.equal(message.notification.title, "It's your turn!");
    assert.equal(
      message.notification.body,
      'Ticket #12 has been called at the queue. Please proceed now.',
    );
  });
});

describe('entryFromData', () => {
  it('converts a Firestore timestamp to milliseconds', () => {
    const converted = entryFromData('e1', {
      customerId: 'c1',
      queueId: 'q1',
      ticketNumber: 3,
      joinedAt: { toMillis: () => 123456 },
      status: 'waiting',
    });
    assert.equal(converted.joinedAt, 123456);
    assert.equal(converted.ticketNumber, 3);
    assert.equal(converted.nearTurnNotified, false);
    assert.equal(converted.calledNotified, false);
  });
});

// The demonstration flow from the Phase 3 plan -------------------------------

describe('demonstration flow', () => {
  it('three customers join, the provider calls and serves each in turn', async () => {
    const world = fakeWorld({ tokens: allTokens });
    const join = (n) =>
      world.write(entry(n, 'waiting', { nearTurnNotified: false }));

    const first = await join(1);
    assert.deepEqual(first.map((r) => [r.entryId, r.type, r.outcome]), [
      ['e1', 'nearTurn', 'sent'],
    ]);
    await join(2);
    const third = await join(3);
    assert.deepEqual(third.map((r) => [r.entryId, r.outcome]), [
      ['e3', 'sent'],
    ]);
    assert.match(
      world.sent.at(-1).notification.body,
      /Ticket #3 at Campus Barber\. Only 2 customers ahead\./,
    );
    assert.equal(world.sent.length, 3);

    // Calling customer 1 sends only the called message.
    const called = await world.write({ id: 'e1', status: 'called' });
    assert.deepEqual(called.map((r) => [r.entryId, r.type, r.outcome]), [
      ['e1', 'called', 'sent'],
    ]);
    assert.equal(world.sent.at(-1).notification.title, "It's your turn!");

    // Serving, then calling customer 2 and customer 3.
    assert.deepEqual(await world.write({ id: 'e1', status: 'served' }), []);
    await world.write({ id: 'e2', status: 'called' });
    await world.write({ id: 'e2', status: 'served' });
    const lastCall = await world.write({ id: 'e3', status: 'called' });
    assert.deepEqual(lastCall.map((r) => [r.entryId, r.type, r.outcome]), [
      ['e3', 'called', 'sent'],
    ]);
    // Three near turn messages and three called messages in total.
    assert.equal(world.sent.length, 6);
  });

  it('does not send again when the same change is delivered twice', async () => {
    const world = fakeWorld({ tokens: allTokens });
    await world.write(entry(1, 'waiting'));
    assert.equal(world.sent.length, 1);

    // The same event delivered again (Cloud Functions can deliver an event
    // twice). The fresh read shows the sent flag, so nothing is planned.
    const again = await processEntryWrite(
      { before: null, after: { ...world.entries.get('e1') } },
      world.deps,
    );
    assert.deepEqual(again, []);
    assert.equal(world.sent.length, 1);
  });

  it('sends once when two runs overlap', async () => {
    const world = fakeWorld({ tokens: allTokens });
    world.entries.set('e1', entry(1, 'waiting'));
    const event = { before: null, after: { ...world.entries.get('e1') } };

    // Both runs read the entry before either one has claimed the flag.
    const [first, second] = await Promise.all([
      processEntryWrite(event, world.deps),
      processEntryWrite(event, world.deps),
    ]);

    const outcomes = [...first, ...second].map((r) => r.outcome).sort();
    assert.deepEqual(outcomes, ['already-sent', 'sent']);
    assert.equal(world.sent.length, 1);
  });
});

// Failure handling -------------------------------------------------------------

describe('failures', () => {
  it('skips a customer without a token and sends later once there is one', async () => {
    const world = fakeWorld({ tokens: {} });
    const joined = await world.write(entry(1, 'waiting'));
    assert.deepEqual(joined.map((r) => r.outcome), ['no-token']);
    assert.equal(world.entries.get('e1').nearTurnNotified, false);

    world.tokens.c1 = 't1';
    await world.write(entry(2, 'waiting'));
    // Customer 1 now has a token and receives the message that was skipped.
    // Customer 2 still has no token, so nothing is sent to them.
    assert.deepEqual(
      world.sent.map((message) => message.token),
      ['t1'],
    );
    assert.equal(world.entries.get('e1').nearTurnNotified, true);
    assert.equal(world.entries.get('e2').nearTurnNotified, false);
  });

  it('releases the claim when sending fails so a later change can retry', async () => {
    const world = fakeWorld({
      tokens: allTokens,
      sendFails: Object.assign(new Error('unavailable'), {
        code: 'messaging/server-unavailable',
      }),
    });
    const failed = await world.write(entry(1, 'waiting'));
    assert.deepEqual(failed.map((r) => r.outcome), ['failed']);
    assert.equal(world.entries.get('e1').nearTurnNotified, false);
    assert.equal(world.tokens.c1, 't1');

    world.sendFails = null;
    await world.write(entry(2, 'waiting'));
    const toCustomer1 = world.sent.filter((m) => m.token === 't1');
    assert.equal(toCustomer1.length, 1);
  });

  it('removes a token that FCM reports as no longer registered', async () => {
    const world = fakeWorld({
      tokens: allTokens,
      sendFails: Object.assign(new Error('gone'), {
        code: 'messaging/registration-token-not-registered',
      }),
    });
    const result = await world.write(entry(1, 'waiting'));
    assert.deepEqual(result.map((r) => r.outcome), ['invalid-token']);
    assert.equal(world.tokens.c1, undefined);
    assert.equal(world.entries.get('e1').nearTurnNotified, false);
  });

  it('keeps going when one message in the plan fails', async () => {
    const world = fakeWorld({ tokens: { c1: 't1', c2: 't2' } });
    world.entries.set('e1', entry(1, 'waiting'));
    world.entries.set('e2', entry(2, 'waiting'));
    const original = world.deps.getToken;
    world.deps.getToken = async (customerId) => {
      if (customerId === 'c1') throw new Error('lookup failed');
      return original(customerId);
    };
    const results = await processEntryWrite(
      { before: null, after: { ...world.entries.get('e2') } },
      world.deps,
    );
    assert.deepEqual(
      results.map((r) => [r.entryId, r.outcome]),
      [
        ['e1', 'failed'],
        ['e2', 'sent'],
      ],
    );
  });
});