import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
import { error } from '@sveltejs/kit';

function getSupabase() {
  return createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY);
}

export async function load({ params, url }) {
  const supabase = getSupabase();
  const { id } = params;
  const token = url.searchParams.get('token');

  const { data: event, error: evErr } = await supabase
    .from('events')
    .select('*')
    .eq('id', id)
    .single();

  if (evErr || !event) throw error(404, 'Event nicht gefunden');

  const isAdmin = token && token === event.admin_token;

  // Load items with their claims
  const { data: items } = await supabase
    .from('items')
    .select('*, claims(*)')
    .eq('event_id', id)
    .order('created_at', { ascending: true });

  return {
    event: {
      id: event.id,
      title: event.title,
      date: event.date,
      location: event.location,
      note: event.note,
    },
    items: items ?? [],
    isAdmin,
    adminToken: isAdmin ? token : null,
  };
}

export const actions = {
  // Add item (admin or guest)
  addItem: async ({ params, request }) => {
    const supabase = getSupabase();
    const data = await request.formData();
    const name = data.get('name')?.trim();
    const qty = parseInt(data.get('quantity_total'));
    const created_by = data.get('created_by') || 'guest';

    if (!name) return { success: false, error: 'Name fehlt' };

    const { error: e } = await supabase.from('items').insert({
      event_id: params.id,
      name,
      quantity_total: isNaN(qty) || qty <= 0 ? null : qty,
      created_by,
    });

    return e ? { success: false, error: e.message } : { success: true };
  },

  // Claim an item
  claim: async ({ params, request }) => {
    const supabase = getSupabase();
    const data = await request.formData();
    const item_id = data.get('item_id');
    const guest_name = data.get('guest_name')?.trim();
    const amount = parseInt(data.get('amount')) || 1;

    if (!item_id || !guest_name) return { success: false, error: 'Daten fehlen' };

    // Fetch item to check quantity
    const { data: item } = await supabase
      .from('items')
      .select('quantity_total, claims(amount)')
      .eq('id', item_id)
      .single();

    if (!item) return { success: false, error: 'Item nicht gefunden' };

    if (item.quantity_total != null) {
      const claimed = item.claims.reduce((s, c) => s + c.amount, 0);
      const left = item.quantity_total - claimed;
      if (amount > left) {
        return { success: false, raceCondition: true, remaining: left };
      }
    } else {
      // No qty = single claim only
      if (item.claims.length > 0) {
        return { success: false, error: 'Bereits übernommen' };
      }
    }

    const { error: e } = await supabase.from('claims').insert({ item_id, guest_name, amount });
    return e ? { success: false, error: e.message } : { success: true };
  },

  // Remove a claim
  removeClaim: async ({ request }) => {
    const supabase = getSupabase();
    const data = await request.formData();
    const claim_id = data.get('claim_id');
    const admin_token = data.get('admin_token');
    const event_id = data.get('event_id');
    const guest_name = data.get('guest_name');

    // Admin can delete any; guest can delete own by name
    if (admin_token) {
      const { data: ev } = await supabase.from('events').select('admin_token').eq('id', event_id).single();
      if (!ev || ev.admin_token !== admin_token) return { success: false, error: 'Kein Zugriff' };
      await supabase.from('claims').delete().eq('id', claim_id);
    } else {
      await supabase.from('claims').delete().eq('id', claim_id).eq('guest_name', guest_name);
    }

    return { success: true };
  },

  // Delete an item (admin only)
  deleteItem: async ({ request }) => {
    const supabase = getSupabase();
    const data = await request.formData();
    const item_id = data.get('item_id');
    const admin_token = data.get('admin_token');
    const event_id = data.get('event_id');

    const { data: ev } = await supabase.from('events').select('admin_token').eq('id', event_id).single();
    if (!ev || ev.admin_token !== admin_token) return { success: false, error: 'Kein Zugriff' };

    await supabase.from('items').delete().eq('id', item_id);
    return { success: true };
  },

  // Update event info (admin only)
  updateEvent: async ({ params, request }) => {
    const supabase = getSupabase();
    const data = await request.formData();
    const admin_token = data.get('admin_token');

    const { data: ev } = await supabase.from('events').select('admin_token').eq('id', params.id).single();
    if (!ev || ev.admin_token !== admin_token) return { success: false, error: 'Kein Zugriff' };

    const { error: e } = await supabase.from('events').update({
      title: data.get('title')?.trim(),
      date: data.get('date')?.trim() || null,
      location: data.get('location')?.trim() || null,
      note: data.get('note')?.trim() || null,
    }).eq('id', params.id);

    return e ? { success: false, error: e.message } : { success: true };
  },
};
