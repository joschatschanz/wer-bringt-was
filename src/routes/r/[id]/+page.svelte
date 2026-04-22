<script>
  import '../../../app.css';
  import { onMount, onDestroy, tick } from 'svelte';
  import DatePicker from '$lib/DatePicker.svelte';
  import LocationPicker from '$lib/LocationPicker.svelte';
  import { page } from '$app/stores';
  import { invalidateAll } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';
  import {
    totalClaimed, remaining, itemStatus, statusLabel, statusBadgeClass,
    getStoredName, setStoredName
  } from '$lib/utils.js';

  export let data;

  $: event     = data.event;
  $: items     = data.items;
  $: isAdmin   = data.isAdmin;
  $: token     = $page.url.searchParams.get('token');

  $: coveredCount = items.filter(i => itemStatus(i) === 'full').length;
  $: totalCount   = items.length;
  $: progressPct  = totalCount ? Math.round((coveredCount / totalCount) * 100) : 0;
  $: allCovered   = totalCount > 0 && coveredCount === totalCount;

  // ── Guest name ─────────────────────────────────────────────────
  let guestName = '';
  let showNameModal = false;
  let pendingAction = null;
  let editingOwnName = false;

  onMount(() => {
    guestName = getStoredName() || '';
    startPolling();
    document.addEventListener('visibilitychange', onVisibilityChange);
  });
  onDestroy(() => {
    clearInterval(pollInterval);
    document.removeEventListener('visibilitychange', onVisibilityChange);
  });

  // ── Polling (pauses when tab is hidden) ─────────────────────────
  let pollInterval;
  function startPolling() {
    clearInterval(pollInterval);
    pollInterval = setInterval(() => invalidateAll(), 10000);
  }
  function onVisibilityChange() {
    if (document.hidden) {
      clearInterval(pollInterval);
    } else {
      invalidateAll();
      startPolling();
    }
  }

  // ── Escape key handler ─────────────────────────────────────────
  function handleKeydown(e) {
    if (e.key !== 'Escape') return;
    if (showNameModal) { showNameModal = false; pendingAction = null; return; }
    if (activeItemId)  { closeClaim(); return; }
    if (editing)       { editing = false; return; }
    if (deletingItemId) { deletingItemId = null; return; }
  }

  // ── Toast ──────────────────────────────────────────────────────
  let toast = '';
  let toastTimer;
  function showToast(msg) {
    clearTimeout(toastTimer);
    toast = msg;
    toastTimer = setTimeout(() => toast = '', 2200);
  }

  // ── Claim ──────────────────────────────────────────────────────
  let activeItemId = null;
  let claimAmount  = 1;
  let claimError   = '';
  let claimLoading = false;
  let claimInputEl;

  function openClaim(item) {
    if (itemStatus(item) === 'full') return;
    activeItemId = item.id;
    claimAmount  = remaining(item) ?? 1;
    claimError   = '';
    tick().then(() => claimInputEl?.focus());
  }

  function closeClaim() {
    activeItemId = null;
    claimError   = '';
  }

  async function submitClaim(item) {
    if (!guestName.trim()) {
      pendingAction = { type: 'claim', item };
      showNameModal = true;
      return;
    }
    claimLoading = true;
    claimError   = '';

    const { data: fresh } = await supabase
      .from('items')
      .select('quantity_total, claims(amount)')
      .eq('id', item.id)
      .single();

    if (fresh?.quantity_total != null) {
      const claimed = fresh.claims.reduce((s, c) => s + c.amount, 0);
      const left    = fresh.quantity_total - claimed;
      if (claimAmount > left) {
        claimError   = left > 0
          ? `Jemand war schneller — noch ${left} übrig.`
          : 'Leider schon komplett gedeckt.';
        claimAmount  = left > 0 ? left : 1;
        claimLoading = false;
        return;
      }
    } else if (fresh?.claims?.length > 0) {
      claimError   = 'Jemand hat das gerade übernommen.';
      claimLoading = false;
      return;
    }

    const { error: e } = await supabase.from('claims').insert({
      item_id:    item.id,
      guest_name: guestName,
      amount:     claimAmount,
    });

    if (e) { claimError = 'Fehler — bitte nochmal versuchen.'; claimLoading = false; return; }

    claimLoading = false;
    activeItemId = null;
    showToast('Eingetragen! 🙌');
    await invalidateAll();
  }

  async function removeClaim(claim) {
    await supabase.from('claims').delete().eq('id', claim.id);
    showToast('Eintrag entfernt.');
    await invalidateAll();
  }

  // ── Add item ───────────────────────────────────────────────────
  let guestItemName    = '';
  let guestItemQty     = '';
  let guestItemLoading = false;
  let guestItemInputEl;

  let adminItemName    = '';
  let adminItemQty     = '';
  let adminItemLoading = false;
  let adminItemInputEl;

  async function addItem(isAdminAdd) {
    const name = isAdminAdd ? adminItemName.trim() : guestItemName.trim();
    if (!name) return;

    if (!isAdminAdd && !guestName.trim()) {
      pendingAction = { type: 'addItem' };
      showNameModal = true;
      return;
    }

    if (isAdminAdd) adminItemLoading = true;
    else            guestItemLoading = true;

    const rawQty = isAdminAdd ? adminItemQty : guestItemQty;
    const qty = parseInt(rawQty);

    await supabase.from('items').insert({
      event_id:       event.id,
      name,
      quantity_total: isNaN(qty) || qty <= 0 ? null : qty,
      created_by:     isAdminAdd ? 'creator' : guestName,
    });

    if (isAdminAdd) {
      adminItemName    = '';
      adminItemQty     = '';
      adminItemLoading = false;
      await tick();
      adminItemInputEl?.focus();
    } else {
      guestItemName    = '';
      guestItemQty     = '';
      guestItemLoading = false;
      await tick();
      guestItemInputEl?.focus();
    }

    showToast('Auf die Liste! ✅');
    await invalidateAll();
  }

  // ── Admin: inline delete confirmation ─────────────────────────
  let deletingItemId = null;

  async function confirmDeleteItem(itemId) {
    await supabase.from('items').delete().eq('id', itemId);
    deletingItemId = null;
    showToast('Eintrag gelöscht.');
    await invalidateAll();
  }

  // ── Admin: edit event ─────────────────────────────────────────
  let editing   = false;
  let editTitle = '';
  let editDate  = '';
  let editLoc   = '';
  let editNote  = '';
  let editTitleEl;

  function startEdit() {
    editTitle = event.title;
    editDate  = event.date     ?? '';
    editLoc   = event.location ?? '';
    editNote  = event.note     ?? '';
    editing   = true;
    tick().then(() => editTitleEl?.focus());
  }

  async function saveEdit() {
    if (!editTitle.trim()) return;
    await supabase.from('events').update({
      title:    editTitle.trim(),
      date:     editDate.trim()  || null,
      location: editLoc.trim()   || null,
      note:     editNote.trim()  || null,
    }).eq('id', event.id);
    editing = false;
    showToast('Gespeichert ✓');
    await invalidateAll();
  }

  // ── Name modal ─────────────────────────────────────────────────
  let nameInput    = '';
  let nameInputEl;

  function openNameModal(opts = {}) {
    pendingAction = opts.pending ?? null;
    editingOwnName = opts.edit ?? false;
    nameInput = editingOwnName ? guestName : '';
    showNameModal = true;
    tick().then(() => nameInputEl?.focus());
  }

  async function confirmName() {
    const name = nameInput.trim();
    if (!name) return;
    guestName = name;
    setStoredName(name);
    showNameModal  = false;
    editingOwnName = false;

    if (pendingAction?.type === 'claim')   { const a = pendingAction; pendingAction = null; await submitClaim(a.item); }
    else if (pendingAction?.type === 'addItem') { pendingAction = null; await addItem(false); }
    else pendingAction = null;

    nameInput = '';
  }

  // ── Copy links ─────────────────────────────────────────────────
  let copiedGuest = false;
  let copiedAdmin = false;

  function copyLink(type) {
    const base = window.location.origin;
    if (type === 'guest') {
      navigator.clipboard.writeText(`${base}/r/${event.id}`);
      copiedGuest = true;
      setTimeout(() => copiedGuest = false, 1500);
    } else {
      navigator.clipboard.writeText(`${base}/r/${event.id}?token=${token}`);
      copiedAdmin = true;
      setTimeout(() => copiedAdmin = false, 1500);
    }
  }
