<script>
  import '../../app.css';
  import { itemStatus, statusLabel, statusBadgeClass, remaining } from '$lib/utils.js';

  const event = {
    id: 'x7k2m',
    title: 'Grillabend bei Nico',
    date: 'Sa, 14. Juni',
    location: 'Marzili, Bern',
    note: 'Ab 17 Uhr, bring Sonnencreme',
  };

  let items = [
    { id: '1', name: 'Bier',                  quantity_total: 12, claims: [{ id: 'c1', guest_name: 'Lea', amount: 6 }, { id: 'c2', guest_name: 'Tom', amount: 3 }] },
    { id: '2', name: 'Salat',                  quantity_total: null, claims: [{ id: 'c3', guest_name: 'Anna', amount: 1 }] },
    { id: '3', name: 'Würste',                 quantity_total: 20, claims: [{ id: 'c4', guest_name: 'Max', amount: 10 }] },
    { id: '4', name: 'Kohle',                  quantity_total: null, claims: [] },
    { id: '5', name: 'Getränke alkoholfrei',   quantity_total: 8,  claims: [{ id: 'c5', guest_name: 'Sara', amount: 4 }, { id: 'c6', guest_name: 'Ben', amount: 4 }] },
    { id: '6', name: 'Teller & Besteck',       quantity_total: null, claims: [] },
  ];

  $: coveredCount = items.filter(i => itemStatus(i) === 'full').length;
  $: totalCount   = items.length;
  $: progressPct  = totalCount ? Math.round((coveredCount / totalCount) * 100) : 0;

  const guestName = 'Lea';
  const isAdmin = true;

  // Demo: inline delete state
  let deletingItemId = null;
  function removeItem(id) { items = items.filter(i => i.id !== id); deletingItemId = null; }

  // Demo: toast
  let toast = '';
  let toastTimer;
  function showToast(msg) { clearTimeout(toastTimer); toast = msg; toastTimer = setTimeout(() => toast = '', 2000); }

  // Demo: copied state
  let copiedGuest = false;
  let copiedAdmin = false;
  function fakeCopy(type) {
    if (type === 'guest') { copiedGuest = true; setTimeout(() => copiedGuest = false, 1500); }
    else { copiedAdmin = true; setTimeout(() => copiedAdmin = false, 1500); }
  }
</script>

<svelte:head><title>Demo – Grillabend bei Nico</title></svelte:head>

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

