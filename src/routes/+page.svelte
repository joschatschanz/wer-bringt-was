<script>
  import '../app.css';
  import { generateEventId, generateToken } from '$lib/utils.js';
  import { supabase } from '$lib/supabase.js';
  import { goto } from '$app/navigation';
  import DatePicker from '$lib/DatePicker.svelte';
  import LocationPicker from '$lib/LocationPicker.svelte';

  let title = '';
  let date = '';
  let location = '';
  let note = '';
  let itemName = '';
  let itemQty = '';
  let items = [];
  let loading = false;
  let error = '';

  function addItem() {
    const name = itemName.trim();
    if (!name) return;
    const qty = parseInt(itemQty);
    items = [...items, { name, quantity_total: isNaN(qty) || qty <= 0 ? null : qty }];
    itemName = '';
    itemQty = '';
  }

  function removeItem(i) {
    items = items.filter((_, idx) => idx !== i);
  }

  function handleItemKeydown(e) {
    if (e.key === 'Enter') { e.preventDefault(); addItem(); }
  }

  async function createEvent() {
    if (!title.trim()) { error = 'Bitte gib einen Titel ein.'; return; }
    loading = true;
    error = '';

    const id = generateEventId();
    const admin_token = generateToken();

    const { error: evErr } = await supabase.from('events').insert({
      id,
      admin_token,
      title: title.trim(),
      date: date.trim() || null,
      location: location.trim() || null,
      note: note.trim() || null,
    });

    if (evErr) { error = 'Fehler beim Erstellen: ' + evErr.message; loading = false; return; }

    if (items.length > 0) {
      const { error: itemErr } = await supabase.from('items').insert(
        items.map(item => ({ event_id: id, name: item.name, quantity_total: item.quantity_total, created_by: 'creator' }))
      );
      if (itemErr) { error = 'Items konnten nicht gespeichert werden: ' + itemErr.message; loading = false; return; }
    }

    goto(`/r/${id}?token=${admin_token}`);
  }
</script>

<svelte:head><title>Was bringst du mit?</title></svelte:head>

<main class="container" style="padding-top: 3rem; padding-bottom: 4rem;">
  <div class="slide-up">
    <div style="text-align:center; margin-bottom:2.5rem;">
      <h1 style="font-size:3rem; color:var(--primary); margin-bottom:0.5rem;">Was bringst du mit?</h1>
      <p style="color:var(--text-muted); font-size:1.1rem;">Erstell eine Liste, teil den Link — fertig.</p>
    </div>

    <div class="card" style="display:flex; flex-direction:column; gap:1.25rem;">
      <!-- Event-Infos -->
      <div class="field">
        <label for="title">Event-Name *</label>
        <input id="title" class="input" type="text" placeholder="z.B. Grillabend bei Nico" bind:value={title} />
      </div>

      <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem;">
        <div class="field">
          <label>Datum</label>
          <DatePicker bind:value={date} />
        </div>
        <div class="field">
          <label>Ort</label>
          <LocationPicker bind:value={location} />
        </div>
      </div>

      <div class="field">
        <label for="note">Notiz</label>
        <input id="note" class="input" type="text" placeholder="z.B. Ab 17 Uhr, bring Sonnencreme" bind:value={note} />
      </div>

      <hr style="border:none; border-top:1.5px solid var(--border);" />

      <!-- Items hinzufügen -->
      <div>
        <p style="font-size:0.85rem; font-weight:700; color:var(--text-muted); text-transform:uppercase; letter-spacing:.05em; margin-bottom:0.75rem;">Was wird gebraucht?</p>

        {#if items.length > 0}
          <ul style="list-style:none; display:flex; flex-direction:column; gap:0.5rem; margin-bottom:0.75rem;">
            {#each items as item, i}
              <li style="display:flex; align-items:center; gap:0.75rem; background:var(--bg); padding:0.5rem 0.75rem; border-radius:var(--radius-sm);">
                <span style="flex:1; font-family:var(--font-hand); font-size:1.1rem;">{item.name}</span>
                {#if item.quantity_total}
                  <span class="badge badge-open">{item.quantity_total}×</span>
                {/if}
                <button class="btn btn-danger" style="padding:0.25rem 0.6rem; font-size:0.8rem;" on:click={() => removeItem(i)}>✕</button>
              </li>
            {/each}
          </ul>
        {/if}

        <div style="display:flex; gap:0.5rem; align-items:center;">
          <input
            class="input"
            type="text"
            placeholder="Was wird gebraucht?"
            bind:value={itemName}
            on:keydown={handleItemKeydown}
            style="flex:1;"
          />
          <input
            class="input"
            type="number"
            placeholder="Anzahl"
            bind:value={itemQty}
            on:keydown={handleItemKeydown}
            style="width:90px;"
            min="1"
          />
          <button class="btn btn-ghost" on:click={addItem} style="white-space:nowrap;">+ Noch was drauf</button>
        </div>
      </div>

      {#if error}
        <p style="color:#B91C1C; font-size:0.9rem; font-weight:600;">{error}</p>
      {/if}

      <button
        class="btn btn-primary"
        style="width:100%; justify-content:center; font-size:1.1rem; padding:0.8rem;"
        on:click={createEvent}
        disabled={loading}
      >
        {loading ? 'Wird erstellt...' : 'Liste erstellen →'}
      </button>
    </div>
  </div>
</main>
