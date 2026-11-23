'use strict';

// Notification rules for QueueLess. Everything here is plain JavaScript with no
// Firebase imports, so it can be tested without a Firebase project. index.js
// connects it to Firestore and Firebase Cloud Messaging.
//
// Messages (see Notification_Plan.md):
//   N1 near turn: a waiting customer has 2 or fewer customers ahead. Sent once
//      per ticket. The called customer counts as ahead.
//   N2 called: the entry changes from waiting to called. Sent once per ticket.
// Served, skipped and left are shown inside the app only.

const NEAR_TURN_AHEAD = 2;

// Field written on the entry (by the Admin SDK only) once a message is sent.
const SENT_FLAG = {
  nearTurn: 'nearTurnNotified',
  called: 'calledNotified',
};

const ACTIVE_STATUSES = new Set(['waiting', 'called']);

const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

// Converts Firestore data to a plain entry. joinedAt becomes milliseconds.
function entryFromData(id, data) {
  const joinedAt = data.joinedAt;
  return {
    id,
    customerId: data.customerId,
    queueId: data.queueId,
    ticketNumber: Number(data.ticketNumber),
    joinedAt:
      joinedAt && typeof joinedAt.toMillis === 'function'
        ? joinedAt.toMillis()
        : Number(joinedAt) || 0,
    status: data.status,
    nearTurnNotified: data.nearTurnNotified === true,
    calledNotified: data.calledNotified === true,
  };
}

// Waiting and called entries in joining order. Ticket numbers break ties.
function activeEntries(entries) {
  return entries
    .filter((entry) => ACTIVE_STATUSES.has(entry.status))
    .sort(
      (a, b) => a.joinedAt - b.joinedAt || a.ticketNumber - b.ticketNumber,
    );
}

// Customers ahead of an entry: every active entry before it, including the
// called customer. Null when the entry is not active.
function customersAhead(entries, entryId) {
  const index = activeEntries(entries).findIndex(
    (entry) => entry.id === entryId,
  );
  return index < 0 ? null : index;
}

// Decides which messages an entry change should produce. `entries` are all
// entries of the queue after the change.
function planNotifications({ before, after, entries }) {
  if (!after) return [];
  // Writes that keep the status (for example the sent flags written by this
  // function) never produce messages, which also stops the function from
  // triggering itself.
  if (before && before.status === after.status) return [];

  const plan = [];
  if (
    before &&
    before.status === 'waiting' &&
    after.status === 'called' &&
    after.calledNotified !== true
  ) {
    plan.push({ type: 'called', entry: after });
  }
  for (const entry of activeEntries(entries)) {
    if (entry.status !== 'waiting' || entry.nearTurnNotified === true) {
      continue;
    }
    const ahead = customersAhead(entries, entry.id);
    if (ahead !== null && ahead <= NEAR_TURN_AHEAD) {
      plan.push({ type: 'nearTurn', entry, customersAhead: ahead });
    }
  }
  return plan;
}

function buildMessage(item, queueName, token) {
  const place = queueName || 'the queue';
  const ticket = item.entry.ticketNumber;
  const message = {
    token,
    data: {
      type: item.type,
      entryId: item.entry.id,
      queueId: item.entry.queueId,
    },
    android: { priority: 'high', ttl: 10 * 60 * 1000 },
  };
  if (item.type === 'called') {
    message.notification = {
      title: "It's your turn!",
      body: `Ticket #${ticket} has been called at ${place}. Please proceed now.`,
    };
    return message;
  }
  const ahead = item.customersAhead;
  const aheadText =
    ahead === 0
      ? 'You are next.'
      : ahead === 1
        ? 'Only 1 customer ahead.'
        : `Only ${ahead} customers ahead.`;
  message.notification = {
    title: 'Your turn is near',
    body: `Ticket #${ticket} at ${place}. ${aheadText} Please be ready.`,
  };
  return message;
}

// Sends one planned message. A message is claimed (flag set in a transaction)
// before it is sent, so two overlapping runs cannot both send it. The claim is
// released when sending fails, so a later change can try again.
async function deliver(item, queue, deps) {
  const { entry, type } = item;
  const result = { entryId: entry.id, type };
  const token = await deps.getToken(entry.customerId);
  // Without a token nothing is claimed, so the message can still be sent after
  // the customer's device registers.
  if (!token) return { ...result, outcome: 'no-token' };

  const flag = SENT_FLAG[type];
  if (!(await deps.claim(entry.id, flag))) {
    return { ...result, outcome: 'already-sent' };
  }
  try {
    await deps.send(buildMessage(item, queue && queue.name, token));
    return { ...result, outcome: 'sent' };
  } catch (error) {
    await deps.release(entry.id, flag);
    if (error && DEAD_TOKEN_CODES.has(error.code)) {
      await deps.clearToken(entry.customerId);
      return { ...result, outcome: 'invalid-token' };
    }
    return { ...result, outcome: 'failed', error: String(error && error.message) };
  }
}

// Entry point used by the Firestore trigger. `deps` provides loadEntries,
// getQueue, getToken, claim, release, clearToken and send.
async function processEntryWrite({ before, after }, deps) {
  if (!after) return [];
  if (before && before.status === after.status) return [];

  const entries = await deps.loadEntries(after.queueId);
  const plan = planNotifications({ before, after, entries });
  if (plan.length === 0) return [];

  const queue = await deps.getQueue(after.queueId);
  const results = [];
  for (const item of plan) {
    try {
      results.push(await deliver(item, queue, deps));
    } catch (error) {
      // One failing message must not block the others.
      results.push({
        entryId: item.entry.id,
        type: item.type,
        outcome: 'failed',
        error: String(error && error.message),
      });
    }
  }
  return results;
}

module.exports = {
  NEAR_TURN_AHEAD,
  SENT_FLAG,
  entryFromData,
  activeEntries,
  customersAhead,
  planNotifications,
  buildMessage,
  processEntryWrite,
};