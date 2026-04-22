import { nanoid } from 'nanoid';

export function generateEventId() {
  return nanoid(5);
}

export function generateToken() {
  return crypto.randomUUID();
}

/** Returns total claimed amount for an item given its claims array */
export function totalClaimed(claims) {
  return claims.reduce((sum, c) => sum + c.amount, 0);
}

/** Remaining amount for an item */
export function remaining(item) {
  if (item.quantity_total == null) return null;
  return item.quantity_total - totalClaimed(item.claims ?? []);
}

/** Status: 'open' | 'partial' | 'full' */
export function itemStatus(item) {
  const claims = item.claims ?? [];
  if (claims.length === 0) return 'open';
  if (item.quantity_total == null) return 'full'; // no qty = single claim takes it
  const claimed = totalClaimed(claims);
  if (claimed >= item.quantity_total) return 'full';
  if (claimed > 0) return 'partial';
  return 'open';
}

export function statusLabel(status) {
  if (status === 'full')    return 'Gedeckt ✓';
  if (status === 'partial') return 'Teilweise';
  return 'Offen';
}

export function statusBadgeClass(status) {
  if (status === 'full')    return 'badge badge-full';
  if (status === 'partial') return 'badge badge-partial';
  return 'badge badge-open';
}

/** localStorage helpers */
export function getStoredName() {
  if (typeof localStorage === 'undefined') return null;
  return localStorage.getItem('wbw_name') || null;
}

export function setStoredName(name) {
  if (typeof localStorage === 'undefined') return;
  localStorage.setItem('wbw_name', name);
}