<main class="container" style="padding-top:2rem; padding-bottom:4rem;">
  <div class="fade-in" style="display:flex; flex-direction:column; gap:1.25rem;">

    <!-- Admin Banner -->
    <div class="admin-banner">
      <div>
        <p style="font-weight:800; font-size:0.95rem; margin-bottom:0.2rem;">🔑 Du bist der Ersteller — nur du siehst das hier.</p>
        <p style="font-size:0.82rem; color:var(--text-muted); margin-bottom:0.6rem;">Teile den Gast-Link mit allen. Den Admin-Link behältst du für dich.</p>
        <div style="display:flex; gap:0.5rem; flex-wrap:wrap;">
          <button class="btn btn-ghost" style="font-size:0.82rem; padding:0.3rem 0.75rem;" on:click={() => fakeopy('guest')}>
            {copiedGuest ? '✓ Kopiert!' : '🔗 Gast-Link kopieren'}
          </button>
          <button class="btn btn-ghost" style="font-size:0.82rem; padding:0.3rem 0.75rem;" on:click={() => fakeopy('admin')}>
            {copiedAdmin ? '✓ Kopiert!' : '🔒 Mein Admin-Link'}
          </button>
          <button class="btn btn-ghost" style="font-size:0.82rem; padding:0.3rem 0.75rem;">✏️ Bearbeiten</button>
        </div>
      </div>
    </div>

    <!-- Event Header -->
    <div class="card">
      <h1 style="font-size:2.4rem; color:var(--text); margin-bottom:0.4rem;">{event.title}</h1>
      <div style="display:flex; gap:0.75rem 1.25rem; flex-wrap:wrap; color:var(--text-muted); font-size:0.92rem; margin-bottom:1rem;">
        <span>📅 {event.date}</span>
        <span>📍 {event.location}</span>
        <span>💬 {event.note}</span>
      </div>
      <div>
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.45rem;">
          <span style="font-weight:700; font-size:0.95rem;">{coveredCount} von {totalCount} Dingen gedeckt</span>
          <span style="font-size:0.82rem; color:var(--text-muted); font-weight:600;">{progressPct}%</span>
        </div>
        <div class="progress-wrap"><div class="progress-bar" style="width:{progressPct}%;"></div></div>
      </div>
    </div>

    <!-- Items -->
    <div style="display:flex; flex-direction:column; gap:0.7rem;">
      {#each items as item (item.id)}
        {@const status = itemStatus(item)}
        {@const left   = remaining(item)}
        {@const isFull = status === 'full'}
        {@const isConfirmingDelete = deletingItemId === item.id}

        <div class="card" style="opacity:{isFull ? 0.65 : 1}; cursor:{isFull ? 'default' : 'pointer'};
          transition:box-shadow 0.15s, transform 0.15s;"
          on:mouseenter={e => { if (!isFull) { e.currentTarget.style.boxShadow='var(--shadow-hover)'; e.currentTarget.style.transform='translateY(-2px)'; }}}
          on:mouseleave={e => { e.currentTarget.style.boxShadow=''; e.currentTarget.style.transform=''; }}
        >
          <div style="display:flex; align-items:flex-start; justify-content:space-between; gap:1rem;">
            <div style="flex:1; min-width:0;">
              <div style="display:flex; align-items:baseline; gap:0.5rem; margin-bottom:0.2rem; flex-wrap:wrap;">
                <span style="font-family:var(--font-hand); font-size:1.4rem; {isFull ? 'text-decoration:line-through; color:var(--text-muted);' : ''}">{item.name}</span>
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
                        <button style="background:none;border:none;cursor:pointer;padding:0;line-height:1;font-size:0.75rem;color:inherit;opacity:0.55;margin-left:0.1rem;"
                          on:click|stopPropagation={() => showToast('Eintrag entfernt.')}>✕</button>
                      {/if}
                    </span>
                  {/each}
                </div>
              {:else if !isFull}
                <p style="font-size:0.8rem; color:var(--text-muted); margin-top:0.3rem; font-style:italic;">Sei der Erste! ✨</p>
              {/if}
            </div>

            <!-- Status + inline delete -->
            <div style="display:flex; align-items:center; gap:0.4rem; flex-shrink:0;">
              <span class={statusBadgeClass(status)}>{statusLabel(status)}</span>

              {#if isConfirmingDelete}
                <span style="display:flex; align-items:center; gap:0.3rem;">
                  <button class="btn btn-danger" style="padding:0.2rem 0.5rem; font-size:0.78rem;"
                    on:click|stopPropagation={() => { removeItem(item.id); showToast('Eintrag gelöscht.'); }}>Ja, löschen</button>
                  <button class="btn btn-ghost" style="padding:0.2rem 0.5rem; font-size:0.78rem;"
                    on:click|stopPropagation={() => deletingItemId = null}>Nein</button>
                </span>
              {:else}
                <button class="btn btn-ghost" style="padding:0.2rem 0.45rem; font-size:0.78rem; color:var(--text-muted);"
                  on:click|stopPropagation={() => deletingItemId = item.id} title="Eintrag löschen">✕</button>
              {/if}
            </div>
          </div>
        </div>
      {/each}
    </div>

    <!-- Add Item -->
    <div class="card" style="border:2px dashed var(--border); box-shadow:none; background:transparent;">
      <p style="font-weight:700; color:var(--text-muted); margin-bottom:0.75rem; font-size:0.88rem; text-transform:uppercase; letter-spacing:0.04em;">➕ Eintrag hinzufügen</p>
      <div style="display:flex; gap:0.5rem; flex-wrap:wrap;">
        <input class="input" type="text" placeholder="Was wird gebraucht?" style="flex:1; min-width:140px;" />
        <input class="input" type="number" placeholder="Anzahl" style="width:85px;" />
        <button class="btn btn-accent" on:click={() => showToast('Auf die Liste! ✅')}>+ Drauf</button>
      </div>
    </div>

  </div>
</main>