</script>

<svelte:head><title>{event.title} – Wer bringt was?</title></svelte:head>
<svelte:window on:keydown={handleKeydown} />

<!-- Toast -->
{#if toast}
  <div style="
    position:fixed; bottom:1.5rem; left:50%; transform:translateX(-50%);
    background:var(--text); color:white;
    padding:0.6rem 1.25rem; border-radius:99px;
    font-size:0.9rem; font-weight:600;
    box-shadow:0 4px 20px rgba(0,0,0,0.2);
    z-index:200; pointer-events:none;
    animation:slideUp 0.25s ease;
  ">{toast}</div>
{/if}

<!-- Name Modal -->
{#if showNameModal}
  <div class="modal-overlay" on:click|self={() => { showNameModal = false; pendingAction = null; }} role="dialog" aria-modal="true">
    <div class="modal slide-up" style="text-align:center;">
      <h2 style="font-size:2rem; color:var(--primary); margin-bottom:0.5rem;">
        {editingOwnName ? 'Name ändern' : 'Wie heisst du?'}
      </h2>
      <p style="color:var(--text-muted); font-size:0.9rem; margin-bottom:1rem;">
        {editingOwnName ? 'So wirst du auf der Liste angezeigt.' : 'So werden deine Einträge auf der Liste angezeigt.'}
      </p>
      <input
        class="input"
        type="text"
        placeholder="Dein Name"
        bind:value={nameInput}
        bind:this={nameInputEl}
        on:keydown={e => e.key === 'Enter' && confirmName()}
        style="margin-bottom:1rem; font-size:1.1rem; text-align:center;"
      />
      <button class="btn btn-primary" style="width:100%; justify-content:center;" on:click={confirmName}>
        {editingOwnName ? 'Speichern' : 'Los geht\'s →'}
      </button>
    </div>
  </div>
{/if}

<!-- Claim Modal -->
{#if activeItemId}
  {@const activeItem = items.find(i => i.id === activeItemId)}
  <div class="modal-overlay" on:click|self={closeClaim} role="dialog" aria-modal="true">
    <div class="modal slide-up">
      <h2 style="font-size:1.9rem; color:var(--primary); margin-bottom:0.25rem;">{activeItem?.name}</h2>

      {#if activeItem?.quantity_total != null}
        <p style="color:var(--text-muted); margin-bottom:1.25rem;">
          Noch <strong>{remaining(activeItem)}</strong> von {activeItem.quantity_total} verfügbar
        </p>
        <div class="field" style="margin-bottom:1rem;">
          <label for="claim-amt">Wie viel bringst du?</label>
          <input
            id="claim-amt"
            class="input"
            type="number"
            min="1"
            max={remaining(activeItem)}
            bind:value={claimAmount}
            bind:this={claimInputEl}
            style="font-size:1.2rem; text-align:center;"
          />
        </div>
      {:else}
        <p style="color:var(--text-muted); margin-bottom:1.5rem;">Übernimmst du das?</p>
      {/if}

      {#if claimError}
        <p style="color:#B91C1C; font-size:0.9rem; font-weight:600; margin-bottom:0.75rem; background:#FEF2F2; padding:0.5rem 0.75rem; border-radius:var(--radius-sm);">{claimError}</p>
      {/if}

      <div style="display:flex; gap:0.75rem;">
        <button class="btn btn-ghost" style="flex:1; justify-content:center;" on:click={closeClaim}>Abbrechen</button>
        <button
          class="btn btn-primary"
          style="flex:1; justify-content:center;"
          on:click={() => submitClaim(activeItem)}
          disabled={claimLoading}
        >
          {claimLoading ? '...' : activeItem?.quantity_total != null ? 'Ich bring einen Teil' : 'Ich bring das'}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Edit Event Modal -->
{#if editing}
  <div class="modal-overlay" on:click|self={() => editing = false} role="dialog" aria-modal="true">
    <div class="modal slide-up" style="max-width:500px;">
      <h2 style="font-size:1.8rem; color:var(--primary); margin-bottom:1.25rem;">Event bearbeiten</h2>
      <div style="display:flex; flex-direction:column; gap:0.9rem;">
        <div class="field">
          <label for="et">Titel *</label>
          <input id="et" class="input" type="text" bind:value={editTitle} bind:this={editTitleEl} />
        </div>
        <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem;">
          <div class="field">
            <label>Datum</label>
            <DatePicker bind:value={editDate} />
          </div>
          <div class="field">
            <label>Ort</label>
            <LocationPicker bind:value={editLoc} />
          </div>
        </div>
        <div class="field">
          <label for="en">Notiz</label>
          <input id="en" class="input" type="text" placeholder="z.B. Ab 17 Uhr, Sonnencreme!" bind:value={editNote} />
        </div>
        <div style="display:flex; gap:0.75rem; margin-top:0.5rem;">
          <button class="btn btn-ghost" style="flex:1; justify-content:center;" on:click={() => editing = false}>Abbrechen</button>
          <button class="btn btn-primary" style="flex:1; justify-content:center;" on:click={saveEdit} disabled={!editTitle.trim()}>Speichern</button>
        </div>
      </div>
    </div>
  </div>
{/if}

<main class="container" style="padding-top:2rem; padding-bottom:5rem;">
  <div class="fade-in" style="display:flex; flex-direction:column; gap:1.25rem;">

    <!-- Admin Banner -->
    {#if isAdmin}
      <div class="admin-banner">
        <div style="flex:1;">
          <p style="font-weight:800; font-size:0.95rem; margin-bottom:0.2rem;">
            🔑 Du bist der Ersteller — nur du siehst das hier.
          </p>
          <p style="font-size:0.82rem; color:var(--text-muted); margin-bottom:0.6rem;">
            Teile den Gast-Link mit allen. Den Admin-Link behältst du für dich.
          </p>
          <div style="display:flex; gap:0.5rem; flex-wrap:wrap;">
            <button class="btn btn-ghost" style="font-size:0.82rem; padding:0.3rem 0.75rem;" on:click={() => copyLink('guest')}>
              {copiedGuest ? '✓ Kopiert!' : '🔗 Gast-Link kopieren'}
            </button>
            <button class="btn btn-ghost" style="font-size:0.82rem; padding:0.3rem 0.75rem;" on:click={() => copyLink('admin')}>
              {copiedAdmin ? '✓ Kopiert!' : '🔒 Mein Admin-Link'}
            </button>
            <button class="btn btn-ghost" style="font-size:0.82rem; padding:0.3rem 0.75rem;" on:click={startEdit}>✏️ Bearbeiten</button>
          </div>
        </div>
      </div>
    {:else}
      <!-- Guest: name display + share -->
      <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:0.5rem;">
        {#if guestName}
          <button
            class="chip"
            style="cursor:pointer; font-size:0.85rem;"
            on:click={() => openNameModal({ edit: true })}
            title="Namen ändern"
          >
            👤 {guestName} <span style="opacity:0.5; margin-left:0.2rem;">✏️</span>
          </button>
        {:else}
          <span style="font-size:0.85rem; color:var(--text-muted);">Klick auf ein Item um mitzumachen</span>
        {/if}
        <button class="btn btn-ghost" style="font-size:0.85rem;" on:click={() => copyLink('guest')}>
          {copiedGuest ? '✓ Kopiert!' : '🔗 Link teilen'}
        </button>
      </div>
    {/if}

    <!-- Event Header -->
    <div class="card">
      <h1 style="font-size:2.4rem; color:var(--text); margin-bottom:0.4rem; line-height:1.15;">{event.title}</h1>
      {#if event.date || event.location || event.note}
        <div style="display:flex; gap:0.75rem 1.25rem; flex-wrap:wrap; color:var(--text-muted); font-size:0.92rem; margin-bottom:1rem;">
          {#if event.date}     <span>📅 {event.date}</span>     {/if}
          {#if event.location} <span>📍 {event.location}</span> {/if}
          {#if event.note}     <span>💬 {event.note}</span>     {/if}
        </div>
      {/if}

      {#if totalCount > 0}
        <div>
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.45rem;">
            <span style="font-weight:700; font-size:0.95rem;">
              {#if allCovered}
                Alles drin! Wird ein guter Abend 🎉
              {:else if coveredCount === 0}
                Noch nichts gedeckt — fang an!
              {:else}
                {coveredCount} von {totalCount} Dingen gedeckt
              {/if}
            </span>
            <span style="font-size:0.82rem; color:var(--text-muted); font-weight:600;">{progressPct}%</span>
          </div>
          <div class="progress-wrap">
            <div class="progress-bar" style="width:{progressPct}%;"></div>
          </div>
        </div>
      {/if}
    </div>

    <!-- Item List -->
    {#if items.length === 0}
      <div class="card" style="text-align:center; padding:3rem 1.5rem; color:var(--text-muted);">
        <div style="font-size:3rem; margin-bottom:0.75rem;">🛒</div>
        <p style="font-size:1.1rem; font-weight:700; color:var(--text);">Noch nichts auf der Liste</p>
        <p style="font-size:0.9rem; margin-top:0.3rem;">Füg unten das erste Ding hinzu!</p>
      </div>
    {:else}
      <div style="display:flex; flex-direction:column; gap:0.7rem;">
        {#each items as item (item.id)}
          {@const status = itemStatus(item)}
          {@const left   = remaining(item)}
          {@const isFull = status === 'full'}
          {@const isConfirmingDelete = deletingItemId === item.id}

          <div
            class="card"
            style="transition:box-shadow 0.15s, transform 0.15s, opacity 0.2s; cursor:{isFull ? 'default' : 'pointer'}; opacity:{isFull ? 0.65 : 1};"
            on:click={() => !isFull && !isConfirmingDelete && openClaim(item)}
            on:mouseenter={e => { if (!isFull) { e.currentTarget.style.boxShadow = 'var(--shadow-hover)'; e.currentTarget.style.transform = 'translateY(-2px)'; } }}
            on:mouseleave={e => { e.currentTarget.style.boxShadow = ''; e.currentTarget.style.transform = ''; }}
            role="button"
            tabindex={isFull ? -1 : 0}
            on:keydown={e => e.key === 'Enter' && !isFull && openClaim(item)}
          >
            <div style="display:flex; align-items:flex-start; justify-content:space-between; gap:1rem;">
              <div style="flex:1; min-width:0;">
                <div style="display:flex; align-items:baseline; gap:0.5rem; margin-bottom:0.2rem; flex-wrap:wrap;">
                  <span style="
                    font-family:var(--font-hand); font-size:1.4rem;
                    {isFull ? 'text-decoration:line-through; color:var(--text-muted);' : ''}
                  ">{item.name}</span>
                  {#if item.quantity_total != null}
                    <span style="font-size:0.83rem; color:var(--text-muted);">
                      {isFull ? `(${item.quantity_total}× gedeckt)` : `noch ${left}× offen`}
                    </span>
                  {/if}
                </div>

                {#if (item.claims ?? []).length > 0}
                  <div style="display:flex; flex-wrap:wrap; gap:0.3rem; margin-top:0.4rem;">
                    {#each item.claims as claim (claim.id)}
                      {@const isOwn = claim.guest_name === guestName}
                      <span class="chip {isOwn ? 'chip-own' : ''}">
                        {claim.guest_name}{item.quantity_total != null ? ` ×${claim.amount}` : ''}
                        {#if isOwn || isAdmin}
                          <button
                            style="background:none;border:none;cursor:pointer;padding:0;line-height:1;font-size:0.75rem;color:inherit;opacity:0.55;margin-left:0.1rem;"
                            on:click|stopPropagation={() => removeClaim(claim)}
                            title="Eintrag entfernen"
                          >✕</button>
                        {/if}
                      </span>
                    {/each}
                  </div>
                {:else if !isFull}
                  <p style="font-size:0.8rem; color:var(--text-muted); margin-top:0.3rem; font-style:italic;">Sei der Erste! ✨</p>
                {/if}
              </div>

              <div style="display:flex; align-items:center; gap:0.4rem; flex-shrink:0;">
                <span class={statusBadgeClass(status)}>{statusLabel(status)}</span>

                {#if isAdmin}
                  {#if isConfirmingDelete}
                    <span style="display:flex; align-items:center; gap:0.3rem; font-size:0.8rem;">
                      <button
                        class="btn btn-danger"
                        style="padding:0.2rem 0.5rem; font-size:0.78rem;"
                        on:click|stopPropagation={() => confirmDeleteItem(item.id)}
                      >Ja, löschen</button>
                      <button
                        class="btn btn-ghost"
                        style="padding:0.2rem 0.5rem; font-size:0.78rem;"
                        on:click|stopPropagation={() => deletingItemId = null}
                      >Nein</button>
                    </span>
                  {:else}
                    <button
                      class="btn btn-ghost"
                      style="padding:0.2rem 0.45rem; font-size:0.78rem; color:var(--text-muted);"
                      on:click|stopPropagation={() => deletingItemId = item.id}
                      title="Eintrag löschen"
                    >✕</button>
                  {/if}
                {/if}
              </div>
            </div>
          </div>
        {/each}
      </div>
    {/if}

    <!-- Add Item -->
    <div class="card" style="border:2px dashed var(--border); box-shadow:none; background:transparent;">
      {#if isAdmin}
        <p style="font-weight:700; color:var(--text-muted); margin-bottom:0.75rem; font-size:0.88rem; text-transform:uppercase; letter-spacing:0.04em;">➕ Eintrag hinzufügen</p>
        <div style="display:flex; gap:0.5rem; flex-wrap:wrap;">
          <input
            class="input"
            type="text"
            placeholder="Was wird gebraucht?"
            bind:value={adminItemName}
            bind:this={adminItemInputEl}
            on:keydown={e => e.key === 'Enter' && addItem(true)}
            style="flex:1; min-width:140px;"
          />
          <input class="input" type="number" placeholder="Anzahl" bind:value={adminItemQty} min="1" style="width:85px;" on:keydown={e => e.key === 'Enter' && addItem(true)} />
          <button class="btn btn-accent" on:click={() => addItem(true)} disabled={adminItemLoading}>
            {adminItemLoading ? '...' : '+ Drauf'}
          </button>
        </div>
      {:else}
        <p style="font-weight:700; color:var(--text-muted); margin-bottom:0.75rem; font-size:0.88rem; text-transform:uppercase; letter-spacing:0.04em;">🙌 Ich bring noch was</p>
        <div style="display:flex; gap:0.5rem; flex-wrap:wrap;">
          <input
            class="input"
            type="text"
            placeholder="z.B. Chips, Sonnencreme..."
            bind:value={guestItemName}
            bind:this={guestItemInputEl}
            on:keydown={e => e.key === 'Enter' && addItem(false)}
            style="flex:1; min-width:140px;"
          />
          <input class="input" type="number" placeholder="Anzahl" bind:value={guestItemQty} min="1" style="width:85px;" on:keydown={e => e.key === 'Enter' && addItem(false)} />
          <button class="btn btn-accent" on:click={() => addItem(false)} disabled={guestItemLoading}>
            {guestItemLoading ? '...' : '+ Drauf'}
          </button>
        </div>
      {/if}
    </div>

  </div>
</main>
